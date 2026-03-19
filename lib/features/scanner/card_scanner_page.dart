part of 'package:tcg_tracker/main.dart';

class _OcrSearchSeed {
  const _OcrSearchSeed({
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

class _ResolvedScanSelection {
  const _ResolvedScanSelection({required this.seed, this.pickedCard});

  final _OcrSearchSeed seed;
  final CardSearchResult? pickedCard;
}

enum _ScanPreviewAction { add, retry }

enum _HomeAddContext { home, set, custom, smart, deck, wishlist }

Future<CardSearchResult?> _pickCardPrintingForName(
  BuildContext context,
  String cardName, {
  required List<String> languages,
  String? preferredSetCode,
  String? preferredCollectorNumber,
  Set<String> localPrintingKeys = const {},
  List<CardSearchResult>? candidatesOverride,
}) async {
  final normalizedTarget = _normalizeCardNameForMatch(cardName);
  if (normalizedTarget.isEmpty) {
    return null;
  }
  var results =
      candidatesOverride ??
      await appRepositories.search.fetchCardsForAdvancedFilters(
        CollectionFilter(name: cardName),
        languages: languages,
        limit: 250,
      );
  if (results.isEmpty && candidatesOverride == null) {
    results = await appRepositories.search.searchCardsByName(
      cardName,
      limit: 120,
      languages: languages,
    );
  }
  if (results.isEmpty) {
    return null;
  }
  final exact = results
      .where(
        (card) => _normalizeCardNameForMatch(card.name) == normalizedTarget,
      )
      .toList(growable: false);
  final candidates = exact.isNotEmpty ? exact : results;
  final byPrinting = <String, CardSearchResult>{};
  for (final card in candidates) {
    final key =
        '${card.name.toLowerCase()}|${card.setCode.toLowerCase()}|${card.collectorNumber.toLowerCase()}';
    byPrinting.putIfAbsent(key, () => card);
  }
  final unique = byPrinting.values.toList(growable: false);
  if (unique.isEmpty) {
    return null;
  }
  final localKeys = localPrintingKeys;
  final localCandidates = localKeys.isEmpty
      ? unique
      : unique
            .where((card) => localKeys.contains(_printingKeyForCard(card)))
            .toList(growable: false);
  final onlineCandidates = localKeys.isEmpty
      ? <CardSearchResult>[]
      : unique
            .where((card) => !localKeys.contains(_printingKeyForCard(card)))
            .toList(growable: false);
  final preferredSet = preferredSetCode?.trim().toLowerCase();
  var effectivePreferredSet = preferredSet;
  if (effectivePreferredSet != null &&
      effectivePreferredSet.isNotEmpty &&
      !unique.any(
        (card) => card.setCode.trim().toLowerCase() == effectivePreferredSet,
      )) {
    effectivePreferredSet = _approximateSetCodeForCandidates(
      effectivePreferredSet,
      unique.map((card) => card.setCode.trim().toLowerCase()),
    );
  }
  // Do not auto-pick when multiple printings exist:
  // always show chooser so user can select Local vs Online printing.
  if (!context.mounted) {
    return null;
  }
  return showModalBottomSheet<CardSearchResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PickPrintingSheet(
      cardName: unique.first.name,
      candidates: unique,
      localCandidates: localCandidates,
      onlineCandidates: onlineCandidates,
    ),
  );
}

String _normalizeCollectorForComparison(String value) {
  final raw = value.trim().toLowerCase();
  if (raw.isEmpty) {
    return '';
  }
  final match = RegExp(r'^0*(\d+)([a-z]?)$').firstMatch(raw);
  if (match == null) {
    return raw;
  }
  final number = match.group(1) ?? '';
  final suffix = match.group(2) ?? '';
  return '$number$suffix';
}

String? _approximateSetCodeForCandidates(
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
  if (best == null) {
    return null;
  }
  return bestDistance <= 2 ? best : null;
}

int _levenshteinDistance(String a, String b) {
  if (a == b) {
    return 0;
  }
  if (a.isEmpty) {
    return b.length;
  }
  if (b.isEmpty) {
    return a.length;
  }
  final prev = List<int>.generate(b.length + 1, (i) => i);
  final curr = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    curr[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final deletion = prev[j] + 1;
      final insertion = curr[j - 1] + 1;
      final substitution = prev[j - 1] + cost;
      var best = deletion < insertion ? deletion : insertion;
      if (substitution < best) {
        best = substitution;
      }
      curr[j] = best;
    }
    for (var j = 0; j <= b.length; j++) {
      prev[j] = curr[j];
    }
  }
  return prev[b.length];
}

String _normalizeCardNameForMatch(String value) {
  return _foldLatinDiacritics(value)
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9'\- ]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _isStorageSpaceError(Object error) {
  final raw = error.toString().toLowerCase();
  return raw.contains('no space left on device') ||
      raw.contains('enospc') ||
      raw.contains('errno = 28') ||
      raw.contains('errno 28') ||
      raw.contains('os error: 28') ||
      raw.contains('database or disk is full') ||
      raw.contains('sqlite_full') ||
      raw.contains('sqlite code 13');
}

String _storageSpaceErrorMessage({required bool italian}) {
  return italian
      ? 'Spazio insufficiente sul dispositivo. Libera spazio e riprova (consigliati almeno 3 GB). In alternativa passa a un database piu piccolo da Impostazioni (es. Oracle Cards / profilo Pokemon piu leggero).'
      : 'Not enough free storage on this device. Free up space and retry (at least 3 GB recommended). Alternatively switch to a smaller database in Settings (for example Oracle Cards / a lighter Pokemon profile).';
}

String _foldLatinDiacritics(String value) {
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

String _printingKeyForCard(CardSearchResult card) {
  return '${_normalizeCardNameForMatch(card.name)}|${card.setCode.trim().toLowerCase()}|${_normalizeCollectorForComparison(card.collectorNumber)}';
}

class _PickPrintingSheet extends StatelessWidget {
  const _PickPrintingSheet({
    required this.cardName,
    required this.candidates,
    this.localCandidates = const [],
    this.onlineCandidates = const [],
  });

  final String cardName;
  final List<CardSearchResult> candidates;
  final List<CardSearchResult> localCandidates;
  final List<CardSearchResult> onlineCandidates;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final sheetMargin = _bottomSheetMenuMargin(context);
    final maxHeight = media.size.height - sheetMargin.top - sheetMargin.bottom;
    return Container(
      margin: sheetMargin,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose printing',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              cardName,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFFBFAE95)),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: (candidates.length * 74.0).clamp(220.0, maxHeight),
              child: ListView(
                children: [
                  if (localCandidates.isNotEmpty) ...[
                    _buildSectionHeader(context, 'Local'),
                    for (final card in localCandidates)
                      _buildPrintingTile(context, card),
                  ],
                  if (onlineCandidates.isNotEmpty) ...[
                    if (localCandidates.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1),
                      ),
                    _buildSectionHeader(context, 'Online'),
                    for (final card in onlineCandidates)
                      _buildPrintingTile(context, card),
                  ],
                  if (localCandidates.isEmpty && onlineCandidates.isEmpty)
                    for (final card in candidates)
                      _buildPrintingTile(context, card),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: const Color(0xFFE9C46A),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildPrintingTile(BuildContext context, CardSearchResult card) {
    return ListTile(
      leading: _buildCardPreview(card),
      title: Text(
        card.setName.trim().isEmpty ? card.setCode.toUpperCase() : card.setName,
      ),
      subtitle: Text(card.collectorProgressLabel),
      trailing: _buildSetIcon(card.setCode, size: 32),
      onTap: () => Navigator.of(context).pop(card),
    );
  }

  Widget _buildCardPreview(CardSearchResult card) {
    final uri = _normalizeCardImageUrlForDisplay(card.imageUri);
    if (uri.isEmpty) {
      return _buildSetIcon(card.setCode, size: 22);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 42,
        height: 58,
        child: Image.network(
          uri,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: const Color(0x221C1713),
            alignment: Alignment.center,
            child: _buildSetIcon(card.setCode, size: 22),
          ),
        ),
      ),
    );
  }
}

class _CardScannerPage extends StatefulWidget {
  const _CardScannerPage();

  @override
  State<_CardScannerPage> createState() => _CardScannerPageState();
}

class _CardScannerPageState extends State<_CardScannerPage>
    with SingleTickerProviderStateMixin {
  static const double _cardAspectRatio = 64 / 96;
  static const bool _showCoverageBadgeInScanner = false;
  static const int _requiredStableHits = 3;
  static const int _requiredNameFieldHits = 2;
  static const int _requiredSetFieldHits = 3;
  static const int _setVoteWindow = 18;
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  late final AnimationController _pulseController;
  CameraController? _cameraController;
  bool _initializing = true;
  bool _handled = false;
  bool _processingFrame = false;
  DateTime _lastProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastCandidateKey = '';
  int _stableHits = 0;
  String _bestStableRawText = '';
  String _lastNameCandidate = '';
  String _lastSetCandidate = '';
  int _nameHits = 0;
  int _setHits = 0;
  String _lockedName = '';
  String _lockedSet = '';
  String _namePreview = '';
  final List<String> _setVoteHistory = <String>[];
  final Map<String, int> _setVoteCounts = <String, int>{};
  Set<String> _knownSetCodes = const {};
  Map<String, String> _knownSetNames = const {};
  String? _selectedSetFilterCode;
  List<String> _scannerLanguageOptions = const <String>['en'];
  String? _selectedLanguageFilterCode;
  bool _foilSelected = false;
  bool _torchEnabled = false;
  bool _torchAvailable = true;
  String _status = '';
  bool _limitedPrintCoverage = false;
  bool _tutorialPromptScheduled = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    unawaited(_loadBulkCoverageState());
    unawaited(_loadScannerLanguageConfig());
    unawaited(_loadKnownSetCodesForScanner());
    unawaited(_initializeCamera());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_status.isEmpty) {
      _status = AppLocalizations.of(context)!.alignCardInFrame;
    }
    if (!_tutorialPromptScheduled) {
      _tutorialPromptScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_maybeShowScannerTutorialOnOpen());
      });
    }
  }

  Future<void> _loadBulkCoverageState() async {
    final selectedGame = await AppSettings.loadSelectedTcgGame();
    final bulkType = await AppSettings.loadBulkTypeForGame(selectedGame);
    if (!mounted) {
      return;
    }
    setState(() {
      _limitedPrintCoverage = _isLimitedPrintCoverage(bulkType);
    });
  }

  Future<void> _loadKnownSetCodesForScanner() async {
    final sets = await appRepositories.sets.fetchAvailableSets();
    if (!mounted) {
      return;
    }
    final knownCodes = <String>{};
    final knownNames = <String, String>{};
    for (final set in sets) {
      final code = set.code.trim().toLowerCase();
      if (code.isEmpty) {
        continue;
      }
      knownCodes.add(code);
      final name = set.name.trim();
      knownNames[code] = name.isEmpty ? code.toUpperCase() : name;
    }
    setState(() {
      _knownSetCodes = knownCodes;
      _knownSetNames = knownNames;
      if (_selectedSetFilterCode != null &&
          !_knownSetCodes.contains(_selectedSetFilterCode)) {
        _selectedSetFilterCode = null;
      }
    });
  }

  Future<List<String>> _loadScannerLanguageOptions() async {
    final game =
        TcgEnvironmentController.instance.currentGame == TcgGame.pokemon
        ? AppTcgGame.pokemon
        : AppTcgGame.mtg;
    final configured = (await AppSettings.loadCardLanguagesForGame(game))
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    configured.add('en');
    final options = configured.toList()..sort();
    return options;
  }

  Future<void> _loadScannerLanguageConfig() async {
    final options = await _loadScannerLanguageOptions();
    final game =
        TcgEnvironmentController.instance.currentGame == TcgGame.pokemon
        ? AppTcgGame.pokemon
        : AppTcgGame.mtg;
    final saved = await AppSettings.loadScannerLanguageForGame(game);
    if (!mounted) {
      return;
    }
    setState(() {
      _scannerLanguageOptions = options;
      if (options.length <= 1) {
        _selectedLanguageFilterCode = 'en';
        return;
      }
      final selected = (saved ?? _selectedLanguageFilterCode)
          ?.trim()
          .toLowerCase();
      if (selected == null || selected.isEmpty || !options.contains(selected)) {
        _selectedLanguageFilterCode = null;
      } else {
        _selectedLanguageFilterCode = selected;
      }
    });
  }

  Future<void> _pickLanguageFilter() async {
    final l10n = AppLocalizations.of(context)!;
    if (_scannerLanguageOptions.length <= 1) {
      return;
    }
    final options = _scannerLanguageOptions;
    final selected = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: _bottomSheetMenuMargin(context),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF5D4731)),
          ),
          child: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.public),
                  title: Text(
                    Localizations.localeOf(
                          context,
                        ).languageCode.toLowerCase().startsWith('it')
                        ? 'Qualsiasi lingua'
                        : 'Any language',
                  ),
                  onTap: () => Navigator.of(context).pop(''),
                ),
                const Divider(height: 1),
                ...options.map(
                  (code) => ListTile(
                    leading: const Icon(Icons.translate_rounded),
                    title: Text(_scannerLanguageLabel(l10n, code)),
                    onTap: () => Navigator.of(context).pop(code),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || selected == null) {
      return;
    }
    final nextSelected = selected.isEmpty
        ? null
        : selected.trim().toLowerCase();
    final game =
        TcgEnvironmentController.instance.currentGame == TcgGame.pokemon
        ? AppTcgGame.pokemon
        : AppTcgGame.mtg;
    await AppSettings.saveScannerLanguageForGame(game, nextSelected);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedLanguageFilterCode = nextSelected;
    });
  }

  String _scannerLanguageLabel(AppLocalizations l10n, String code) {
    final normalized = code.trim().toLowerCase();
    if (normalized == 'en') {
      return l10n.languageEnglish;
    }
    if (normalized == 'it') {
      return l10n.languageItalian;
    }
    return normalized.toUpperCase();
  }

  Future<void> _maybeShowScannerTutorialOnOpen() async {
    final hidden = await AppSettings.loadHideScannerTutorial();
    if (!mounted || hidden) {
      return;
    }
    await _showScannerTutorialDialog();
  }

  Future<void> _showScannerTutorialDialog() async {
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final showPokemonNote =
        TcgEnvironmentController.instance.currentGame == TcgGame.pokemon;
    final localeCode = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase();
    final pokemonTutorialNote = localeCode.startsWith('it')
        ? 'Nota Pokemon: l\'OCR puo avere difficolta a identificare la carta corretta, perche molti nomi non sono univoci. Lo scanner verra migliorato nelle prossime release.'
        : 'Pokemon note: OCR can struggle to identify the exact card because many card names are not unique. Scanner accuracy will improve in upcoming releases.';
    var dontShowAgain = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            title: Text(l10n.scannerTutorialTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.scannerTutorialIntro),
                const SizedBox(height: 10),
                Text(l10n.scannerTutorialSet),
                Text(l10n.scannerTutorialFoil),
                Text(l10n.scannerTutorialCheck),
                Text(l10n.scannerTutorialFlash),
                if (showPokemonNote) ...[
                  const SizedBox(height: 10),
                  Text(
                    pokemonTutorialNote,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFE9C46A),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: dontShowAgain,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.doNotShowAgain),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) {
                    setModalState(() {
                      dontShowAgain = value ?? false;
                    });
                  },
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () async {
                  if (dontShowAgain) {
                    await AppSettings.saveHideScannerTutorial(true);
                  }
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickSetFilter() async {
    final l10n = AppLocalizations.of(context)!;
    final entries = _knownSetNames.entries.toList()
      ..sort((a, b) {
        final byName = a.value.toLowerCase().compareTo(b.value.toLowerCase());
        if (byName != 0) {
          return byName;
        }
        return a.key.compareTo(b.key);
      });
    final selected = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = entries
                .where((entry) {
                  if (query.isEmpty) {
                    return true;
                  }
                  final q = query.toLowerCase();
                  return entry.key.toLowerCase().contains(q) ||
                      entry.value.toLowerCase().contains(q);
                })
                .toList(growable: false);
            return Container(
              margin: _bottomSheetMenuMargin(context),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF5D4731)),
              ),
              child: SafeArea(
                top: false,
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: l10n.searchSetHint,
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          query = value.trim();
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(Icons.clear_all_rounded),
                      title: Text(l10n.scannerAnySetOption),
                      onTap: () => Navigator.of(context).pop(''),
                    ),
                    const Divider(height: 1),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final entry = filtered[index];
                          return ListTile(
                            title: Text(entry.value),
                            subtitle: Text(entry.key.toUpperCase()),
                            onTap: () => Navigator.of(context).pop(entry.key),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _selectedSetFilterCode = selected.isEmpty
          ? null
          : selected.trim().toLowerCase();
    });
  }

  void _confirmRecognizedName() {
    final candidate = _lockedName.isNotEmpty
        ? _lockedName.trim()
        : _namePreview.trim();
    if (candidate.isEmpty) {
      return;
    }
    setState(() {
      _lockedName = candidate;
      _lastNameCandidate = candidate;
      _nameHits = _requiredNameFieldHits;
      _status = AppLocalizations.of(context)!.nameRecognizedOpeningSearchStatus;
    });
    if (_pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.nv21,
      );
      await controller.initialize();
      await controller.startImageStream(_processCameraFrame);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _initializing = false;
      });
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {
        if (mounted) {
          setState(() {
            _torchAvailable = false;
          });
        }
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initializing = false;
        _status = AppLocalizations.of(
          context,
        )!.cameraUnavailableCheckPermissions;
      });
    }
  }

  @override
  void dispose() {
    final controller = _cameraController;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        unawaited(controller.stopImageStream());
      }
      controller.dispose();
    }
    _pulseController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _toggleTorch() async {
    final controller = _cameraController;
    if (controller == null || !_torchAvailable) {
      return;
    }
    try {
      final next = _torchEnabled ? FlashMode.off : FlashMode.torch;
      await controller.setFlashMode(next);
      if (!mounted) {
        return;
      }
      setState(() {
        _torchEnabled = !_torchEnabled;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _torchAvailable = false;
      });
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.flashNotAvailableOnDevice,
      );
    }
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    if (_handled || _processingFrame || !mounted) {
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastProcessedAt).inMilliseconds < 380) {
      return;
    }
    _lastProcessedAt = now;
    final controller = _cameraController;
    if (controller == null) {
      return;
    }
    final input = _toInputImage(image, controller);
    if (input == null) {
      return;
    }
    _processingFrame = true;
    try {
      final recognized = await _textRecognizer.processImage(input);
      final rawText = recognized.text.trim();
      _updateFieldStates(rawText);
      final stableKey = _buildStabilityKey(rawText);
      if (stableKey.isEmpty) {
        if (mounted) {
          setState(() {
            _status = AppLocalizations.of(context)!.searchingCardTextStatus;
          });
        }
        _stableHits = 0;
        _lastCandidateKey = '';
        _bestStableRawText = '';
        _nameHits = 0;
        _setHits = 0;
        _clearSetVotes();
        return;
      }
      final key = stableKey.toLowerCase();
      if (key == _lastCandidateKey) {
        _stableHits += 1;
        if (rawText.length > _bestStableRawText.length) {
          _bestStableRawText = rawText;
        }
      } else {
        _lastCandidateKey = key;
        _stableHits = 1;
        _bestStableRawText = rawText;
      }
      if (mounted) {
        setState(() {
          if (_lockedName.isEmpty) {
            _status = AppLocalizations.of(context)!.searchingCardNameStatus;
          } else {
            _status = AppLocalizations.of(
              context,
            )!.nameRecognizedOpeningSearchStatus;
          }
        });
      }
      if (_stableHits < _requiredStableHits ||
          rawText.isEmpty ||
          _lockedName.isEmpty) {
        return;
      }
      _handled = true;
      await controller.stopImageStream();
      if (mounted) {
        final payload = jsonEncode({
          'raw': _bestStableRawText.isNotEmpty ? _bestStableRawText : rawText,
          'lockedName': _lockedName,
          'lockedSet': _lockedSet,
          'selectedSetCode': _selectedSetFilterCode,
          'selectedLanguageCode': _selectedLanguageFilterCode,
          'foil': _foilSelected,
        });
        Navigator.of(context).pop('__SCAN_PAYLOAD__$payload');
      }
    } catch (_) {
      _stableHits = 0;
      _bestStableRawText = '';
      _clearSetVotes();
      if (mounted) {
        setState(() {
          _status = AppLocalizations.of(context)!.ocrUnstableRetryingStatus;
        });
      }
    } finally {
      _processingFrame = false;
    }
  }

  String _buildStabilityKey(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (_lockedName.isNotEmpty) {
      // Once name is locked, stabilize on name only to avoid collector/set OCR jitter.
      final locked = _lockedName
          .replaceAll(RegExp(r'[^A-Za-z0-9\s]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (locked.length >= 3) {
        return locked.length > 80 ? '${locked.substring(0, 80)}...' : locked;
      }
    }
    if (lines.isEmpty) {
      return '';
    }
    final name = lines
        .take(6)
        .map((line) => line.replaceAll(RegExp(r'[^A-Za-z0-9\s]'), ' ').trim())
        .firstWhere(
          (line) => line.length >= 3 && RegExp(r'[A-Za-z]').hasMatch(line),
          orElse: () => '',
        );
    if (name.isEmpty && _namePreview.isNotEmpty) {
      final previewName = _namePreview
          .replaceAll(RegExp(r'[^A-Za-z0-9\s]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (previewName.length >= 3) {
        return previewName.length > 80
            ? '${previewName.substring(0, 80)}...'
            : previewName;
      }
    }
    final collector =
        (lines.reversed
            .map((line) => line.toLowerCase())
            .map(
              (line) => RegExp(r'(\d{1,5}[a-z]?)').firstMatch(line)?.group(1),
            )
            .firstWhere(
              (value) => value != null && value.isNotEmpty,
              orElse: () => '',
            )) ??
        '';
    final parts = <String>[
      if (name.isNotEmpty) name,
      if (collector.isNotEmpty) collector,
    ];
    final snippet = parts.join(' | ').trim();
    if (snippet.length < 3) {
      return '';
    }
    return snippet.length > 80 ? '${snippet.substring(0, 80)}...' : snippet;
  }

  void _updateFieldStates(String rawText) {
    final lines = rawText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return;
    }
    final nameCandidate = _extractNameForField(lines.take(3).toList());
    final bottomStart = lines.length > 8 ? lines.length - 8 : 0;
    var setCandidate = _extractSetForField(lines.sublist(bottomStart));
    if (setCandidate.isEmpty) {
      setCandidate = _extractSetForField(lines);
    }
    final votedSetCandidate = _registerSetVote(setCandidate);
    _namePreview = nameCandidate;

    if (nameCandidate.isNotEmpty) {
      if (nameCandidate.toLowerCase() == _lastNameCandidate.toLowerCase()) {
        _nameHits += 1;
      } else {
        _lastNameCandidate = nameCandidate;
        _nameHits = 1;
      }
      if (_nameHits >= _requiredNameFieldHits) {
        _lockedName = nameCandidate;
        if (_pulseController.isAnimating) {
          _pulseController.stop();
        }
      }
    }

    if (votedSetCandidate.isNotEmpty) {
      final hasResolvedSet = RegExp(
        r'^[A-Z]{2,5}\s+[0-9]{1,5}[A-Z]?$',
      ).hasMatch(votedSetCandidate.trim().toUpperCase());
      if (!hasResolvedSet) {
        _setHits = 0;
        return;
      }
      if (votedSetCandidate.toLowerCase() == _lastSetCandidate.toLowerCase()) {
        _setHits += 1;
      } else {
        _lastSetCandidate = votedSetCandidate;
        _setHits = 1;
      }
      if (_setHits >= _requiredSetFieldHits) {
        _lockedSet = votedSetCandidate;
      }
    }
  }

  String _registerSetVote(String candidate) {
    final normalized = _normalizeSetCandidateForVote(candidate);
    if (normalized.isEmpty) {
      return '';
    }
    _setVoteHistory.add(normalized);
    _setVoteCounts.update(normalized, (value) => value + 1, ifAbsent: () => 1);
    if (_setVoteHistory.length > _setVoteWindow) {
      final removed = _setVoteHistory.removeAt(0);
      final next = (_setVoteCounts[removed] ?? 0) - 1;
      if (next <= 0) {
        _setVoteCounts.remove(removed);
      } else {
        _setVoteCounts[removed] = next;
      }
    }
    return _bestSetVoteCandidate() ?? normalized;
  }

  String? _bestSetVoteCandidate() {
    String? best;
    var bestCount = 0;
    for (final entry in _setVoteCounts.entries) {
      if (entry.value > bestCount) {
        bestCount = entry.value;
        best = entry.key;
      }
    }
    return best;
  }

  String _normalizeSetCandidateForVote(String value) {
    final match = RegExp(
      r'^([A-Z]{2,5})\s+([0-9]{1,5}[A-Z]?)$',
    ).firstMatch(value.trim().toUpperCase());
    if (match == null) {
      return '';
    }
    final setCode = (match.group(1) ?? '').trim();
    final collectorRaw = (match.group(2) ?? '').trim();
    if (setCode.isEmpty || collectorRaw.isEmpty) {
      return '';
    }
    final normalizedCollector = _normalizeCollectorForComparison(collectorRaw);
    return '$setCode ${normalizedCollector.toUpperCase()}';
  }

  void _clearSetVotes() {
    _setVoteHistory.clear();
    _setVoteCounts.clear();
  }

  String _extractNameForField(List<String> lines) {
    for (final rawLine in lines) {
      final cleaned = rawLine
          .replaceAll(RegExp(r"[^A-Za-z0-9'\-\s]"), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.length < 3) {
        continue;
      }
      final hasLetters = RegExp(r'[A-Za-z]').hasMatch(cleaned);
      final hasManyDigits =
          RegExp(r'\d').allMatches(cleaned).length > (cleaned.length * 0.25);
      if (!hasLetters || hasManyDigits) {
        continue;
      }
      final words = cleaned.split(' ').where((w) => w.isNotEmpty).length;
      if (words > 7) {
        continue;
      }
      return cleaned;
    }
    return '';
  }

  String _extractSetForField(List<String> lines) {
    final directRegex = RegExp(r'\b([A-Z0-9]{2,5})\s+([0-9]{1,5}[A-Z]?)\b');
    final collectorRegex = RegExp(r'\b([0-9]{1,5}[A-Z]?)\s*/\s*[0-9]{1,5}\b');
    final collectorOnlyRegex = RegExp(r'^\s*([0-9]{1,5}[A-Z]?)\s*$');
    for (var i = lines.length - 1; i >= 0; i--) {
      final upper = lines[i].toUpperCase();
      final match = directRegex.firstMatch(upper);
      if (match == null) {
        final collectorMatch = collectorRegex.firstMatch(upper);
        if (collectorMatch != null) {
          final collector = (collectorMatch.group(1) ?? '').trim();
          final nearSet = _guessSetTokenAroundIndex(lines, i);
          if (collector.isNotEmpty && nearSet.isNotEmpty) {
            return '$nearSet $collector';
          }
          if (collector.isNotEmpty) {
            return '#$collector';
          }
        }
        final clean = upper
            .replaceAll('O', '0')
            .replaceAll('I', '1')
            .replaceAll('L', '1')
            .replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ')
            .trim();
        final singleCollector = collectorOnlyRegex.firstMatch(clean);
        if (singleCollector != null) {
          final collector = (singleCollector.group(1) ?? '').trim();
          if (collector.isNotEmpty) {
            final nearSet = _guessSetTokenAroundIndex(lines, i);
            if (nearSet.isNotEmpty) {
              return '$nearSet $collector';
            }
            return '#$collector';
          }
        }
        continue;
      }
      final setCode = (match.group(1) ?? '').trim();
      final collector = (match.group(2) ?? '').trim();
      if (setCode.isEmpty || collector.isEmpty) {
        continue;
      }
      if (!RegExp(r'[A-Z]').hasMatch(setCode)) {
        continue;
      }
      return '${setCode.toUpperCase()} $collector';
    }
    return '';
  }

  String _guessSetTokenAroundIndex(List<String> lines, int anchorIndex) {
    const rarityTokens = {'C', 'U', 'R', 'M', 'L'};
    for (var delta = 0; delta <= 4; delta++) {
      final indices = <int>{anchorIndex - delta, anchorIndex + delta};
      for (final idx in indices) {
        if (idx < 0 || idx >= lines.length) {
          continue;
        }
        final tokens = lines[idx]
            .toUpperCase()
            .replaceAll('0', 'O')
            .replaceAll('1', 'I')
            .split(RegExp(r'[^A-Z0-9]'))
            .where((t) => t.isNotEmpty)
            .toList(growable: false);
        for (final token in tokens.reversed) {
          if (token.length < 2 || token.length > 5) {
            continue;
          }
          if (rarityTokens.contains(token)) {
            continue;
          }
          if (RegExp(r'^\d+$').hasMatch(token)) {
            continue;
          }
          final resolved = _resolveKnownSetCode(token);
          if (resolved != null) {
            return resolved.toUpperCase();
          }
          if (RegExp(r'^[A-Z]{2,5}$').hasMatch(token)) {
            return token;
          }
        }
      }
    }
    return '';
  }

  String? _resolveKnownSetCode(String token) {
    final raw = token.trim().toLowerCase();
    if (raw.isEmpty) {
      return null;
    }
    if (_knownSetCodes.contains(raw)) {
      return raw;
    }
    final normalized = raw
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('5', 's')
        .replaceAll('8', 'b');
    if (_knownSetCodes.contains(normalized)) {
      return normalized;
    }
    return null;
  }

  InputImage? _toInputImage(CameraImage image, CameraController controller) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) {
      return null;
    }
    final bytes = Uint8List.fromList(
      image.planes.expand((plane) => plane.bytes).toList(growable: false),
    );
    final rotation =
        InputImageRotationValue.fromRawValue(
          controller.description.sensorOrientation,
        ) ??
        InputImageRotation.rotation0deg;
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Widget _buildLimitedCoverageBadge() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xCC3A2412),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE9C46A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: Color(0xFFE9C46A),
          ),
          const SizedBox(width: 6),
          Text(
            l10n.limitedCoverageTapAllArtworks,
            style: TextStyle(
              color: Color(0xFFF5EEDA),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 96,
        leading: Row(
          children: [
            IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, color: Color(0xFFE9C46A)),
            ),
            IconButton(
              tooltip: l10n.scannerTutorialTitle,
              onPressed: _showScannerTutorialDialog,
              icon: const Icon(
                Icons.help_outline_rounded,
                color: Color(0xFFE9C46A),
              ),
            ),
          ],
        ),
        title: Text(l10n.liveCardScanTitle),
        actions: [
          IconButton(
            tooltip: l10n.torchTooltip,
            onPressed: (_initializing || !_torchAvailable)
                ? null
                : _toggleTorch,
            icon: Icon(
              _torchEnabled ? Icons.flash_on : Icons.flash_off,
              color: const Color(0xFFE9C46A),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_initializing || controller == null)
            const Center(child: CircularProgressIndicator())
          else
            CameraPreview(controller),
          IgnorePointer(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = (constraints.maxWidth - 48).clamp(
                  110.0,
                  constraints.maxWidth,
                );
                final mediaPadding = MediaQuery.of(context).padding;
                final topReserved = mediaPadding.top + 8;
                final bottomReserved = mediaPadding.bottom + 236;
                final frameAreaHeight =
                    (constraints.maxHeight - topReserved - bottomReserved)
                        .clamp(80.0, constraints.maxHeight);
                final availableHeight = frameAreaHeight;
                var guideWidth = availableWidth;
                var guideHeight = guideWidth / _cardAspectRatio;
                if (guideHeight > availableHeight) {
                  guideHeight = availableHeight;
                  guideWidth = guideHeight * _cardAspectRatio;
                }
                final centerY = topReserved + (frameAreaHeight / 2) + 10;
                final guideRect = Rect.fromCenter(
                  center: Offset(constraints.maxWidth / 2, centerY),
                  width: guideWidth,
                  height: guideHeight,
                );
                return AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) => CustomPaint(
                    painter: _CardGuideOverlayPainter(
                      guideRect: guideRect,
                      borderRadius: 20,
                      pulse: _lockedName.isNotEmpty
                          ? 1
                          : (0.45 + (_pulseController.value * 0.55)),
                      locked: _lockedName.isNotEmpty,
                    ),
                  ),
                );
              },
            ),
          ),
          if (_showCoverageBadgeInScanner && _limitedPrintCoverage)
            Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: SafeArea(
                bottom: false,
                child: Center(child: _buildLimitedCoverageBadge()),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 138,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickSetFilter,
                      icon: const Icon(Icons.auto_awesome_mosaic, size: 16),
                      label: Text(
                        _selectedSetFilterCode == null
                            ? l10n.scannerSetAnyLabel
                            : 'Set: ${_knownSetNames[_selectedSetFilterCode!] ?? _selectedSetFilterCode!.toUpperCase()}',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE9C46A),
                        side: const BorderSide(color: Color(0xFF5D4731)),
                        backgroundColor: const Color(0xAA1B1511),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    if (_scannerLanguageOptions.length > 1) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _pickLanguageFilter,
                        icon: const Icon(Icons.translate_rounded, size: 16),
                        label: Text(
                          _selectedLanguageFilterCode == null
                              ? (Localizations.localeOf(context).languageCode
                                        .toLowerCase()
                                        .startsWith('it')
                                    ? 'Lang: tutte'
                                    : 'Lang: any')
                              : 'Lang: ${_selectedLanguageFilterCode!.toUpperCase()}',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE9C46A),
                          side: const BorderSide(color: Color(0xFF5D4731)),
                          backgroundColor: const Color(0xAA1B1511),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _foilSelected = !_foilSelected;
                        });
                      },
                      icon: Icon(
                        _foilSelected ? Icons.star : Icons.star_border_rounded,
                        size: 16,
                      ),
                      label: Text(l10n.foilLabel),
                      style: FilledButton.styleFrom(
                        foregroundColor: const Color(0xFF1C1510),
                        backgroundColor: _foilSelected
                            ? const Color(0xFFE9C46A)
                            : const Color(0xCC3A2412),
                        side: BorderSide(
                          color: _foilSelected
                              ? const Color(0xFFF5DEA0)
                              : const Color(0xFF5D4731),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ScanFieldStatusBox(
                          label: AppLocalizations.of(context)!.nameLabel,
                          value: _lockedName.isEmpty
                              ? (_namePreview.isEmpty
                                    ? AppLocalizations.of(
                                        context,
                                      )!.waitingStatus
                                    : _namePreview)
                              : _lockedName,
                          locked: _lockedName.isNotEmpty,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: FilledButton(
                          onPressed:
                              (_namePreview.trim().isEmpty &&
                                  _lockedName.trim().isEmpty)
                              ? null
                              : _confirmRecognizedName,
                          style: FilledButton.styleFrom(
                            foregroundColor: const Color(0xFF1C1510),
                            backgroundColor: const Color(0xFFE9C46A),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Icon(Icons.done_rounded, size: 22),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFEFE7D8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppLocalizations.of(context)!.liveOcrActive,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFE9C46A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardGuideOverlayPainter extends CustomPainter {
  const _CardGuideOverlayPainter({
    required this.guideRect,
    required this.borderRadius,
    required this.pulse,
    required this.locked,
  });

  final Rect guideRect;
  final double borderRadius;
  final double pulse;
  final bool locked;

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;
    final guideRRect = RRect.fromRectAndRadius(
      guideRect,
      Radius.circular(borderRadius),
    );

    final overlayPath = Path()
      ..addRect(fullRect)
      ..addRRect(guideRRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      overlayPath,
      Paint()
        ..color = Colors.black.withValues(
          alpha: locked ? 0.42 : (0.40 + (0.12 * (1 - pulse))),
        ),
    );

    final frameColor = locked
        ? const Color(0xFF4CAF50)
        : const Color(0xFFE9C46A);
    final accentColor = locked
        ? const Color(0xFFC8FACC)
        : const Color(0xFFF5E3A4);
    final glowPaint = Paint()
      ..color = frameColor.withValues(
        alpha: locked ? 0.72 : (0.36 + (0.38 * pulse)),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(guideRRect, glowPaint);

    final outerStroke = Paint()
      ..color = frameColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawRRect(guideRRect, outerStroke);

    final innerRRect = guideRRect.deflate(6);
    final innerStroke = Paint()
      ..color = accentColor.withValues(
        alpha: locked ? 0.55 : (0.32 + (0.30 * pulse)),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(innerRRect, innerStroke);

    final accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const accentLen = 22.0;
    final left = guideRect.left + 12;
    final right = guideRect.right - 12;
    final top = guideRect.top + 12;
    final bottom = guideRect.bottom - 12;
    canvas.drawLine(
      Offset(left, top),
      Offset(left + accentLen, top),
      accentPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left, top + accentLen),
      accentPaint,
    );
    canvas.drawLine(
      Offset(right, top),
      Offset(right - accentLen, top),
      accentPaint,
    );
    canvas.drawLine(
      Offset(right, top),
      Offset(right, top + accentLen),
      accentPaint,
    );
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left + accentLen, bottom),
      accentPaint,
    );
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left, bottom - accentLen),
      accentPaint,
    );
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right - accentLen, bottom),
      accentPaint,
    );
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right, bottom - accentLen),
      accentPaint,
    );

    final zoneStroke = Paint()
      ..color = const Color(0x99E9C46A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final zoneFill = Paint()
      ..color = const Color(0x22E9C46A)
      ..style = PaintingStyle.fill;

    final nameZone = Rect.fromLTWH(
      guideRect.left + 14,
      guideRect.top + 14,
      guideRect.width - 28,
      guideRect.height * 0.16,
    );
    final nameRRect = RRect.fromRectAndRadius(
      nameZone,
      const Radius.circular(8),
    );
    canvas.drawRRect(nameRRect, zoneFill);
    canvas.drawRRect(nameRRect, zoneStroke);

    final nameTp = TextPainter(
      text: const TextSpan(
        text: 'NAME',
        style: TextStyle(
          color: Color(0xFFE9C46A),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    nameTp.paint(
      canvas,
      Offset(nameZone.left + 8, nameZone.center.dy - (nameTp.height / 2)),
    );
  }

  @override
  bool shouldRepaint(covariant _CardGuideOverlayPainter oldDelegate) {
    return oldDelegate.guideRect != guideRect ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.pulse != pulse ||
        oldDelegate.locked != locked;
  }
}

class _ScanFieldStatusBox extends StatelessWidget {
  const _ScanFieldStatusBox({
    required this.label,
    required this.value,
    required this.locked,
  });

  final String label;
  final String value;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final borderColor = locked
        ? const Color(0xFF4CAF50)
        : const Color(0x99E9C46A);
    final fillColor = locked
        ? const Color(0x334CAF50)
        : const Color(0x221C1713);
    final valueColor = locked
        ? const Color(0xFFC8FACC)
        : const Color(0xFFEFE7D8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: borderColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
