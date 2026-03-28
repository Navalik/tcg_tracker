# Cloud Backup Firebase Setup

This document defines the backend contract for BinderVault cloud backup.

## Goal

Allow only authenticated `Plus` users to read and write their own collection snapshots in Firebase Storage.

Current app-side implementation already uploads to:

- `users/{uid}/cloud-backup/latest.json.gz`

The app checks auth and local premium state before showing the feature, but Firebase Storage must enforce access independently.

## Storage Rules

This repo now includes [`storage.rules`](/c:/Users/Naval/Documents/TGC/tcg_tracker/storage.rules).

The rules require:

- authenticated user
- path owner match: `request.auth.uid == uid`
- custom auth claim: `request.auth.token.tier == 'plus'`

Without that claim, Storage access is denied even if the app UI says the user is premium.

## Required Backend Flow

Firebase does not know Play Billing / App Store entitlement by itself.

Recommended flow:

1. User signs in with Firebase Auth.
2. App sends purchase proof or a refresh request to your backend.
3. Backend verifies subscription status with the store.
4. Backend writes Firebase custom claims on that UID:
   - `tier: "plus"` when active
   - remove or downgrade claim when inactive
5. App refreshes the Firebase ID token.
6. Storage Rules start allowing cloud backup access.

## Recommended Claim Shape

Use the smallest stable claim set possible:

```json
{
  "tier": "plus"
}
```

Optional extra claims if you need diagnostics:

```json
{
  "tier": "plus",
  "entitlement_source": "play",
  "entitlement_updated_at": 1774713600000
}
```

Keep the authoritative gate as `tier == "plus"`.

## App Refresh Requirement

After backend entitlement changes, the app must refresh the Firebase token:

```dart
await FirebaseAuth.instance.currentUser?.getIdToken(true);
```

Until that happens, Storage Rules may still see the previous claim set.

## Suggested Backend Endpoints / Functions

The repo does not currently contain Firebase Functions code. A practical first backend is:

- callable or HTTPS endpoint: `syncPlusEntitlement`

Responsibilities:

- authenticate Firebase user
- inspect latest Play/App Store entitlement using your server-side credentials
- set or remove custom claims through Firebase Admin SDK
- return the resolved tier

Pseudo-shape:

```ts
// Pseudocode only
const uid = verifiedFirebaseUser.uid;
const plusActive = await verifyStoreEntitlement(uid, purchasePayload);

if (plusActive) {
  await admin.auth().setCustomUserClaims(uid, { tier: 'plus' });
} else {
  await admin.auth().setCustomUserClaims(uid, {});
}
```

## Deployment

After configuring the Firebase project locally:

```powershell
firebase deploy --only storage
```

If you also add Functions later:

```powershell
firebase deploy --only functions,storage
```

## Testing Checklist

1. Sign in with a non-anonymous Firebase user without `tier=plus`.
2. Confirm cloud backup upload is denied by Storage.
3. Assign custom claim `tier=plus`.
4. Force token refresh in the app.
5. Confirm upload succeeds only for:
   - correct UID path
   - authenticated plus user
6. Confirm one user cannot access another user’s backup path.

## Notes

- Current app-side premium detection is still local/store-driven.
- That is fine for UX, but not sufficient for backend authorization.
- The backend custom claim is the authoritative gate for cloud backup.
