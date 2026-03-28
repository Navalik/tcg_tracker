import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import 'app_settings.dart';
import 'cloud_backup_service.dart';
import 'cloud_backup_signals.dart';

class CloudBackupScheduler with WidgetsBindingObserver {
  CloudBackupScheduler._();

  static final CloudBackupScheduler instance = CloudBackupScheduler._();
  static const Duration _debounceDelay = Duration(seconds: 90);

  StreamSubscription<String>? _changeSubscription;
  StreamSubscription<User?>? _authSubscription;
  Timer? _debounceTimer;
  bool _initialized = false;
  bool _uploading = false;
  bool _pending = false;
  String _lastReason = 'collections_changed';

  void init() {
    if (_initialized) {
      return;
    }
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    _changeSubscription = CloudBackupSignals.instance.collectionsChanged.listen(
      _handleCollectionsChanged,
    );
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null || user.isAnonymous) {
        _debounceTimer?.cancel();
      }
    });
  }

  Future<void> dispose() async {
    _debounceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    await _changeSubscription?.cancel();
    await _authSubscription?.cancel();
    _changeSubscription = null;
    _authSubscription = null;
    _initialized = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_flushPendingUpload(force: true));
    }
  }

  Future<void> triggerNow({String reason = 'manual'}) async {
    _lastReason = reason.trim().isEmpty ? 'manual' : reason.trim();
    _pending = true;
    await _flushPendingUpload(force: true);
  }

  void _handleCollectionsChanged(String reason) {
    _lastReason = reason.trim().isEmpty ? 'collections_changed' : reason.trim();
    _pending = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () {
      unawaited(_flushPendingUpload());
    });
  }

  Future<void> _flushPendingUpload({bool force = false}) async {
    if (_uploading || !_pending) {
      return;
    }
    final enabled = await AppSettings.loadCloudBackupAutoEnabled();
    if (!enabled && !force) {
      return;
    }
    _uploading = true;
    try {
      await CloudBackupService.instance.uploadLatestBackup(
        automatic: true,
        force: force,
        reason: _lastReason,
      );
      _pending = false;
    } catch (error) {
      await CloudBackupService.instance.saveLastError(error);
    } finally {
      _uploading = false;
      if (_pending && force) {
        unawaited(_flushPendingUpload());
      }
    }
  }
}
