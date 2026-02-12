part of 'package:tcg_tracker/main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loading = true;
  String? _bulkType;
  String _appVersion = '0.4.2';

  bool get _supportsFirebaseAuth => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final bulkType = await AppSettings.loadBulkType();
    var appVersion = _appVersion;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.version;
    } catch (_) {
      appVersion = _appVersion;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _bulkType = bulkType;
      _appVersion = appVersion;
      _loading = false;
    });
  }

  Future<void> _changeBulkType() async {
    final selected = await _showBulkTypePicker(
      context,
      allowCancel: true,
      selectedType: _bulkType,
    );
    if (selected == null || selected == _bulkType) {
      return;
    }
    if (!mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.changeDatabaseTitle),
          content: Text(l10n.changeDatabaseBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.updatingDatabaseTitle),
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l10n.preparingDatabaseBody),
              ),
            ],
          ),
        );
      },
    );

    try {
      await AppSettings.saveBulkType(selected);
      await ScryfallBulkChecker().resetState();
      await ScryfallDatabase.instance.hardReset();
      await _deleteBulkFiles();
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _bulkType = selected;
    });
    showAppSnackBar(
      context,
      AppLocalizations.of(context)!.databaseChangedGoHome,
    );
  }

  Future<void> _deleteBulkFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final legacyPath = '${directory.path}/scryfall_all_cards.json';
    final legacyTempPath = '$legacyPath.download';
    final legacyFile = File(legacyPath);
    final legacyTempFile = File(legacyTempPath);
    if (await legacyFile.exists()) {
      await legacyFile.delete();
    }
    if (await legacyTempFile.exists()) {
      await legacyTempFile.delete();
    }
    for (final option in _bulkOptions) {
      final targetPath =
          '${directory.path}/${_bulkTypeFileName(option.type)}';
      final tempPath = '$targetPath.download';
      final mainFile = File(targetPath);
      final tempFile = File(tempPath);
      if (await mainFile.exists()) {
        await mainFile.delete();
      }
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to sign out. Try again.')),
      );
    }
  }

  Widget _buildProfileTile(User? user) {
    final displayName = user?.displayName?.trim();
    final email = user?.email?.trim();
    final hasDisplayName = displayName != null && displayName.isNotEmpty;
    final hasEmail = email != null && email.isNotEmpty;
    final isGuest = user == null;
    final title = hasDisplayName ? displayName : (isGuest ? 'Guest' : 'Google User');
    final subtitle =
        hasEmail ? email : (isGuest ? 'Local profile' : 'Signed in with Google');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: const Color(0xFF2D241B),
        foregroundImage: (user?.photoURL?.isNotEmpty ?? false)
            ? NetworkImage(user!.photoURL!)
            : null,
        child: (user?.photoURL?.isNotEmpty ?? false)
            ? null
            : const Icon(Icons.person, color: Color(0xFFEFE7D8)),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: isGuest
          ? null
          : TextButton(
              onPressed: _signOut,
              child: const Text('Sign out'),
            ),
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

  Widget _buildSectionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A2F24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFFE9C46A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFBFAE95),
                  ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFF3A2F24)),
          ),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: Stack(
        children: [
          const _AppBackground(),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                _buildSectionCard(
                  context: context,
                  icon: Icons.account_circle_outlined,
                  title: 'Profile',
                  children: [
                    _buildProfileSection(context),
                  ],
                ),
                const SizedBox(height: 14),
                _buildSectionCard(
                  context: context,
                  icon: Icons.storage_rounded,
                  title: l10n.cardDatabase,
                  subtitle: l10n.cardDatabaseSubtitle,
                  children: [
                    Text(
                      _bulkTypeLabel(l10n, _bulkType),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _bulkTypeDescription(l10n, _bulkType ?? ''),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFBFAE95),
                          ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton(
                        onPressed: _changeBulkType,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF5D4731)),
                        ),
                        child: Text(l10n.change),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildSectionCard(
                  context: context,
                  icon: Icons.workspace_premium_outlined,
                  title: l10n.pro,
                  subtitle: 'Unlock higher limits and upcoming premium features.',
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      decoration: BoxDecoration(
                        color: const Color(0x221D1712),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF3A2F24)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Need more than Free?',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'See plans, compare limits, and choose the best option for your collection workflow.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFFBFAE95),
                                ),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ProPage(),
                                  ),
                                );
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE9C46A),
                                foregroundColor: const Color(0xFF1C1510),
                              ),
                              icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                              label: const Text('Discover Plus'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildSectionCard(
                  context: context,
                  icon: Icons.info_outline_rounded,
                  title: 'App info',
                  children: [
                    ListTile(
                      title: const Text('Version'),
                      subtitle: Text(_appVersion),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}
