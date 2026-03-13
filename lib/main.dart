import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'l10n/app_localizations.dart';

import 'db/app_database.dart';
import 'domain/domain_models.dart';
import 'models.dart';
import 'repositories/app_repositories.dart';
import 'repositories/filter_definitions.dart';
import 'services/app_settings.dart';
import 'services/analytics_service.dart';
import 'services/local_backup_service.dart';
import 'services/price_repository.dart';
import 'services/inventory_service.dart';
import 'services/pokemon_bulk_service.dart';
import 'services/pokemon_scanner_resolver.dart';
import 'services/purchase_manager.dart';
import 'services/scryfall_api_client.dart';
import 'services/tcg_environment.dart';

part 'features/home/home_page.dart';
part 'features/home/home_dialogs.dart';
part 'features/home/home_shell.dart';
part 'features/collections/collection_detail_page.dart';
part 'features/collections/collection_detail_deck.dart';
part 'features/collections/collection_detail_filters.dart';
part 'features/collections/collection_detail_details.dart';
part 'features/collections/collection_detail_tiles.dart';
part 'features/collections/collection_detail_scan.dart';
part 'features/search/card_search_sheet.dart';
part 'features/search/card_search_filters.dart';
part 'features/search/card_search_details.dart';
part 'features/search/card_search_results.dart';
part 'features/search/collection_filter_builder.dart';
part 'features/scanner/card_scanner_page.dart';
part 'features/collections/collection_detail_extras.dart';
part 'features/settings/settings_page.dart';
part 'features/settings/settings_actions.dart';
part 'features/settings/settings_operations.dart';
part 'features/settings/settings_profile.dart';
part 'features/billing/pro_page.dart';
part 'parts/shared_widgets.dart';
part 'parts/bulk_helpers.dart';
part 'parts/scryfall_bulk.dart';
part 'parts/ui_helpers.dart';

bool _firebaseReady = false;
bool _crashReportingReady = false;

bool _isNonFatalUiResourceError(Object error, {String? reason}) {
  if (error is NetworkImageLoadException) {
    return true;
  }
  final message = error.toString().toLowerCase();
  final context = (reason ?? '').toLowerCase();
  if (message.contains('error thrown resolving an image codec') ||
      message.contains('http request failed, statuscode: 404') ||
      message.contains('bad state: invalid svg data')) {
    return true;
  }
  if (context.contains('resolving an image codec')) {
    return true;
  }
  return false;
}

enum AppVisualTheme { magic, vault }

AppVisualTheme appVisualThemeFromCode(String? rawCode) {
  switch (rawCode?.trim().toLowerCase()) {
    case 'vault':
      return AppVisualTheme.vault;
    case 'magic':
    default:
      return AppVisualTheme.magic;
  }
}

String appVisualThemeToCode(AppVisualTheme theme) {
  switch (theme) {
    case AppVisualTheme.vault:
      return 'vault';
    case AppVisualTheme.magic:
      return 'magic';
  }
}

class _AppVisualPalette {
  const _AppVisualPalette({
    required this.seedColor,
    required this.surfaceColor,
    required this.scaffoldBackground,
    required this.cardColor,
    required this.bodyColor,
    required this.displayColor,
    required this.snackBarBackground,
    required this.snackBarText,
    required this.snackBarBorder,
  });

  final Color seedColor;
  final Color surfaceColor;
  final Color scaffoldBackground;
  final Color cardColor;
  final Color bodyColor;
  final Color displayColor;
  final Color snackBarBackground;
  final Color snackBarText;
  final Color snackBarBorder;
}

_AppVisualPalette _paletteForTheme(AppVisualTheme theme) {
  switch (theme) {
    case AppVisualTheme.vault:
      return const _AppVisualPalette(
        seedColor: Color(0xFF4E8FB8),
        surfaceColor: Color(0xFF111A21),
        scaffoldBackground: Color(0xFF070D12),
        cardColor: Color(0xFF101922),
        bodyColor: Color(0xFFDCE8EF),
        displayColor: Color(0xFFEAF3F8),
        snackBarBackground: Color(0xFF6CB4DD),
        snackBarText: Color(0xFF0B1B26),
        snackBarBorder: Color(0xFF3A86B3),
      );
    case AppVisualTheme.magic:
      return const _AppVisualPalette(
        seedColor: Color(0xFFC9A043),
        surfaceColor: Color(0xFF1C1510),
        scaffoldBackground: Color(0xFF0E0A08),
        cardColor: Color(0xFF171411),
        bodyColor: Color(0xFFEFE7D8),
        displayColor: Color(0xFFF5EEDA),
        snackBarBackground: Color(0xFFE9C46A),
        snackBarText: Color(0xFF1C1510),
        snackBarBorder: Color(0xFFB07C2A),
      );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 8));
      _firebaseReady = true;
      await AnalyticsService.instance.init().timeout(
        const Duration(seconds: 5),
      );
      await _configureCrashReporting();
    } catch (_) {
      _firebaseReady = false;
    }
  }
  runZonedGuarded(() => runApp(const TCGTracker()), (error, stackTrace) {
    final reason = 'run_zoned_guarded';
    unawaited(
      _recordAppError(
        error,
        stackTrace,
        fatal: !_isNonFatalUiResourceError(error, reason: reason),
        reason: reason,
      ),
    );
  });
}

Future<void> _configureCrashReporting() async {
  if (!_firebaseReady || !(Platform.isAndroid || Platform.isIOS)) {
    return;
  }
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
    !kDebugMode,
  );
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    final reason = details.context?.toDescription();
    unawaited(
      _recordAppError(
        details.exception,
        details.stack ?? StackTrace.current,
        fatal: !_isNonFatalUiResourceError(details.exception, reason: reason),
        reason: reason,
      ),
    );
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(
      _recordAppError(
        error,
        stackTrace,
        fatal: true,
        reason: 'platform_dispatcher',
      ),
    );
    return true;
  };
  _crashReportingReady = true;
}

Future<void> _recordAppError(
  Object error,
  StackTrace stackTrace, {
  required bool fatal,
  String? reason,
}) async {
  if (!_crashReportingReady) {
    debugPrint('App error (crash reporting disabled): $error');
    return;
  }
  try {
    await FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      fatal: fatal,
      reason: reason,
    );
  } catch (_) {
    debugPrint('Failed to report error: $error');
  }
}

Future<bool> _submitManualIssueReport(
  String message, {
  String source = 'manual',
  String category = 'other',
  String? diagnostics,
}) async {
  final normalized = message.trim();
  if (normalized.isEmpty) {
    return false;
  }
  if (!_crashReportingReady) {
    return false;
  }
  try {
    final normalizedCategory = category.trim().isEmpty ? 'other' : category;
    final safeDiagnostics = diagnostics?.trim() ?? '';
    FirebaseCrashlytics.instance.log(
      'user_issue_report source=$source category=$normalizedCategory message=$normalized',
    );
    if (safeDiagnostics.isNotEmpty) {
      FirebaseCrashlytics.instance.log(
        'user_issue_diagnostics $safeDiagnostics',
      );
    }
    await FirebaseCrashlytics.instance.recordError(
      StateError('User issue report'),
      StackTrace.current,
      reason: 'user_issue_report:$source:$normalizedCategory',
      fatal: false,
      information: [
        'category=$normalizedCategory',
        if (safeDiagnostics.isNotEmpty) 'diagnostics=$safeDiagnostics',
        normalized,
      ],
    );
    return true;
  } catch (_) {
    return false;
  }
}

final ValueNotifier<Locale> _appLocaleNotifier = ValueNotifier<Locale>(
  const Locale('en'),
);
final ValueNotifier<AppVisualTheme> _appThemeNotifier =
    ValueNotifier<AppVisualTheme>(AppVisualTheme.magic);
final ValueNotifier<int> _collectionsRefreshNotifier = ValueNotifier<int>(0);

class TCGTracker extends StatefulWidget {
  const TCGTracker({super.key});

  @override
  State<TCGTracker> createState() => _TCGTrackerState();
}

class _TCGTrackerState extends State<TCGTracker> {
  @override
  void initState() {
    super.initState();
    _loadAppLocale();
    _loadAppTheme();
  }

  Future<void> _loadAppLocale() async {
    final localeCode = await AppSettings.loadAppLocale();
    if (!mounted) {
      return;
    }
    _appLocaleNotifier.value = Locale(localeCode);
  }

  Future<void> _loadAppTheme() async {
    final themeCode = await AppSettings.loadVisualTheme();
    if (!mounted) {
      return;
    }
    _appThemeNotifier.value = appVisualThemeFromCode(themeCode);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: _appLocaleNotifier,
      builder: (context, locale, _) {
        return ValueListenableBuilder<AppVisualTheme>(
          valueListenable: _appThemeNotifier,
          builder: (context, visualTheme, _) {
            final palette = _paletteForTheme(visualTheme);
            final colorScheme = ColorScheme.fromSeed(
              seedColor: palette.seedColor,
              brightness: Brightness.dark,
              surface: palette.surfaceColor,
            );
            final textTheme =
                GoogleFonts.sourceSans3TextTheme(
                  ThemeData(brightness: Brightness.dark).textTheme,
                ).apply(
                  bodyColor: palette.bodyColor,
                  displayColor: palette.displayColor,
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
              onGenerateTitle: (context) =>
                  AppLocalizations.of(context)?.appTitle ?? 'BinderVault',
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: colorScheme,
                textTheme: scaledTextTheme,
                scaffoldBackgroundColor: palette.scaffoldBackground,
                cardColor: palette.cardColor,
                snackBarTheme: SnackBarThemeData(
                  backgroundColor: palette.snackBarBackground,
                  contentTextStyle: scaledTextTheme.bodyMedium?.copyWith(
                    color: palette.snackBarText,
                    fontWeight: FontWeight.w600,
                  ),
                  behavior: SnackBarBehavior.floating,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: palette.snackBarBorder),
                  ),
                  insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  centerTitle: true,
                ),
              ),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              locale: locale,
              themeMode: ThemeMode.dark,
              home: const _StartupSplashGate(),
            );
          },
        );
      },
    );
  }
}

class _StartupSplashGate extends StatefulWidget {
  const _StartupSplashGate();

  @override
  State<_StartupSplashGate> createState() => _StartupSplashGateState();
}

class _StartupSplashGateState extends State<_StartupSplashGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  bool _showAuthGate = false;
  String _versionLabel = '';
  Timer? _transitionTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    unawaited(_loadVersionLabel());
    _transitionTimer = Timer(
      const Duration(milliseconds: 2600),
      () => unawaited(_scheduleTransition()),
    );
  }

  Future<void> _loadVersionLabel() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) {
        return;
      }
      setState(() {
        _versionLabel = 'v${info.version}+${info.buildNumber}';
      });
    } catch (_) {
      // Keep splash resilient even if version is unavailable.
    }
  }

  Future<void> _scheduleTransition() async {
    if (!mounted) {
      return;
    }
    await _controller.reverse();
    if (!mounted) {
      return;
    }
    await _ensureGuiLanguageSelectedBeforeAuth();
    if (!mounted) {
      return;
    }
    setState(() {
      _showAuthGate = true;
    });
  }

  Future<void> _ensureGuiLanguageSelectedBeforeAuth() async {
    final firstOpenFlag = await AppSettings.loadAppFirstOpenFlag();
    if (firstOpenFlag != 1 || !mounted) {
      return;
    }
    var selected = _appLocaleNotifier.value.languageCode.trim().toLowerCase();
    if (selected != 'it') {
      selected = 'en';
    }
    final picked = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(
                selected == 'it' ? 'Scegli lingua' : 'Choose language',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioGroup<String>(
                    groupValue: selected,
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setModalState(() {
                        selected = value;
                      });
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        RadioListTile<String>(
                          value: 'en',
                          title: Text('English'),
                        ),
                        RadioListTile<String>(
                          value: 'it',
                          title: Text('Italiano'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(selected),
                  child: Text(selected == 'it' ? 'Avanti' : 'Next'),
                ),
              ],
            );
          },
        );
      },
    );
    if (!mounted || picked == null) {
      return;
    }
    await AppSettings.saveAppLocale(picked);
    _appLocaleNotifier.value = Locale(picked);
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showAuthGate) {
      return const _AuthGate();
    }
    return FadeTransition(
      opacity: _opacity,
      child: _UniversalSplashScreen(versionLabel: _versionLabel),
    );
  }
}

class _UniversalSplashScreen extends StatelessWidget {
  const _UniversalSplashScreen({required this.versionLabel});

  final String versionLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const _AppBackground(),
          SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [const _SplashCardMark()],
                  ),
                ),
                if (versionLabel.trim().isNotEmpty)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Text(
                        versionLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFC9BDA4),
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashCardMark extends StatelessWidget {
  const _SplashCardMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 272,
      child: Stack(
        alignment: Alignment.center,
        children: const [
          _SplashCard(
            offset: Offset(-44, 24),
            angle: -0.22,
            fill: Color(0xFF6A4A45),
            stroke: Color(0xFF8B655F),
          ),
          _SplashCard(
            offset: Offset(44, 24),
            angle: 0.22,
            fill: Color(0xFF465B72),
            stroke: Color(0xFF667E99),
          ),
          _SplashCard(
            offset: Offset(0, 10),
            angle: 0,
            fill: Color(0xFF4E624F),
            stroke: Color(0xFF6F8670),
          ),
          _SplashDiamondShadow(),
          _SplashDiamond(),
        ],
      ),
    );
  }
}

class _SplashCard extends StatelessWidget {
  const _SplashCard({
    required this.offset,
    required this.angle,
    required this.fill,
    required this.stroke,
  });

  final Offset offset;
  final double angle;
  final Color fill;
  final Color stroke;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: 102,
          height: 148,
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: stroke, width: 1.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _SplashDiamondShadow extends StatelessWidget {
  const _SplashDiamondShadow();

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, 90),
      child: Transform.rotate(
        angle: 0.785398,
        child: Container(width: 44, height: 44, color: const Color(0x82000000)),
      ),
    );
  }
}

class _SplashDiamond extends StatelessWidget {
  const _SplashDiamond();

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, 82),
      child: Transform.rotate(
        angle: 0.785398,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFD4B86A),
            border: Border.all(color: const Color(0xFFB26A39), width: 2),
          ),
        ),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _continueAsGuest = false;
  bool _isSigningIn = false;

  bool get _supportsFirebaseAuth =>
      (Platform.isAndroid || Platform.isIOS) && _firebaseReady;

  String _googleSignInErrorMessage(Object error) {
    final l10n = AppLocalizations.of(context)!;
    if (error is FirebaseAuthException) {
      if (error.code == 'network-request-failed') {
        return l10n.authNetworkErrorDuringSignIn;
      }
      if (error.code == 'invalid-credential') {
        return l10n.authInvalidGoogleCredential;
      }
      return l10n.authGoogleSignInFailedWithCode(error.code);
    }
    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      final message = (error.message ?? '').toLowerCase();
      final details = '${error.details ?? ''}'.toLowerCase();
      final blob = '$code $message $details';
      if (blob.contains('10') || blob.contains('developer_error')) {
        return l10n.authGoogleSignInConfigError;
      }
      if (blob.contains('network_error')) {
        return l10n.authGoogleSignInFailedWithCode(error.code);
      }
      if (blob.contains('sign_in_canceled') || blob.contains('cancel')) {
        return l10n.authGoogleSignInCancelled;
      }
      return l10n.authGoogleSignInFailedWithCode(error.code);
    }
    return l10n.authGoogleSignInFailedTryAgain;
  }

  Future<void> _signInWithGoogle() async {
    if (_isSigningIn) {
      return;
    }
    setState(() {
      _isSigningIn = true;
    });
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_googleSignInErrorMessage(error))));
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_continueAsGuest || !_supportsFirebaseAuth) {
      return const CollectionHomePage();
    }
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data != null) {
          return const CollectionHomePage();
        }
        final l10n = AppLocalizations.of(context)!;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              const _AppBackground(),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF171411,
                          ).withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF3A2D20)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 16,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(
                              Icons.collections_bookmark_rounded,
                              size: 36,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l10n.authWelcomeTitle,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l10n.authWelcomeSubtitle,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: const Color(0xFFBFAE95)),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _isSigningIn
                                  ? null
                                  : _signInWithGoogle,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFC9A043),
                                foregroundColor: const Color(0xFF1C1510),
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: _isSigningIn
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF1C1510),
                                      ),
                                    )
                                  : const Icon(Icons.login_rounded),
                              label: Text(l10n.authSignInWithGoogle),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _isSigningIn
                                  ? null
                                  : () =>
                                        setState(() => _continueAsGuest = true),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEFE7D8),
                                minimumSize: const Size.fromHeight(46),
                                side: const BorderSide(
                                  color: Color(0xFF5D4731),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(l10n.authContinueAsGuest),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
