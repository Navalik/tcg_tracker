const admin = require("firebase-admin");
const {GoogleAuth} = require("google-auth-library");
const {setGlobalOptions} = require("firebase-functions/v2");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

setGlobalOptions({ maxInstances: 10 });

admin.initializeApp();

const playAuth = new GoogleAuth({
  scopes: ["https://www.googleapis.com/auth/androidpublisher"],
});
const supportedAndroidPackageNames = new Set(["com.navalik.bindervault"]);
const plusProductId = "bindervault_plus";

function isActiveSubscriptionState(state) {
  return state === "SUBSCRIPTION_STATE_ACTIVE" ||
    state === "SUBSCRIPTION_STATE_IN_GRACE_PERIOD" ||
    state === "SUBSCRIPTION_STATE_CANCELED";
}

function buildUpdatedClaims(existingClaims, plusActive) {
  const nextClaims = {...existingClaims};
  if (plusActive) {
    nextClaims.tier = "plus";
  } else {
    delete nextClaims.tier;
  }
  return nextClaims;
}

async function verifyAndroidSubscription(androidProof) {
  const packageName = typeof androidProof?.packageName === "string" ?
    androidProof.packageName.trim() :
    "";
  const productId = typeof androidProof?.productId === "string" ?
    androidProof.productId.trim() :
    "";
  const purchaseToken = typeof androidProof?.purchaseToken === "string" ?
    androidProof.purchaseToken.trim() :
    "";

  if (!supportedAndroidPackageNames.has(packageName)) {
    throw new HttpsError(
        "invalid-argument",
        "Unsupported Android package for entitlement verification.",
    );
  }
  if (productId !== plusProductId) {
    throw new HttpsError(
        "invalid-argument",
        "Unsupported product id for entitlement verification.",
    );
  }
  if (!purchaseToken) {
    throw new HttpsError(
        "invalid-argument",
        "Missing Android purchase token.",
    );
  }

  const client = await playAuth.getClient();
  const accessTokenResponse = await client.getAccessToken();
  const accessToken = typeof accessTokenResponse === "string" ?
    accessTokenResponse :
    accessTokenResponse?.token;
  if (!accessToken) {
    throw new HttpsError(
        "failed-precondition",
        "Could not acquire Google Play API access token.",
    );
  }

  const url = "https://androidpublisher.googleapis.com/androidpublisher/v3/" +
    `applications/${encodeURIComponent(packageName)}` +
    `/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
  });

  if (response.status === 404 || response.status === 410) {
    return {
      plusActive: false,
      source: "google_play",
      state: "NOT_FOUND",
    };
  }

  if (!response.ok) {
    const body = await response.text();
    logger.error("Google Play entitlement verification failed.", {
      status: response.status,
      body,
      packageName,
      productId,
    });
    throw new HttpsError(
        "internal",
        "Google Play entitlement verification request failed.",
    );
  }

  const payload = await response.json();
  const lineItems = Array.isArray(payload.lineItems) ? payload.lineItems : [];
  const matchingLineItem = lineItems.find((lineItem) =>
    (lineItem?.productId || "").trim() === productId,
  );
  const subscriptionState = (payload.subscriptionState || "").trim();
  return {
    plusActive: Boolean(matchingLineItem) &&
      isActiveSubscriptionState(subscriptionState),
    source: "google_play",
    state: subscriptionState,
  };
}

async function resolveEntitlement(context, data) {
  const expectedTier = typeof data?.expectedTier === "string" ?
    data.expectedTier.trim().toLowerCase() :
    "free";
  if (expectedTier !== "free" && expectedTier !== "plus") {
    throw new HttpsError(
        "invalid-argument",
        "expectedTier must be 'plus' or 'free'.",
    );
  }

  if (expectedTier === "free") {
    return {
      plusActive: false,
      source: "expected_free",
      state: "FREE",
    };
  }

  if (data?.platform !== "android") {
    throw new HttpsError(
        "failed-precondition",
        "Only Android entitlement verification is currently configured.",
    );
  }

  return verifyAndroidSubscription(data.android);
}

function buildResponseClaims(nextClaims, resolution) {
  return {
    tier: nextClaims.tier || "free",
    source: resolution.source,
    verificationState: resolution.state,
  };
}

exports.syncPlusEntitlement = onCall({region: "europe-west1"}, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError(
        "unauthenticated",
        "Authentication is required.",
    );
  }

  const {uid} = request.auth;
  const userRecord = await admin.auth().getUser(uid);
  const resolution = await resolveEntitlement(request, request.data);
  const nextClaims = buildUpdatedClaims(
      userRecord.customClaims || {},
      resolution.plusActive,
  );

  await admin.auth().setCustomUserClaims(uid, nextClaims);

  logger.info("Updated cloud backup entitlement claim.", {
    uid,
    ...buildResponseClaims(nextClaims, resolution),
  });

  return {
    uid,
    ...buildResponseClaims(nextClaims, resolution),
    tokenRefreshRequired: true,
  };
});
