// ignore_for_file: invalid_use_of_protected_member, use_build_context_synchronously

part of 'package:tcg_tracker/main.dart';

extension _SettingsProfileSection on _SettingsPageState {
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

  Future<void> _promptGuestSignIn() async {
    if (!_supportsFirebaseAuth) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final shouldSignIn = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.authSignInWithGoogle),
          content: Text(l10n.authWelcomeSubtitle),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.login_rounded),
              label: Text(l10n.authSignInWithGoogle),
            ),
          ],
        );
      },
    );
    if (shouldSignIn != true) {
      return;
    }
    await _signInWithGoogleFromSettings();
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
        : (isGuest ? l10n.guestLabel : l10n.googleUserLabel);
    final subtitle = hasEmail
        ? email
        : (isGuest ? l10n.localProfileLabel : l10n.signedInWithGoogle);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: isGuest ? _promptGuestSignIn : null,
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
      trailing: isGuest
          ? null
          : TextButton(onPressed: _signOut, child: Text(l10n.signOut)),
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
