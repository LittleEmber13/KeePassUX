import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_autofill_service/flutter_autofill_service.dart';
import 'package:lottie/lottie.dart';

import '../model/db_root.dart';
import '../model/kdbx_action_result.dart';
import '../services/vault_storage_service.dart';
import '../utils/kdbx_command.dart';
import '../utils/kdbx_isolate.dart';
import 'autofill_matcher.dart';

const _channel = MethodChannel('com.example.keepassux/autofill');

enum _SavePhase { saving, saved, error }

class AutofillSavePage extends StatefulWidget {
  const AutofillSavePage({
    super.key,
    required this.root,
    required this.isolate,
    required this.kdbxUri,
    this.metadata,
  });

  final DbRoot root;
  final KdbxIsolate isolate;
  final String kdbxUri;
  final AutofillMetadata? metadata;

  @override
  State<AutofillSavePage> createState() => _AutofillSavePageState();
}

class _AutofillSavePageState extends State<AutofillSavePage> {
  _SavePhase _phase = _SavePhase.saving;
  String _errorMessage = '';

  String _title = '';
  String _username = '';
  String _password = '';
  String _url = '';
  String _groupName = '';

  @override
  void initState() {
    super.initState();
    _title = _initialTitle();
    _username = widget.metadata?.saveInfo?.username ?? '';
    _password = widget.metadata?.saveInfo?.password ?? '';
    _url = _initialUrl();
    _groupName = widget.root.rootGroup.name.isNotEmpty
        ? widget.root.rootGroup.name
        : tr('autofill.default_group_name');
    _autoSave();
  }

  String? get _firstDomain {
    final domains = widget.metadata?.webDomains
        .map((d) => d.domain)
        .where((d) => d.isNotEmpty);
    return (domains != null && domains.isNotEmpty) ? domains.first : null;
  }

  String _initialUrl() {
    final domain = _firstDomain;
    return domain != null ? 'https://$domain' : '';
  }

  String _initialTitle() {
    final domain = _firstDomain;
    if (domain != null) return AutofillMatcher.normalizeHost(domain);
    final packages = widget.metadata?.packageNames.where((p) => p != 'android');
    if (packages != null && packages.isNotEmpty) return packages.first;
    return '';
  }

  Future<void> _autoSave() async {
    try {
      final result = await widget.isolate.send<KdbxActionResult>(
        AddEntryCmd(
          groupUuid: widget.root.rootGroup.uuid,
          title: _title,
          userName: _username,
          url: _url,
          notes: '',
          password: _password,
        ),
      );
      await vaultStorage.save(widget.kdbxUri, result.savedBytes);
      await AutofillService().onSaveComplete();
      if (mounted) {
        setState(() => _phase = _SavePhase.saved);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) SystemNavigator.pop();
        });
      }
    } catch (e) {
      debugPrint('Autofill save failed: $e');
      if (!mounted) return;
      setState(() {
        _phase = _SavePhase.error;
        _errorMessage = tr('autofill.save_error');
      });
    }
  }

  Future<void> _launchMainApp() async {
    try {
      await _channel.invokeMethod('launchMainActivity');
      await AutofillService().onSaveComplete();
      if (mounted) SystemNavigator.pop();
    } catch (_) {
      await AutofillService().onSaveComplete();
      if (mounted) SystemNavigator.pop();
    }
  }

  Future<void> _close() async {
    await AutofillService().onSaveComplete();
    if (mounted) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KeepassUX')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _SavePhase.saving:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/animations/loading_keyhole_spinner.json',
              width: 80,
              height: 80,
            ),
            const SizedBox(height: 20),
            Text(tr('autofill.saving_status')),
          ],
        );
      case _SavePhase.saved:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(
              tr('autofill.saved_status'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(tr('autofill.group_label', namedArgs: {'group': _groupName})),
            const SizedBox(height: 32),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              icon: const Icon(Icons.open_in_new),
              label: Text(tr('autofill.open_in_app')),
              onPressed: _launchMainApp,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _close,
              child: Text(tr('autofill.close')),
            ),
          ],
        );
      case _SavePhase.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(_errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _close,
              child: Text(tr('autofill.close')),
            ),
          ],
        );
    }
  }
}
