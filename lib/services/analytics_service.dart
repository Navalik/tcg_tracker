import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  bool get _supportsAnalytics =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> init() async {
    if (!_supportsAnalytics) {
      return;
    }
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    } catch (_) {
      // Analytics is non-blocking for app startup.
    }
  }

  Future<void> logBackupExported({
    required int collections,
    required int collectionCards,
    required int cards,
  }) async {
    await _logEvent('local_backup_exported', <String, Object>{
      'collections': collections,
      'collection_cards': collectionCards,
      'cards': cards,
    });
  }

  Future<void> logBackupImported({
    required int collections,
    required int collectionCards,
    required int cards,
  }) async {
    await _logEvent('local_backup_imported', <String, Object>{
      'collections': collections,
      'collection_cards': collectionCards,
      'cards': cards,
    });
  }

  Future<void> _logEvent(String name, Map<String, Object> parameters) async {
    if (!_supportsAnalytics) {
      return;
    }
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (_) {
      // Ignore analytics failures.
    }
  }
}
