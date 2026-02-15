import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'l10n/app_localizations.dart';

import 'db/app_database.dart';
import 'models.dart';
import 'services/app_settings.dart';
import 'services/price_repository.dart';
import 'services/purchase_manager.dart';
import 'services/scryfall_api_client.dart';

part 'parts/home_page.dart';
part 'parts/collection_detail_page.dart';
part 'parts/collection_detail_search.dart';
part 'parts/collection_detail_extras.dart';
part 'parts/settings_page.dart';
part 'parts/pro_page.dart';
part 'parts/shared_widgets.dart';
part 'parts/bulk_helpers.dart';
part 'parts/scryfall_bulk.dart';
part 'parts/ui_helpers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid || Platform.isIOS) {
    await Firebase.initializeApp();
  }
  runApp(const TCGTracker());
}

final ValueNotifier<Locale> _appLocaleNotifier =
    ValueNotifier<Locale>(const Locale('en'));

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
  }

  Future<void> _loadAppLocale() async {
    final localeCode = await AppSettings.loadAppLocale();
    if (!mounted) {
      return;
    }
    _appLocaleNotifier.value = Locale(localeCode);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFC9A043),
      brightness: Brightness.dark,
      surface: const Color(0xFF1C1510),
    );
    const scaffoldBackground = Color(0xFF0E0A08);
    final textTheme =
        GoogleFonts.sourceSans3TextTheme(
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

    return ValueListenableBuilder<Locale>(
      valueListenable: _appLocaleNotifier,
      builder: (context, locale, _) {
        return MaterialApp(
          onGenerateTitle: (context) =>
              AppLocalizations.of(context)?.appTitle ?? 'BinderVault',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: colorScheme,
            textTheme: scaledTextTheme,
            scaffoldBackgroundColor: scaffoldBackground,
            cardColor: const Color(0xFF171411),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: const Color(0xFFE9C46A),
              contentTextStyle: scaledTextTheme.bodyMedium?.copyWith(
                color: const Color(0xFF1C1510),
                fontWeight: FontWeight.w600,
              ),
              behavior: SnackBarBehavior.floating,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFB07C2A)),
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
          home: const _AuthGate(),
        );
      },
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

  bool get _supportsFirebaseAuth => Platform.isAndroid || Platform.isIOS;

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
        return l10n.authNetworkErrorDuringGoogleSignIn;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_googleSignInErrorMessage(error))),
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
                          color: const Color(0xFF171411).withValues(alpha: 0.92),
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
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFFBFAE95),
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _isSigningIn ? null : _signInWithGoogle,
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
                                  : () => setState(() => _continueAsGuest = true),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEFE7D8),
                                minimumSize: const Size.fromHeight(46),
                                side: const BorderSide(color: Color(0xFF5D4731)),
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
