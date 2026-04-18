import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class CatalogBundleService {
  const CatalogBundleService._();

  static const defaultFirebaseBucket = 'bindervault.firebasestorage.app';
  static const firebaseStorageHost = 'firebasestorage.googleapis.com';

  static String stripUtf8Bom(String value) {
    if (value.isNotEmpty && value.codeUnitAt(0) == 0xFEFF) {
      return value.substring(1);
    }
    return value;
  }

  static Uri manifestUri({required String bucket, required String game}) {
    return firebaseDownloadUriForObjectPath(
      bucket: bucket,
      game: game,
      objectPath: 'catalog/$game/latest/manifest.json',
    );
  }

  static Uri firebaseDownloadUriForObjectPath({
    required String bucket,
    required String game,
    required String objectPath,
  }) {
    final normalized = normalizeObjectPath(objectPath);
    final prefix = 'catalog/$game/';
    if (!normalized.startsWith(prefix)) {
      throw ArgumentError.value(
        objectPath,
        'objectPath',
        'Must start with $prefix',
      );
    }
    return Uri.https(
      firebaseStorageHost,
      '/v0/b/$bucket/o/${Uri.encodeComponent(normalized)}',
      const <String, String>{'alt': 'media'},
    );
  }

  static String normalizeObjectPath(String objectPath) {
    return objectPath.trim().replaceAll('\\', '/');
  }

  static bool isAllowedFirebaseCatalogUri(
    String? rawUri, {
    required String bucket,
    required String game,
  }) {
    if (rawUri == null || rawUri.trim().isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(rawUri.trim());
    if (uri == null) {
      return false;
    }
    if (uri.scheme.toLowerCase() != 'https') {
      return false;
    }
    if (uri.userInfo.isNotEmpty || uri.host.trim().isEmpty) {
      return false;
    }
    if (uri.host.toLowerCase() != firebaseStorageHost) {
      return false;
    }
    final expectedPrefix = '/v0/b/$bucket/o/';
    if (!uri.path.startsWith(expectedPrefix)) {
      return false;
    }
    final encodedObjectPath = uri.path.substring(expectedPrefix.length);
    final objectPath = Uri.decodeComponent(encodedObjectPath);
    final gamePrefix = 'catalog/$game/';
    if (!objectPath.startsWith(gamePrefix)) {
      return false;
    }
    final alt = uri.queryParameters['alt'];
    return alt == null || alt == 'media';
  }

  static Uri? resolveArtifactUri(
    CatalogBundleArtifact artifact, {
    required String bucket,
    required String game,
  }) {
    final downloadUrl = artifact.downloadUrl;
    if (downloadUrl != null && downloadUrl.trim().isNotEmpty) {
      final uri = Uri.tryParse(downloadUrl.trim());
      if (uri != null && uri.hasScheme) {
        return uri;
      }
    }

    final candidate = (artifact.path == null || artifact.path!.trim().isEmpty)
        ? artifact.name
        : artifact.path!.trim();
    if (candidate.isEmpty) {
      return null;
    }
    final absoluteUri = Uri.tryParse(candidate);
    if (absoluteUri != null && absoluteUri.hasScheme) {
      return absoluteUri;
    }

    final normalized = normalizeObjectPath(candidate);
    final objectPath = normalized.startsWith('catalog/$game/')
        ? normalized
        : 'catalog/$game/$normalized';
    try {
      return firebaseDownloadUriForObjectPath(
        bucket: bucket,
        game: game,
        objectPath: objectPath,
      );
    } on ArgumentError {
      return null;
    }
  }

  static CatalogManifest parseManifest(
    String rawJson, {
    required String expectedGame,
  }) {
    final parsed = jsonDecode(stripUtf8Bom(rawJson));
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('catalog_manifest_not_object');
    }
    return CatalogManifest.fromJson(parsed, expectedGame: expectedGame);
  }

  static Future<String> fetchJsonWithRetry({
    required http.Client client,
    required Uri uri,
    required String errorPrefix,
    int retryAttempts = 4,
    Duration requestTimeout = const Duration(seconds: 35),
  }) async {
    final headers = <String, String>{
      'accept': 'application/json',
      'user-agent': 'bindervault/1.0',
    };
    Object? lastError;
    for (var attempt = 1; attempt <= retryAttempts; attempt++) {
      try {
        final response = await client
            .get(uri, headers: headers)
            .timeout(requestTimeout);
        if (response.statusCode == 200) {
          return response.body;
        }
        final retryable =
            response.statusCode == 404 ||
            response.statusCode == 429 ||
            response.statusCode >= 500;
        if (!retryable || attempt == retryAttempts) {
          throw HttpException('${errorPrefix}_http_${response.statusCode}');
        }
        lastError = HttpException('${errorPrefix}_http_${response.statusCode}');
      } on TimeoutException catch (error) {
        lastError = error;
      } on SocketException catch (error) {
        lastError = error;
      } on http.ClientException catch (error) {
        lastError = error;
      }
      if (attempt < retryAttempts) {
        await Future<void>.delayed(_retryDelay(attempt));
      }
    }
    if (lastError is HttpException) {
      throw lastError;
    }
    if (lastError is TimeoutException) {
      throw SocketException('${errorPrefix}_timeout');
    }
    if (lastError is SocketException) {
      throw SocketException('${errorPrefix}_unreachable');
    }
    if (lastError is http.ClientException) {
      throw HttpException('${errorPrefix}_client_error');
    }
    throw HttpException('${errorPrefix}_failed');
  }

  static Duration _retryDelay(int attempt) {
    switch (attempt) {
      case 1:
        return const Duration(milliseconds: 600);
      case 2:
        return const Duration(milliseconds: 1300);
      default:
        return const Duration(seconds: 2);
    }
  }
}

class CatalogManifest {
  const CatalogManifest({
    required this.game,
    required this.version,
    required this.schemaVersion,
    required this.compatibilityVersion,
    required this.bundles,
    required this.raw,
    this.source,
    this.languages = const <String>[],
    this.artifacts = const <CatalogBundleArtifact>[],
  });

  factory CatalogManifest.fromJson(
    Map<String, dynamic> json, {
    required String expectedGame,
  }) {
    final game = (json['bundle'] as String?)?.trim().toLowerCase();
    if (game == null || game.isEmpty) {
      throw const FormatException('catalog_manifest_missing_bundle');
    }
    if (game != expectedGame.trim().toLowerCase()) {
      throw FormatException('catalog_manifest_bundle_mismatch:$game');
    }
    final version = (json['version'] as String?)?.trim();
    if (version == null || version.isEmpty) {
      throw const FormatException('catalog_manifest_missing_version');
    }
    final schemaVersion = (json['schema_version'] as num?)?.toInt();
    if (schemaVersion == null) {
      throw const FormatException('catalog_manifest_missing_schema_version');
    }
    final compatibilityVersion = (json['compatibility_version'] as num?)
        ?.toInt();
    if (compatibilityVersion == null) {
      throw const FormatException(
        'catalog_manifest_missing_compatibility_version',
      );
    }
    final rawBundles = json['bundles'];
    final bundles = rawBundles is List
        ? rawBundles
              .whereType<Map>()
              .map(
                (value) =>
                    CatalogBundle.fromJson(Map<String, dynamic>.from(value)),
              )
              .toList(growable: false)
        : const <CatalogBundle>[];
    final rawArtifacts = json['artifacts'];
    final artifacts = rawArtifacts is List
        ? rawArtifacts
              .whereType<Map>()
              .map(
                (value) => CatalogBundleArtifact.fromJson(
                  Map<String, dynamic>.from(value),
                ),
              )
              .toList(growable: false)
        : const <CatalogBundleArtifact>[];
    final rawLanguages = json['languages'];
    final languages = rawLanguages is List
        ? rawLanguages
              .whereType<String>()
              .map((value) => value.trim().toLowerCase())
              .where((value) => value.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final source = json['source'];
    return CatalogManifest(
      game: game,
      version: version,
      schemaVersion: schemaVersion,
      compatibilityVersion: compatibilityVersion,
      source: source is Map ? Map<String, dynamic>.from(source) : null,
      languages: languages,
      artifacts: artifacts,
      bundles: bundles,
      raw: json,
    );
  }

  final String game;
  final String version;
  final int schemaVersion;
  final int compatibilityVersion;
  final Map<String, dynamic>? source;
  final List<String> languages;
  final List<CatalogBundleArtifact> artifacts;
  final List<CatalogBundle> bundles;
  final Map<String, dynamic> raw;
}

class CatalogBundle {
  const CatalogBundle({
    required this.id,
    required this.kind,
    required this.schemaVersion,
    required this.compatibilityVersion,
    required this.requires,
    required this.artifacts,
    required this.raw,
    this.profile,
    this.language,
    this.languages = const <String>[],
  });

  factory CatalogBundle.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim() ?? '';
    final kind = (json['kind'] as String?)?.trim() ?? '';
    final schemaVersion = (json['schema_version'] as num?)?.toInt() ?? 1;
    final compatibilityVersion =
        (json['compatibility_version'] as num?)?.toInt() ?? 1;
    final requires = (json['requires'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final artifacts = (json['artifacts'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (value) =>
              CatalogBundleArtifact.fromJson(Map<String, dynamic>.from(value)),
        )
        .toList(growable: false);
    final languages = (json['languages'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    return CatalogBundle(
      id: id,
      kind: kind,
      schemaVersion: schemaVersion,
      compatibilityVersion: compatibilityVersion,
      profile: (json['profile'] as String?)?.trim().toLowerCase(),
      language: (json['language'] as String?)?.trim().toLowerCase(),
      languages: languages,
      requires: requires,
      artifacts: artifacts,
      raw: json,
    );
  }

  final String id;
  final String kind;
  final int schemaVersion;
  final int compatibilityVersion;
  final String? profile;
  final String? language;
  final List<String> languages;
  final List<String> requires;
  final List<CatalogBundleArtifact> artifacts;
  final Map<String, dynamic> raw;
}

class CatalogBundleArtifact {
  const CatalogBundleArtifact({
    required this.name,
    this.path,
    this.downloadUrl,
    this.sizeBytes,
    this.sha256,
    this.raw = const <String, dynamic>{},
  });

  factory CatalogBundleArtifact.fromJson(Map<String, dynamic> json) {
    return CatalogBundleArtifact(
      name: (json['name'] as String?)?.trim() ?? '',
      path: (json['path'] as String?)?.trim(),
      downloadUrl: (json['download_url'] as String?)?.trim(),
      sizeBytes: (json['size_bytes'] as num?)?.toInt(),
      sha256: (json['sha256'] as String?)?.trim().toLowerCase(),
      raw: json,
    );
  }

  final String name;
  final String? path;
  final String? downloadUrl;
  final int? sizeBytes;
  final String? sha256;
  final Map<String, dynamic> raw;
}
