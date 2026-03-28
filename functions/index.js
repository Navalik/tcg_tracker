const admin = require("firebase-admin");
const {setGlobalOptions} = require("firebase-functions/v2");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

setGlobalOptions({ maxInstances: 10 });

admin.initializeApp();

function buildUpdatedClaims(existingClaims, plusActive) {
  const nextClaims = {...existingClaims};
  if (plusActive) {
    nextClaims.tier = "plus";
  } else {
    delete nextClaims.tier;
  }
  return nextClaims;
}

async function resolveEntitlement(context, data) {
  const manualSyncEnabled =
    process.env.BINDERVAULT_ENABLE_MANUAL_CLAIM_SYNC === "true";
  const rawRequestedTier = typeof data?.expectedTier === "string" ?
    data.expectedTier :
    data?.debugTier;
  const requestedTier = typeof rawRequestedTier === "string" ?
    rawRequestedTier.trim().toLowerCase() :
    "";

  if (!manualSyncEnabled) {
    throw new HttpsError(
        "failed-precondition",
        "Entitlement verifier not configured. " +
        "Set up store verification before enabling syncPlusEntitlement.",
    );
  }

  if (requestedTier !== "plus" && requestedTier !== "free") {
    throw new HttpsError(
        "invalid-argument",
        "When manual claim sync is enabled, expectedTier must be 'plus' or 'free'.",
    );
  }

  logger.warn("Using manual claim sync override.", {
    uid: context.auth.uid,
    requestedTier,
  });
  return {
    plusActive: requestedTier === "plus",
    source: "manual_override",
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
    tier: nextClaims.tier || "free",
    source: resolution.source,
  });

  return {
    uid,
    tier: nextClaims.tier || "free",
    source: resolution.source,
    tokenRefreshRequired: true,
  };
});
