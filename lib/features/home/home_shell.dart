// ignore_for_file: invalid_use_of_protected_member

part of 'package:tcg_tracker/main.dart';

extension _HomeShellStateX on _CollectionHomePageState {
  Widget? _buildPinnedAllCardsCard(BuildContext context) {
    final allCards = _collections.cast<CollectionInfo?>().firstWhere(
      (item) => item?.name == _allCardsCollectionName,
      orElse: () => null,
    );
    if (allCards == null) {
      return null;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: _CollectionCard(
        name: _collectionDisplayName(allCards),
        count: _totalCardCount,
        icon: _collectionIcon(allCards),
        onLongPress: (position) {
          _showCollectionActions(allCards, position);
        },
        onTap: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) => CollectionDetailPage(
                    collectionId: allCards.id,
                    name: _collectionDisplayName(allCards),
                    isAllCards: true,
                    filter: allCards.filter,
                  ),
                ),
              )
              .then((_) => _loadCollections());
        },
      ),
    );
  }

  Widget _buildPinnedLatestAddsHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: _SectionDivider(label: l10n.latestAddsLabel),
    );
  }

  Widget _buildCollectionsMenu() {
    final l10n = AppLocalizations.of(context)!;
    final items = <(_HomeCollectionsMenu, IconData, String)>[
      (_HomeCollectionsMenu.set, Icons.auto_awesome_mosaic, l10n.setLabel),
      (
        _HomeCollectionsMenu.custom,
        Icons.collections_bookmark_outlined,
        l10n.customLabel,
      ),
      (
        _HomeCollectionsMenu.smart,
        Icons.auto_fix_high_rounded,
        l10n.smartLabel,
      ),
      (
        _HomeCollectionsMenu.wish,
        Icons.favorite_border_rounded,
        l10n.wishlistCollectionTitle,
      ),
      (
        _HomeCollectionsMenu.deck,
        Icons.view_carousel_rounded,
        l10n.deckCollectionTitle,
      ),
    ];
    return Column(
      children: [
        const Divider(height: 1, color: Color(0x7A5D4731)),
        const SizedBox(height: 10),
        Row(
          children: items
              .map(
                (entry) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _MenuPillButton(
                      icon: entry.$2,
                      tooltip: entry.$3,
                      selected: _activeCollectionsMenu == entry.$1,
                      onTap: () {
                        if (_activeCollectionsMenu == entry.$1) {
                          return;
                        }
                        setState(() {
                          _activeCollectionsMenu = entry.$1;
                        });
                      },
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 10),
        const Divider(height: 1, color: Color(0x7A5D4731)),
      ],
    );
  }
}
