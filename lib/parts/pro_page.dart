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

  void _showPreviewMessage(String planLabel) {
    showAppSnackBar(
      context,
      '$planLabel plan selected. Billing will be enabled in a next step.',
    );
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
            child: Text(
              feature,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            flex: 3,
            child: _buildPlanCell(text: freeValue, pro: false),
          ),
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
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('BinderVault Plus'),
          ),
          body: Stack(
            children: [
              const _AppBackground(),
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171411).withValues(alpha: 0.9),
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
                    child: Row(
                      children: [
                        const Icon(
                          Icons.workspace_premium_rounded,
                          color: Color(0xFFE9C46A),
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isPro ? 'Plus active' : 'Upgrade to Plus',
                            style: Theme.of(context).textTheme.titleMedium,
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
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF3A2F24)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              flex: 5,
                              child: SizedBox.shrink(),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Free',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Plus',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: const Color(0xFFE9C46A),
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1, color: Color(0xFF3A2F24)),
                        _buildFeatureRow(
                          feature: 'Daily card scans',
                          freeValue: '20/day',
                          plusValue: 'Unlimited',
                          highlightPlus: true,
                        ),
                        _buildFeatureRow(
                          feature: 'Collections',
                          freeValue: '3',
                          plusValue: 'Unlimited',
                          highlightPlus: true,
                        ),
                        _buildFeatureRow(
                          feature: 'Card search & add',
                          freeValue: 'Unlimited',
                          plusValue: 'Unlimited',
                        ),
                        _buildFeatureRow(
                          feature: 'Advanced filters',
                          freeValue: 'Unlimited',
                          plusValue: 'Unlimited',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showPreviewMessage('Monthly'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFFE9C46A)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'EUR 1.99',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              SizedBox(height: 2),
                              Text('1 month'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _showPreviewMessage('Yearly'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE9C46A),
                            foregroundColor: const Color(0xFF1C1510),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'EUR 19.90',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              SizedBox(height: 2),
                              Text('12 months'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _manager.restorePurchases,
                    child: const Text('Already subscribed? Restore'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Preview screen: real billing flow will be integrated next.',
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
