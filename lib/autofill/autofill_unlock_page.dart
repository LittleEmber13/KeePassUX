import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../model/db_root.dart';
import '../services/biometric_service.dart';
import '../ui/theme/theme.dart';
import '../utils/kdbx_command.dart';
import '../utils/kdbx_isolate.dart';
import '../ui/widgets/app_logo.dart';
import '../ui/widgets/loading_overlay.dart';
import '../ui/widgets/slide_to_open_button.dart';

class AutofillUnlockPage extends StatefulWidget {
  const AutofillUnlockPage({
    super.key,
    required this.kdbxUri,
    required this.bytes,
    required this.isolate,
    required this.biometricEligible,
    required this.onUnlocked,
    this.subtitle,
  });

  final String kdbxUri;
  final Uint8List bytes;
  final KdbxIsolate isolate;

  final bool biometricEligible;

  final void Function(DbRoot root) onUnlocked;

  final String? subtitle;

  @override
  State<AutofillUnlockPage> createState() => _AutofillUnlockPageState();
}

class _AutofillUnlockPageState extends State<AutofillUnlockPage> {
  final TextEditingController _passwordController = TextEditingController();
  final BiometricService _biometric = BiometricService();

  bool _obscure = true;
  bool _busy = false;
  bool _passwordMode = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _passwordController.dispose();
    super.dispose();
  }

  Future<bool> _unlockWithPassword() async {
    return _tryUnlock(_passwordController.text);
  }

  Future<void> _unlockWithBiometric() async {
    final password = await _biometric.authenticateAndRetrievePassword(
      widget.kdbxUri,
    );
    if (password == null || password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('autofill.unlock_biometric_error')),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    setState(() => _busy = true);
    await _tryUnlock(password);
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<bool> _tryUnlock(String password) async {
    setState(() => _error = null);
    try {
      final root = await widget.isolate.send<DbRoot>(
        LoadDatabaseCmd(bytes: widget.bytes, password: password),
      );
      widget.onUnlocked(root);
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _error = tr('autofill.unlock_wrong_password_error'));
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _page(),
        LoadingOverlay(isLoading: _busy),
      ],
    );
  }

  Widget _page() {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopGroup(),
              _buildBottomGroup(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopGroup() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 42),
        const Center(child: AppLogo()),
        const SizedBox(height: 40),
        _buildFormCard(),
        const SizedBox(height: 20),
        Text(
          widget.subtitle ?? tr('autofill.unlock_default_subtitle'),
          textAlign: TextAlign.center,
          style: TextStyle(color: context.appColors.secondaryText),
        ),
      ],
    );
  }

  Widget _buildBottomGroup() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _buildBottomAction()),
        if (widget.biometricEligible) ...[
          const SizedBox(height: 24),
          _buildToggleLink(),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: cardDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_passwordMode) _buildPasswordField(),
            if (!_passwordMode)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  tr('start_page.open_with_biometric'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.appColors.secondaryText),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscure,
      autofocus: true,
      enabled: !_busy,
      decoration: InputDecoration(
        labelText: tr('autofill.master_password_hint'),
        errorText: _error,
        suffixIcon: IconButton(
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }

  Widget _buildToggleLink() {
    return GestureDetector(
      onTap: () => setState(() => _passwordMode = !_passwordMode),
      child: Text(
        _passwordMode
            ? tr("start_page.open_with_biometric")
            : tr("start_page.open_with_password"),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: context.appColors.secondaryText,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    if (!_passwordMode && widget.biometricEligible) {
      return _buildBiometricButton();
    }
    return SlideToOpenButton(
      label: tr("start_page.open_database"),
      enabled: _passwordController.text.isNotEmpty && !_busy,
      onConfirmed: _unlockWithPassword,
    );
  }

  Widget _buildBiometricButton() {
    return GestureDetector(
      onTap: _busy ? null : _unlockWithBiometric,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          FontAwesomeIcons.fingerprint,
          color: context.appColors.secondaryText,
          size: 56,
        ),
      ),
    );
  }
}
