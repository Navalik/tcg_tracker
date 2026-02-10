import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'l10n/app_localizations.dart';

import 'db/app_database.dart';
import 'models.dart';
import 'services/app_settings.dart';
import 'services/purchase_manager.dart';

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


void main() {
  runApp(const TCGTracker());
}

class TCGTracker extends StatelessWidget {
  const TCGTracker({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFC9A043),
      brightness: Brightness.dark,
      surface: const Color(0xFF1C1510),
    );
    const scaffoldBackground = Color(0xFF0E0A08);
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
      locale: const Locale('en'),
      themeMode: ThemeMode.dark,
      home: const CollectionHomePage(),
    );
  }
}
