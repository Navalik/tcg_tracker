import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tcg_tracker/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{
      'app_locale': 'en',
      'visual_theme': 'magic',
      'app_first_open_flag': 0,
    });
    PackageInfo.setMockInitialValues(
      appName: 'BinderVault',
      packageName: 'tcg.tracker.test',
      version: '0.5.0',
      buildNumber: '10',
      buildSignature: '',
    );
  });

  testWidgets('App bootstrap smoke test renders splash shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TCGTracker());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
    expect(find.text('v0.5.0+10'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
