import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'db/app_database.dart';
import 'models.dart';

class _BulkOption {
  const _BulkOption({
    required this.type,
    required this.title,
    required this.description,
  });

  final String type;
  final String title;
  final String description;
}

class _GameOption {
  const _GameOption({
    required this.id,
    required this.name,
    required this.description,
  });

  final String id;
  final String name;
  final String description;
}

const List<_BulkOption> _bulkOptions = [
  _BulkOption(
    type: 'default_cards',
    title: 'All printings',
    description: 'All printings and languages. Heaviest.',
  ),
  _BulkOption(
    type: 'oracle_cards',
    title: 'Oracle cards',
    description: 'One entry per card. Fewer variants.',
  ),
  _BulkOption(
    type: 'unique_artwork',
    title: 'Unique artwork',
    description: 'One entry per artwork. Lightest.',
  ),
];

const List<_GameOption> _gameOptions = [
  _GameOption(
    id: 'pokemon',
    name: 'Pokemon',
    description: 'Pokemon TCG collections.',
  ),
  _GameOption(
    id: 'magic',
    name: 'Magic',
    description: 'Magic: The Gathering collections.',
  ),
  _GameOption(
    id: 'yugioh',
    name: 'Yu-Gi-Oh',
    description: 'Yu-Gi-Oh! collections.',
  ),
];

String _bulkTypeLabel(String? type) {
  if (type == null) {
    return 'Non selezionato';
  }
  for (final option in _bulkOptions) {
    if (option.type == type) {
      return option.title;
    }
  }
  return type;
}

String _bulkTypeFileName(String type) {
  final sanitized = type.replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
  return 'scryfall_$sanitized.json';
}

String _gameLabel(String? id) {
  if (id == null || id.isEmpty) {
    return 'Not selected';
  }
  for (final option in _gameOptions) {
    if (option.id == id) {
      return option.name;
    }
  }
  return id;
}

Future<String?> _showBulkTypePicker(
  BuildContext context, {
  required bool allowCancel,
  String? selectedType,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: allowCancel,
    builder: (context) {
      return AlertDialog(
        title: const Text('Choose card database'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _bulkOptions
              .map(
                (option) => ListTile(
                  title: Text(option.title),
                  subtitle: Text(option.description),
                  trailing: option.type == selectedType
                      ? const Icon(Icons.check, size: 18)
                      : null,
                  onTap: () => Navigator.of(context).pop(option.type),
                ),
              )
              .toList(),
        ),
        actions: allowCancel
            ? [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ]
            : null,
      );
    },
  );
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFC9A043),
      brightness: Brightness.dark,
      surface: const Color(0xFF1C1510),
      background: const Color(0xFF0E0A08),
    );
    final textTheme = GoogleFonts.sourceSans3TextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ).apply(
      bodyColor: const Color(0xFFEFE7D8),
      displayColor: const Color(0xFFF5EEDA),
    );
    final scaledTextTheme = textTheme.copyWith(
      bodySmall: textTheme.bodySmall?.copyWith(fontSize: 13.5),
      bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: 15.5),
      bodyLarge: textTheme.bodyLarge?.copyWith(fontSize: 17),
      titleSmall: textTheme.titleSmall?.copyWith(fontSize: 15),
      titleMedium: textTheme.titleMedium?.copyWith(fontSize: 17.5),
      titleLarge: textTheme.titleLarge?.copyWith(fontSize: 20),
      headlineSmall: textTheme.headlineSmall?.copyWith(fontSize: 24),
      headlineMedium: textTheme.headlineMedium?.copyWith(fontSize: 28),
    );

    return MaterialApp(
      title: 'TCG Tracker',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        textTheme: scaledTextTheme,
        scaffoldBackgroundColor: colorScheme.background,
        cardColor: const Color(0xFF171411),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      themeMode: ThemeMode.dark,
      home: const CollectionHomePage(),
    );
  }
}

class CollectionHomePage extends StatefulWidget {
  const CollectionHomePage({super.key});

  @override
  State<CollectionHomePage> createState() => _CollectionHomePageState();
}

class _CollectionHomePageState extends State<CollectionHomePage>
    with TickerProviderStateMixin {
  final List<CollectionInfo> _collections = [];
  String? _selectedBulkType;
  static const int _freeCollectionLimit = 5;
  String? _selectedGameId;
  bool _isProUnlocked = false;
  late final PurchaseManager _purchaseManager;
  late final VoidCallback _purchaseListener;
  bool _checkingBulk = false;
  bool _bulkUpdateAvailable = false;
  String? _bulkDownloadUri;
  DateTime? _bulkUpdatedAt;
  bool _bulkDownloading = false;
  double _bulkDownloadProgress = 0;
  int _bulkDownloadReceived = 0;
  int _bulkDownloadTotal = 0;
  String? _bulkDownloadError;
  bool _bulkImporting = false;
  double _bulkImportProgress = 0;
  int _bulkImportedCount = 0;
  String? _bulkUpdatedAtRaw;
  bool _cardsMissing = false;
  int _totalCardCount = 0;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseOpacity;
  late final Animation<double> _pulseScale;
  late final AnimationController _snakeController;
  static const _setPrefix = 'Set: ';
  Map<String, String> _setNameLookup = {};

  @override
  void initState() {
    super.initState();
    unawaited(ScryfallDatabase.instance.open());
    _purchaseManager = PurchaseManager.instance;
    _purchaseListener = () {
      if (!mounted) {
        return;
      }
      setState(() {
        _isProUnlocked = _purchaseManager.isPro;
      });
    };
    _purchaseManager.addListener(_purchaseListener);
    unawaited(_purchaseManager.init());
    _isProUnlocked = _purchaseManager.isPro;
    unawaited(_loadGameSelection());
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseOpacity = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseScale = Tween<double>(begin: 0.96, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _snakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _initializeStartup();
    _loadCollections();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _snakeController.dispose();
    _purchaseManager.removeListener(_purchaseListener);
    super.dispose();
  }

  bool _isSetCollection(CollectionInfo collection) {
    return collection.name.startsWith(_setPrefix);
  }

  String _setCollectionName(String setCode) {
    return '$_setPrefix${setCode.trim().toLowerCase()}';
  }

  String? _setCodeForCollection(CollectionInfo collection) {
    if (!_isSetCollection(collection)) {
      return null;
    }
    return collection.name.substring(_setPrefix.length).trim();
  }

  String _collectionDisplayName(CollectionInfo collection) {
    final setCode = _setCodeForCollection(collection);
    if (setCode != null) {
      return _setNameLookup[setCode] ?? setCode.toUpperCase();
    }
    return collection.name;
  }

  int _userCollectionCount() {
    return _collections.where((item) => item.name != 'All cards').length;
  }

  bool _canCreateCollection() {
    return _isProUnlocked || _userCollectionCount() < _freeCollectionLimit;
  }

  Future<void> _loadGameSelection() async {
    final primary = await AppSettings.loadPrimaryGameId();
    final enabled = await AppSettings.loadEnabledGames();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedGameId = primary;
    });
    if (primary == null || primary.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _promptInitialGameSelection();
        }
      });
    } else if (!enabled.contains(primary)) {
      await AppSettings.saveEnabledGames([...enabled, primary]);
    }
  }

  Future<void> _promptInitialGameSelection() async {
    final selected = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose your game'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _gameOptions
                .map(
                  (option) => ListTile(
                    title: Text(option.name),
                    subtitle: Text(option.description),
                    onTap: () => Navigator.of(context).pop(option.id),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
    if (selected == null || selected.isEmpty) {
      return;
    }
    await _setPrimaryGame(selected);
  }

  Future<void> _setPrimaryGame(String id) async {
    final enabled = await AppSettings.loadEnabledGames();
    final updated = enabled.contains(id) ? enabled : [...enabled, id];
    await AppSettings.saveEnabledGames(updated);
    await AppSettings.savePrimaryGameId(id);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedGameId = id;
    });
  }

  Future<void> _showCollectionLimitDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Collection limit reached'),
          content: Text(
            'The free version allows up to $_freeCollectionLimit collections. '
            'Upgrade to Pro to unlock unlimited collections.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProPage(),
                  ),
                );
              },
              child: const Text('Upgrade'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProBanner(BuildContext context) {
    final isPro = _isProUnlocked;
    final subtitle = isPro
        ? 'Pro active. Unlimited collections.'
        : 'Base plan: up to $_freeCollectionLimit collections.';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.75),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF3A2F24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              isPro ? Icons.verified : Icons.workspace_premium,
              color: const Color(0xFFE9C46A),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPro ? 'Pro enabled' : 'Upgrade to Pro',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFBFAE95),
                        ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProPage(),
                  ),
                );
              },
              child: Text(isPro ? 'Manage' : 'Upgrade'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadCollections() async {
    final collections = await ScryfallDatabase.instance.fetchCollections();
    final owned = await ScryfallDatabase.instance.countOwnedCards();
    if (!mounted) {
      return;
    }
    if (collections.isEmpty) {
      final id = await ScryfallDatabase.instance.addCollection('All cards');
      if (!mounted) {
        return;
      }
      setState(() {
        _collections
          ..clear()
          ..add(CollectionInfo(id: id, name: 'All cards', cardCount: 0));
        _totalCardCount = owned;
      });
      return;
    }
    final renamed = <CollectionInfo>[];
    final setCodes = <String>[];
    for (final collection in collections) {
      if (collection.name == 'My collection') {
        await ScryfallDatabase.instance
            .renameCollection(collection.id, 'All cards');
        renamed.add(
          CollectionInfo(
            id: collection.id,
            name: 'All cards',
            cardCount: collection.cardCount,
          ),
        );
      } else {
        renamed.add(collection);
      }
      final setCode = _setCodeForCollection(collection);
      if (setCode != null) {
        setCodes.add(setCode);
      }
    }
    final setNames =
        await ScryfallDatabase.instance.fetchSetNamesForCodes(setCodes);
    if (!mounted) {
      return;
    }
    setState(() {
      _collections
        ..clear()
        ..addAll(renamed);
      _totalCardCount = owned;
      _setNameLookup = setNames;
    });
  }

  List<Widget> _buildCollectionSections(BuildContext context) {
    final allCards = _collections
        .cast<CollectionInfo?>()
        .firstWhere((item) => item?.name == 'All cards', orElse: () => null);
    final userCollections = _collections
        .where((collection) => collection.name != 'All cards')
        .toList();
    final widgets = <Widget>[];

    if (allCards != null) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _CollectionCard(
            name: allCards.name,
            count: _totalCardCount,
            onLongPress: (position) {
              _showCollectionActions(allCards, position);
            },
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CollectionDetailPage(
                    collectionId: allCards.id,
                    name: allCards.name,
                    isAllCards: true,
                  ),
                ),
              ).then((_) => _loadCollections());
            },
          ),
        ),
      );
    }

    widgets.add(const SizedBox(height: 6));
    widgets.add(const _SectionDivider(label: 'My collections'));
    widgets.add(const SizedBox(height: 12));

    if (userCollections.isEmpty) {
      widgets.add(_buildCreateCollectionCard(
        context,
        title: 'Build your own collections',
        subtitle: 'Tap to create your first collection.',
        onTap: () => _showCreateCollectionOptions(context),
      ));
      return widgets;
    }

    for (final collection in userCollections) {
      final setCode = _setCodeForCollection(collection);
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _CollectionCard(
            name: _collectionDisplayName(collection),
            count: collection.cardCount,
            onLongPress: (position) {
              _showCollectionActions(collection, position);
            },
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CollectionDetailPage(
                    collectionId: collection.id,
                    name: _collectionDisplayName(collection),
                    isSetCollection: setCode != null,
                    setCode: setCode,
                  ),
                ),
              ).then((_) => _loadCollections());
            },
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildCreateCollectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF3A2F24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.add_box, color: Color(0xFFE9C46A)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFBFAE95),
                            ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFFBFAE95)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _initializeStartup() async {
    final storedBulkType = await AppSettings.loadBulkType();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedBulkType = storedBulkType;
      _bulkUpdateAvailable = false;
      _bulkDownloadUri = null;
      _bulkUpdatedAt = null;
      _bulkUpdatedAtRaw = null;
      _bulkDownloadError = null;
    });

    await _checkCardsInstalled();
    if (!mounted) {
      return;
    }

    if (_cardsMissing && _selectedBulkType == null) {
      await Future<void>.delayed(Duration.zero);
      final selected =
          await _showBulkTypePicker(context, allowCancel: false);
      if (!mounted) {
        return;
      }
      if (selected != null) {
        await AppSettings.saveBulkType(selected);
        if (!mounted) {
          return;
        }
        setState(() {
          _selectedBulkType = selected;
        });
      }
    }

    if (_selectedBulkType != null) {
      await _checkScryfallBulk();
    }
  }

  Future<bool> _ensureBulkTypeSelected() async {
    if (_selectedBulkType != null) {
      return true;
    }
    final selected = await _showBulkTypePicker(
      context,
      allowCancel: true,
    );
    if (!mounted) {
      return false;
    }
    if (selected == null) {
      return false;
    }
    await AppSettings.saveBulkType(selected);
    if (!mounted) {
      return false;
    }
    setState(() {
      _selectedBulkType = selected;
      _bulkUpdateAvailable = false;
      _bulkDownloadUri = null;
      _bulkUpdatedAt = null;
      _bulkUpdatedAtRaw = null;
    });
    await _checkScryfallBulk();
    return true;
  }

  Future<void> _checkScryfallBulk() async {
    if (_checkingBulk) {
      return;
    }
    final bulkType = _selectedBulkType;
    if (bulkType == null) {
      return;
    }
    setState(() {
      _checkingBulk = true;
    });

    final result = await ScryfallBulkChecker().checkAllCardsUpdate(bulkType);
    if (!mounted) {
      return;
    }

    setState(() {
      _checkingBulk = false;
      _bulkUpdateAvailable = result.updateAvailable;
      _bulkDownloadUri = result.downloadUri;
      _bulkUpdatedAt = result.updatedAt;
      _bulkUpdatedAtRaw = result.updatedAtRaw;
    });

    if (result.updateAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scryfall bulk update available.'),
        ),
      );
    }
  }

  Future<void> _checkCardsInstalled() async {
    final count = await ScryfallDatabase.instance.countCards();
    final owned = await ScryfallDatabase.instance.countOwnedCards();
    if (!mounted) {
      return;
    }
    if (count > 0) {
      setState(() {
        _cardsMissing = false;
        _totalCardCount = owned;
      });
      return;
    }
    setState(() {
      _cardsMissing = true;
      _totalCardCount = owned;
    });
    final bulkType = _selectedBulkType;
    if (bulkType == null) {
      return;
    }
    final result = await ScryfallBulkChecker().checkAllCardsUpdate(bulkType);
    if (!mounted) {
      return;
    }
    setState(() {
      _bulkDownloadUri = result.downloadUri ?? _bulkDownloadUri;
      _bulkUpdatedAt = result.updatedAt ?? _bulkUpdatedAt;
      _bulkUpdatedAtRaw = result.updatedAtRaw ?? _bulkUpdatedAtRaw;
      _bulkUpdateAvailable = true;
    });
  }

  Future<void> _addCollection(BuildContext context) async {
    if (!_canCreateCollection()) {
      await _showCollectionLimitDialog();
      return;
    }
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New collection'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Collection name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                Navigator.of(context).pop(value.isEmpty ? null : value);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (name == null) {
      return;
    }

    int id;
    try {
      id = await ScryfallDatabase.instance.addCollection(name);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add collection: $error')),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _collections.add(CollectionInfo(id: id, name: name, cardCount: 0));
    });

    final addCards = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Vuoi aggiungere delle carte?'),
          content: const Text(
            'Puoi usare la ricerca e i filtri per aggiungere più carte.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Non ora'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sì'),
            ),
          ],
        );
      },
    );
    if (addCards == true && mounted) {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => CollectionDetailPage(
                collectionId: id,
                name: name,
                autoOpenAddCard: true,
              ),
            ),
          )
          .then((_) => _loadCollections());
    }
  }

  Future<void> _addSetCollection(BuildContext context) async {
    if (!_canCreateCollection()) {
      await _showCollectionLimitDialog();
      return;
    }
    final sets = await ScryfallDatabase.instance.fetchAvailableSets();
    if (!mounted) {
      return;
    }
    if (sets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No sets available yet.')),
      );
      return;
    }

    final selected = await showDialog<SetInfo>(
      context: context,
      builder: (context) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setState) {
            final filtered = sets
                .where((set) =>
                    set.name.toLowerCase().contains(query.toLowerCase()) ||
                    set.code.toLowerCase().contains(query.toLowerCase()))
                .toList();
            return AlertDialog(
              title: const Text('New set collection'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search set',
                      ),
                      onChanged: (value) {
                        setState(() {
                          query = value.trim();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final set = filtered[index];
                          return ListTile(
                            title: Text(set.name),
                            subtitle: Text(set.code.toUpperCase()),
                            onTap: () => Navigator.of(context).pop(set),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected == null) {
      return;
    }

    final resolvedName = _setCollectionName(selected.code);
    if (_collections.any((item) => item.name == resolvedName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collection already exists.')),
      );
      return;
    }

    int id;
    try {
      id = await ScryfallDatabase.instance.addCollection(resolvedName);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add collection: $error')),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _collections.add(
        CollectionInfo(id: id, name: resolvedName, cardCount: 0),
      );
      _setNameLookup = {
        ..._setNameLookup,
        selected.code: selected.name,
      };
    });
  }

  Future<void> _showCreateCollectionOptions(BuildContext context) async {
    if (!_canCreateCollection()) {
      await _showCollectionLimitDialog();
      return;
    }
    final selection = await showModalBottomSheet<_CollectionCreateAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CreateCollectionSheet();
      },
    );
    if (selection == _CollectionCreateAction.custom) {
      await _addCollection(context);
    } else if (selection == _CollectionCreateAction.setBased) {
      await _addSetCollection(context);
    }
  }

  Future<void> _showCollectionActions(
    CollectionInfo collection,
    Offset globalPosition,
  ) async {
    if (collection.name == 'All cards') {
      return;
    }
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) {
      return;
    }
    final isSetCollection = _isSetCollection(collection);
    final menuItems = <PopupMenuEntry<_CollectionAction>>[];
    if (!isSetCollection) {
      menuItems.add(
        const PopupMenuItem(
          value: _CollectionAction.rename,
          child: Row(
            children: [
              Icon(Icons.edit, size: 18),
              SizedBox(width: 8),
              Text('Rename'),
            ],
          ),
        ),
      );
    }
    menuItems.add(
      const PopupMenuItem(
        value: _CollectionAction.delete,
        child: Row(
          children: [
            Icon(Icons.delete_outline, size: 18),
            SizedBox(width: 8),
            Text('Delete'),
          ],
        ),
      ),
    );
    final selection = await showMenu<_CollectionAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(globalPosition, globalPosition),
        Offset.zero & overlay.size,
      ),
      items: menuItems,
    );

    if (selection == _CollectionAction.rename) {
      await _renameCollection(collection);
    } else if (selection == _CollectionAction.delete) {
      await _deleteCollection(collection);
    }
  }

  Future<void> _renameCollection(CollectionInfo collection) async {
    if (_isSetCollection(collection)) {
      return;
    }
    final controller =
        TextEditingController(text: _collectionDisplayName(collection));
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename collection'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Collection name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                Navigator.of(context).pop(value.isEmpty ? null : value);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (name == null) {
      return;
    }

    final resolvedName = name;
    if (resolvedName == collection.name) {
      return;
    }
    await ScryfallDatabase.instance.renameCollection(
      collection.id,
      resolvedName,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      final index =
          _collections.indexWhere((item) => item.id == collection.id);
      if (index != -1) {
        _collections[index] = CollectionInfo(
          id: collection.id,
          name: resolvedName,
          cardCount: collection.cardCount,
        );
      }
    });
  }

  Future<void> _deleteCollection(CollectionInfo collection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete collection?'),
          content: Text(
            '"${_collectionDisplayName(collection)}" will be removed from this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ScryfallDatabase.instance.deleteCollection(collection.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _collections.removeWhere((item) => item.id == collection.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Collection deleted.')),
    );
  }

  Future<void> _onBulkUpdatePressed() async {
    if (_bulkDownloading) {
      return;
    }
    if (_bulkImporting) {
      return;
    }
    final ready = await _ensureBulkTypeSelected();
    if (!ready) {
      return;
    }
    if (_bulkDownloadUri == null) {
      await _checkScryfallBulk();
    }
    if (_bulkDownloadUri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download link unavailable.')),
      );
      return;
    }
    await _downloadBulkFile(_bulkDownloadUri!);
  }

  Future<void> _downloadBulkFile(String downloadUri) async {
    final bulkType = _selectedBulkType;
    if (bulkType == null) {
      return;
    }
    setState(() {
      _bulkDownloading = true;
      _bulkDownloadProgress = 0;
      _bulkDownloadReceived = 0;
      _bulkDownloadTotal = 0;
      _bulkDownloadError = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    try {
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(downloadUri));
        final response = await client.send(request);
        if (response.statusCode != 200) {
          throw HttpException('HTTP ${response.statusCode}');
        }

        final directory = await getApplicationDocumentsDirectory();
        final targetPath =
            '${directory.path}/${_bulkTypeFileName(bulkType)}';
        final tempPath = '$targetPath.download';
        final file = File(tempPath);
        final sink = file.openWrite();

        final totalBytes = response.contentLength ?? 0;
        if (mounted) {
          setState(() {
            _bulkDownloadTotal = totalBytes;
          });
        }
        var received = 0;
        await for (final chunk in response.stream) {
          received += chunk.length;
          if (mounted) {
            setState(() {
              _bulkDownloadReceived = received;
            });
          }
          sink.add(chunk);
          if (totalBytes > 0 && mounted) {
            setState(() {
              _bulkDownloadProgress = received / totalBytes;
            });
          }
        }
        await sink.flush();
        await sink.close();
        await file.rename(targetPath);

        if (!mounted) {
          return;
        }

        setState(() {
          _bulkDownloading = false;
          _bulkDownloadProgress = 1;
        });
        messenger.showSnackBar(
          SnackBar(content: Text('Download complete: $targetPath')),
        );
        await _importBulkFile(targetPath);
      } finally {
        client.close();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bulkDownloading = false;
        _bulkDownloadError = error.toString();
      });
      messenger.showSnackBar(
        SnackBar(content: Text('Download failed: $_bulkDownloadError')),
      );
    }
  }

  Future<void> _importBulkFile(String filePath) async {
    if (_bulkImporting) {
      return;
    }
    final storedLanguages = await AppSettings.loadSearchLanguages();
    final allowedLanguages =
        storedLanguages.isEmpty ? {'en'} : storedLanguages;
    setState(() {
      _bulkImporting = true;
      _bulkImportProgress = 0;
      _bulkImportedCount = 0;
    });

    final messenger = ScaffoldMessenger.of(context);
    try {
      final importer = ScryfallBulkImporter();
      await importer.importAllCardsJson(
        filePath,
        updatedAtRaw: _bulkUpdatedAtRaw,
        bulkType: _selectedBulkType,
        allowedLanguages: allowedLanguages.toList()..sort(),
        onProgress: (count, progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _bulkImportedCount = count;
            _bulkImportProgress = progress;
          });
        },
      );

      if (!mounted) {
        return;
      }
      await _rebuildSearchIndex();

      if (!mounted) {
        return;
      }
      final total = await ScryfallDatabase.instance.countOwnedCards();
      if (!mounted) {
        return;
      }

      setState(() {
        _bulkImporting = false;
        _bulkImportProgress = 1;
        _bulkUpdateAvailable = false;
        _cardsMissing = false;
        _totalCardCount = total;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Import complete.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bulkImporting = false;
      });
      messenger.showSnackBar(
        SnackBar(content: Text('Import failed: $error')),
      );
    }
  }

  Future<void> _rebuildSearchIndex() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rebuilding search index'),
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                    'Required after large updates.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      },
    );
    try {
      await ScryfallDatabase.instance.rebuildCardsFts();
    } finally {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    }
  }

  Widget _buildUpdateCta(BuildContext context) {
    final progressPercent = (_bulkDownloadProgress * 100).clamp(0, 100).round();
    final importPercent = (_bulkImportProgress * 100).clamp(0, 100).round();
    final isBusy = _bulkDownloading || _bulkImporting;
    final actionLabel = _selectedBulkType == null
        ? 'Choose database'
        : _cardsMissing
            ? 'Download database'
            : 'Download update';
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: FadeTransition(
        opacity: _pulseOpacity,
        child: ScaleTransition(
          scale: _pulseScale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFE9C46A),
                  Color(0xFFB85C38),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE9C46A).withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isBusy ? null : _onBulkUpdatePressed,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isBusy ? Icons.downloading : Icons.cloud_download,
                        color: Colors.black,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _bulkDownloading
                            ? (_bulkDownloadTotal > 0
                                ? 'Downloading... $progressPercent%'
                                : 'Downloading...')
                            : _bulkImporting
                                ? 'Importing... $importPercent%'
                                : actionLabel,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Colors.black,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bulkLabel = _bulkTypeLabel(_selectedBulkType);
    final showImportCta = _cardsMissing ||
        _bulkUpdateAvailable ||
        _bulkDownloadError != null ||
        _bulkDownloading ||
        _bulkImporting ||
        _selectedBulkType == null;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const _AppBackground(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 40),
                          Expanded(
                            child: Column(
                              children: [
                                _TitleLockup(),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Settings',
                            icon: const Icon(Icons.settings),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SettingsPage(),
                                ),
                              ).then((_) {
                                if (mounted) {
                                  _initializeStartup();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_checkingBulk)
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Checking updates...'),
                          ],
                        )
                      else if (_bulkDownloading)
                        Text(
                          _bulkDownloadTotal > 0
                              ? 'Downloading update... ${(_bulkDownloadProgress * 100).clamp(0, 100).round()}% (${_formatBytes(_bulkDownloadReceived)} / ${_formatBytes(_bulkDownloadTotal)})'
                              : 'Downloading update... ${_formatBytes(_bulkDownloadReceived)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFE3B55C),
                              ),
                        )
                      else if (_bulkImporting)
                        Text(
                          'Importing cards... ${(_bulkImportProgress * 100).clamp(0, 100).round()}% (${_bulkImportedCount} cards)',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFE3B55C),
                              ),
                        )
                      else if (_bulkDownloadError != null)
                        Text(
                          'Download failed. Tap update again.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFE38B5C),
                              ),
                        )
                      else if (_cardsMissing)
                        Text(
                          _selectedBulkType == null
                              ? 'Select a database to download.'
                              : 'Database $bulkLabel missing. Download required.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFE38B5C),
                              ),
                        )
                      else if (_bulkUpdateAvailable)
                        Text(
                          'Update ready: ${_bulkUpdatedAt?.toLocal().toIso8601String().split('T').first ?? 'unknown'}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFE3B55C),
                              ),
                        )
                      else
                        Text(
                          'Up to date.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF908676),
                              ),
                        ),
                      const SizedBox(height: 10),
                      if (showImportCta)
                        OutlinedButton.icon(
                          onPressed: (_bulkDownloading || _bulkImporting)
                              ? null
                              : _onBulkUpdatePressed,
                          icon: const Icon(Icons.cloud_download, size: 18),
                          label: const Text('Import now'),
                        ),
                      if (_selectedGameId != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Game: ${_gameLabel(_selectedGameId)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFFBFAE95),
                                  ),
                        ),
                      ],
                      if (_bulkDownloading || _bulkImporting)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _SnakeProgressBar(
                            animation: _snakeController,
                            value: _bulkDownloading
                                ? _bulkDownloadProgress
                                : _bulkImportProgress,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                    children: [
                      _buildProBanner(context),
                      ..._buildCollectionSections(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateCollectionOptions(context),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: (_bulkUpdateAvailable ||
              _bulkDownloading ||
              _bulkImporting ||
              _cardsMissing)
          ? _buildUpdateCta(context)
          : null,
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.name,
    required this.count,
    required this.onTap,
    this.onLongPress,
  });

  final String name;
  final int count;
  final VoidCallback onTap;
  final ValueChanged<Offset>? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: onLongPress == null
          ? null
          : (details) => onLongPress?.call(details.globalPosition),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.collections_bookmark, color: Color(0xFFE9C46A)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$count card${count == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFBFAE95),
                            ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFFBFAE95)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: _DividerGlow(),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFFC9BDA4),
                letterSpacing: 0.6,
              ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: _DividerGlow(),
        ),
      ],
    );
  }
}

class _DividerGlow extends StatelessWidget {
  const _DividerGlow();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0x00E2C26A),
            const Color(0x66E2C26A),
            const Color(0x00E2C26A),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _CreateCollectionSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Create collection',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.auto_awesome_mosaic),
            title: const Text('Set collection'),
            subtitle: const Text('Tracks missing cards by set.'),
            onTap: () => Navigator.of(context)
                .pop(_CollectionCreateAction.setBased),
          ),
          ListTile(
            leading: const Icon(Icons.collections_bookmark),
            title: const Text('Custom collection'),
            subtitle: const Text('Add cards manually.'),
            onTap: () =>
                Navigator.of(context).pop(_CollectionCreateAction.custom),
          ),
        ],
      ),
    );
  }
}

class _TitleLockup extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        );
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          'TCG TRACKER',
          style: textStyle?.copyWith(
            color: const Color(0xFF39251A),
            shadows: [
              const Shadow(
                blurRadius: 18,
                color: Color(0x55E2C26A),
                offset: Offset(0, 6),
              ),
            ],
          ),
        ),
        ShaderMask(
          shaderCallback: (bounds) {
            return const LinearGradient(
              colors: [
                Color(0xFFF5E3A4),
                Color(0xFFE2C26A),
                Color(0xFFB85C38),
              ],
            ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height));
          },
          child: Text(
            'TCG TRACKER',
            style: textStyle?.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

enum _CollectionAction { rename, delete }

enum _CollectionCreateAction { custom, setBased }

class CollectionDetailPage extends StatefulWidget {
  const CollectionDetailPage({
    super.key,
    required this.collectionId,
    required this.name,
    this.isAllCards = false,
    this.isSetCollection = false,
    this.setCode,
    this.autoOpenAddCard = false,
  });

  final int collectionId;
  final String name;
  final bool isAllCards;
  final bool isSetCollection;
  final String? setCode;
  final bool autoOpenAddCard;

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loading = true;
  bool _loadingLanguages = true;
  bool _loadingGames = true;
  List<String> _languageOptions = [];
  Set<String> _selectedLanguages = {};
  String? _bulkType;
  List<String> _enabledGames = [];
  String? _primaryGameId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final stored = await AppSettings.loadSearchLanguages();
    final cachedLanguages = await AppSettings.loadAvailableLanguages();
    final allOptions = AppSettings.languageLabels.keys.toList()..sort();
    final bulkType = await AppSettings.loadBulkType();
    final enabledGames = await AppSettings.loadEnabledGames();
    final primaryGameId = await AppSettings.loadPrimaryGameId();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedLanguages = stored.isEmpty ? {'en'} : stored;
      _languageOptions = cachedLanguages.isEmpty ? allOptions : cachedLanguages;
      _bulkType = bulkType;
      _enabledGames = enabledGames;
      _primaryGameId = primaryGameId;
      _loading = false;
      _loadingLanguages = cachedLanguages.isEmpty;
      _loadingGames = false;
    });
    if (cachedLanguages.isNotEmpty) {
      return;
    }
    final available = AppSettings.languageLabels.keys.toList()..sort();
    if (!mounted) {
      return;
    }
    final resolved =
        available.isEmpty ? AppSettings.defaultLanguages : available;
    await AppSettings.saveAvailableLanguages(resolved);
    if (!mounted) {
      return;
    }
    setState(() {
      _languageOptions = resolved;
      _loadingLanguages = false;
    });
  }

  Future<void> _saveLanguages() async {
    await AppSettings.saveSearchLanguages(_selectedLanguages);
  }

  String _languageLabel(String code) {
    return AppSettings.languageLabels[code] ?? code.toUpperCase();
  }

  Future<void> _addLanguage() async {
    final options = _languageOptions
        .where((code) => !_selectedLanguages.contains(code))
        .toList()
      ..sort();
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All languages are already added.')),
      );
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add language'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: options.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final code = options[index];
                return ListTile(
                  title: Text(_languageLabel(code)),
                  subtitle: Text(code),
                  onTap: () => Navigator.of(context).pop(code),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _selectedLanguages.add(selected);
    });
    await _saveLanguages();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Language added. Download again to import the cards.',
        ),
      ),
    );
  }

  Future<void> _removeLanguage(String code) async {
    if (code == 'en') {
      return;
    }
    setState(() {
      _selectedLanguages.remove(code);
    });
    await _saveLanguages();
  }

  Future<void> _changeBulkType() async {
    final selected = await _showBulkTypePicker(
      context,
      allowCancel: true,
      selectedType: _bulkType,
    );
    if (selected == null || selected == _bulkType) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change database?'),
          content: const Text(
            'The current database will be removed and you will need to '
            'download the cards again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          title: Text('Updating database'),
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text('Preparing the new database...'),
              ),
            ],
          ),
        );
      },
    );

    try {
      await AppSettings.saveBulkType(selected);
      await ScryfallBulkChecker().resetState();
      await ScryfallDatabase.instance.hardReset();
      await _deleteBulkFiles();
    } finally {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _bulkType = selected;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Database changed. Go back to Home to download.'),
      ),
    );
  }

  Future<void> _setPrimaryGame(String id) async {
    if (id.isEmpty) {
      return;
    }
    if (!_enabledGames.contains(id)) {
      _enabledGames = [..._enabledGames, id];
      await AppSettings.saveEnabledGames(_enabledGames);
    }
    await AppSettings.savePrimaryGameId(id);
    if (!mounted) {
      return;
    }
    setState(() {
      _primaryGameId = id;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Primary game set to ${_gameLabel(id)}.')),
    );
  }

  Future<void> _showGameLimitDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Game limit reached'),
          content: const Text(
            'The free version allows one game. Upgrade to Pro to add more.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProPage(),
                  ),
                );
              },
              child: const Text('Upgrade'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addGame() async {
    final manager = PurchaseManager.instance;
    if (!manager.isPro && _enabledGames.length >= 1) {
      await _showGameLimitDialog();
      return;
    }
    final remaining = _gameOptions
        .where((option) => !_enabledGames.contains(option.id))
        .toList();
    if (remaining.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All games are already added.')),
      );
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add game'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: remaining
                .map(
                  (option) => ListTile(
                    title: Text(option.name),
                    subtitle: Text(option.description),
                    onTap: () => Navigator.of(context).pop(option.id),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
    if (selected == null || selected.isEmpty) {
      return;
    }
    final updated = [..._enabledGames, selected];
    await AppSettings.saveEnabledGames(updated);
    if (!mounted) {
      return;
    }
    setState(() {
      _enabledGames = updated;
      _primaryGameId ??= selected;
    });
    await AppSettings.savePrimaryGameId(_primaryGameId!);
  }

  String _gameStatusLabel(String id) {
    if (_primaryGameId == id) {
      return 'Primary';
    }
    return 'Added';
  }

  Future<void> _performHardReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Factory reset?'),
          content: const Text(
            'This will remove all collections, the card database, and '
            'downloads. The app will return to a first-launch state.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          title: Text('Cleaning up'),
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text('Removing local data...'),
              ),
            ],
          ),
        );
      },
    );

    try {
      await AppSettings.reset();
      await ScryfallBulkChecker().resetState();
      await ScryfallDatabase.instance.hardReset();
      await _deleteBulkFiles();
    } finally {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reset complete. Restart the app.'),
      ),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _deleteBulkFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final legacyPath = '${directory.path}/scryfall_all_cards.json';
    final legacyTempPath = '$legacyPath.download';
    final legacyFile = File(legacyPath);
    final legacyTempFile = File(legacyTempPath);
    if (await legacyFile.exists()) {
      await legacyFile.delete();
    }
    if (await legacyTempFile.exists()) {
      await legacyTempFile.delete();
    }
    for (final option in _bulkOptions) {
      final targetPath =
          '${directory.path}/${_bulkTypeFileName(option.type)}';
      final tempPath = '$targetPath.download';
      final mainFile = File(targetPath);
      final tempFile = File(tempPath);
      if (await mainFile.exists()) {
        await mainFile.delete();
      }
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedLanguages = _selectedLanguages.toList()..sort();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Stack(
        children: [
          const _AppBackground(),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Text(
                  'Search languages',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose which card languages appear in search.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFBFAE95),
                      ),
                ),
                const SizedBox(height: 12),
                if (_loadingLanguages)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  ...selectedLanguages.map(
                    (code) => ListTile(
                      title: Text(_languageLabel(code)),
                      subtitle: Text(code),
                      contentPadding: EdgeInsets.zero,
                      trailing: code == 'en'
                          ? const Text('Default')
                          : IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => _removeLanguage(code),
                            ),
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _loadingLanguages ? null : _addLanguage,
                  icon: const Icon(Icons.add),
                  label: const Text('Add language'),
                ),
                const SizedBox(height: 24),
                Text(
                  'Card database',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose which database to download from Scryfall.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFBFAE95),
                      ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: Text(_bulkTypeLabel(_bulkType)),
                  subtitle: const Text('Selected type'),
                  contentPadding: EdgeInsets.zero,
                  trailing: TextButton(
                    onPressed: _changeBulkType,
                    child: const Text('Change'),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Games',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage which TCGs are enabled.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFBFAE95),
                      ),
                ),
                const SizedBox(height: 12),
                if (_loadingGames)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  ..._enabledGames.map(
                    (id) => ListTile(
                      title: Text(_gameLabel(id)),
                      subtitle: Text(_gameStatusLabel(id)),
                      contentPadding: EdgeInsets.zero,
                      trailing: TextButton(
                        onPressed: () => _setPrimaryGame(id),
                        child: const Text('Make primary'),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _addGame,
                  icon: const Icon(Icons.add),
                  label: const Text('Add game'),
                ),
                const SizedBox(height: 24),
                Text(
                  'Pro',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Unlock unlimited collections.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFBFAE95),
                      ),
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: PurchaseManager.instance,
                  builder: (context, _) {
                    final manager = PurchaseManager.instance;
                    return ListTile(
                      title: const Text('Pro status'),
                      subtitle: Text(
                        manager.isPro ? 'Pro active' : 'Base plan',
                      ),
                      contentPadding: EdgeInsets.zero,
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ProPage(),
                            ),
                          );
                        },
                        child: const Text('Manage'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Reset',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Remove all collections and the card database.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFBFAE95),
                      ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _performHardReset,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB85C38),
                  ),
                  child: const Text('Factory reset'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class ProPage extends StatefulWidget {
  const ProPage({super.key});

  @override
  State<ProPage> createState() => _ProPageState();
}

class _ProPageState extends State<ProPage> {
  late final PurchaseManager _manager;

  @override
  void initState() {
    super.initState();
    _manager = PurchaseManager.instance;
    unawaited(_manager.init());
  }

  Widget _buildFeatureRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFE9C46A)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _manager,
      builder: (context, _) {
        final isPro = _manager.isPro;
        final priceLabel = _manager.priceLabel;
        final testMode = _manager.testMode;
        final storeNote = _manager.storeAvailable
            ? 'Store available'
            : 'Store not available yet';
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Pro'),
          ),
          body: Stack(
            children: [
              const _AppBackground(),
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surface.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF3A2F24)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPro ? 'Pro active' : 'Base plan',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isPro
                              ? 'Unlimited collections are unlocked.'
                              : 'Unlock Pro to remove the 5-collection limit.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFFBFAE95),
                                  ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Price: $priceLabel',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFFE3B55C),
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          storeNote,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF908676),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'What you get',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  _buildFeatureRow(
                    Icons.collections_bookmark,
                    'Unlimited collections',
                  ),
                  const SizedBox(height: 8),
                  _buildFeatureRow(
                    Icons.workspace_premium,
                    'Support future premium features',
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _manager.purchasePro,
                    child: Text(
                      testMode
                          ? (isPro ? 'Switch to Base (test)' : 'Switch to Pro (test)')
                          : (isPro ? 'Pro enabled' : 'Upgrade to Pro'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _manager.restorePurchases,
                    child: const Text('Restore purchases'),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    value: testMode,
                    onChanged: _manager.setTestMode,
                    title: const Text('Test mode'),
                    subtitle: const Text(
                      'When enabled, Upgrade toggles Pro locally.',
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CollectionDetailPageState extends State<CollectionDetailPage> {
  final List<CollectionCardEntry> _cards = [];
  bool _loading = true;
  _CollectionViewMode _viewMode = _CollectionViewMode.list;
  bool _showOwned = true;
  bool _showMissing = true;
  String _searchQuery = '';
  final Set<String> _selectedRarities = {};
  final Set<String> _selectedSetCodes = {};
  final Set<String> _selectedColors = {};
  final Set<String> _selectedTypes = {};
  int? _manaValueMin;
  int? _manaValueMax;
  bool _autoAddShown = false;
  Map<String, int> _setTotalsByCode = {};

  @override
  void initState() {
    super.initState();
    _loadCards();
    _loadViewMode();
    if (widget.autoOpenAddCard && !widget.isSetCollection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoAddShown) {
          return;
        }
        _autoAddShown = true;
        _addCard(context);
      });
    }
  }

  Future<void> _loadViewMode() async {
    final mode = await AppSettings.loadCollectionViewMode();
    if (!mounted) {
      return;
    }
    setState(() {
      _viewMode = mode;
    });
  }

  Future<void> _loadCards() async {
    final cards = widget.isAllCards
        ? await ScryfallDatabase.instance.fetchOwnedCards()
        : widget.isSetCollection
            ? await ScryfallDatabase.instance.fetchSetCollectionCards(
                widget.collectionId,
                widget.setCode ?? '',
              )
            : await ScryfallDatabase.instance
                .fetchCollectionCards(widget.collectionId);
    final setCodes = cards
        .map((entry) => entry.setCode.trim().toLowerCase())
        .where((code) => code.isNotEmpty)
        .toSet()
        .toList();
    final totals = await ScryfallDatabase.instance
        .fetchSetTotalsForCodes(setCodes);
    if (!mounted) {
      return;
    }
    setState(() {
      _cards
        ..clear()
        ..addAll(cards);
      _setTotalsByCode = totals;
      _loading = false;
    });
  }

  List<CollectionCardEntry> _baseVisibleCards() {
    if (!widget.isSetCollection) {
      return _cards;
    }
    if (_searchQuery.isEmpty && _showOwned && _showMissing) {
      return _cards;
    }
    final queryLower = _searchQuery.toLowerCase();
    return _cards.where((entry) {
      if (queryLower.isNotEmpty) {
        final haystack =
            '${entry.name} ${entry.collectorNumber}'.toLowerCase();
        if (!haystack.contains(queryLower)) {
          return false;
        }
      }
      final owned = entry.quantity > 0;
      if (owned && _showOwned) {
        return true;
      }
      if (!owned && _showMissing) {
        return true;
      }
      return false;
    }).toList();
  }

  List<CollectionCardEntry> _filteredCards() {
    final base = _baseVisibleCards();
    if (_selectedRarities.isEmpty &&
        _selectedSetCodes.isEmpty &&
        _selectedColors.isEmpty &&
        _selectedTypes.isEmpty &&
        _manaValueMin == null &&
        _manaValueMax == null) {
      return base;
    }
    return base.where(_matchesAdvancedFilters).toList();
  }

  bool _matchesAdvancedFilters(CollectionCardEntry entry) {
    if (_selectedRarities.isNotEmpty) {
      final rarity = entry.rarity.trim().toLowerCase();
      if (!_selectedRarities.contains(rarity)) {
        return false;
      }
    }
    if (_selectedSetCodes.isNotEmpty) {
      final code = entry.setCode.trim().toLowerCase();
      if (!_selectedSetCodes.contains(code)) {
        return false;
      }
    }
    if (_selectedColors.isNotEmpty) {
      final colors = _cardColors(entry);
      if (colors.intersection(_selectedColors).isEmpty) {
        return false;
      }
    }
    if (_selectedTypes.isNotEmpty) {
      final types = _cardTypes(entry);
      if (types.intersection(_selectedTypes).isEmpty) {
        return false;
      }
    }
    if (_manaValueMin != null || _manaValueMax != null) {
      final manaValue = _cardManaValue(entry);
      if (_manaValueMin != null && manaValue < _manaValueMin!) {
        return false;
      }
      if (_manaValueMax != null && manaValue > _manaValueMax!) {
        return false;
      }
    }
    return true;
  }

  Set<String> _cardColors(CollectionCardEntry entry) {
    final data = _decodeCardJson(entry);
    if (data == null) {
      return {'C'};
    }
    final colors = (data['colors'] as List?)?.whereType<String>().toList() ??
        (data['color_identity'] as List?)
            ?.whereType<String>()
            .toList() ??
        <String>[];
    if (colors.isEmpty) {
      return {'C'};
    }
    return colors.map((code) => code.toUpperCase()).toSet();
  }

  Set<String> _cardTypes(CollectionCardEntry entry) {
    final data = _decodeCardJson(entry);
    final typeLine = data?['type_line']?.toString() ?? '';
    if (typeLine.isEmpty) {
      return {};
    }
    const knownTypes = [
      'Artifact',
      'Creature',
      'Enchantment',
      'Instant',
      'Land',
      'Planeswalker',
      'Sorcery',
      'Battle',
      'Tribal',
    ];
    final matches = <String>{};
    for (final type in knownTypes) {
      if (typeLine.toLowerCase().contains(type.toLowerCase())) {
        matches.add(type);
      }
    }
    return matches;
  }

  double _cardManaValue(CollectionCardEntry entry) {
    final data = _decodeCardJson(entry);
    final value = data?['cmc'];
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  bool _hasActiveAdvancedFilters() {
    return _selectedRarities.isNotEmpty ||
        _selectedSetCodes.isNotEmpty ||
        _selectedColors.isNotEmpty ||
        _selectedTypes.isNotEmpty ||
        _manaValueMin != null ||
        _manaValueMax != null;
  }

  String _setLabelForEntry(CollectionCardEntry entry) {
    if (entry.setName.trim().isNotEmpty) {
      return entry.setName.trim();
    }
    return entry.setCode.toUpperCase();
  }

  int? _setTotalForEntry(CollectionCardEntry entry) {
    final data = _decodeCardJson(entry);
    int? parseTotal(dynamic raw) {
      if (raw is num) {
        final value = raw.toInt();
        return value > 0 ? value : null;
      }
      if (raw is String) {
        final parsed = int.tryParse(raw.trim());
        if (parsed != null && parsed > 0) {
          return parsed;
        }
      }
      return null;
    }

    if (data != null) {
      final direct = [
        data['printed_total'],
        data['set_total'],
        data['printedTotal'],
        data['setTotal'],
        data['total'],
      ];
      for (final raw in direct) {
        final parsed = parseTotal(raw);
        if (parsed != null) {
          return parsed;
        }
      }

      final setData = data['set'];
      if (setData is Map<String, dynamic>) {
        final nested = [
          setData['printed_total'],
          setData['set_total'],
          setData['printedTotal'],
          setData['setTotal'],
          setData['total'],
        ];
        for (final raw in nested) {
          final parsed = parseTotal(raw);
          if (parsed != null) {
            return parsed;
          }
        }
      }
    }
    final code = entry.setCode.trim().toLowerCase();
    final fromMap = _setTotalsByCode[code];
    if (fromMap != null && fromMap > 0) {
      return fromMap;
    }
    if (widget.isSetCollection && _cards.isNotEmpty) {
      return _cards.length;
    }
    return null;
  }

  String _collectorProgressLabel(CollectionCardEntry entry) {
    final number = entry.collectorNumber.trim();
    if (number.isEmpty) {
      return '';
    }
    if (number.contains('/')) {
      return number;
    }
    final total = _setTotalForEntry(entry);
    if (total == null || total <= 0) {
      return number;
    }
    return '$number/$total';
  }

  String _subtitleLabel(CollectionCardEntry entry) {
    final setLabel = _setLabelForEntry(entry);
    final progress = _collectorProgressLabel(entry);
    if (setLabel.isEmpty) {
      return progress;
    }
    if (progress.isEmpty) {
      return setLabel;
    }
    return '$setLabel • $progress';
  }

  Future<void> _showAdvancedFilters() async {
    final base = _baseVisibleCards();
    final availableRarities = <String>{};
    final availableSetCodes = <String, String>{};
    final availableColors = <String>{};
    final availableTypes = <String>{};
    for (final entry in base) {
      if (entry.rarity.trim().isNotEmpty) {
        availableRarities.add(entry.rarity.trim().toLowerCase());
      }
      if (entry.setCode.trim().isNotEmpty) {
        availableSetCodes[entry.setCode.trim().toLowerCase()] =
            _setLabelForEntry(entry);
      }
      availableColors.addAll(_cardColors(entry));
      availableTypes.addAll(_cardTypes(entry));
    }

    final tempRarities = _selectedRarities.toSet();
    final tempSetCodes = _selectedSetCodes.toSet();
    final tempColors = _selectedColors.toSet();
    final tempTypes = _selectedTypes.toSet();
    final minController =
        TextEditingController(text: _manaValueMin?.toString() ?? '');
    final maxController =
        TextEditingController(text: _manaValueMax?.toString() ?? '');
    var setQuery = '';

    var applied = false;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget buildChipRow<T>(
              Iterable<T> items,
              bool Function(T) isSelected,
              void Function(T) toggle,
              String Function(T) label,
            ) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items
                    .map(
                      (item) => FilterChip(
                        label: Text(label(item)),
                        selected: isSelected(item),
                        onSelected: (_) => setSheetState(() => toggle(item)),
                      ),
                    )
                    .toList(),
              );
            }

            final rarityOrder = ['common', 'uncommon', 'rare', 'mythic'];
            final sortedRarities = availableRarities.toList()
              ..sort((a, b) {
                final ai = rarityOrder.indexOf(a);
                final bi = rarityOrder.indexOf(b);
                if (ai == -1 && bi == -1) {
                  return a.compareTo(b);
                }
                if (ai == -1) return 1;
                if (bi == -1) return -1;
                return ai.compareTo(bi);
              });
            final sortedSets = availableSetCodes.entries.toList()
              ..sort((a, b) => a.value.compareTo(b.value));
            final filteredSets = sortedSets.where((entry) {
              if (setQuery.isEmpty) {
                return true;
              }
              return entry.value.toLowerCase().contains(setQuery) ||
                  entry.key.toLowerCase().contains(setQuery);
            }).toList();
            const colorOrder = ['W', 'U', 'B', 'R', 'G', 'C'];
            final sortedColors = availableColors.toList()
              ..sort((a, b) =>
                  colorOrder.indexOf(a).compareTo(colorOrder.indexOf(b)));
            final sortedTypes = availableTypes.toList()..sort();

            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Advanced filters',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    if (sortedRarities.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Rarity',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      buildChipRow<String>(
                        sortedRarities,
                        (value) => tempRarities.contains(value),
                        (value) {
                          if (!tempRarities.add(value)) {
                            tempRarities.remove(value);
                          }
                        },
                        (value) => _formatRarity(value),
                      ),
                    ],
                    if (sortedSets.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Set',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search set',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) {
                          setSheetState(() {
                            setQuery = value.trim().toLowerCase();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: sortedSets.length > 16 ? 200 : null,
                        child: SingleChildScrollView(
                          child: buildChipRow<MapEntry<String, String>>(
                            filteredSets,
                            (value) => tempSetCodes.contains(value.key),
                            (value) {
                              if (!tempSetCodes.add(value.key)) {
                                tempSetCodes.remove(value.key);
                              }
                            },
                            (value) => value.value,
                          ),
                        ),
                      ),
                    ],
                    if (sortedColors.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Color',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      buildChipRow<String>(
                        sortedColors,
                        (value) => tempColors.contains(value),
                        (value) {
                          if (!tempColors.add(value)) {
                            tempColors.remove(value);
                          }
                        },
                        (value) => _colorLabel(value),
                      ),
                    ],
                    if (sortedTypes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Type',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      buildChipRow<String>(
                        sortedTypes,
                        (value) => tempTypes.contains(value),
                        (value) {
                          if (!tempTypes.add(value)) {
                            tempTypes.remove(value);
                          }
                        },
                        (value) => value,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Mana value',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Min',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: maxController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Max',
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (sortedRarities.isEmpty &&
                        sortedSets.isEmpty &&
                        sortedColors.isEmpty &&
                        sortedTypes.isEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('No filters available for this list.'),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              tempRarities.clear();
                              tempSetCodes.clear();
                              tempColors.clear();
                              tempTypes.clear();
                              minController.clear();
                              maxController.clear();
                            });
                          },
                          child: const Text('Clear'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () {
                            applied = true;
                            Navigator.of(context).pop();
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || !applied) {
      return;
    }
    int? minValue = int.tryParse(minController.text.trim());
    int? maxValue = int.tryParse(maxController.text.trim());
    if (minValue != null && maxValue != null && minValue > maxValue) {
      final swap = minValue;
      minValue = maxValue;
      maxValue = swap;
    }
    setState(() {
      _selectedRarities
        ..clear()
        ..addAll(tempRarities);
      _selectedSetCodes
        ..clear()
        ..addAll(tempSetCodes);
      _selectedColors
        ..clear()
        ..addAll(tempColors);
      _selectedTypes
        ..clear()
        ..addAll(tempTypes);
      _manaValueMin = minValue;
      _manaValueMax = maxValue;
    });
  }

  String _colorLabel(String code) {
    switch (code.toUpperCase()) {
      case 'W':
        return 'White';
      case 'U':
        return 'Blue';
      case 'B':
        return 'Black';
      case 'R':
        return 'Red';
      case 'G':
        return 'Green';
      case 'C':
        return 'Colorless';
      default:
        return code.toUpperCase();
    }
  }

  Widget _buildSetHeader() {
    final ownedCount = _cards.where((entry) => entry.quantity > 0).length;
    final missingCount = _cards.length - ownedCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search cards',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.trim();
              });
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              FilterChip(
                label: Text('Owned ($ownedCount)'),
                selected: _showOwned,
                onSelected: (value) {
                  setState(() {
                    _showOwned = value;
                  });
                },
              ),
              FilterChip(
                label: Text('Missing ($missingCount)'),
                selected: _showMissing,
                onSelected: (value) {
                  setState(() {
                    _showMissing = value;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _quickAddCard(CollectionCardEntry entry) async {
    if (widget.isSetCollection) {
      final nextQuantity = entry.quantity + 1;
      await ScryfallDatabase.instance.upsertCollectionCard(
        widget.collectionId,
        entry.cardId,
        quantity: nextQuantity,
        foil: entry.foil,
        altArt: entry.altArt,
      );
    } else if (widget.isAllCards) {
      await ScryfallDatabase.instance
          .addCardToCollection(widget.collectionId, entry.cardId);
    } else {
      return;
    }
    await _loadCards();
  }

  Future<void> _addCard(BuildContext context) async {
    if (widget.isSetCollection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Use the list to set owned quantities.'),
        ),
      );
      return;
    }
    final selection = await showModalBottomSheet<_CardSearchSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CardSearchSheet(),
    );

    if (selection == null) {
      return;
    }

    if (selection.isBulk) {
      await ScryfallDatabase.instance.addCardsToCollection(
        widget.collectionId,
        selection.cardIds,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${selection.count} cards.')),
        );
      }
    } else {
      await ScryfallDatabase.instance.addCardToCollection(
        widget.collectionId,
        selection.cardIds.first,
      );
    }
    await _loadCards();
  }

  Future<void> _showCardDetails(CollectionCardEntry entry) async {
    final details = _parseCardDetails(entry);
    final cardData = _decodeCardJson(entry);
    final typeLine = _safeCardField(cardData, 'type_line');
    final manaCost = _safeCardField(cardData, 'mana_cost');
    final oracleText = _safeCardField(cardData, 'oracle_text');
    final power = _safeCardField(cardData, 'power');
    final toughness = _safeCardField(cardData, 'toughness');
    final loyalty = _safeCardField(cardData, 'loyalty');
    final stats = _joinStats(power, toughness);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ListView(
                controller: scrollController,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildSetIcon(entry.setCode, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        _subtitleLabel(entry),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFBFAE95),
                            ),
                      ),
                      const Spacer(),
                      if (manaCost.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A221B),
                            borderRadius: BorderRadius.circular(999),
                            border:
                                Border.all(color: const Color(0xFF3A2F24)),
                          ),
                          child: Text(
                            manaCost,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                  if (typeLine.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      typeLine,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFE3D4B8),
                          ),
                    ),
                  ],
                  if (oracleText.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF201A14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF3A2F24)),
                      ),
                      child: Text(
                        oracleText,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                  if (stats.isNotEmpty || loyalty.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (stats.isNotEmpty) _buildBadge(stats),
                        if (loyalty.isNotEmpty) _buildBadge('Loyalty $loyalty'),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (entry.imageUri != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        entry.imageUri!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  if (entry.imageUri != null &&
                      _subtitleLabel(entry).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _subtitleLabel(entry),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFBFAE95),
                          ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Dettagli',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  _buildDetailGrid(details),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<_CardDetail> _parseCardDetails(CollectionCardEntry entry) {
    final setLabel =
        entry.setName.isNotEmpty ? entry.setName : entry.setCode.toUpperCase();
    final details = <_CardDetail>[
      _CardDetail('Set', setLabel),
      _CardDetail('Collector', entry.collectorNumber),
    ];
    final data = _decodeCardJson(entry);
    if (data == null) {
      return details.where((item) => item.value.isNotEmpty).toList();
    }
    void add(String label, dynamic value) {
      if (value == null) {
        return;
      }
      final text = value.toString().trim();
      if (text.isEmpty) {
        return;
      }
      details.add(_CardDetail(label, text));
    }

    add('Rarity', data['rarity']);
    add('Set name', data['set_name']);
    add('Language', data['lang']);
    add('Release', data['released_at']);
    add('Artist', data['artist']);
    return details.where((item) => item.value.isNotEmpty).toList();
  }

  String _joinStats(dynamic power, dynamic toughness) {
    final p = power?.toString().trim() ?? '';
    final t = toughness?.toString().trim() ?? '';
    if (p.isEmpty && t.isEmpty) {
      return '';
    }
    if (p.isEmpty) {
      return t;
    }
    if (t.isEmpty) {
      return p;
    }
    return '$p/$t';
  }

  Map<String, dynamic>? _decodeCardJson(CollectionCardEntry entry) {
    final raw = entry.cardJson;
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return null;
  }

  String _safeCardField(Map<String, dynamic>? data, String key) {
    if (data == null) {
      return '';
    }
    final value = data[key];
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }

  Widget _buildDetailGrid(List<_CardDetail> details) {
    if (details.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: details
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _DetailRow(
                    label: item.label,
                    value: item.value,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Future<void> _showCardActions(CollectionCardEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final quantityController =
            TextEditingController(text: entry.quantity.toString());
        var foil = entry.foil;
        var altArt = entry.altArt;
        final isSetCollection = widget.isSetCollection;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    entry.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _subtitleLabel(entry),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: const Color(0xFFBFAE95)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: foil,
                    onChanged: (value) {
                      setSheetState(() {
                        foil = value ?? false;
                      });
                    },
                    title: const Text('Foil'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: altArt,
                    onChanged: (value) {
                      setSheetState(() {
                        altArt = value ?? false;
                      });
                    },
                    title: const Text('Alt art'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () async {
                          if (isSetCollection) {
                            await ScryfallDatabase.instance.upsertCollectionCard(
                              widget.collectionId,
                              entry.cardId,
                              quantity: 0,
                              foil: foil,
                              altArt: altArt,
                            );
                          } else {
                            await ScryfallDatabase.instance.deleteCollectionCard(
                              widget.collectionId,
                              entry.cardId,
                            );
                          }
                          if (!mounted) {
                            return;
                          }
                          Navigator.of(context).pop();
                          await _loadCards();
                        },
                        child: Text(isSetCollection ? 'Mark missing' : 'Delete'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () async {
                          final parsed =
                              int.tryParse(quantityController.text.trim()) ??
                                  entry.quantity;
                          final quantity = isSetCollection
                              ? (parsed < 0 ? 0 : parsed)
                              : (parsed < 1 ? 1 : parsed);
                          if (isSetCollection) {
                            await ScryfallDatabase.instance
                                .upsertCollectionCard(
                              widget.collectionId,
                              entry.cardId,
                              quantity: quantity,
                              foil: foil,
                              altArt: altArt,
                            );
                          } else if (widget.isAllCards) {
                            await ScryfallDatabase.instance
                                .upsertCollectionCard(
                              widget.collectionId,
                              entry.cardId,
                              quantity: quantity,
                              foil: foil,
                              altArt: altArt,
                            );
                          } else {
                            await ScryfallDatabase.instance.updateCollectionCard(
                              widget.collectionId,
                              entry.cardId,
                              quantity: quantity,
                              foil: foil,
                              altArt: altArt,
                            );
                          }
                          if (!mounted) {
                            return;
                          }
                          Navigator.of(context).pop();
                          await _loadCards();
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleCards = _filteredCards();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.name),
        bottom: widget.isSetCollection
            ? PreferredSize(
                preferredSize: const Size.fromHeight(108),
                child: _buildSetHeader(),
              )
            : null,
        actions: [
          IconButton(
            tooltip: _viewMode == _CollectionViewMode.list
                ? 'Galleria'
                : 'Lista',
            icon: Icon(
              _viewMode == _CollectionViewMode.list
                  ? Icons.grid_view
                  : Icons.list,
            ),
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == _CollectionViewMode.list
                    ? _CollectionViewMode.gallery
                    : _CollectionViewMode.list;
              });
              AppSettings.saveCollectionViewMode(_viewMode);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          const _AppBackground(),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (visibleCards.isEmpty)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.collections,
                        size: 36, color: Color(0xFFE9C46A)),
                    const SizedBox(height: 12),
                    Text(
                      widget.isSetCollection
                          ? 'No cards match these filters'
                          : widget.isAllCards
                              ? 'No owned cards yet'
                              : 'No cards yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isSetCollection
                          ? 'Try enabling owned or missing cards.'
                          : widget.isAllCards
                              ? 'Add cards here or inside any collection.'
                              : 'Add your first card to start this collection.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFBFAE95),
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (!widget.isSetCollection)
                      FilledButton.icon(
                        onPressed: () => _addCard(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add card'),
                      ),
                  ],
                ),
              ),
            )
          else
            _viewMode == _CollectionViewMode.list
                ? ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: visibleCards.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final entry = visibleCards[index];
                      final isMissing =
                          widget.isSetCollection && entry.quantity == 0;
                      final hasCornerQuantity = entry.quantity > 1;
                      return GestureDetector(
                        onTap: () => _showCardDetails(entry),
                        onLongPress: () => _showCardActions(entry),
                        child: Opacity(
                          opacity: isMissing ? 0.45 : 1,
                          child: Stack(
                            children: [
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(minHeight: 108),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration:
                                      _cardTintDecoration(context, entry),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      _buildSetIcon(entry.setCode, size: 30),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              entry.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                            ),
                                            const SizedBox(height: 4),
                                            Builder(
                                              builder: (context) {
                                                final setLabel =
                                                    _setLabelForEntry(entry);
                                                final progress =
                                                    _collectorProgressLabel(
                                                        entry);
                                                final hasRarity = entry.rarity
                                                    .trim()
                                                    .isNotEmpty;
                                                final leftLabel = setLabel
                                                        .isNotEmpty
                                                    ? setLabel
                                                    : progress;
                                                return Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        leftLabel,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: const Color(
                                                                  0xFFBFAE95),
                                                            ),
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if (progress.isNotEmpty &&
                                                        setLabel
                                                            .isNotEmpty) ...[
                                                      Text(
                                                        progress,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: const Color(
                                                                  0xFFBFAE95),
                                                            ),
                                                      ),
                                                    ],
                                                    if (hasRarity) ...[
                                                      const SizedBox(width: 6),
                                                      _raritySquare(
                                                          entry.rarity),
                                                    ],
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (widget.isSetCollection ||
                                          widget.isAllCards) ...[
                                        const SizedBox(width: 8),
                                        IconButton(
                                          tooltip: 'Add one',
                                          icon: const Icon(
                                              Icons.add_circle_outline),
                                          color: const Color(0xFFE9C46A),
                                          onPressed: () =>
                                              _quickAddCard(entry),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              if (isMissing)
                                Positioned(
                                  top: 6,
                                  right: hasCornerQuantity ? 42 : 8,
                                  child: _buildBadge('Missing'),
                                ),
                              if (entry.foil || entry.altArt)
                                Positioned(
                                  top: isMissing ? 42 : 6,
                                  right: hasCornerQuantity ? 42 : 8,
                                  child: Row(
                                    children: [
                                      if (entry.foil)
                                        _statusMiniBadge(icon: Icons.star),
                                      if (entry.foil && entry.altArt)
                                        const SizedBox(width: 6),
                                      if (entry.altArt)
                                        _statusMiniBadge(icon: Icons.brush),
                                    ],
                                  ),
                                ),
                              if (hasCornerQuantity)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: _cornerQuantityBadge(entry.quantity),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: visibleCards.length,
                    itemBuilder: (context, index) {
                      final entry = visibleCards[index];
                      final isMissing =
                          widget.isSetCollection && entry.quantity == 0;
                      final hasCornerQuantity = entry.quantity > 1;
                      return GestureDetector(
                        onTap: () => _showCardDetails(entry),
                        onLongPress: () => _showCardActions(entry),
                        child: Opacity(
                          opacity: isMissing ? 0.45 : 1,
                          child: Stack(
                            children: [
                              Container(
                                decoration: _cardTintDecoration(context, entry),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                          top: Radius.circular(16),
                                        ),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            entry.imageUri == null
                                                ? Container(
                                                    color:
                                                        const Color(0xFF201A14),
                                                    child: const Icon(
                                                      Icons.image_not_supported,
                                                      color: Color(0xFFBFAE95),
                                                    ),
                                                  )
                                                : Image.network(
                                                    entry.imageUri!,
                                                    fit: BoxFit.cover,
                                                  ),
                                            if (widget.isSetCollection ||
                                                widget.isAllCards)
                                              Positioned(
                                                top: 8,
                                                left: 8,
                                                child: Material(
                                                  color: const Color(0xFF1C1713)
                                                      .withOpacity(0.9),
                                                  shape: const CircleBorder(),
                                                  child: InkWell(
                                                    customBorder:
                                                        const CircleBorder(),
                                                    onTap: () =>
                                                        _quickAddCard(entry),
                                                    child: const Padding(
                                                      padding:
                                                          EdgeInsets.all(9),
                                                      child: Icon(
                                                        Icons.add,
                                                        size: 22,
                                                        color:
                                                            Color(0xFFE9C46A),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if (isMissing)
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: _buildBadge('Missing'),
                                              ),
                                            if (entry.foil || entry.altArt)
                                              Positioned(
                                                bottom: 8,
                                                right: 8,
                                                child: Row(
                                                  children: [
                                                    if (entry.foil)
                                                      _statusMiniBadge(
                                                        icon: Icons.star,
                                                      ),
                                                    if (entry.foil &&
                                                        entry.altArt)
                                                      const SizedBox(width: 6),
                                                    if (entry.altArt)
                                                      _statusMiniBadge(
                                                        icon: Icons.brush,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            height: 44,
                                            child: Text(
                                              entry.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              _buildSetIcon(entry.setCode,
                                                  size: 22),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _setLabelForEntry(entry),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: const Color(
                                                                0xFFBFAE95),
                                                          ),
                                                    ),
                                                    Builder(
                                                      builder: (context) {
                                                        final progress =
                                                            _collectorProgressLabel(
                                                                entry);
                                                        final hasRarity = entry
                                                            .rarity
                                                            .trim()
                                                            .isNotEmpty;
                                                        if (!hasRarity &&
                                                            progress
                                                                .isEmpty) {
                                                          return const SizedBox
                                                              .shrink();
                                                        }
                                                        return Row(
                                                          children: [
                                                            const Spacer(),
                                                            if (progress
                                                                .isNotEmpty)
                                                              Text(
                                                                progress,
                                                                style: Theme.of(
                                                                        context)
                                                                    .textTheme
                                                                    .bodySmall
                                                                    ?.copyWith(
                                                                      color: const Color(
                                                                          0xFFBFAE95),
                                                                    ),
                                                              ),
                                                            if (hasRarity) ...[
                                                              const SizedBox(
                                                                  width: 6),
                                                              _raritySquare(
                                                                  entry.rarity),
                                                            ],
                                                          ],
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (entry.quantity > 1)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: _cornerQuantityBadge(entry.quantity),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          if (!_loading)
            Positioned(
              left: 20,
              bottom: 20 + MediaQuery.of(context).padding.bottom,
              child: FloatingActionButton(
                heroTag: 'filters_fab',
                onPressed: _showAdvancedFilters,
                tooltip: 'Filters',
                backgroundColor: _hasActiveAdvancedFilters()
                    ? const Color(0xFFE9C46A)
                    : null,
                foregroundColor: _hasActiveAdvancedFilters()
                    ? const Color(0xFF1C1510)
                    : null,
                child: Icon(
                  _hasActiveAdvancedFilters()
                      ? Icons.filter_list_alt
                      : Icons.filter_list,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: widget.isSetCollection
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addCard(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Card'),
            ),
    );
  }
}

class _AppBackground extends StatelessWidget {
  const _AppBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0B0806),
            Color(0xFF1A120C),
            Color(0xFF2E2217),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.14,
              child: SvgPicture.asset(
                'assets/textures/paper-fibers.svg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: -20,
            child: Transform.rotate(
              angle: 0.2,
              child: Container(
                width: 120,
                height: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: -30,
            child: Transform.rotate(
              angle: -0.22,
              child: Container(
                width: 140,
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            right: 40,
            child: Transform.rotate(
              angle: 0.15,
              child: Container(
                width: 130,
                height: 190,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 200,
            left: 20,
            child: Transform.rotate(
              angle: -0.05,
              child: Container(
                width: 110,
                height: 160,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.45),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 120,
            right: 70,
            child: Transform.rotate(
              angle: 0.32,
              child: Container(
                width: 90,
                height: 130,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 160,
            right: 10,
            child: Transform.rotate(
              angle: -0.18,
              child: Container(
                width: 120,
                height: 170,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 360,
            left: 90,
            child: Transform.rotate(
              angle: 0.12,
              child: Container(
                width: 80,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 80,
            left: -10,
            child: Transform.rotate(
              angle: -0.38,
              child: Container(
                width: 100,
                height: 150,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.32),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.24),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 260,
            left: 140,
            child: Transform.rotate(
              angle: 0.28,
              child: Container(
                width: 90,
                height: 130,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.28),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 90,
            right: 160,
            child: Transform.rotate(
              angle: -0.12,
              child: Container(
                width: 110,
                height: 160,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.26),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 260,
            right: 120,
            child: Transform.rotate(
              angle: 0.1,
              child: Container(
                width: 95,
                height: 140,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 220,
            left: 60,
            child: Transform.rotate(
              angle: -0.08,
              child: Container(
                width: 100,
                height: 150,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.28),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 140,
            right: 10,
            child: Transform.rotate(
              angle: -0.2,
              child: Container(
                width: 80,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410).withOpacity(0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3A2F24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -120,
            left: -80,
            child: Transform.rotate(
              angle: -0.35,
              child: Container(
                width: 420,
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0x00D97745),
                      Color(0x33D97745),
                      Color(0x00D97745),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(120),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -120,
            child: Transform.rotate(
              angle: 0.35,
              child: Container(
                width: 420,
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0x00E2C26A),
                      Color(0x33E2C26A),
                      Color(0x00E2C26A),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(120),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _CardSearchSelection {
  _CardSearchSelection.single(CardSearchResult card)
      : cards = const [],
        isBulk = false,
        count = 1,
        cardIds = [card.id];

  _CardSearchSelection.bulk(List<CardSearchResult> cards)
      : cards = cards,
        isBulk = true,
        count = cards.length,
        cardIds = cards.map((card) => card.id).toList(growable: false);

  final List<CardSearchResult> cards;
  final bool isBulk;
  final int count;
  final List<String> cardIds;
}

class _CardSearchSheet extends StatefulWidget {
  const _CardSearchSheet();

  @override
  State<_CardSearchSheet> createState() => _CardSearchSheetState();
}

class _CardSearchSheetState extends State<_CardSearchSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  bool _loading = false;
  List<CardSearchResult> _results = [];
  String _query = '';
  OverlayEntry? _previewEntry;
  late final AnimationController _previewController;
  late final Animation<double> _previewOpacity;
  late final Animation<double> _previewScale;
  Set<String> _searchLanguages = {};
  bool _loadingLanguages = true;
  bool _searching = false;
  String? _pendingQuery;
  final Set<String> _selectedRarities = {};
  final Set<String> _selectedSetCodes = {};
  final Set<String> _selectedColors = {};
  final Set<String> _selectedTypes = {};
  int? _manaValueMin;
  int? _manaValueMax;

  @override
  void initState() {
    super.initState();
    _previewController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _previewOpacity = CurvedAnimation(
      parent: _previewController,
      curve: Curves.easeOut,
    );
    _previewScale = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _previewController, curve: Curves.easeOutBack),
    );
    _focusNode.requestFocus();
    _controller.addListener(_onQueryChanged);
    _loadSearchLanguages();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _hidePreview(immediate: true);
    _previewController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final value = _controller.text.trim();
    if (value == _query) {
      return;
    }
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  Future<void> _runSearch() async {
    if (_query.isEmpty) {
      if (mounted) {
        setState(() {
          _results = [];
          _loading = false;
        });
      }
      return;
    }
    if (_searching) {
      _pendingQuery = _query;
      return;
    }
    _hidePreview(immediate: false);
    _searching = true;
    setState(() {
      _loading = true;
    });

    final currentQuery = _query;
    try {
      final results = await ScryfallDatabase.instance.searchCardsByName(
        currentQuery,
        languages: _searchLanguages.toList(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _results = results;
        _loading = false;
      });
    } finally {
      if (mounted && _loading) {
        setState(() {
          _loading = false;
        });
      }
      _searching = false;
    }
    if (!mounted) {
      return;
    }
    if (_pendingQuery != null && _pendingQuery != currentQuery) {
      _pendingQuery = null;
      await _runSearch();
    } else {
      _pendingQuery = null;
    }
  }

  Future<void> _loadSearchLanguages() async {
    final stored = await AppSettings.loadSearchLanguages();
    if (!mounted) {
      return;
    }
    setState(() {
      _searchLanguages = stored.isEmpty ? {'en'} : stored;
      _loadingLanguages = false;
    });
    if (_query.isNotEmpty) {
      await _runSearch();
    }
  }

  List<CardSearchResult> _filteredResults() {
    if (_selectedRarities.isEmpty &&
        _selectedSetCodes.isEmpty &&
        _selectedColors.isEmpty &&
        _selectedTypes.isEmpty &&
        _manaValueMin == null &&
        _manaValueMax == null) {
      return _results;
    }
    return _results.where(_matchesAdvancedFilters).toList();
  }

  bool _matchesAdvancedFilters(CardSearchResult card) {
    if (_selectedRarities.isNotEmpty) {
      final rarity = _resultRarity(card);
      if (rarity.isEmpty || !_selectedRarities.contains(rarity)) {
        return false;
      }
    }
    if (_selectedSetCodes.isNotEmpty) {
      final code = card.setCode.trim().toLowerCase();
      if (!_selectedSetCodes.contains(code)) {
        return false;
      }
    }
    if (_selectedColors.isNotEmpty) {
      final colors = _resultColors(card);
      if (colors.intersection(_selectedColors).isEmpty) {
        return false;
      }
    }
    if (_selectedTypes.isNotEmpty) {
      final types = _resultTypes(card);
      if (types.intersection(_selectedTypes).isEmpty) {
        return false;
      }
    }
    if (_manaValueMin != null || _manaValueMax != null) {
      final manaValue = _resultManaValue(card);
      if (_manaValueMin != null && manaValue < _manaValueMin!) {
        return false;
      }
      if (_manaValueMax != null && manaValue > _manaValueMax!) {
        return false;
      }
    }
    return true;
  }

  String _resultRarity(CardSearchResult card) {
    final data = _decodeCardJson(card.cardJson);
    final value = data?['rarity']?.toString().trim().toLowerCase() ?? '';
    return value;
  }

  Set<String> _resultColors(CardSearchResult card) {
    final data = _decodeCardJson(card.cardJson);
    final colors = (data?['colors'] as List?)?.whereType<String>().toList() ??
        (data?['color_identity'] as List?)
            ?.whereType<String>()
            .toList() ??
        <String>[];
    if (colors.isEmpty) {
      return {'C'};
    }
    return colors.map((code) => code.toUpperCase()).toSet();
  }

  Set<String> _resultTypes(CardSearchResult card) {
    final data = _decodeCardJson(card.cardJson);
    final typeLine = data?['type_line']?.toString() ?? '';
    if (typeLine.isEmpty) {
      return {};
    }
    const knownTypes = [
      'Artifact',
      'Creature',
      'Enchantment',
      'Instant',
      'Land',
      'Planeswalker',
      'Sorcery',
      'Battle',
      'Tribal',
    ];
    final matches = <String>{};
    for (final type in knownTypes) {
      if (typeLine.toLowerCase().contains(type.toLowerCase())) {
        matches.add(type);
      }
    }
    return matches;
  }

  double _resultManaValue(CardSearchResult card) {
    final data = _decodeCardJson(card.cardJson);
    final value = data?['cmc'];
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  Map<String, dynamic>? _decodeCardJson(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return null;
  }

  bool _hasActiveAdvancedFilters() {
    return _selectedRarities.isNotEmpty ||
        _selectedSetCodes.isNotEmpty ||
        _selectedColors.isNotEmpty ||
        _selectedTypes.isNotEmpty ||
        _manaValueMin != null ||
        _manaValueMax != null;
  }

  bool _hasNarrowingFilters() {
    return _selectedRarities.isNotEmpty ||
        _selectedSetCodes.isNotEmpty ||
        _selectedTypes.isNotEmpty;
  }

  String _colorLabel(String code) {
    switch (code.toUpperCase()) {
      case 'W':
        return 'White';
      case 'U':
        return 'Blue';
      case 'B':
        return 'Black';
      case 'R':
        return 'Red';
      case 'G':
        return 'Green';
      case 'C':
        return 'Colorless';
      default:
        return code.toUpperCase();
    }
  }

  Future<void> _showAdvancedFilters() async {
    final availableRarities = <String>{};
    final availableSetCodes = <String, String>{};
    final availableColors = <String>{};
    final availableTypes = <String>{};
    if (_results.isEmpty) {
      const fallbackRarities = ['common', 'uncommon', 'rare', 'mythic'];
      const fallbackColors = ['W', 'U', 'B', 'R', 'G', 'C'];
      const fallbackTypes = [
        'Artifact',
        'Creature',
        'Enchantment',
        'Instant',
        'Land',
        'Planeswalker',
        'Sorcery',
        'Battle',
        'Tribal',
      ];
      availableRarities.addAll(fallbackRarities);
      availableColors.addAll(fallbackColors);
      availableTypes.addAll(fallbackTypes);
      final sets = await ScryfallDatabase.instance.fetchAvailableSets();
      for (final set in sets) {
        availableSetCodes[set.code.trim().toLowerCase()] =
            set.name.trim().isNotEmpty
                ? set.name.trim()
                : set.code.toUpperCase();
      }
    } else {
      for (final card in _results) {
        final rarity = _resultRarity(card);
        if (rarity.isNotEmpty) {
          availableRarities.add(rarity);
        }
        if (card.setCode.trim().isNotEmpty) {
          availableSetCodes[card.setCode.trim().toLowerCase()] =
              card.setName.trim().isNotEmpty
                  ? card.setName.trim()
                  : card.setCode.toUpperCase();
        }
        availableColors.addAll(_resultColors(card));
        availableTypes.addAll(_resultTypes(card));
      }
    }

    final tempRarities = _selectedRarities.toSet();
    final tempSetCodes = _selectedSetCodes.toSet();
    final tempColors = _selectedColors.toSet();
    final tempTypes = _selectedTypes.toSet();
    final minController =
        TextEditingController(text: _manaValueMin?.toString() ?? '');
    final maxController =
        TextEditingController(text: _manaValueMax?.toString() ?? '');
    var setQuery = '';

    var applied = false;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget buildChipRow<T>(
              Iterable<T> items,
              bool Function(T) isSelected,
              void Function(T) toggle,
              String Function(T) label,
            ) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items
                    .map(
                      (item) => FilterChip(
                        label: Text(label(item)),
                        selected: isSelected(item),
                        onSelected: (_) => setSheetState(() => toggle(item)),
                      ),
                    )
                    .toList(),
              );
            }

            final rarityOrder = ['common', 'uncommon', 'rare', 'mythic'];
            final sortedRarities = availableRarities.toList()
              ..sort((a, b) {
                final ai = rarityOrder.indexOf(a);
                final bi = rarityOrder.indexOf(b);
                if (ai == -1 && bi == -1) {
                  return a.compareTo(b);
                }
                if (ai == -1) return 1;
                if (bi == -1) return -1;
                return ai.compareTo(bi);
              });
            final sortedSets = availableSetCodes.entries.toList()
              ..sort((a, b) => a.value.compareTo(b.value));
            final filteredSets = sortedSets.where((entry) {
              if (setQuery.isEmpty) {
                return true;
              }
              return entry.value.toLowerCase().contains(setQuery) ||
                  entry.key.toLowerCase().contains(setQuery);
            }).toList();
            const colorOrder = ['W', 'U', 'B', 'R', 'G', 'C'];
            final sortedColors = availableColors.toList()
              ..sort((a, b) =>
                  colorOrder.indexOf(a).compareTo(colorOrder.indexOf(b)));
            final sortedTypes = availableTypes.toList()..sort();

            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Advanced filters',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    if (sortedRarities.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Rarity',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      buildChipRow<String>(
                        sortedRarities,
                        (value) => tempRarities.contains(value),
                        (value) {
                          if (!tempRarities.add(value)) {
                            tempRarities.remove(value);
                          }
                        },
                        (value) => _formatRarity(value),
                      ),
                    ],
                    if (sortedSets.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Set',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search set',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) {
                          setSheetState(() {
                            setQuery = value.trim().toLowerCase();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: sortedSets.length > 16 ? 200 : null,
                        child: SingleChildScrollView(
                          child: buildChipRow<MapEntry<String, String>>(
                            filteredSets,
                            (value) => tempSetCodes.contains(value.key),
                            (value) {
                              if (!tempSetCodes.add(value.key)) {
                                tempSetCodes.remove(value.key);
                              }
                            },
                            (value) => value.value,
                          ),
                        ),
                      ),
                    ],
                    if (sortedColors.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Color',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      buildChipRow<String>(
                        sortedColors,
                        (value) => tempColors.contains(value),
                        (value) {
                          if (!tempColors.add(value)) {
                            tempColors.remove(value);
                          }
                        },
                        (value) => _colorLabel(value),
                      ),
                    ],
                    if (sortedTypes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Type',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      buildChipRow<String>(
                        sortedTypes,
                        (value) => tempTypes.contains(value),
                        (value) {
                          if (!tempTypes.add(value)) {
                            tempTypes.remove(value);
                          }
                        },
                        (value) => value,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Mana value',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Min',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: maxController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Max',
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (sortedRarities.isEmpty &&
                        sortedSets.isEmpty &&
                        sortedColors.isEmpty &&
                        sortedTypes.isEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('No filters available.'),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              tempRarities.clear();
                              tempSetCodes.clear();
                              tempColors.clear();
                              tempTypes.clear();
                              minController.clear();
                              maxController.clear();
                            });
                          },
                          child: const Text('Clear'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () {
                            applied = true;
                            Navigator.of(context).pop();
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || !applied) {
      return;
    }
    int? minValue = int.tryParse(minController.text.trim());
    int? maxValue = int.tryParse(maxController.text.trim());
    if (minValue != null && maxValue != null && minValue > maxValue) {
      final swap = minValue;
      minValue = maxValue;
      maxValue = swap;
    }
    setState(() {
      _selectedRarities
        ..clear()
        ..addAll(tempRarities);
      _selectedSetCodes
        ..clear()
        ..addAll(tempSetCodes);
      _selectedColors
        ..clear()
        ..addAll(tempColors);
      _selectedTypes
        ..clear()
        ..addAll(tempTypes);
      _manaValueMin = minValue;
      _manaValueMax = maxValue;
    });
  }

  Future<void> _bulkAddByFilters() async {
    if (!_hasActiveAdvancedFilters()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select filters first.')),
      );
      return;
    }
    if (!_hasNarrowingFilters()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select Set, Rarity, or Type to narrow results.'),
        ),
      );
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      final candidates = await ScryfallDatabase.instance.fetchCardsForFilters(
        setCodes: _selectedSetCodes.toList(),
        rarities: _selectedRarities.toList(),
        types: _selectedTypes.toList(),
        languages: _searchLanguages.toList(),
      );
      final filtered = candidates.where(_matchesAdvancedFilters).toList();
      if (!mounted) {
        return;
      }
      if (filtered.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No cards match these filters.')),
        );
        return;
      }
      final confirmed = await _confirmBulkAdd(filtered.length);
      if (!confirmed || !mounted) {
        return;
      }
      Navigator.of(context).pop(_CardSearchSelection.bulk(filtered));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<bool> _confirmBulkAdd(int count) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add all results?'),
          content: Text('This will add $count cards to the collection.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Add all'),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.78;
    final visibleResults = _filteredResults();
    final filtersActive = _hasActiveAdvancedFilters();
    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF14110F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: sheetHeight,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B3229),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Search card',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: _showAdvancedFilters,
                        icon: Icon(
                          Icons.filter_list,
                          color: filtersActive
                              ? const Color(0xFFE9C46A)
                              : null,
                        ),
                        tooltip: 'Filters',
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: const InputDecoration(
                      hintText: 'Type a card name',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                if (_loadingLanguages)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_query.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      filtersActive
                          ? 'Results: ${visibleResults.length} / ${_results.length} · Languages: ${(_searchLanguages.toList()..sort()).join(', ')}'
                          : 'Results: ${_results.length} · Languages: ${(_searchLanguages.toList()..sort()).join(', ')}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFBFAE95),
                          ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (!_loading && filtersActive && _query.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton.icon(
                      onPressed: _bulkAddByFilters,
                      icon: const Icon(Icons.playlist_add_check),
                      label: const Text('Add filtered cards'),
                    ),
                  ),
                if (!_loading && visibleResults.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final confirmed =
                            await _confirmBulkAdd(visibleResults.length);
                        if (!confirmed) {
                          return;
                        }
                        if (!mounted) {
                          return;
                        }
                        Navigator.of(context)
                            .pop(_CardSearchSelection.bulk(visibleResults));
                      },
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('Add all results'),
                    ),
                  ),
                Expanded(
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        )
                      : visibleResults.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _query.isEmpty
                                        ? 'Start typing to search.'
                                        : 'No results found',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                    textAlign: TextAlign.center,
                                  ),
                                  if (_query.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try a different name or spelling.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: const Color(0xFFBFAE95),
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                              itemCount: visibleResults.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final card = visibleResults[index];
                                return InkWell(
                                  onTap: () => Navigator.of(context)
                                      .pop(_CardSearchSelection.single(card)),
                                  onLongPress: () => _showPreview(card),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1C1713),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFF322A22),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildSetIcon(card.setCode, size: 24),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                card.name,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                card.subtitleLabel,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: const Color(
                                                          0xFFBFAE95),
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.add,
                                            color: Color(0xFFE9C46A)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPreview(CardSearchResult card) {
    final imageUrl = card.imageUri;
    if (imageUrl == null || imageUrl.isEmpty) {
      return;
    }
    _hidePreview(immediate: true);

    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    _previewController.value = 0;
    _previewEntry = OverlayEntry(
      builder: (context) {
        final size = MediaQuery.of(context).size;
        final maxWidth = size.width * 0.7;
        final maxHeight = size.height * 0.7;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _hidePreview(immediate: false),
          child: Material(
            color: Colors.black.withOpacity(0.72),
            child: Center(
              child: FadeTransition(
                opacity: _previewOpacity,
                child: ScaleTransition(
                  scale: _previewScale,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxWidth.clamp(220, 420),
                      maxHeight: maxHeight.clamp(320, 640),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0C0A),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFF3A2F24),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) {
                              return child;
                            }
                            return const SizedBox(
                              height: 360,
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox(
                              height: 360,
                              child: Center(
                                child: Icon(Icons.broken_image, size: 48),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_previewEntry!);
    _previewController.forward();
  }

  Future<void> _hidePreview({required bool immediate}) async {
    if (_previewEntry == null) {
      return;
    }
    if (!immediate) {
      await _previewController.reverse();
    }
    _previewEntry?.remove();
    _previewEntry = null;
  }
}

class _SnakeProgressBar extends StatelessWidget {
  const _SnakeProgressBar({
    required this.animation,
    required this.value,
  });

  final Animation<double> animation;
  final double value;

  @override
  Widget build(BuildContext context) {
    final trackColor = const Color(0xFF2A221B);
    final fillColor = const Color(0xFFB85C38);
    final highlightColor = const Color(0xFFF3D28B);

    return SizedBox(
      height: 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final clampedValue = value.clamp(0.0, 1.0);
          final fillWidth = maxWidth * clampedValue;
          final snakeWidth = maxWidth * 0.22;

          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final availableWidth = fillWidth > 0 ? fillWidth : maxWidth;
              final travel = (availableWidth - snakeWidth).clamp(0.0, maxWidth);
              final left = travel * animation.value;

              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: trackColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  if (fillWidth > 0)
                    FractionallySizedBox(
                      widthFactor: clampedValue,
                      child: Container(
                        decoration: BoxDecoration(
                          color: fillColor.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  Positioned(
                    left: left,
                    child: Container(
                      width: snakeWidth,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            highlightColor.withOpacity(0.1),
                            highlightColor,
                            highlightColor.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class AppSettings {
  static const _prefsKeySearchLanguages = 'search_languages';
  static const _prefsKeySearchAllLanguages = 'search_all_languages';
  static const _prefsKeyAvailableLanguages = 'available_languages';
  static const _prefsKeyCollectionViewMode = 'collection_view_mode';
  static const _prefsKeyBulkType = 'scryfall_bulk_type';
  static const _prefsKeyProUnlocked = 'pro_unlocked';
  static const _prefsKeyPrimaryGameId = 'primary_game_id';
  static const _prefsKeyEnabledGames = 'enabled_games';

  static const Map<String, String> languageLabels = {
    'en': 'English',
    'it': 'Italiano',
    'fr': 'Francais',
    'de': 'Deutsch',
    'es': 'Espanol',
    'pt': 'Portugues',
    'ja': 'Japanese',
    'ko': 'Korean',
    'ru': 'Russian',
    'zhs': 'Chinese (Simplified)',
    'zht': 'Chinese (Traditional)',
    'ar': 'Arabic',
    'he': 'Hebrew',
    'la': 'Latin',
    'grc': 'Greek',
    'sa': 'Sanskrit',
    'ph': 'Phyrexian',
    'qya': 'Quenya',
  };

  static const List<String> defaultLanguages = [
    'en',
  ];

  static Future<Set<String>> loadSearchLanguages() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_prefsKeySearchLanguages) ?? [];
    if (values.isEmpty) {
      return {'en'};
    }
    return values.toSet();
  }

  static Future<bool> loadSearchAllLanguages() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKeySearchAllLanguages) ?? false;
  }

  static Future<void> saveSearchLanguages(Set<String> languages) async {
    final prefs = await SharedPreferences.getInstance();
    if (languages.isEmpty) {
      languages = {'en'};
    }
    await prefs.setStringList(
      _prefsKeySearchLanguages,
      languages.toList()..sort(),
    );
  }

  static Future<void> saveSearchAllLanguages(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeySearchAllLanguages, value);
  }

  static Future<List<String>> loadAvailableLanguages() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_prefsKeyAvailableLanguages) ?? [];
  }

  static Future<void> saveAvailableLanguages(List<String> languages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKeyAvailableLanguages,
      languages.toList()..sort(),
    );
  }

  static Future<String?> loadBulkType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKeyBulkType);
  }

  static Future<void> saveBulkType(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyBulkType, value);
  }

  static Future<String?> loadPrimaryGameId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKeyPrimaryGameId);
  }

  static Future<void> savePrimaryGameId(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyPrimaryGameId, value);
  }

  static Future<List<String>> loadEnabledGames() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_prefsKeyEnabledGames) ?? [];
  }

  static Future<void> saveEnabledGames(List<String> games) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKeyEnabledGames,
      games.toSet().toList(),
    );
  }

  static Future<bool> loadProUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKeyProUnlocked) ?? false;
  }

  static Future<void> saveProUnlocked(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyProUnlocked, value);
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeySearchLanguages);
    await prefs.remove(_prefsKeySearchAllLanguages);
    await prefs.remove(_prefsKeyAvailableLanguages);
    await prefs.remove(_prefsKeyCollectionViewMode);
    await prefs.remove(_prefsKeyBulkType);
    await prefs.remove(_prefsKeyProUnlocked);
    await prefs.remove(_prefsKeyPrimaryGameId);
    await prefs.remove(_prefsKeyEnabledGames);
  }

  static Future<_CollectionViewMode> loadCollectionViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefsKeyCollectionViewMode);
    if (value == 'gallery') {
      return _CollectionViewMode.gallery;
    }
    return _CollectionViewMode.list;
  }

  static Future<void> saveCollectionViewMode(
    _CollectionViewMode mode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKeyCollectionViewMode,
      mode == _CollectionViewMode.gallery ? 'gallery' : 'list',
    );
  }
}

class PurchaseManager extends ChangeNotifier {
  PurchaseManager._();

  static final PurchaseManager instance = PurchaseManager._();
  static const String _proProductId = 'tcg_tracker_pro';

  bool _isPro = false;
  bool _storeAvailable = false;
  bool _testMode = true;
  bool _initialized = false;
  ProductDetails? _proProduct;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool get isPro => _isPro;
  bool get storeAvailable => _storeAvailable;
  bool get testMode => _testMode;
  bool get isInitialized => _initialized;
  String get priceLabel => _proProduct?.price ?? 'TBD';

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    _isPro = await AppSettings.loadProUnlocked();
    if (_supportsStore()) {
      _storeAvailable = await InAppPurchase.instance.isAvailable();
      _subscription ??= InAppPurchase.instance.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () {
          _subscription = null;
        },
      );
      if (_storeAvailable) {
        final response = await InAppPurchase.instance.queryProductDetails(
          {_proProductId},
        );
        if (response.error == null && response.productDetails.isNotEmpty) {
          _proProduct = response.productDetails.first;
        }
      }
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> setTestMode(bool value) async {
    _testMode = value;
    notifyListeners();
  }

  Future<void> purchasePro() async {
    if (_testMode || !_supportsStore()) {
      await _setPro(!_isPro);
      return;
    }
    if (!_storeAvailable || _proProduct == null) {
      return;
    }
    final purchaseParam = PurchaseParam(productDetails: _proProduct!);
    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: purchaseParam,
    );
  }

  Future<void> restorePurchases() async {
    if (!_supportsStore()) {
      return;
    }
    await InAppPurchase.instance.restorePurchases();
  }

  bool _supportsStore() => Platform.isAndroid || Platform.isIOS;

  Future<void> _setPro(bool value) async {
    _isPro = value;
    await AppSettings.saveProUnlocked(value);
    notifyListeners();
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _setPro(true);
      }
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }
}

enum _CollectionViewMode { list, gallery }

class _CardDetail {
  const _CardDetail(this.label, this.value);

  final String label;
  final String value;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFFBFAE95),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

typedef ImportProgressCallback = void Function(int count, double progress);

class ScryfallBulkImporter {
  static const _batchSize = 200;

  Future<void> importAllCardsJson(
    String filePath, {
    required ImportProgressCallback onProgress,
    String? updatedAtRaw,
    String? bulkType,
    List<String>? allowedLanguages,
  }) async {
    final database = await ScryfallDatabase.instance.open();
    final receivePort = ReceivePort();
    final languageFilter = allowedLanguages ?? const <String>[];
    final isolate = await Isolate.spawn<_ScryfallParseConfig>(
      _scryfallParseIsolate,
      _ScryfallParseConfig(
        filePath: filePath,
        sendPort: receivePort.sendPort,
        batchSize: _batchSize,
        allowedLanguages: languageFilter,
      ),
    );

    var count = 0;
    Object? error;

    try {
      await database.transaction(() async {
        await ScryfallDatabase.instance.deleteAllCards(database);
        await for (final message in receivePort) {
          if (message is Map) {
            final type = message['type'] as String?;
            if (type == 'progress') {
              count = message['count'] as int? ?? count;
              final progress = message['progress'] as double? ?? 0;
              onProgress(count, progress);
            } else if (type == 'batch') {
              final items = message['items'] as List<dynamic>? ?? [];
              final mapped = items
                  .whereType<Map<String, dynamic>>()
                  .toList(growable: false);
              await ScryfallDatabase.instance.insertCardsBatch(
                database,
                mapped,
              );
              count += items.length;
              onProgress(count, message['progress'] as double? ?? 0);
            } else if (type == 'done') {
              count = message['count'] as int? ?? count;
              onProgress(count, 1);
              break;
            } else if (type == 'error') {
              error = message['message'];
              break;
            }
          }
        }
      });
    } finally {
      receivePort.close();
      isolate.kill(priority: Isolate.immediate);
    }

    if (error != null) {
      throw Exception(error);
    }

    if (updatedAtRaw != null && bulkType != null) {
      await ScryfallBulkChecker()
          .markAllCardsInstalled(updatedAtRaw, bulkType: bulkType);
    }
  }
}

class JsonArrayObjectParser {
  JsonArrayObjectParser(this._input);

  final Stream<String> _input;

  Stream<Map<String, dynamic>> objects() async* {
    var arrayStarted = false;
    var inString = false;
    var escape = false;
    var depth = 0;
    var inObject = false;
    StringBuffer? buffer;

    await for (final chunk in _input) {
      for (var i = 0; i < chunk.length; i++) {
        final char = chunk[i];

        if (!arrayStarted) {
          if (char == '[') {
            arrayStarted = true;
          }
          continue;
        }

        if (!inObject) {
          if (char == '{') {
            inObject = true;
            depth = 1;
            buffer = StringBuffer()..write(char);
          } else if (char == ']') {
            return;
          }
          continue;
        }

        buffer?.write(char);

        if (escape) {
          escape = false;
          continue;
        }

        if (char == '\\' && inString) {
          escape = true;
          continue;
        }

        if (char == '"') {
          inString = !inString;
          continue;
        }

        if (!inString) {
          if (char == '{') {
            depth += 1;
          } else if (char == '}') {
            depth -= 1;
            if (depth == 0) {
              final jsonText = buffer.toString();
              buffer = null;
              inObject = false;
              yield jsonDecode(jsonText) as Map<String, dynamic>;
            }
          }
        }
      }
    }
  }
}

class _ScryfallParseConfig {
  const _ScryfallParseConfig({
    required this.filePath,
    required this.sendPort,
    required this.batchSize,
    required this.allowedLanguages,
  });

  final String filePath;
  final SendPort sendPort;
  final int batchSize;
  final List<String> allowedLanguages;
}

Future<void> _scryfallParseIsolate(_ScryfallParseConfig config) async {
  final file = File(config.filePath);
  final totalBytes = await file.length();
  var bytesRead = 0;
  var count = 0;
  final batch = <Map<String, dynamic>>[];
  var lastProgress = DateTime.now();

  void sendProgress() {
    final progress = totalBytes > 0 ? bytesRead / totalBytes : 0;
    config.sendPort.send({
      'type': 'progress',
      'count': count,
      'progress': progress,
    });
  }

  try {
    final stream = file.openRead().map((chunk) {
      bytesRead += chunk.length;
      final now = DateTime.now();
      if (now.difference(lastProgress).inMilliseconds > 200) {
        lastProgress = now;
        sendProgress();
      }
      return chunk;
    }).transform(utf8.decoder);

    final parser = JsonArrayObjectParser(stream);
    await for (final card in parser.objects()) {
      if (config.allowedLanguages.isNotEmpty) {
        final lang = card['lang'];
        if (lang is! String || !config.allowedLanguages.contains(lang)) {
          continue;
        }
      }
      batch.add(card);
      count += 1;
      if (batch.length >= config.batchSize) {
        final progress = totalBytes > 0 ? bytesRead / totalBytes : 0;
        config.sendPort.send({
          'type': 'batch',
          'items': List<Map<String, dynamic>>.from(batch),
          'progress': progress,
        });
        batch.clear();
      }
    }

    if (batch.isNotEmpty) {
      final progress = totalBytes > 0 ? bytesRead / totalBytes : 0;
      config.sendPort.send({
        'type': 'batch',
        'items': List<Map<String, dynamic>>.from(batch),
        'progress': progress,
      });
      batch.clear();
    }

    config.sendPort.send({
      'type': 'done',
      'count': count,
    });
  } catch (error) {
    config.sendPort.send({
      'type': 'error',
      'message': error.toString(),
    });
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '${bytes}B';
  }
  final kb = bytes / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(1)}KB';
  }
  final mb = kb / 1024;
  if (mb < 1024) {
    return '${mb.toStringAsFixed(1)}MB';
  }
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(2)}GB';
}

String _setIconUrl(String setCode) {
  final code = setCode.trim().toLowerCase();
  if (code.isEmpty) {
    return '';
  }
  return 'https://svgs.scryfall.io/sets/$code.svg';
}

Widget _buildSetIcon(String setCode, {double size = 28}) {
  if (setCode.trim().isEmpty) {
    return _emptySetIcon(size);
  }
  return Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFF201A14),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: const Color(0xFF3A2F24),
      ),
    ),
    child: SvgPicture.network(
      _setIconUrl(setCode),
      fit: BoxFit.contain,
      colorFilter: const ColorFilter.mode(
        Color(0xFFE9C46A),
        BlendMode.srcIn,
      ),
      placeholderBuilder: (_) => _emptySetIcon(size - 12),
      errorBuilder: (_, __, ___) => _emptySetIcon(size - 12),
    ),
  );
}

Widget _emptySetIcon(double size) {
  return SizedBox(
    width: size,
    height: size,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF201A14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF3A2F24)),
      ),
    ),
  );
}

Widget _buildBadge(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF2A221B),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFF3A2F24)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        color: Color(0xFFE9C46A),
      ),
    ),
  );
}

Widget _statusMiniBadge({IconData? icon, String? label}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFF2A221B),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF3A2F24)),
    ),
    child: icon != null
        ? Icon(
            icon,
            size: 12,
            color: const Color(0xFFE9C46A),
          )
        : Text(
            label ?? '',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE9C46A),
            ),
          ),
  );
}

String _formatRarity(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return '';
  }
  return value[0].toUpperCase() + value.substring(1);
}

Widget _cornerQuantityBadge(int quantity) {
  return CustomPaint(
    painter: _CornerBadgePainter(),
    child: SizedBox(
      width: 36,
      height: 36,
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 6, right: 6),
          child: Text(
            'x$quantity',
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFFE9C46A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );
}

class _CornerBadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF2A221B);
    final border = Paint()
      ..color = const Color(0xFF3A2F24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

List<Color> _manaAccentColors(String? cardJson) {
  if (cardJson == null || cardJson.isEmpty) {
    return const [];
  }
  final decoded = jsonDecode(cardJson);
  if (decoded is! Map<String, dynamic>) {
    return const [];
  }
  final colors = (decoded['colors'] as List?)?.whereType<String>().toList() ??
      (decoded['color_identity'] as List?)?.whereType<String>().toList() ??
      <String>[];
  if (colors.isEmpty) {
    return const [Color(0xFFB9B1A5)];
  }
  return colors.map(_manaColorFromCode).toList();
}

Color _manaColorFromCode(String code) {
  switch (code.toUpperCase()) {
    case 'W':
      return const Color(0xFFF5EED3);
    case 'U':
      return const Color(0xFF7FB4FF);
    case 'B':
      return const Color(0xFF8A7CA8);
    case 'R':
      return const Color(0xFFEF8A5A);
    case 'G':
      return const Color(0xFF7FCF9B);
    default:
      return const Color(0xFFB9B1A5);
  }
}

Decoration _cardTintDecoration(BuildContext context, CollectionCardEntry entry) {
  final base = Theme.of(context).colorScheme.surface;
  final accents = _manaAccentColors(entry.cardJson);
  if (accents.isEmpty) {
    return BoxDecoration(
      color: base,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.35),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
  final tintStops = accents
      .map((color) => Color.lerp(base, color, 0.35) ?? base)
      .toList();
  return BoxDecoration(
    gradient: LinearGradient(
      colors: tintStops.length == 1 ? [base, tintStops.first] : tintStops,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.35),
        blurRadius: 18,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

Color _rarityColor(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'common':
      return const Color(0xFFB8B1A5);
    case 'uncommon':
      return const Color(0xFF7FB98E);
    case 'rare':
      return const Color(0xFFE2C26A);
    case 'mythic':
    case 'mythic rare':
      return const Color(0xFFEA8A5C);
    default:
      return const Color(0xFFBFAE95);
  }
}

Widget _raritySquare(String raw) {
  return Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: _rarityColor(raw),
      borderRadius: BorderRadius.circular(2),
      border: Border.all(color: const Color(0xFF3A2F24)),
    ),
  );
}

class ScryfallBulkCheckResult {
  const ScryfallBulkCheckResult({
    required this.updateAvailable,
    this.updatedAt,
    this.downloadUri,
    this.updatedAtRaw,
  });

  final bool updateAvailable;
  final DateTime? updatedAt;
  final String? downloadUri;
  final String? updatedAtRaw;
}

class ScryfallBulkChecker {
  static const _bulkEndpoint = 'https://api.scryfall.com/bulk-data';
  static String _prefsKeyLatestUpdatedAt(String bulkType) =>
      'scryfall_${bulkType}_latest_updated_at';
  static String _prefsKeyInstalledUpdatedAt(String bulkType) =>
      'scryfall_${bulkType}_installed_updated_at';
  static String _prefsKeyDownloadUri(String bulkType) =>
      'scryfall_${bulkType}_download_uri';

  Future<ScryfallBulkCheckResult> checkAllCardsUpdate(String bulkType) async {
    try {
      final response = await http
          .get(Uri.parse(_bulkEndpoint))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return const ScryfallBulkCheckResult(updateAvailable: false);
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final data = payload['data'] as List<dynamic>?;
      if (data == null) {
        return const ScryfallBulkCheckResult(updateAvailable: false);
      }

      final entry = data.whereType<Map<String, dynamic>>().firstWhere(
            (item) => item['type'] == bulkType,
            orElse: () => const {},
          );
      if (entry.isEmpty) {
        return const ScryfallBulkCheckResult(updateAvailable: false);
      }

      final updatedAtRaw = entry['updated_at'] as String?;
      final downloadUri = entry['download_uri'] as String?;
      final updatedAt =
          updatedAtRaw != null ? DateTime.tryParse(updatedAtRaw) : null;

      final prefs = await SharedPreferences.getInstance();
      if (updatedAtRaw != null) {
        await prefs.setString(_prefsKeyLatestUpdatedAt(bulkType), updatedAtRaw);
      }
      if (downloadUri != null) {
        await prefs.setString(_prefsKeyDownloadUri(bulkType), downloadUri);
      }

      final installedUpdatedAt =
          prefs.getString(_prefsKeyInstalledUpdatedAt(bulkType));
      final updateAvailable =
          updatedAtRaw != null && updatedAtRaw != installedUpdatedAt;

      return ScryfallBulkCheckResult(
        updateAvailable: updateAvailable,
        updatedAt: updatedAt,
        downloadUri: downloadUri,
        updatedAtRaw: updatedAtRaw,
      );
    } catch (_) {
      return const ScryfallBulkCheckResult(updateAvailable: false);
    }
  }

  Future<void> markAllCardsInstalled(
    String updatedAtRaw, {
    required String bulkType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyInstalledUpdatedAt(bulkType), updatedAtRaw);
  }

  Future<void> resetState() async {
    final prefs = await SharedPreferences.getInstance();
    for (final option in _bulkOptions) {
      await prefs.remove(_prefsKeyLatestUpdatedAt(option.type));
      await prefs.remove(_prefsKeyInstalledUpdatedAt(option.type));
      await prefs.remove(_prefsKeyDownloadUri(option.type));
    }
  }
}
