import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EntitlementSyncResult {
  const EntitlementSyncResult({
    required this.claimTier,
    required this.synced,
    required this.source,
  });

  final String claimTier;
  final bool synced;
  final String? source;
}

class EntitlementSyncService {
  EntitlementSyncService._();

  static final EntitlementSyncService instance = EntitlementSyncService._();

  Future<String> loadClaimTier({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return 'free';
    }
    final token = await user.getIdTokenResult(forceRefresh);
    final rawTier = token.claims?['tier']?.toString().trim().toLowerCase();
    return rawTier == 'plus' ? 'plus' : 'free';
  }

  Future<EntitlementSyncResult> syncCurrentUserTier({
    required bool localPlusActive,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return const EntitlementSyncResult(
        claimTier: 'free',
        synced: false,
        source: null,
      );
    }

    if (!(Platform.isAndroid || Platform.isIOS)) {
      final claimTier = await loadClaimTier();
      return EntitlementSyncResult(
        claimTier: claimTier,
        synced: false,
        source: 'unsupported_platform',
      );
    }

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('syncPlusEntitlement');
      final response = await callable.call(<String, Object?>{
        'expectedTier': localPlusActive ? 'plus' : 'free',
      });
      final data = response.data;
      String? source;
      if (data is Map) {
        source = data['source']?.toString().trim();
      }
      await user.getIdToken(true);
      final refreshedTier = await loadClaimTier(forceRefresh: true);
      return EntitlementSyncResult(
        claimTier: refreshedTier,
        synced: true,
        source: source,
      );
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'failed-precondition' ||
          error.code == 'unimplemented' ||
          error.code == 'not-found') {
        final claimTier = await loadClaimTier();
        return EntitlementSyncResult(
          claimTier: claimTier,
          synced: false,
          source: error.code,
        );
      }
      rethrow;
    }
  }
}
