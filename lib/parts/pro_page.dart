part of 'package:tcg_tracker/main.dart';

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
        final l10n = AppLocalizations.of(context)!;
        final isPro = _manager.isPro;
        final priceLabel = _manager.priceLabel;
        final testMode = _manager.testMode;
        final storeNote = _manager.storeAvailable
            ? l10n.storeAvailable
            : l10n.storeNotAvailableYet;
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(l10n.pro),
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
                          Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF3A2F24)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPro ? l10n.proActive : l10n.basePlan,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isPro
                              ? l10n.unlimitedCollectionsUnlocked
                              : l10n.unlockProRemoveLimit,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFFBFAE95),
                                  ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.priceLabel(priceLabel),
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
                    l10n.whatYouGet,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  _buildFeatureRow(
                    Icons.collections_bookmark,
                    l10n.unlimitedCollectionsFeature,
                  ),
                  const SizedBox(height: 8),
                  _buildFeatureRow(
                    Icons.workspace_premium,
                    l10n.supportFuturePremiumFeatures,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _manager.purchasePro,
                    child: Text(
                      testMode
                          ? (isPro
                              ? l10n.switchToBaseTest
                              : l10n.switchToProTest)
                          : (isPro ? l10n.proEnabled : l10n.upgradeToPro),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _manager.restorePurchases,
                    child: Text(l10n.restorePurchases),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    value: testMode,
                    onChanged: _manager.setTestMode,
                    title: Text(l10n.testMode),
                    subtitle: Text(l10n.testModeSubtitle),
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

