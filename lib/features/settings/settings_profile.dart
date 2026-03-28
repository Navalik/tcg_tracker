// ignore_for_file: invalid_use_of_protected_member, use_build_context_synchronously

part of 'package:tcg_tracker/main.dart';

extension _SettingsProfileSection on _SettingsPageState {
  Future<void> _openAccountSettings(User user) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _AccountSettingsPage(hostState: this)),
    );
  }

  Future<void> _changeEmailFromSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    final currentEmail = user?.email?.trim();
    if (!_canChangeEmail(user) ||
        currentEmail == null ||
        currentEmail.isEmpty) {
      return;
    }
    final request = await _promptForEmailChange(
      context,
      currentEmail: currentEmail,
    );
    if (request == null) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    try {
      final isFresh = await _ensureFreshAuthenticatedUser(
        reason: 'change_email_start',
      );
      if (!isFresh) {
        return;
      }
      final currentUser = FirebaseAuth.instance.currentUser;
      final email = currentUser?.email?.trim();
      if (currentUser == null ||
          currentUser.isAnonymous ||
          email == null ||
          email.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authChangeEmailUnavailable)),
        );
        return;
      }
      final credential = EmailAuthProvider.credential(
        email: email,
        password: request.currentPassword,
      );
      await currentUser.reauthenticateWithCredential(credential);
      await currentUser.verifyBeforeUpdateEmail(
        request.newEmail,
        _authActionCodeSettings(),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.authChangeEmailVerificationSent)),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      final message = switch (error.code) {
        'wrong-password' ||
        'invalid-credential' ||
        'invalid-login-credentials' => l10n.authCurrentPasswordIncorrect,
        'invalid-email' => l10n.authInvalidEmailAddress,
        'email-already-in-use' => l10n.authEmailAlreadyInUse,
        'requires-recent-login' => l10n.authRequiresRecentLogin,
        'network-request-failed' => l10n.authNetworkErrorDuringSignIn,
        _ => l10n.authChangeEmailFailedWithCode(error.code),
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.authChangeEmailFailedTryAgain)),
      );
    }
  }

  Future<void> _changePasswordFromSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (!_canChangePassword(user)) {
      return;
    }
    final request = await _promptForPasswordChange(context);
    if (request == null) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    try {
      final isFresh = await _ensureFreshAuthenticatedUser(
        reason: 'change_password_start',
      );
      if (!isFresh) {
        return;
      }
      final currentUser = FirebaseAuth.instance.currentUser;
      final email = currentUser?.email?.trim();
      if (currentUser == null ||
          currentUser.isAnonymous ||
          email == null ||
          email.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authChangePasswordUnavailable)),
        );
        return;
      }
      final credential = EmailAuthProvider.credential(
        email: email,
        password: request.currentPassword,
      );
      await currentUser.reauthenticateWithCredential(credential);
      await currentUser.updatePassword(request.newPassword);
      await currentUser.getIdToken(true);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.authPasswordChangedSuccess)),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      final message = switch (error.code) {
        'wrong-password' ||
        'invalid-credential' ||
        'invalid-login-credentials' => l10n.authCurrentPasswordIncorrect,
        'weak-password' => l10n.authWeakPassword,
        'requires-recent-login' => l10n.authRequiresRecentLogin,
        'network-request-failed' => l10n.authNetworkErrorDuringSignIn,
        _ => l10n.authChangePasswordFailedWithCode(error.code),
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.authChangePasswordFailedTryAgain)),
      );
    }
  }

  Future<void> _reauthenticateGoogleUserForDelete(User user) async {
    await _ensureGoogleSignInInitialized();
    final googleUser = await _googleSignIn.authenticate();
    final idToken = googleUser.authentication.idToken?.trim();
    if (idToken == null || idToken.isEmpty) {
      throw const FormatException('google_id_token_missing');
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await user.reauthenticateWithCredential(credential);
  }

  Future<bool> _deleteAccountFromSettings({String? password}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return false;
    }
    final rootContext = _rootNavigatorKey.currentContext;
    if (rootContext == null) {
      return false;
    }
    final l10n = AppLocalizations.of(rootContext)!;
    try {
      final isFresh = await _ensureFreshAuthenticatedUser(
        reason: 'delete_account_start',
      );
      if (!isFresh) {
        return false;
      }
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.isAnonymous) {
        _rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(l10n.authDeleteAccountUnavailable)),
        );
        return false;
      }
      if (_canChangePassword(currentUser)) {
        final email = currentUser.email?.trim();
        if (email == null || email.isEmpty || password == null) {
          _rootScaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(content: Text(l10n.authDeleteAccountUnavailable)),
          );
          return false;
        }
        final credential = EmailAuthProvider.credential(
          email: email,
          password: password,
        );
        await currentUser.reauthenticateWithCredential(credential);
      } else if (_userHasProvider(currentUser, 'google.com')) {
        await _reauthenticateGoogleUserForDelete(currentUser);
      } else {
        _rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(l10n.authDeleteAccountUnavailable)),
        );
        return false;
      }
      await currentUser.delete();
      return true;
    } on FirebaseAuthException catch (error) {
      final message = switch (error.code) {
        'wrong-password' ||
        'invalid-credential' ||
        'invalid-login-credentials' => l10n.authCurrentPasswordIncorrect,
        'requires-recent-login' => l10n.authRequiresRecentLogin,
        'network-request-failed' => l10n.authNetworkErrorDuringSignIn,
        _ => l10n.authDeleteAccountFailedWithCode(error.code),
      };
      _rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(message)),
      );
      return false;
    } catch (error) {
      final message = _userHasProvider(user, 'google.com')
          ? _googleSignInErrorMessage(error)
          : l10n.authDeleteAccountFailedTryAgain;
      _rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(message)),
      );
      return false;
    }
  }

  Future<void> _signOut() async {
    try {
      await _ensureGoogleSignInInitialized();
      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();
      await _signInAnonymouslyIfNeeded();
    } catch (_) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.unableToSignOutTryAgain)));
    }
  }

  Future<void> _signInWithGoogleFromSettings() async {
    try {
      await _signInToFirebaseWithGoogle();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_googleSignInErrorMessage(error))));
    }
  }

  Future<void> _authenticateWithEmailFromSettings() async {
    final request = await _promptForEmailPasswordAuth(context);
    if (request == null) {
      return;
    }
    try {
      final result = await _authenticateWithEmailPassword(
        email: request.email,
        password: request.password,
        createAccount: request.createAccount,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_emailPasswordSuccessMessage(context, result))),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_emailPasswordErrorMessage(context, error))),
      );
    }
  }

  Future<void> _promptGuestSignIn() async {
    if (!_supportsFirebaseAuth) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final action = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.authWelcomeTitle),
          content: Text(l10n.authWelcomeSubtitle),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop('email'),
              icon: const Icon(Icons.mark_email_read_outlined),
              label: Text(l10n.authContinueWithEmail),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop('google'),
              icon: const Icon(Icons.login_rounded),
              label: Text(l10n.authSignInWithGoogle),
            ),
          ],
        );
      },
    );
    if (action == 'google') {
      await _signInWithGoogleFromSettings();
      return;
    }
    if (action == 'email') {
      await _authenticateWithEmailFromSettings();
      return;
    }
  }

  Widget _buildProfileTile(User? user) {
    final displayName = user?.displayName?.trim();
    final email = user?.email?.trim();
    final hasDisplayName = displayName != null && displayName.isNotEmpty;
    final hasEmail = email != null && email.isNotEmpty;
    final isGuest = user == null || user.isAnonymous;
    final l10n = AppLocalizations.of(context)!;
    final title = hasDisplayName
        ? displayName
        : (hasEmail
              ? email
              : (isGuest ? l10n.guestLabel : l10n.googleUserLabel));
    final subtitle = isGuest
        ? l10n.localProfileLabel
        : _linkedProviderDescription(l10n, user);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: isGuest
          ? _promptGuestSignIn
          : () => _openAccountSettings(user),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: const Color(0xFF2D241B),
        foregroundImage: (user?.photoURL?.isNotEmpty == true)
            ? NetworkImage(user!.photoURL!)
            : null,
        child: (user?.photoURL?.isNotEmpty == true)
            ? null
            : const Icon(Icons.person, color: Color(0xFFEFE7D8)),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: isGuest ? null : const Icon(Icons.chevron_right_rounded),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    if (!_supportsFirebaseAuth) {
      return _buildProfileTile(null);
    }
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) => _buildProfileTile(snapshot.data),
    );
  }
}

class _AccountSettingsPage extends StatefulWidget {
  const _AccountSettingsPage({required this.hostState});

  final _SettingsPageState hostState;

  @override
  State<_AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<_AccountSettingsPage>
    with WidgetsBindingObserver {
  bool _isRefreshingVerification = false;
  bool _isSendingVerificationEmail = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshVerificationStatus());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshVerificationStatus());
    }
  }

  Future<void> _refreshVerificationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (_isRefreshingVerification ||
        user == null ||
        user.isAnonymous ||
        !_canChangeEmail(user)) {
      return;
    }
    setState(() {
      _isRefreshingVerification = true;
    });
    try {
      await user.reload();
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingVerification = false;
        });
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (_isSendingVerificationEmail ||
        user == null ||
        user.isAnonymous ||
        !_canChangeEmail(user) ||
        user.emailVerified) {
      return;
    }
    setState(() {
      _isSendingVerificationEmail = true;
    });
    try {
      await FirebaseAuth.instance.setLanguageCode(
        Localizations.localeOf(context).languageCode,
      );
      final sent = await _sendEmailVerificationIfPossible(user);
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      final message = sent
          ? l10n.authVerificationEmailResent
          : l10n.authVerificationEmailResendFailed;
      _rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingVerificationEmail = false;
        });
      }
    }
  }

  Future<void> _changeEmail() async {
    await widget.hostState._changeEmailFromSettings();
    if (mounted) {
      unawaited(_refreshVerificationStatus());
    }
  }

  Future<void> _changePassword() async {
    await widget.hostState._changePasswordFromSettings();
  }

  Future<void> _signOut() async {
    await widget.hostState._signOut();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return;
    }
    final confirmed = await _confirmDeleteAccount(user);
    if (!confirmed || !mounted) {
      return;
    }
    String? password;
    if (_canChangePassword(user)) {
      password = await _promptForDeleteAccountPassword();
      if (password == null || !mounted) {
        return;
      }
    }
    final deleted = await widget.hostState._deleteAccountFromSettings(
      password: password,
    );
    if (!deleted) {
      return;
    }
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    _rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(l10n.authDeleteAccountSuccess)),
    );
  }

  Future<bool> _confirmDeleteAccount(User user) async {
    final l10n = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.authDeleteAccountTitle),
            content: Text(
              _canChangePassword(user)
                  ? l10n.authDeleteAccountBodyPassword
                  : l10n.authDeleteAccountBodyProvider,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB44336),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.authDeleteAccountAction),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _promptForDeleteAccountPassword() async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _DeleteAccountPasswordDialog(),
    );
    final password = result?.trim() ?? '';
    if (password.isEmpty) {
      return null;
    }
    return password;
  }

  Widget _buildHeader(BuildContext context, User user) {
    final l10n = AppLocalizations.of(context)!;
    final displayName = user.displayName?.trim();
    final email = user.email?.trim();
    final title = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : ((email != null && email.isNotEmpty) ? email : l10n.googleUserLabel);
    final canVerifyEmail = _canChangeEmail(user);
    final emailVerified = user.emailVerified;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171411).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF3A2D20)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF2D241B),
            foregroundImage: (user.photoURL?.isNotEmpty == true)
                ? NetworkImage(user.photoURL!)
                : null,
            child: (user.photoURL?.isNotEmpty == true)
                ? null
                : const Icon(Icons.person, color: Color(0xFFEFE7D8)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  _linkedProviderDescription(l10n, user),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFBFAE95)),
                ),
                if (canVerifyEmail) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: emailVerified
                          ? const Color(0xFF223827)
                          : const Color(0xFF3A2A17),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: emailVerified
                            ? const Color(0xFF335B3A)
                            : const Color(0xFF7D6231),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          emailVerified
                              ? Icons.verified_outlined
                              : Icons.mark_email_unread_outlined,
                          size: 16,
                          color: emailVerified
                              ? const Color(0xFF9FD7AA)
                              : const Color(0xFFE9C46A),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            emailVerified
                                ? l10n.authEmailVerifiedStatus
                                : l10n.authEmailNotVerifiedStatus,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: emailVerified
                                      ? const Color(0xFFD9F0DD)
                                      : const Color(0xFFF3D99A),
                                ),
                          ),
                        ),
                        if (_isRefreshingVerification) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(List<Widget> tiles) {
    final children = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) {
        children.add(const Divider(height: 1, indent: 16, endIndent: 16));
      }
      children.add(tiles[i]);
    }
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF171411).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF3A2D20)),
      ),
      child: Column(children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.profile)),
      body: Stack(
        children: [
          const _AppBackground(),
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            initialData: FirebaseAuth.instance.currentUser,
            builder: (context, snapshot) {
              final user = snapshot.data;
              if (user == null || user.isAnonymous) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.authAccountPageSignedOut,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final tiles = <Widget>[
                if (_canChangeEmail(user) && !user.emailVerified)
                  ListTile(
                    leading: const Icon(Icons.mark_email_read_outlined),
                    title: Text(l10n.authResendVerificationEmailTitle),
                    subtitle: Text(l10n.authResendVerificationEmailSubtitle),
                    trailing: _isSendingVerificationEmail
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: _isSendingVerificationEmail
                        ? null
                        : _resendVerificationEmail,
                  ),
                if (_canChangeEmail(user))
                  ListTile(
                    leading: const Icon(Icons.alternate_email_rounded),
                    title: Text(l10n.authChangeEmailTitle),
                    subtitle: Text(l10n.authChangeEmailTileSubtitle),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _changeEmail,
                  ),
                if (_canChangePassword(user))
                  ListTile(
                    leading: const Icon(Icons.password_rounded),
                    title: Text(l10n.authChangePasswordTitle),
                    subtitle: Text(l10n.authChangePasswordTileSubtitle),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _changePassword,
                  ),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: Text(l10n.signOut),
                  subtitle: Text(l10n.authSignOutSubtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _signOut,
                ),
              ];
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  24 + MediaQuery.of(context).padding.bottom + 16,
                ),
                children: [
                  _buildHeader(context, user),
                  const SizedBox(height: 14),
                  _buildActionCard(tiles),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171411).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF5B2622)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.authDeleteAccountTitle,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: const Color(0xFFE08A82)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.authDeleteAccountTileSubtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFFCCB7A8)),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE08A82),
                              side: const BorderSide(
                                color: Color(0xFF8E4D46),
                              ),
                            ),
                            onPressed: _deleteAccount,
                            icon: const Icon(Icons.delete_forever_rounded),
                            label: Text(l10n.authDeleteAccountAction),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountPasswordDialog extends StatefulWidget {
  const _DeleteAccountPasswordDialog();

  @override
  State<_DeleteAccountPasswordDialog> createState() =>
      _DeleteAccountPasswordDialogState();
}

class _DeleteAccountPasswordDialogState
    extends State<_DeleteAccountPasswordDialog> {
  late final TextEditingController _passwordController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _hasAttemptedSubmit = false;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  String? _passwordErrorText(String value, AppLocalizations l10n) {
    if (!_hasAttemptedSubmit && value.isEmpty) {
      return null;
    }
    if (value.isEmpty) {
      return l10n.authCurrentPasswordRequired;
    }
    return null;
  }

  void _submit() {
    setState(() {
      _hasAttemptedSubmit = true;
    });
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(_passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.authDeleteAccountPasswordTitle),
      content: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SizedBox(
          width: double.maxFinite,
          child: TextFormField(
            controller: _passwordController,
            autofocus: true,
            obscureText: _obscurePassword,
            keyboardType: TextInputType.visiblePassword,
            enableSuggestions: false,
            autocorrect: false,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            enableInteractiveSelection: true,
            showCursor: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.authCurrentPasswordLabel,
              hintText: l10n.authCurrentPasswordHint,
              suffixIcon: IconButton(
                tooltip: _obscurePassword
                    ? l10n.authShowPassword
                    : l10n.authHidePassword,
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility,
                ),
              ),
            ),
            validator: (value) => _passwordErrorText(value ?? '', l10n),
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB44336),
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: Text(l10n.authDeleteAccountAction),
        ),
      ],
    );
  }
}
