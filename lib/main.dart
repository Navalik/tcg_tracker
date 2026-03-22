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
final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
Future<void>? _googleSignInInitialization;

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
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 8));
      _firebaseReady = true;
      _googleSignInInitialization = _googleSignIn.initialize();
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

Future<void> _ensureGoogleSignInInitialized() async {
  final initialization =
      _googleSignInInitialization ??= _googleSignIn.initialize();
  await initialization;
}

Future<void> _logAuthBreadcrumb(
  String event, {
  Map<String, Object?> details = const <String, Object?>{},
}) async {
  if (!_firebaseReady) {
    return;
  }
  try {
    final payload = <String>[
      'event=$event',
      ...details.entries.map(
        (entry) =>
            '${entry.key}=${entry.value?.toString().replaceAll(RegExp(r"[\r\n]+"), " ").trim() ?? ''}',
      ),
    ];
    FirebaseCrashlytics.instance.log('auth ${payload.join(' ')}');
  } catch (_) {}
}

bool _hasNonEmptyValue(Object? value) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isNotEmpty;
}

Future<UserCredential> _signInToFirebaseWithGoogle() async {
  await _logAuthBreadcrumb('google_sign_in_start');
  await _ensureGoogleSignInInitialized();
  final googleUser = await _googleSignIn.authenticate();
  await _logAuthBreadcrumb(
    'google_authenticate_success',
    details: {'has_email': _hasNonEmptyValue(googleUser.email)},
  );
  final idToken = googleUser.authentication.idToken?.trim();
  if (idToken == null || idToken.isEmpty) {
    await _logAuthBreadcrumb(
      'google_id_token_missing',
      details: {'has_email': _hasNonEmptyValue(googleUser.email)},
    );
    throw const FormatException('google_id_token_missing');
  }
  final credential = GoogleAuthProvider.credential(idToken: idToken);
  final auth = FirebaseAuth.instance;
  final currentUser = auth.currentUser;
  final UserCredential result;
  if (currentUser?.isAnonymous ?? false) {
    result = await currentUser!.linkWithCredential(credential);
    await _logAuthBreadcrumb(
      'firebase_google_link_success',
      details: {'has_uid': _hasNonEmptyValue(result.user?.uid)},
    );
  } else {
    result = await auth.signInWithCredential(credential);
  }
  await _logAuthBreadcrumb(
    'firebase_google_sign_in_success',
    details: {'has_uid': _hasNonEmptyValue(result.user?.uid)},
  );
  return result;
}

Future<UserCredential?> _signInAnonymouslyIfNeeded() async {
  if (!_firebaseReady) {
    return null;
  }
  final auth = FirebaseAuth.instance;
  final currentUser = auth.currentUser;
  if (currentUser != null) {
    return null;
  }
  await _logAuthBreadcrumb('anonymous_sign_in_start');
  final result = await auth.signInAnonymously();
  await _logAuthBreadcrumb(
    'anonymous_sign_in_success',
    details: {'has_uid': _hasNonEmptyValue(result.user?.uid)},
  );
  return result;
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
    if (kDebugMode) {
      debugPrint('App error (crash reporting disabled): $error');
    }
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
    if (kDebugMode) {
      debugPrint('Failed to report error: $error');
    }
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
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const _SplashBackdrop(),
          SafeArea(
            child: Stack(
              children: [
                Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxHeight < 700;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 28,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _SplashLogoWordmark(),
                              SizedBox(height: compact ? 10 : 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Container(
                                      constraints: BoxConstraints(
                                        maxWidth: compact ? 22 : 34,
                                      ),
                                      height: 1,
                                      color: const Color(0x59F2CA50),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    flex: 0,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Archive. Protect. Prosper.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.spaceGrotesk(
                                          color: const Color(0xFFF2CA50),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: compact ? 2.6 : 3.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Container(
                                      constraints: BoxConstraints(
                                        maxWidth: compact ? 22 : 34,
                                      ),
                                      height: 1,
                                      color: const Color(0x59F2CA50),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: compact ? 18 : 30),
                              _SplashCardMark(compact: compact),
                              SizedBox(height: compact ? 52 : 70),
                              Container(
                                width: 164,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4D4635),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: const Align(
                                  alignment: Alignment.centerLeft,
                                  child: _SplashStatusBeam(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Opening the vault',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.spaceGrotesk(
                                  color: const Color(0xFFD0C5AF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (versionLabel.trim().isNotEmpty)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Text(
                        versionLabel,
                        style: textTheme.bodySmall?.copyWith(
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

class _SplashBackdrop extends StatelessWidget {
  const _SplashBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1B1512),
            Color(0xFF15110F),
            Color(0xFF100D0B),
          ],
        ),
      ),
      child: Stack(
        children: const [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.92, -0.96),
                  radius: 0.44,
                  colors: [Color(0x29C06F22), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.95, 0.96),
                  radius: 0.38,
                  colors: [Color(0x14F2CA50), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned.fill(child: _SplashGridPattern()),
          Positioned.fill(child: _SplashFrame()),
          Positioned.fill(child: _SplashGhostCards()),
        ],
      ),
    );
  }
}

class _SplashGridPattern extends StatelessWidget {
  const _SplashGridPattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SplashGridPainter());
  }
}

class _SplashFrame extends StatelessWidget {
  const _SplashFrame();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: const [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(28)),
                  border: Border.fromBorderSide(
                    BorderSide(color: Color(0x24F2CA50)),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              child: _SplashCorner(top: true, left: true),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: _SplashCorner(top: true, left: false),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              child: _SplashCorner(top: false, left: true),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: _SplashCorner(top: false, left: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashCorner extends StatelessWidget {
  const _SplashCorner({required this.top, required this.left});

  final bool top;
  final bool left;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: top && left ? const Radius.circular(16) : Radius.zero,
            topRight: top && !left ? const Radius.circular(16) : Radius.zero,
            bottomLeft: !top && left ? const Radius.circular(16) : Radius.zero,
            bottomRight: !top && !left
                ? const Radius.circular(16)
                : Radius.zero,
          ),
          border: Border(
            top: top
                ? const BorderSide(color: Color(0x52F2CA50), width: 2)
                : BorderSide.none,
            bottom: !top
                ? const BorderSide(color: Color(0x52F2CA50), width: 2)
                : BorderSide.none,
            left: left
                ? const BorderSide(color: Color(0x52F2CA50), width: 2)
                : BorderSide.none,
            right: !left
                ? const BorderSide(color: Color(0x52F2CA50), width: 2)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _SplashGhostCards extends StatelessWidget {
  const _SplashGhostCards();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: const [
          _GhostCard(left: 0.08, top: 0.08, width: 78, height: 124, angle: -0.32),
          _GhostCard(left: 0.03, top: 0.30, width: 92, height: 138, angle: -0.08),
          _GhostCard(left: 0.17, top: 0.60, width: 80, height: 124, angle: 0.14),
          _GhostCard(left: 0.34, top: 0.76, width: 68, height: 112, angle: -0.10),
          _GhostCard(right: 0.10, top: 0.10, width: 78, height: 124, angle: 0.28),
          _GhostCard(right: 0.19, top: 0.26, width: 68, height: 112, angle: 0.22),
          _GhostCard(right: 0.34, top: 0.38, width: 66, height: 106, angle: 0.16),
          _GhostCard(right: 0.08, top: 0.64, width: 80, height: 124, angle: -0.18),
          _GhostCard(right: 0.20, top: 0.80, width: 66, height: 106, angle: 0.07),
        ],
      ),
    );
  }
}

class _GhostCard extends StatelessWidget {
  const _GhostCard({
    this.left,
    this.right,
    required this.top,
    required this.width,
    required this.height,
    required this.angle,
  });

  final double? left;
  final double? right;
  final double top;
  final double width;
  final double height;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left != null ? MediaQuery.sizeOf(context).width * left! : null,
      right: right != null ? MediaQuery.sizeOf(context).width * right! : null,
      top: MediaQuery.sizeOf(context).height * top,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x38EAE1DD)),
            color: const Color(0x128B6444),
          ),
        ),
      ),
    );
  }
}

class _SplashLogoWordmark extends StatelessWidget {
  const _SplashLogoWordmark();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 380;
    final style = GoogleFonts.cinzelDecorative(
      fontSize: compact ? 38 : 46,
      fontWeight: FontWeight.w900,
      letterSpacing: compact ? 0.8 : 1.4,
      height: 0.92,
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE8D08A),
            Color(0xFFC8952A),
            Color(0xFF7A4A0A),
            Color(0xFF3D1F00),
          ],
          stops: [0.0, 0.32, 0.62, 1.0],
        ).createShader(bounds),
        child: Text(
          'BinderVault',
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.center,
          style: style.copyWith(
            color: Colors.white,
            shadows: const [
              Shadow(
                color: Color(0x731A0800),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
              Shadow(
                color: Color(0x991A0800),
                blurRadius: 0,
                offset: Offset(2, 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashCardMark extends StatelessWidget {
  const _SplashCardMark({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 248 : 288,
      height: compact ? 264 : 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _SplashCard(
            offset: compact ? const Offset(-66, 30) : const Offset(-78, 34),
            angle: -0.20,
            fill: Color(0xFF8A6662),
            stroke: Color(0x26FFFFFF),
          ),
          _SplashCard(
            offset: compact ? const Offset(66, 30) : const Offset(78, 34),
            angle: 0.20,
            fill: Color(0xFF657D9F),
            stroke: Color(0x26FFFFFF),
          ),
          _SplashCard(
            offset: compact ? const Offset(0, 8) : const Offset(0, 12),
            angle: 0,
            fill: Color(0xFF6F876D),
            stroke: Color(0x26FFFFFF),
            compact: compact,
          ),
          _SplashDiamondShadow(compact: compact),
          _SplashDiamond(compact: compact),
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
    this.compact = false,
  });

  final Offset offset;
  final double angle;
  final Color fill;
  final Color stroke;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: compact ? 96 : 112,
          height: compact ? 152 : 176,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.alphaBlend(const Color(0x36FFFFFF), fill), fill],
            ),
            border: Border.all(color: stroke, width: 1.3),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x73000000),
                blurRadius: 28,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x1FFFFFFF)),
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashDiamondShadow extends StatelessWidget {
  const _SplashDiamondShadow({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: compact ? const Offset(0, 100) : const Offset(0, 118),
      child: Transform.rotate(
        angle: 0.785398,
        child: Container(
          width: 52,
          height: 52,
          color: const Color(0x82000000),
        ),
      ),
    );
  }
}

class _SplashDiamond extends StatelessWidget {
  const _SplashDiamond({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: compact ? const Offset(0, 92) : const Offset(0, 108),
      child: Transform.rotate(
        angle: 0.785398,
        child: Container(
          width: compact ? 34 : 40,
          height: compact ? 34 : 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF6D872), Color(0xFFEFC74C)],
            ),
            border: Border.all(color: const Color(0xFFC88D24), width: 2),
          ),
        ),
      ),
    );
  }
}

class _SplashStatusBeam extends StatefulWidget {
  const _SplashStatusBeam();

  @override
  State<_SplashStatusBeam> createState() => _SplashStatusBeamState();
}

class _SplashStatusBeamState extends State<_SplashStatusBeam>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2150),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final trackWidth = 164.0;
        final beamWidth = 56.0;
        final progress = Curves.easeInOut.transform(_controller.value);
        final left = (trackWidth + beamWidth) * progress - beamWidth;
        return Transform.translate(
          offset: Offset(left, 0),
          child: child,
        );
      },
      child: Container(
        width: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: [
              Color(0x00F2CA50),
              Color(0x2EF2CA50),
              Color(0xF2FFE896),
              Color(0x38F2CA50),
              Color(0x00F2CA50),
            ],
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x59F2CA50), blurRadius: 10),
            BoxShadow(color: Color(0x47F2CA50), blurRadius: 18),
          ],
        ),
      ),
    );
  }
}

class _SplashGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0x06FFFFFF)
      ..strokeWidth = 1;
    const spacing = 48.0;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final diagonalPaint = Paint()
      ..color = const Color(0x09F2CA50)
      ..strokeWidth = 1;
    const diagonalSpacing = 24.0;
    for (double start = -size.height; start <= size.width; start += diagonalSpacing) {
      canvas.drawLine(
        Offset(start, 0),
        Offset(start + size.height, size.height),
        diagonalPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
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
    if (error is GoogleSignInException) {
      final blob =
          '${error.code} ${error.description ?? ''} ${error.details ?? ''}'
              .toLowerCase();
      if (blob.contains('clientconfigurationerror') ||
          blob.contains('providerconfigurationerror')) {
        return l10n.authGoogleSignInConfigError;
      }
      if (blob.contains('canceled') || blob.contains('interrupted')) {
        return l10n.authGoogleSignInCancelled;
      }
      return l10n.authGoogleSignInFailedTryAgain;
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
    if (error is FormatException &&
        error.message.toLowerCase().contains('google_id_token_missing')) {
      return l10n.authGoogleSignInConfigError;
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
      await _signInToFirebaseWithGoogle();
    } catch (error) {
      await _logAuthBreadcrumb('google_sign_in_error', details: {'error': error});
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

  Future<void> _continueAsGuest() async {
    if (_isSigningIn || !_supportsFirebaseAuth) {
      return;
    }
    setState(() {
      _isSigningIn = true;
    });
    try {
      await _signInAnonymouslyIfNeeded();
    } catch (error) {
      await _logAuthBreadcrumb(
        'anonymous_sign_in_error',
        details: {'error': error},
      );
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.authGoogleSignInFailedTryAgain)),
      );
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
    if (!_supportsFirebaseAuth) {
      return const CollectionHomePage();
    }
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
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
                                  : _continueAsGuest,
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
