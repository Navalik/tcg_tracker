import 'dart:convert';

import '../domain/domain_models.dart';
import '../models.dart';
import '../repositories/search_repository.dart';

class ScannerOcrSeed {
  const ScannerOcrSeed({
    required this.query,
    this.cardName,
    this.setCode,
    this.collectorNumber,
    this.scannerLanguageCode,
    this.isFoil = false,
  });

  final String query;
  final String? cardName;
  final String? setCode;
  final String? collectorNumber;
  final String? scannerLanguageCode;
  final bool isFoil;
}

class PokemonScannerMetrics {
  const PokemonScannerMetrics({
    required this.candidateCount,
    required this.exactNameMatches,
    required this.exactSetMatches,
    required this.exactCollectorMatches,
    required this.fallbackSteps,
  });

  final int candidateCount;
  final int exactNameMatches;
  final int exactSetMatches;
  final int exactCollectorMatches;
  final List<String> fallbackSteps;
}

class PokemonScannerResolution {
  const PokemonScannerResolution({
    required this.candidates,
    required this.metrics,
  });

  final List<CardSearchResult> candidates;
  final PokemonScannerMetrics metrics;
}

class PokemonScannerResolver {
  const PokemonScannerResolver._();

  static ScannerOcrSeed? parseSeed(
    String rawInput, {
    required Set<String> knownSetCodes,
  }) {
    var text = rawInput.trim();
    if (text.isEmpty) {
      return null;
    }

    String? forcedName;
    String? forcedSet;
    String? selectedSetCode;
    String? scannerLanguageCode;
    var isFoil = false;

    if (text.startsWith('__SCAN_PAYLOAD__')) {
      final payloadText = text.substring('__SCAN_PAYLOAD__'.length).trim();
      try {
        final payload = jsonMap(payloadText);
        final raw = _normalizedText(payload['raw']);
        final lockedName = _normalizedText(payload['lockedName']);
        final lockedSet = _normalizedText(payload['lockedSet']);
        final payloadSet = _normalizedText(payload['selectedSetCode']);
        final payloadLanguage = _normalizedText(
          payload['selectedLanguageCode'],
        );
        final payloadFoil = payload['foil'];
        if (raw != null) {
          text = raw;
        }
        forcedName = lockedName;
        forcedSet = lockedSet;
        selectedSetCode = payloadSet;
        scannerLanguageCode = payloadLanguage;
        if (payloadFoil is bool) {
          isFoil = payloadFoil;
        }
      } catch (_) {
        // Fall back to plain raw text if payload parsing fails.
      }
    }

    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      return null;
    }

    final topLines = lines.take(3).toList(growable: false);
    final bottomLines = lines.sublist(lines.length > 5 ? lines.length - 5 : 0);
    final bestName = forcedName ?? _extractLikelyCardName(topLines);

    String? setCode;
    String? collectorNumber;
    if (forcedSet != null && forcedSet.isNotEmpty) {
      final forced = _extractSetAndCollector(<String>[
        forcedSet,
      ], knownSetCodes: knownSetCodes);
      setCode = forced.$1;
      collectorNumber = forced.$2;
    }

    final extracted = _extractSetAndCollector(
      bottomLines,
      knownSetCodes: knownSetCodes,
    );
    setCode = extracted.$1 ?? setCode;
    collectorNumber = _pickBetterCollectorNumber(collectorNumber, extracted.$2);

    if (selectedSetCode != null && selectedSetCode.isNotEmpty) {
      final normalizedSelected = selectedSetCode.trim().toLowerCase();
      if (knownSetCodes.isEmpty || knownSetCodes.contains(normalizedSelected)) {
        setCode = normalizedSelected;
      }
    }

    if (bestName.isEmpty &&
        (setCode == null || setCode.isEmpty) &&
        (collectorNumber == null || collectorNumber.isEmpty)) {
      return null;
    }

    final fallbackQuery = bestName.isEmpty ? lines.first : bestName;
    final useCollectorQuery =
        collectorNumber != null &&
        collectorNumber.isNotEmpty &&
        setCode != null &&
        setCode.isNotEmpty &&
        !_isWeakCollectorNumber(collectorNumber);

    return ScannerOcrSeed(
      query: useCollectorQuery ? collectorNumber : fallbackQuery,
      cardName: bestName.isEmpty ? null : bestName,
      setCode: setCode,
      collectorNumber: collectorNumber,
      scannerLanguageCode: scannerLanguageCode,
      isFoil: isFoil,
    );
  }

  static Future<PokemonScannerResolution> resolve({
    required ScannerOcrSeed seed,
    required SearchRepository searchRepository,
    int limit = 120,
  }) async {
    final fallbackSteps = <String>[];
    final preferredLanguages = _preferredLanguages(seed.scannerLanguageCode);
    final results = <CardSearchResult>[];

    Future<void> addCandidates(
      String step,
      Future<List<CardSearchResult>> Function() loader,
    ) async {
      final loaded = await loader();
      if (loaded.isEmpty) {
        return;
      }
      fallbackSteps.add(step);
      results.addAll(loaded);
    }

    final normalizedName = _normalizeCardName(seed.cardName ?? seed.query);
    final setCode = seed.setCode?.trim().toLowerCase();
    final collectorNumber = _normalizeCollector(seed.collectorNumber ?? '');
    final hasUsableCollector = collectorNumber.isNotEmpty;
    final exactFilter = CollectionFilter(
      name: seed.cardName ?? seed.query,
      sets: setCode == null || setCode.isEmpty ? const <String>{} : {setCode},
      collectorNumber: hasUsableCollector ? collectorNumber : null,
    );
    final setNameFilter = CollectionFilter(
      name: seed.cardName ?? seed.query,
      sets: setCode == null || setCode.isEmpty ? const <String>{} : {setCode},
    );

    if (setCode != null && setCode.isNotEmpty && hasUsableCollector) {
      await addCandidates(
        'collector+set',
        () => searchRepository.fetchCardsForAdvancedFilters(
          CollectionFilter(
            sets: {setCode},
            collectorNumber: hasUsableCollector ? collectorNumber : null,
          ),
          gameId: TcgGameId.pokemon,
          languages: preferredLanguages,
          limit: limit,
        ),
      );
    }

    if (setCode != null && setCode.isNotEmpty && hasUsableCollector) {
      await addCandidates(
        'name+set+collector',
        () => searchRepository.fetchCardsForAdvancedFilters(
          exactFilter,
          gameId: TcgGameId.pokemon,
          languages: preferredLanguages,
          limit: limit,
        ),
      );
    }

    if (setCode != null && setCode.isNotEmpty) {
      await addCandidates(
        'name+set',
        () => searchRepository.fetchCardsForAdvancedFilters(
          setNameFilter,
          gameId: TcgGameId.pokemon,
          languages: preferredLanguages,
          limit: limit,
        ),
      );
    }

    await addCandidates(
      'name',
      () => searchRepository.searchCardsByName(
        seed.cardName ?? seed.query,
        gameId: TcgGameId.pokemon,
        languages: preferredLanguages,
        limit: limit,
      ),
    );

    final deduped = <String, CardSearchResult>{};
    for (final card in results) {
      deduped.putIfAbsent(_printingKey(card), () => card);
    }
    final ranked = deduped.values.toList(growable: false)
      ..sort(
        (a, b) =>
            _scoreCandidate(
              b,
              normalizedName: normalizedName,
              setCode: setCode,
              collectorNumber: collectorNumber,
            ).compareTo(
              _scoreCandidate(
                a,
                normalizedName: normalizedName,
                setCode: setCode,
                collectorNumber: collectorNumber,
              ),
            ),
      );

    final metrics = PokemonScannerMetrics(
      candidateCount: ranked.length,
      exactNameMatches: ranked
          .where((card) => _normalizeCardName(card.name) == normalizedName)
          .length,
      exactSetMatches: ranked
          .where((card) => card.setCode.trim().toLowerCase() == setCode)
          .length,
      exactCollectorMatches: ranked
          .where(
            (card) =>
                _normalizeCollector(card.collectorNumber) == collectorNumber,
          )
          .length,
      fallbackSteps: fallbackSteps,
    );
    return PokemonScannerResolution(candidates: ranked, metrics: metrics);
  }

  static List<String> _preferredLanguages(String? scannerLanguageCode) {
    final normalized = scannerLanguageCode?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return const <String>['en', 'it'];
    }
    final ordered = <String>[normalized, 'en', 'it'];
    final unique = <String>{};
    final result = <String>[];
    for (final code in ordered) {
      final value = code.trim().toLowerCase();
      if (value.isEmpty || unique.contains(value)) {
        continue;
      }
      unique.add(value);
      result.add(value);
    }
    return result;
  }

  static int _scoreCandidate(
    CardSearchResult card, {
    required String normalizedName,
    required String? setCode,
    required String collectorNumber,
  }) {
    var score = 0;
    final cardName = _normalizeCardName(card.name);
    final cardSetCode = card.setCode.trim().toLowerCase();
    final cardCollector = _normalizeCollector(card.collectorNumber);

    if (normalizedName.isNotEmpty && cardName == normalizedName) {
      score += 120;
    } else if (normalizedName.isNotEmpty && cardName.contains(normalizedName)) {
      score += 55;
    }

    if (setCode != null && setCode.isNotEmpty) {
      if (cardSetCode == setCode) {
        score += 90;
      } else if (_approximateSetCode(setCode, <String>[cardSetCode]) ==
          cardSetCode) {
        score += 45;
      }
    }

    if (collectorNumber.isNotEmpty) {
      if (cardCollector == collectorNumber) {
        score += 100;
      } else if (card.collectorNumber.trim().toLowerCase() ==
          collectorNumber.toLowerCase()) {
        score += 85;
      }
    }

    if (score == 0) {
      score = 1;
    }
    return score;
  }

  static (String?, String?) _extractSetAndCollector(
    List<String> lines, {
    required Set<String> knownSetCodes,
  }) {
    final setCollectorRegex = RegExp(
      r'\b([A-Z0-9]{2,6})\s+([0-9]{1,5}[A-Z]?)\b',
    );
    final collectorSlashRegex = RegExp(
      r'\b([0-9]{1,5}[A-Z]?)\s*/\s*[0-9]{1,5}\b',
    );
    String? setCode;
    String? collectorNumber;
    for (var i = lines.length - 1; i >= 0; i -= 1) {
      final upper = lines[i].toUpperCase();
      final direct = setCollectorRegex.firstMatch(upper);
      if (direct != null) {
        setCode ??= _detectSetCodeFromToken(
          direct.group(1) ?? '',
          knownSetCodes: knownSetCodes,
        );
        collectorNumber ??= _normalizeCollectorNumber(direct.group(2) ?? '');
      }
      final slash = collectorSlashRegex.firstMatch(upper);
      if (slash != null) {
        collectorNumber ??= _normalizeCollectorNumber(slash.group(1) ?? '');
      }
      if (collectorNumber != null && setCode == null) {
        setCode = _findNearestSetCode(
          lines,
          anchorIndex: i,
          knownSetCodes: knownSetCodes,
        );
      }
      if (setCode != null && collectorNumber != null) {
        break;
      }
    }
    return (setCode, collectorNumber);
  }

  static String? _findNearestSetCode(
    List<String> lines, {
    required int anchorIndex,
    required Set<String> knownSetCodes,
  }) {
    for (var delta = 0; delta <= 2; delta += 1) {
      final candidates = <int>{anchorIndex - delta, anchorIndex + delta};
      for (final index in candidates) {
        if (index < 0 || index >= lines.length) {
          continue;
        }
        final detected = _detectSetCodeInLine(
          lines[index],
          knownSetCodes: knownSetCodes,
        );
        if (detected != null) {
          return detected;
        }
      }
    }
    return null;
  }

  static String? _detectSetCodeInLine(
    String line, {
    required Set<String> knownSetCodes,
  }) {
    final tokens = line
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    for (final token in tokens.reversed) {
      if (RegExp(r'^\d+$').hasMatch(token)) {
        continue;
      }
      final detected = _detectSetCodeFromToken(
        token,
        knownSetCodes: knownSetCodes,
      );
      if (detected != null) {
        return detected;
      }
    }
    return null;
  }

  static String? _detectSetCodeFromToken(
    String token, {
    required Set<String> knownSetCodes,
  }) {
    final raw = token.trim().toLowerCase();
    if (raw.isEmpty) {
      return null;
    }
    final candidates = <String>{
      raw,
      raw
          .replaceAll('0', 'o')
          .replaceAll('1', 'i')
          .replaceAll('5', 's')
          .replaceAll('8', 'b'),
    };
    for (final candidate in candidates) {
      if (knownSetCodes.contains(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  static String? _approximateSetCode(
    String preferredSet,
    Iterable<String> candidateSetCodes,
  ) {
    final normalizedPreferred = preferredSet
        .trim()
        .toLowerCase()
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('5', 's')
        .replaceAll('8', 'b');
    if (normalizedPreferred.isEmpty) {
      return null;
    }
    String? best;
    var bestDistance = 999;
    for (final rawCandidate in candidateSetCodes) {
      final candidate = rawCandidate.trim().toLowerCase();
      if (candidate.isEmpty) {
        continue;
      }
      final distance = _levenshteinDistance(normalizedPreferred, candidate);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = candidate;
      }
    }
    if (best == null || bestDistance > 2) {
      return null;
    }
    return best;
  }

  static String _extractLikelyCardName(List<String> lines) {
    const oracleLikeWords = <String>{
      'deals',
      'damage',
      'target',
      'draw',
      'discard',
      'player',
      'turn',
      'energy',
      'trainer',
      'supporter',
    };
    var best = '';
    var bestScore = -1;
    for (var i = 0; i < lines.length && i < 8; i += 1) {
      final normalized = _trimToNameSegment(
        lines[i]
            .replaceAll(RegExp(r"[^A-Za-z0-9'\-\s,]"), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim(),
      );
      if (normalized.length < 3 || !RegExp(r'[A-Za-z]').hasMatch(normalized)) {
        continue;
      }
      final lowerWords = normalized
          .toLowerCase()
          .split(' ')
          .where((word) => word.isNotEmpty)
          .toList(growable: false);
      final oracleHits = lowerWords
          .where((word) => oracleLikeWords.contains(word))
          .length;
      final score = normalized.length - (oracleHits * 5) + (8 - i);
      if (score > bestScore) {
        bestScore = score;
        best = normalized;
      }
    }
    return best;
  }

  static String _trimToNameSegment(String value) {
    const cutWords = <String>{
      'deals',
      'damage',
      'target',
      'draw',
      'discard',
      'player',
      'turn',
      'when',
      'whenever',
      'if',
      'then',
    };
    final words = value.split(' ').where((word) => word.isNotEmpty);
    final kept = <String>[];
    for (final word in words) {
      if (cutWords.contains(word.toLowerCase())) {
        break;
      }
      kept.add(word);
      if (kept.length >= 6) {
        break;
      }
    }
    final trimmed = kept.join(' ').trim();
    return trimmed.isEmpty ? value : trimmed;
  }

  static String _normalizeCardName(String value) {
    return _foldLatinDiacritics(value)
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9'\- ]"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _normalizeCollector(String value) {
    final raw = value.trim().toLowerCase();
    if (raw.isEmpty) {
      return '';
    }
    final match = RegExp(r'^0*(\d+)([a-z]?)$').firstMatch(raw);
    if (match == null) {
      return raw;
    }
    return '${match.group(1) ?? ''}${match.group(2) ?? ''}';
  }

  static String? _normalizeCollectorNumber(String input) {
    final value = input
        .trim()
        .toLowerCase()
        .replaceAll('#', '')
        .replaceAll('o', '0')
        .replaceAll('i', '1')
        .replaceAll('l', '1')
        .replaceAll('s', '5')
        .replaceAll(RegExp(r'[^a-z0-9/]'), '');
    if (value.isEmpty) {
      return null;
    }
    final match = RegExp(r'^(\d{1,5}[a-z]?)$').firstMatch(value);
    if (match == null) {
      return null;
    }
    return match.group(1);
  }

  static String? _pickBetterCollectorNumber(
    String? current,
    String? candidate,
  ) {
    if (candidate == null || candidate.isEmpty) {
      return current;
    }
    if (current == null || current.isEmpty) {
      return candidate;
    }
    final currentScore = _collectorConfidenceScore(current);
    final candidateScore = _collectorConfidenceScore(candidate);
    return candidateScore > currentScore ? candidate : current;
  }

  static int _collectorConfidenceScore(String value) {
    final normalized = value.toLowerCase();
    final digitCount = RegExp(r'\d').allMatches(normalized).length;
    final hasSuffixLetter = RegExp(r'\d+[a-z]$').hasMatch(normalized);
    final isSingleDigit = RegExp(r'^\d$').hasMatch(normalized);
    var score = digitCount * 3;
    if (hasSuffixLetter) {
      score += 2;
    }
    if (isSingleDigit) {
      score -= 4;
    }
    return score;
  }

  static bool _isWeakCollectorNumber(String value) {
    return RegExp(r'^\d$').hasMatch(value.trim());
  }

  static String _printingKey(CardSearchResult card) {
    return '${_normalizeCardName(card.name)}|${card.setCode.trim().toLowerCase()}|${_normalizeCollector(card.collectorNumber)}';
  }

  static int _levenshteinDistance(String a, String b) {
    if (a == b) {
      return 0;
    }
    if (a.isEmpty) {
      return b.length;
    }
    if (b.isEmpty) {
      return a.length;
    }
    final previous = List<int>.generate(b.length + 1, (index) => index);
    final current = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i += 1) {
      current[0] = i;
      for (var j = 1; j <= b.length; j += 1) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        final deletion = previous[j] + 1;
        final insertion = current[j - 1] + 1;
        final substitution = previous[j - 1] + cost;
        current[j] = [
          deletion,
          insertion,
          substitution,
        ].reduce((value, element) => value < element ? value : element);
      }
      for (var j = 0; j <= b.length; j += 1) {
        previous[j] = current[j];
      }
    }
    return previous[b.length];
  }

  static Map<String, dynamic> jsonMap(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('invalid_scan_payload');
    }
    return decoded;
  }

  static String? _normalizedText(Object? value) {
    if (value is! String) {
      return null;
    }
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static String _foldLatinDiacritics(String value) {
    const replacements = <String, String>{
      '\u00E0': 'a',
      '\u00E1': 'a',
      '\u00E2': 'a',
      '\u00E4': 'a',
      '\u00E3': 'a',
      '\u00E5': 'a',
      '\u00E7': 'c',
      '\u00E8': 'e',
      '\u00E9': 'e',
      '\u00EA': 'e',
      '\u00EB': 'e',
      '\u00EC': 'i',
      '\u00ED': 'i',
      '\u00EE': 'i',
      '\u00EF': 'i',
      '\u00F1': 'n',
      '\u00F2': 'o',
      '\u00F3': 'o',
      '\u00F4': 'o',
      '\u00F6': 'o',
      '\u00F5': 'o',
      '\u00F9': 'u',
      '\u00FA': 'u',
      '\u00FB': 'u',
      '\u00FC': 'u',
      '\u00FD': 'y',
      '\u00FF': 'y',
      '\u00C0': 'a',
      '\u00C1': 'a',
      '\u00C2': 'a',
      '\u00C4': 'a',
      '\u00C3': 'a',
      '\u00C5': 'a',
      '\u00C7': 'c',
      '\u00C8': 'e',
      '\u00C9': 'e',
      '\u00CA': 'e',
      '\u00CB': 'e',
      '\u00CC': 'i',
      '\u00CD': 'i',
      '\u00CE': 'i',
      '\u00CF': 'i',
      '\u00D1': 'n',
      '\u00D2': 'o',
      '\u00D3': 'o',
      '\u00D4': 'o',
      '\u00D6': 'o',
      '\u00D5': 'o',
      '\u00D9': 'u',
      '\u00DA': 'u',
      '\u00DB': 'u',
      '\u00DC': 'u',
      '\u00DD': 'y',
    };
    if (value.isEmpty) {
      return value;
    }
    final buffer = StringBuffer();
    for (final char in value.split('')) {
      buffer.write(replacements[char] ?? char);
    }
    return buffer.toString();
  }
}
