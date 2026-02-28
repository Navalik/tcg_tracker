import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';

class PokemonBulkService {
  PokemonBulkService._();

  static final PokemonBulkService instance = PokemonBulkService._();

  static const String datasetVersion = 'pokemon_tcg_api_v2';
  static const String _cardsEndpoint = 'https://api.pokemontcg.io/v2/cards';
  static const int _pageSize = 250;
  static const String _prefsKeyInstalledVersion = 'pokemon_dataset_version';

  Future<bool> isInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    final installedVersion = prefs.getString(_prefsKeyInstalledVersion);
    final count = await ScryfallDatabase.instance.countCards();
    return installedVersion == datasetVersion && count > 0;
  }

  Future<void> ensureInstalled({
    required void Function(double progress) onProgress,
  }) async {
    if (await isInstalled()) {
      onProgress(1);
      return;
    }
    await installDataset(onProgress: onProgress);
  }

  Future<void> installDataset({
    required void Function(double progress) onProgress,
  }) async {
    if (!_isAllowedDownloadUri(_cardsEndpoint)) {
      throw const FormatException('pokemon_dataset_url_not_allowed');
    }
    final database = await ScryfallDatabase.instance.open();
    onProgress(0.02);
    var inserted = 0;
    await database.transaction(() async {
      await ScryfallDatabase.instance.deleteAllCards(database);
      var page = 1;
      var totalCount = 0;
      while (true) {
        final uri = Uri.parse(_cardsEndpoint).replace(
          queryParameters: <String, String>{
            'page': '$page',
            'pageSize': '$_pageSize',
          },
        );
        final response = await http.get(uri).timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) {
          throw HttpException('HTTP ${response.statusCode}');
        }
        final payload = jsonDecode(response.body);
        if (payload is! Map<String, dynamic>) {
          throw const FormatException('pokemon_api_invalid_payload');
        }
        final responseTotal = (payload['totalCount'] as num?)?.toInt() ?? 0;
        if (totalCount == 0 && responseTotal > 0) {
          totalCount = responseTotal;
        }
        final data = payload['data'];
        if (data is! List) {
          break;
        }
        final mapped = <Map<String, dynamic>>[];
        for (final row in data) {
          if (row is! Map) {
            continue;
          }
          final normalized = _mapPokemonApiCard(Map<String, dynamic>.from(row));
          if (normalized != null) {
            mapped.add(normalized);
          }
        }
        if (mapped.isNotEmpty) {
          await ScryfallDatabase.instance.insertPokemonCardsBatch(database, mapped);
          inserted += mapped.length;
        }
        if (totalCount > 0) {
          onProgress((inserted / totalCount).clamp(0.02, 0.95));
        }
        if (data.isEmpty || (totalCount > 0 && inserted >= totalCount)) {
          break;
        }
        page += 1;
      }
    });

    if (inserted <= 0) {
      throw const FormatException('pokemon_dataset_empty');
    }

    await database.rebuildFts();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyInstalledVersion, datasetVersion);
    onProgress(1);
  }

  bool _isAllowedDownloadUri(String rawUri) {
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
    final host = uri.host.toLowerCase();
    return host == 'api.pokemontcg.io';
  }
}

Map<String, dynamic>? _mapPokemonApiCard(Map<String, dynamic> card) {
  final id = (card['id'] as String?)?.trim();
  final name = (card['name'] as String?)?.trim();
  if (id == null || id.isEmpty || name == null || name.isEmpty) {
    return null;
  }

  final set = card['set'];
  String setCode = '';
  String setName = '';
  String releasedAt = '';
  if (set is Map) {
    setCode = ((set['id'] as String?) ?? '').trim().toLowerCase();
    setName = ((set['name'] as String?) ?? '').trim();
    releasedAt = _normalizePokemonDate(((set['releaseDate'] as String?) ?? '').trim());
  }

  final number = ((card['number'] as String?) ?? '').trim();
  final rarity = ((card['rarity'] as String?) ?? '').trim();
  final supertype = ((card['supertype'] as String?) ?? '').trim();
  final types = (card['types'] as List<dynamic>? ?? const [])
      .whereType<String>()
      .map((it) => it.trim())
      .where((it) => it.isNotEmpty)
      .toList(growable: false);
  final subtypes = (card['subtypes'] as List<dynamic>? ?? const [])
      .whereType<String>()
      .map((it) => it.trim())
      .where((it) => it.isNotEmpty)
      .toList(growable: false);
  final typeParts = <String>[
    if (supertype.isNotEmpty) supertype,
    if (types.isNotEmpty) ...types,
    if (subtypes.isNotEmpty) '(${subtypes.join(', ')})',
  ];
  final typeLine = typeParts.join(' ').trim();

  final images = card['images'];
  String imageSmall = '';
  String imageLarge = '';
  if (images is Map) {
    imageSmall = ((images['small'] as String?) ?? '').trim();
    imageLarge = ((images['large'] as String?) ?? '').trim();
  }

  return {
    'id': id,
    'name': name,
    'set_code': setCode,
    'set_name': setName,
    'collector_number': number,
    'rarity': rarity,
    'type_line': typeLine,
    'released_at': releasedAt,
    'image_small': imageSmall,
    'image_large': imageLarge,
  };
}

String _normalizePokemonDate(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return '';
  }
  return value.replaceAll('/', '-');
}
