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
    final textColor = highlighted
        ? (pro ? const Color(0xFFE9C46A) : const Color(0xFFF5EADB))
        : const Color(0xFFEFE7D8);
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted
            ? (pro ? const Color(0xFF16110C) : const Color(0xFF221A14))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: highlighted && pro
            ? Border.all(color: const Color(0xFF7A5B2E))
            : null,
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

  String _planDescription(AppLocalizations l10n, PlusPlanOption option) {
    switch (option.period) {
      case PlusPlanPeriod.monthly:
        return l10n.plusMonthlyPlanPrice(option.formattedPrice);
      case PlusPlanPeriod.yearly:
        return l10n.plusYearlyPlanPrice(option.formattedPrice);
    }
  }

  Widget _buildPlanButton({
    required BuildContext context,
    required AppLocalizations l10n,
    required PlusPlanOption option,
    required bool filled,
    required VoidCallback? onPressed,
  }) {
    final title = option.period == PlusPlanPeriod.monthly
        ? l10n.plusMonthlyLabel
        : l10n.plusYearlyLabel;
    final details = _planDescription(l10n, option);
    final titleColor = filled
        ? const Color(0xFF6E4C0F)
        : const Color(0xFFEFE7D8);
    final detailsColor = filled
        ? const Color(0xFF4A3210)
        : const Color(0xFFF5EADB);
    final style = filled
        ? FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE9C46A),
            foregroundColor: const Color(0xFF1C1510),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          )
        : OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            side: const BorderSide(color: Color(0xFFE9C46A)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          );
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          details,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.35,
            color: detailsColor,
          ),
        ),
      ],
    );
    return filled
        ? FilledButton(onPressed: onPressed, style: style, child: child)
        : OutlinedButton(onPressed: onPressed, style: style, child: child);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _manager,
      builder: (context, _) {
        final isPro = _manager.isPro;
        final l10n = AppLocalizations.of(context)!;
        final monthly = _manager.monthlyPlan;
        final yearly = _manager.yearlyPlan;
        final bottomInset = MediaQuery.of(context).padding.bottom;
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(l10n.plusPageTitle)),
          body: Stack(
            children: [
              const _AppBackground(),
              ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  24 + bottomInset + 16,
                ),
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
                                color: const Color(
                                  0xFFE9C46A,
                                ).withValues(alpha: 0.15),
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
                                l10n.plusPageTitle,
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
                          l10n.plusPaywallSubtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFFCCBA9E)),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _PlusTag(label: l10n.plusTagAccountWide),
                            _PlusTag(label: l10n.plusTagAllUnlockedTcgs),
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
                            l10n.plusPaywallCoverageNote,
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
                          feature: l10n.smartCollectionsFeature,
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
                    Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          decoration: BoxDecoration(
                            color: const Color(0x221D1712),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF5D4731)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.plusDisclosureAutoRenew,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: const Color(0xFFE7DCCB),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.plusDisclosureCancellation,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: const Color(0xFFE7DCCB),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.plusDisclosureFreeUsage,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: const Color(0xFFE7DCCB),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.plusDisclosureRegionalPricing,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: const Color(0xFFE7DCCB),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Google Play requires explicit subscription terms in-app,
                        // before the purchase sheet is shown.
                        Row(
                          children: [
                            Expanded(
                              child: _buildPlanButton(
                                context: context,
                                l10n: l10n,
                                option: monthly,
                                filled: false,
                                onPressed: _manager.purchasePending
                                    ? null
                                    : () => _manager.purchasePlus(
                                        PlusPlanPeriod.monthly,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildPlanButton(
                                context: context,
                                l10n: l10n,
                                option: yearly,
                                filled: true,
                                onPressed: _manager.purchasePending
                                    ? null
                                    : () => _manager.purchasePlus(
                                        PlusPlanPeriod.yearly,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  if (!isPro)
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF5D4731)),
                      ),
                      child: Text(l10n.continueWithFree),
                    ),
                  if (!isPro) const SizedBox(height: 4),
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
