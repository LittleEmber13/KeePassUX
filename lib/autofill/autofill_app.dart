import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_autofill_service/flutter_autofill_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uri_content/uri_content.dart';

import '../model/db_root.dart';
import '../services/biometric_service.dart';
import '../services/vault_storage_service.dart';
import '../ui/theme/theme.dart';
import '../ui/theme/theme_controller.dart';
import '../ui/widgets/loading_overlay.dart';
import '../utils/kdbx_command.dart';
import '../utils/kdbx_isolate.dart';
import 'autofill_fill_page.dart';
import 'autofill_save_page.dart';
import 'autofill_unlock_page.dart';

enum _Phase { loading, unlock, needsSetup, fill, save, error }

class AutofillApp extends StatelessWidget {
  const AutofillApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'KeepassUX Autofill',
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          theme: lightThemeData,
          darkTheme: darkThemeData,
          themeMode: themeMode,
          builder: (context, child) => Directionality(
            textDirection: TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const _AutofillGate(),
        );
      },
    );
  }
}

class _AutofillGate extends StatefulWidget {
  const _AutofillGate();

  @override
  State<_AutofillGate> createState() => _AutofillGateState();
}

class _AutofillGateState extends State<_AutofillGate> {
  final BiometricService _biometric = BiometricService();
  KdbxIsolate? _isolate;

  _Phase _phase = _Phase.loading;
  String _message = '';
  AutofillMetadata? _metadata;
  DbRoot? _root;
  String _kdbxUri = '';
  Uint8List? _bytes;
  bool _biometricEligible = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _isolate?.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _kdbxUri = prefs.getString('kdbx_uri') ?? '';
      _metadata = await AutofillService().autofillMetadata;

      if (_kdbxUri.isEmpty) {
        return _setPhase(_Phase.needsSetup, tr('autofill.needs_setup_message'));
      }

      _bytes = await UriContent().from(Uri.parse(_kdbxUri));
      vaultStorage.rememberBaseline(_kdbxUri, _bytes!);

      final isolate = KdbxIsolate();
      await isolate.init();
      _isolate = isolate;

      final canBiometric = await _biometric.canAuthenticate();
      final hasSaved = await _biometric.hasSavedPassword(_kdbxUri);
      final biometricEnabled =
          prefs.getBool('biometric_login_enabled') ?? false;
      _biometricEligible = canBiometric && hasSaved && biometricEnabled;

      if (_biometricEligible) {
        final password = await _biometric.authenticateAndRetrievePassword(
          _kdbxUri,
        );
        if (password != null && password.isNotEmpty) {
          final root = await isolate.send<DbRoot>(
            LoadDatabaseCmd(bytes: _bytes!, password: password),
          );
          return _onUnlocked(root);
        }
      }

      _setPhase(_Phase.unlock, '');
    } catch (e) {
      debugPrint('AutofillApp bootstrap failed: $e');
      _setPhase(_Phase.error, tr('autofill.open_database_error'));
    }
  }

  void _onUnlocked(DbRoot root) {
    if (!mounted) return;
    _root = root;
    final isSave = _metadata?.saveInfo != null;
    _setPhase(isSave ? _Phase.save : _Phase.fill, '');
  }

  String? _appPackageForAssociation(AutofillMetadata? meta) {
    if (meta == null || meta.webDomains.isNotEmpty) return null;
    for (final p in meta.packageNames) {
      if (p != 'android' && p != 'com.cinderfall.keepassux') return p;
    }
    return null;
  }

  void _setPhase(_Phase phase, String message) {
    if (!mounted) return;
    setState(() {
      _phase = phase;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.loading:
        return const Scaffold(
          body: LoadingOverlay(isLoading: true),
        );
      case _Phase.unlock:
        return AutofillUnlockPage(
          kdbxUri: _kdbxUri,
          bytes: _bytes!,
          isolate: _isolate!,
          biometricEligible: _biometricEligible,
          onUnlocked: _onUnlocked,
          subtitle: _metadata?.saveInfo != null
              ? tr('autofill.unlock_subtitle_save')
              : tr('autofill.unlock_subtitle_fill'),
        );
      case _Phase.fill:
        return AutofillFillPage(
          root: _root!,
          isolate: _isolate!,
          kdbxUri: _kdbxUri,
          metadata: _metadata,
          appPackage: _appPackageForAssociation(_metadata),
        );
      case _Phase.save:
        return AutofillSavePage(
          root: _root!,
          isolate: _isolate!,
          metadata: _metadata,
          kdbxUri: _kdbxUri,
        );
      case _Phase.needsSetup:
      case _Phase.error:
        return _MessageScaffold(message: _message);
    }
  }
}

class _MessageScaffold extends StatelessWidget {
  const _MessageScaffold({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KeepassUX')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
