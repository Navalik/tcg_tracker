(function () {
  "use strict";

  const title = document.getElementById("title");
  const subtitle = document.getElementById("subtitle");
  const status = document.getElementById("status");
  const form = document.getElementById("reset-form");
  const emailInput = document.getElementById("email");
  const passwordInput = document.getElementById("password");
  const confirmPasswordInput = document.getElementById("confirm-password");
  const submitButton = document.getElementById("submit-button");
  const successActions = document.getElementById("success-actions");

  const url = new URL(window.location.href);
  const mode = url.searchParams.get("mode") || "";
  const oobCode = url.searchParams.get("oobCode") || "";
  const linkApiKey = url.searchParams.get("apiKey") || "";
  const configuredApiKey =
    window.BINDERVAULT_FIREBASE_WEB_CONFIG &&
    window.BINDERVAULT_FIREBASE_WEB_CONFIG.apiKey
      ? String(window.BINDERVAULT_FIREBASE_WEB_CONFIG.apiKey).trim()
      : "";
  const apiKey =
    configuredApiKey && configuredApiKey !== "REPLACE_WITH_BROWSER_API_KEY"
      ? configuredApiKey
      : linkApiKey;
  const continueUrl = url.searchParams.get("continueUrl") || "";

  function showStatus(kind, message) {
    status.className = "status visible " + kind;
    status.textContent = message;
  }

  function setBusy(isBusy) {
    submitButton.disabled = isBusy;
    submitButton.textContent = isBusy ? "Saving…" : "Save new password";
  }

  function hasSupportedCharacters(value) {
    return /^[\x21-\x7E]+$/.test(value);
  }

  function hasUppercase(value) {
    return /[A-Z]/.test(value);
  }

  function hasDigit(value) {
    return /\d/.test(value);
  }

  function hasAsciiSymbol(value) {
    return /[!@#$%^&*()_\-+=\[\]{}|\\:;"'<>,.?/~`]/.test(value);
  }

  function validatePassword(value) {
    if (!value) {
      return "Enter a new password.";
    }
    if (!hasSupportedCharacters(value)) {
      return "Use only standard keyboard characters.";
    }
    if (value.length < 8) {
      return "Password must be at least 8 characters.";
    }
    if (!hasUppercase(value)) {
      return "Add at least 1 uppercase letter.";
    }
    if (!hasDigit(value)) {
      return "Add at least 1 number.";
    }
    if (!hasAsciiSymbol(value)) {
      return "Add at least 1 symbol.";
    }
    return "";
  }

  function mapIdentityError(message) {
    const normalized = String(message || "").toUpperCase();
    if (normalized.includes("EXPIRED_OOB_CODE")) {
      return "This action link has expired. Request a new email and try again.";
    }
    if (normalized.includes("INVALID_OOB_CODE")) {
      return "This action link is invalid or has already been used.";
    }
    if (normalized.includes("WEAK_PASSWORD")) {
      return "Firebase rejected the password as too weak. Try a stronger password.";
    }
    if (normalized.includes("USER_DISABLED")) {
      return "This account is disabled.";
    }
    if (normalized.includes("OPERATION_NOT_ALLOWED")) {
      return "This Firebase action is not enabled for the project.";
    }
    if (normalized.includes("MISSING_BROWSER_API_KEY")) {
      return "This page is missing the Firebase Browser API key configuration.";
    }
    if (normalized.includes("NETWORK_REQUEST_FAILED")) {
      return "Network error while contacting Firebase. Try again.";
    }
    if (normalized.includes("EMAIL_NOT_FOUND")) {
      return "This account no longer exists.";
    }
    return "Unable to complete this account action. Request a new email and try again. (" + normalized + ")";
  }

  async function postJson(endpoint, body) {
    if (!apiKey) {
      throw new Error("MISSING_BROWSER_API_KEY");
    }
    const response = await fetch(
      "https://identitytoolkit.googleapis.com/v1/" +
        endpoint +
        "?key=" +
        encodeURIComponent(apiKey),
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      },
    );

    const payload = await response.json().catch(function () {
      return {};
    });

    if (!response.ok) {
      const message =
        payload && payload.error && payload.error.message
          ? payload.error.message
          : "UNKNOWN_ERROR";
      throw new Error(message);
    }

    return payload;
  }

  async function verifyPasswordResetCode() {
    return postJson("accounts:resetPassword", { oobCode: oobCode });
  }

  async function confirmPasswordReset(newPassword) {
    return postJson("accounts:resetPassword", {
      oobCode: oobCode,
      newPassword: newPassword,
    });
  }

  async function checkActionCode() {
    return postJson("accounts:resetPassword", { oobCode: oobCode });
  }

  async function applyActionCode() {
    return postJson("accounts:update", { oobCode: oobCode });
  }

  function maybeShowContinueHint() {
    if (!continueUrl) {
      return;
    }
    const separator = status.textContent ? " " : "";
    status.textContent += separator + "You can return to the app after this step.";
  }

  async function handleResetPassword() {
    title.textContent = "Reset your password";
    subtitle.textContent = "Checking your reset link…";

    try {
      const payload = await verifyPasswordResetCode();
      if (payload.requestType !== "PASSWORD_RESET" || !payload.email) {
        throw new Error("INVALID_OOB_CODE");
      }

      emailInput.value = payload.email;
      subtitle.textContent = "Choose a new password for your BinderVault account.";
      showStatus("info", "Your reset link is valid. Enter your new password below.");
      maybeShowContinueHint();
      form.hidden = false;
    } catch (error) {
      subtitle.textContent = "This reset link is no longer usable.";
      showStatus("error", mapIdentityError(error && error.message));
    }
  }

  async function handleVerifyEmail() {
    title.textContent = "Verify your email";
    subtitle.textContent = "Checking your verification link…";

    try {
      await applyActionCode();
      subtitle.textContent = "Your email has been verified.";
      showStatus("success", "Email verified successfully. You can return to the app and continue.");
      maybeShowContinueHint();
      successActions.hidden = false;
    } catch (error) {
      subtitle.textContent = "This verification link is no longer usable.";
      showStatus("error", mapIdentityError(error && error.message));
    }
  }

  async function handleVerifyAndChangeEmail() {
    title.textContent = "Change your email";
    subtitle.textContent = "Checking your email change linkâ€¦";

    try {
      await applyActionCode();
      subtitle.textContent = "Your email has been updated.";
      showStatus(
        "success",
        "Email changed successfully. You can return to the app and sign in with the new email address.",
      );
      maybeShowContinueHint();
      successActions.hidden = false;
    } catch (error) {
      subtitle.textContent = "This email change link is no longer usable.";
      showStatus("error", mapIdentityError(error && error.message));
    }
  }

  async function handleRecoverEmail() {
    title.textContent = "Recover your email";
    subtitle.textContent = "Checking your recovery link…";

    try {
      const payload = await checkActionCode();
      await applyActionCode();
      const restoredEmail =
        payload && payload.data && payload.data.email ? payload.data.email : "";
      subtitle.textContent = "Your email change has been reverted.";
      showStatus(
        "success",
        restoredEmail
          ? "Your previous email " + restoredEmail + " has been restored."
          : "Your previous email has been restored.",
      );
      successActions.hidden = false;
    } catch (error) {
      subtitle.textContent = "This recovery link is no longer usable.";
      showStatus("error", mapIdentityError(error && error.message));
    }
  }

  form.addEventListener("submit", async function (event) {
    event.preventDefault();

    const password = passwordInput.value;
    const confirmPassword = confirmPasswordInput.value;
    const passwordError = validatePassword(password);

    if (passwordError) {
      showStatus("error", passwordError);
      passwordInput.focus();
      return;
    }

    if (confirmPassword !== password) {
      showStatus("error", "Passwords do not match.");
      confirmPasswordInput.focus();
      return;
    }

    setBusy(true);
    showStatus("info", "Saving your new password…");

    try {
      await confirmPasswordReset(password);
      subtitle.textContent = "Your password was updated successfully.";
      showStatus("success", "Password updated. You can now sign in in the app with your new password.");
      form.hidden = true;
      successActions.hidden = false;
    } catch (error) {
      showStatus("error", mapIdentityError(error && error.message));
    } finally {
      setBusy(false);
    }
  });

  async function run() {
    if (!mode || !oobCode) {
      subtitle.textContent = "This page can only open valid Firebase account action links.";
      showStatus(
        "error",
        "Missing or invalid action parameters. Request a new email and try again.",
      );
      successActions.hidden = false;
      return;
    }

    switch (mode) {
      case "resetPassword":
        await handleResetPassword();
        break;
      case "verifyEmail":
        await handleVerifyEmail();
        break;
      case "verifyAndChangeEmail":
        await handleVerifyAndChangeEmail();
        break;
      case "recoverEmail":
        await handleRecoverEmail();
        break;
      default:
        subtitle.textContent = "This page does not support the requested Firebase action.";
        showStatus(
          "error",
          "Unsupported action mode (" + mode + "). Request a new email and try again.",
        );
        successActions.hidden = false;
        break;
    }
  }

  run();
})();
