import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_events.dart';
import 'package:keepassux/ui/pages/autofill_settings_page.dart';
import 'package:keepassux/ui/pages/change_password_page.dart';
import 'package:keepassux/ui/pages/kdf_settings_page.dart';
import 'package:keepassux/ui/pages/start_page.dart';
import 'package:keepassux/services/autofill_settings_service.dart';
import 'package:keepassux/services/biometric_service.dart';
import 'package:keepassux/services/screenshot_protection_service.dart';
import 'package:keepassux/ui/theme/theme.dart';
import 'package:keepassux/ui/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

const _languageOptions = <String, String>{
  'es': 'Español',
  'en': 'English',
  'id': 'Bahasa Indonesia',
  'ca': 'Català',
  'da': 'Dansk',
  'de': 'Deutsch',
  'fr': 'Français',
  'hr': 'Hrvatski',
  'it': 'Italiano',
  'lt': 'Lietuvių',
  'hu': 'Magyar',
  'nl': 'Nederlands',
  'nb': 'Norsk bokmål',
  'pl': 'Polski',
  'pt': 'Português',
  'ro': 'Română',
  'sk': 'Slovenčina',
  'fi': 'Suomi',
  'sv': 'Svenska',
  'vi': 'Tiếng Việt',
  'tr': 'Türkçe',
  'el': 'Ελληνικά',
  'bg': 'Български',
  'ru': 'Русский',
  'uk': 'Українська',
  'hi': 'हिन्दी',
  'zh': '中文（简体）',
  'ja': '日本語',
  'ko': '한국어',
};

class _SettingsTabState extends State<SettingsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final BiometricService _biometricService = BiometricService();
  final AutofillSettingsService _autofillService = AutofillSettingsService();
  final ScreenshotProtectionService _screenshotProtectionService =
      ScreenshotProtectionService();

  String selectedLanguage = 'es';
  bool biometricLoginEnabled = false;
  bool screenshotProtectionEnabled = true;
  bool _hasBiometrics = false;
  bool _autofillSupported = false;
  bool _autofillEnabled = false;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _initStateAsync();
  }

  Future<void> _initStateAsync() async {
    _prefs = await SharedPreferences.getInstance();
    final currentLocale = context.locale;
    _hasBiometrics = await _biometricService.canAuthenticate();
    final savedEnabled = _prefs?.getBool('biometric_login_enabled') ?? false;
    final savedScreenshotProtection =
        _prefs?.getBool('screenshot_protection_enabled') ?? true;
    _autofillSupported = await _autofillService.isSupported;
    if (_autofillSupported) {
      _autofillEnabled = await _autofillService.isEnabled;
    }
    setState(() {
      if (_languageOptions.containsKey(currentLocale.languageCode)) {
        selectedLanguage = currentLocale.languageCode;
      }
      biometricLoginEnabled = savedEnabled;
      screenshotProtectionEnabled = savedScreenshotProtection;
    });
  }

  Future<void> _onBiometricToggle(bool value) async {
    final uri = _prefs?.getString('kdbx_uri') ?? '';
    final sessionPassword = context.read<KeePassBloc>().sessionPassword;
    await _biometricService.syncSavedPassword(
      uri,
      enabled: value,
      password: sessionPassword,
    );
    await _prefs?.setBool('biometric_login_enabled', value);
    setState(() => biometricLoginEnabled = value);
  }

  Future<void> _onScreenshotProtectionToggle(bool value) async {
    if (value) {
      await _prefs?.setBool('screenshot_protection_enabled', true);
      await _screenshotProtectionService.enableProtection();
      setState(() => screenshotProtectionEnabled = true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(tr("settings_page.screenshot_protection")),
            content: Text(
              tr("settings_page.screenshot_protection_disable_warning"),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr("settings_page.screenshot_protection_cancel")),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(tr("settings_page.screenshot_protection_confirm")),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    await _prefs?.setBool('screenshot_protection_enabled', false);
    await _screenshotProtectionService.disableProtection();
    setState(() => screenshotProtectionEnabled = false);

    if (!mounted) return;
    context.read<KeePassBloc>().add(LockDatabase());
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => StartPage()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _onAutofillSettingsTap() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AutofillSettingsPage()),
    );
    if (_autofillSupported) {
      _autofillEnabled = await _autofillService.isEnabled;
    }
    if (mounted) setState(() {});
  }

  Future<void> _onDarkThemeToggle(bool value) async {
    await themeController.setThemeMode(
      value ? ThemeMode.dark : ThemeMode.light,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Container(
          //   decoration: BoxDecoration(
          //     color: Colors.white,
          //     borderRadius: BorderRadius.circular(8),
          //     boxShadow: [
          //       BoxShadow(
          //         color: Colors.black.withOpacity(0.05),
          //         blurRadius: 5,
          //         spreadRadius: 1,
          //         offset: Offset(1, 2),
          //       ),
          //     ],
          //   ),
          //   child: ListTile(
          //     leading: const Icon(Icons.star_border),
          //     title: const Text('FAQ'),
          //     onTap: () {},
          //   ),
          // ),
          // const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: cardDecoration(context),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr("settings_page.language"),
                    style: TextStyle(color: context.appColors.secondaryText),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedLanguage,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      for (final entry in _languageOptions.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => selectedLanguage = value);
                      context.setLocale(Locale(value));
                    },
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeController,
                    builder: (context, mode, _) {
                      return SwitchListTile(
                        title: Text(tr("settings_page.dark_theme")),
                        value: mode == ThemeMode.dark,
                        onChanged: _onDarkThemeToggle,
                        contentPadding: EdgeInsets.zero,
                      );
                    },
                  ),
                  if (_hasBiometrics) ...[
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: Text(tr("settings_page.biometric_login")),
                      value: biometricLoginEnabled,
                      onChanged: _onBiometricToggle,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                  if (Platform.isAndroid) ...[
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: Text(tr("settings_page.screenshot_protection")),
                      subtitle: Text(
                        tr("settings_page.screenshot_protection_subtitle"),
                      ),
                      value: screenshotProtectionEnabled,
                      onChanged: _onScreenshotProtectionToggle,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                  if (_autofillSupported) ...[
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.auto_fix_high_outlined),
                      title: Text(tr("settings_page.autofill_settings")),
                      subtitle: Text(
                        _autofillEnabled
                            ? tr("settings_page.autofill_settings_active")
                            : tr("settings_page.autofill_settings_inactive"),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      contentPadding: EdgeInsets.zero,
                      onTap: _onAutofillSettingsTap,
                    ),
                  ],
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text(tr("settings_page.change_password")),
                    trailing: const Icon(Icons.chevron_right),
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChangePasswordPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.security_outlined),
                    title: Text(tr("settings_page.kdf_settings")),
                    trailing: const Icon(Icons.chevron_right),
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const KdfSettingsPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
