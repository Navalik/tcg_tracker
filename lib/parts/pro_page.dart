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

  String _errorLabel(AppLocalizations l10n, String? error) {
    if (error == null || error.trim().isEmpty) {
      return l10n.billingPlansUnavailable;
    }
    if (error == 'store_unavailable') {
      return l10n.billingStoreUnavailable;
    }
    if (error == 'plans_unavailable' ||
        error == 'missing_offer_token' ||
        error == 'catalog_load_failed' ||
        error == 'purchase_start_failed' ||
        error == 'purchase_failed' ||
        error == 'restore_failed' ||
        error == 'entitlement_refresh_failed' ||
        error == 'entitlement_verification_failed' ||
        error == 'server_entitlement_unverified') {
      return l10n.billingPlansUnavailable;
    }
    return l10n.billingPlansUnavailable;
  }

  Widget _buildPlanCell({
    required String text,
    required bool pro,
    bool highlighted = false,
  }) {
    final textColor = pro ? const Color(0xFFEFE7D8) : const Color(0xFFEFE7D8);
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted
            ? (pro ? const Color(0xFF2C2118) : const Color(0xFF221A14))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required String feature,
    required String freeValue,
    required String plusValue,
    bool highlightPlus = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(feature, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(flex: 3, child: _buildPlanCell(text: freeValue, pro: false)),
          Expanded(
            flex: 3,
            child: _buildPlanCell(
              text: plusValue,
              pro: true,
              highlighted: highlightPlus,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _manager,
      builder: (context, _) {
        final isPro = _manager.isPro;
        final l10n = AppLocalizations.of(context)!;
        final isItalian = Localizations.localeOf(
          context,
        ).languageCode.toLowerCase().startsWith('it');
        final monthly = _manager.monthlyPlan;
        final yearly = _manager.yearlyPlan;
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(l10n.plusPageTitle)),
          body: Stack(
            children: [
              const _AppBackground(),
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1E1712), Color(0xFF120F0C)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF3A2F24)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9C46A).withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF7A5B2E),
                                ),
                              ),
                              child: const Icon(
                                Icons.workspace_premium_rounded,
                                color: Color(0xFFE9C46A),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isPro ? l10n.plusActive : l10n.upgradeToPlus,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9C46A),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'PLUS',
                                style: TextStyle(
                                  color: Color(0xFF1C1510),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isItalian
                              ? 'Un solo Plus, su tutti i tuoi TCG sbloccati.'
                              : 'One Plus plan, across all your unlocked TCGs.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFFCCBA9E)),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _PlusTag(
                              label: isItalian
                                  ? 'Valido su account'
                                  : 'Account-wide',
                            ),
                            _PlusTag(
                              label: isItalian
                                  ? 'Tutti i TCG sbloccati'
                                  : 'All unlocked TCGs',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: const Color(0x221D1712),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF3A2F24)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: Color(0xFFE9C46A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isItalian
                                ? 'Il Plus si applica a tutte le funzionalita premium di ogni TCG che hai gia sbloccato o acquistato.'
                                : 'Plus applies to premium features for every TCG you have already unlocked or purchased.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xFFBFAE95)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF3A2F24)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(flex: 5, child: SizedBox.shrink()),
                            Expanded(
                              flex: 3,
                              child: Text(
                                l10n.freePlanLabel,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                l10n.plusPlanLabel,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(color: const Color(0xFFE9C46A)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1, color: Color(0xFF3A2F24)),
                        _buildFeatureRow(
                          feature: l10n.dailyCardScansFeature,
                          freeValue: l10n.scansPerDay(20),
                          plusValue: l10n.unlimitedLabel,
                          highlightPlus: true,
                        ),
                        _buildFeatureRow(
                          feature: l10n.setCollectionsFeature,
                          freeValue: '2',
                          plusValue: l10n.unlimitedLabel,
                          highlightPlus: true,
                        ),
                        _buildFeatureRow(
                          feature: l10n.customCollectionsFeature,
                          freeValue: '2',
                          plusValue: l10n.unlimitedLabel,
                          highlightPlus: true,
                        ),
                        _buildFeatureRow(
                          feature: isItalian
                              ? 'Collezioni smart'
                              : 'Smart collections',
                          freeValue: '1',
                          plusValue: l10n.unlimitedLabel,
                          highlightPlus: true,
                        ),
                        _buildFeatureRow(
                          feature: l10n.decksFeature,
                          freeValue: '2',
                          plusValue: l10n.unlimitedLabel,
                          highlightPlus: true,
                        ),
                        _buildFeatureRow(
                          feature: l10n.wishlistFeature,
                          freeValue: '1',
                          plusValue: l10n.unlimitedLabel,
                          highlightPlus: true,
                        ),
                        _buildFeatureRow(
                          feature: l10n.cardSearchAddFeature,
                          freeValue: l10n.unlimitedLabel,
                          plusValue: l10n.unlimitedLabel,
                        ),
                        _buildFeatureRow(
                          feature: l10n.advancedFiltersFeature,
                          freeValue: l10n.unlimitedLabel,
                          plusValue: l10n.unlimitedLabel,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_manager.loadingPlans)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            l10n.billingLoadingPlans,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xFFBFAE95)),
                          ),
                        ],
                      ),
                    )
                  else if (!_manager.storeAvailable ||
                      monthly == null ||
                      yearly == null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        color: const Color(0x221D1712),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF3A2F24)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _manager.storeAvailable
                                ? _errorLabel(l10n, _manager.lastError)
                                : l10n.billingStoreUnavailable,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton(
                              onPressed: _manager.loadingPlans
                                  ? null
                                  : () => _manager.refreshCatalog(),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF5D4731),
                                ),
                              ),
                              child: Text(l10n.retry),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _manager.purchasePending
                                ? null
                                : () => _manager.purchasePlus(
                                    PlusPlanPeriod.monthly,
                                  ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFFE9C46A)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  monthly.formattedPrice,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(l10n.oneMonthLabel),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _manager.purchasePending
                                ? null
                                : () => _manager.purchasePlus(
                                    PlusPlanPeriod.yearly,
                                  ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFE9C46A),
                              foregroundColor: const Color(0xFF1C1510),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  yearly.formattedPrice,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(l10n.twelveMonthsLabel),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _manager.restoringPurchases
                        ? null
                        : _manager.restorePurchases,
                    child: Text(l10n.alreadySubscribedRestore),
                  ),
                  if (_manager.purchasePending ||
                      _manager.restoringPurchases) ...[
                    const SizedBox(height: 6),
                    Text(
                      _manager.restoringPurchases
                          ? l10n.billingRestoringPurchases
                          : l10n.billingWaitingPurchase,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFBFAE95),
                      ),
                    ),
                  ],
                  if (_manager.lastError != null &&
                      _manager.lastError!.trim().isNotEmpty &&
                      _manager.lastError != 'plans_unavailable') ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorLabel(l10n, _manager.lastError),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFE6B1A6),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    l10n.previewBillingNotice,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF908676),
                    ),
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

class _PlusTag extends StatelessWidget {
  const _PlusTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF241C15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF5D4731)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: const Color(0xFFDCC8A4),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
