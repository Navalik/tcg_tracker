import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AndroidEntitlementProof {
  const AndroidEntitlementProof({
    required this.packageName,
    required this.productId,
    required this.purchaseToken,
  });

  final String packageName;
  final String productId;
  final String purchaseToken;
}

class EntitlementSyncResult {
  const EntitlementSyncResult({
    required this.claimTier,
    required this.synced,
    required this.source,
    required this.verificationState,
  });

  final String claimTier;
  final bool synced;
  final String? source;
  final String? verificationState;
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
    AndroidEntitlementProof? androidProof,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return const EntitlementSyncResult(
        claimTier: 'free',
        synced: false,
        source: null,
        verificationState: null,
      );
    }

    if (!(Platform.isAndroid || Platform.isIOS)) {
      final claimTier = await loadClaimTier();
      return EntitlementSyncResult(
        claimTier: claimTier,
        synced: false,
        source: 'unsupported_platform',
        verificationState: null,
      );
    }

    try {
      final payload = <String, Object?>{
        'expectedTier': localPlusActive ? 'plus' : 'free',
      };
      if (localPlusActive && androidProof != null) {
        payload['platform'] = 'android';
        payload['android'] = <String, Object?>{
          'packageName': androidProof.packageName,
          'productId': androidProof.productId,
          'purchaseToken': androidProof.purchaseToken,
        };
      }
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('syncPlusEntitlement');
      final response = await callable.call(payload);
      final data = response.data;
      String? source;
      String? verificationState;
      if (data is Map) {
        source = data['source']?.toString().trim();
        verificationState = data['verificationState']?.toString().trim();
      }
      await user.getIdToken(true);
      final refreshedTier = await loadClaimTier(forceRefresh: true);
      return EntitlementSyncResult(
        claimTier: refreshedTier,
        synced: true,
        source: source,
        verificationState: verificationState,
      );
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'failed-precondition' ||
          error.code == 'unimplemented' ||
          error.code == 'not-found' ||
          error.code == 'invalid-argument') {
        final claimTier = await loadClaimTier();
        return EntitlementSyncResult(
          claimTier: claimTier,
          synced: false,
          source: error.code,
          verificationState: null,
        );
      }
      rethrow;
    }
  }
}
