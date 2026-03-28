import 'dart:async';

class CloudBackupSignals {
  CloudBackupSignals._();

  static final CloudBackupSignals instance = CloudBackupSignals._();

  final StreamController<String> _collectionsChangedController =
      StreamController<String>.broadcast();

  Stream<String> get collectionsChanged => _collectionsChangedController.stream;

  void markCollectionsChanged(String reason) {
    final normalized = reason.trim();
    if (normalized.isEmpty || _collectionsChangedController.isClosed) {
      return;
    }
    _collectionsChangedController.add(normalized);
  }

  Future<void> dispose() async {
    await _collectionsChangedController.close();
  }
}
