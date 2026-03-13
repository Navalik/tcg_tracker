// ignore_for_file: invalid_use_of_protected_member, use_build_context_synchronously

part of 'package:tcg_tracker/main.dart';

extension _SettingsActionsSection on _SettingsPageState {
  Future<void> _changeAppLanguage() async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(l10n.uiLanguageTitle),
          children: [
            RadioGroup<String>(
              groupValue: _appLocaleCode,
              onChanged: (value) => Navigator.of(context).pop(value),
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: 'en',
                    title: Text(l10n.languageEnglish),
                  ),
                  RadioListTile<String>(
                    value: 'it',
                    title: Text(l10n.languageItalian),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
    if (selected == null || selected == _appLocaleCode) {
      return;
    }
    await AppSettings.saveAppLocale(selected);
    if (!mounted) {
      return;
    }
    setState(() {
      _appLocaleCode = selected;
    });
    _appLocaleNotifier.value = Locale(selected);
  }

  String _themeLabel(String code) {
    switch (code.trim().toLowerCase()) {
      case 'vault':
        return 'Vault';
      case 'magic':
      default:
        return 'Magic';
    }
  }

  String _themeDescription(String code) {
    final l10n = AppLocalizations.of(context)!;
    final normalized = code.trim().toLowerCase();
    if (normalized == 'vault') {
      return l10n.themeVaultDescription;
    }
    return l10n.themeMagicDescription;
  }

  Future<void> _changeVisualTheme() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return SimpleDialog(
          title: Text(l10n.visualThemeTitle),
          children: [
            RadioGroup<String>(
              groupValue: _appThemeCode,
              onChanged: (value) => Navigator.of(context).pop(value),
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: 'magic',
                    title: const Text('Magic'),
                    subtitle: Text(l10n.themeMagicSubtitle),
                  ),
                  RadioListTile<String>(
                    value: 'vault',
                    title: const Text('Vault'),
                    subtitle: Text(l10n.themeVaultSubtitle),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
    if (selected == null || selected == _appThemeCode) {
      return;
    }
    await AppSettings.saveVisualTheme(selected);
    if (!mounted) {
      return;
    }
    setState(() {
      _appThemeCode = selected;
    });
    _appThemeNotifier.value = appVisualThemeFromCode(selected);
  }

  Future<void> _changePriceSource() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return SimpleDialog(
          title: Text(l10n.priceSourceTitle),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop('scryfall'),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.scryfallProviderLabel),
                subtitle: Text(l10n.dailySnapshot),
              ),
            ),
          ],
        );
      },
    );
    if (selected == null || selected == _priceSource || !mounted) {
      return;
    }
    setState(() {
      _priceSource = selected;
    });
  }

  Future<void> _changePriceCurrency(String currency) async {
    final normalized = currency.trim().toLowerCase() == 'usd' ? 'usd' : 'eur';
    if (normalized == _priceCurrency) {
      return;
    }
    await AppSettings.savePriceCurrency(normalized);
    if (!mounted) {
      return;
    }
    setState(() {
      _priceCurrency = normalized;
    });
  }

  Future<void> _changeShowPrices(String value) async {
    final nextValue = value.trim().toLowerCase() == 'off' ? false : true;
    if (nextValue == _showPrices) {
      return;
    }
    await AppSettings.saveShowPrices(nextValue);
    if (!mounted) {
      return;
    }
    setState(() {
      _showPrices = nextValue;
    });
  }

  String _pokemonProfileLabel(String profile) {
    return _pokemonDatasetProfileTitle(context, profile);
  }

  String _pokemonProfileDescription(String profile) {
    return _pokemonDatasetProfileDescription(context, profile);
  }

  Future<void> _changePokemonDatasetProfile() async {
    final selected = await _showPokemonDatasetProfilePicker(
      context,
      allowCancel: true,
      selectedProfile: _pokemonDatasetProfile,
      requireConfirmation: true,
      confirmLabel: AppLocalizations.of(context)!.applyProfileLabel,
    );
    if (selected == null || selected == _pokemonDatasetProfile) {
      return;
    }
    await AppSettings.savePokemonDatasetProfile(selected);
    if (!mounted) {
      return;
    }
    setState(() {
      _pokemonDatasetProfile = selected;
    });
    showAppSnackBar(
      context,
      AppLocalizations.of(context)!.pokemonProfileUpdatedTapUpdate,
    );
  }
}
