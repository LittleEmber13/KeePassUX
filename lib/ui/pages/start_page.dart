import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:keepassux/bloc/entries/keepass_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_states.dart';
import 'package:keepassux/ui/pages/create_database_page.dart';
import 'package:keepassux/ui/pages/main_tabs_page.dart';
import 'package:keepassux/services/biometric_service.dart';
import 'package:keepassux/services/saf_service.dart';
import 'package:keepassux/ui/widgets/app_logo.dart';
import 'package:keepassux/ui/widgets/loading_overlay.dart';
import 'package:keepassux/ui/widgets/slide_to_open_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uri_content/uri_content.dart';
import 'package:keepassux/ui/theme/theme.dart';

import '../../bloc/entries/keepass_events.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final SafService _safService = SafService();
  final BiometricService _biometricService = BiometricService();

  TextEditingController passwordController = TextEditingController();
  TextEditingController folderController = TextEditingController();

  bool obscurePassword = true;
  bool _hasBiometrics = false;
  bool _hasSavedPassword = false;
  bool _biometricLoginEnabled = false;
  bool _passwordMode = true;

  SharedPreferences? preferences;

  Completer<bool>? _openCompleter;

  bool get _canOpenDatabase =>
      folderController.text.isNotEmpty && passwordController.text.isNotEmpty;

  bool get _showBiometricOption =>
      _hasBiometrics && _hasSavedPassword && _biometricLoginEnabled;

  Future<void> _initStateAsync() async {
    preferences = await SharedPreferences.getInstance();
    final savedUri = preferences!.getString('kdbx_uri') ?? '';
    folderController.text = savedUri;
    if (savedUri.isNotEmpty) {
      _safService.takePersistablePermission(savedUri);
    }
    _hasBiometrics = await _biometricService.canAuthenticate();
    _hasSavedPassword = await _biometricService.hasSavedPassword(savedUri);
    _biometricLoginEnabled = preferences!.getBool('biometric_login_enabled') ?? false;
    _passwordMode = !_showBiometricOption;
    setState(() {});
  }

  @override
  void initState() {
    _initStateAsync();
    passwordController.addListener(_onCredentialsChanged);
    folderController.addListener(_onCredentialsChanged);
    super.initState();
  }

  void _onCredentialsChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    passwordController.removeListener(_onCredentialsChanged);
    folderController.removeListener(_onCredentialsChanged);
    passwordController.dispose();
    folderController.dispose();
    super.dispose();
  }

  Future<void> _onFilePicked(String safUri) async {
    folderController.text = safUri;
    await preferences!.setString('kdbx_uri', safUri);
    _safService.takePersistablePermission(safUri);
    _hasSavedPassword = await _biometricService.hasSavedPassword(safUri);
    _passwordMode = !_showBiometricOption;
    setState(() {});
  }

  Future<bool> _openDatabase() async {
    if (!_formKey.currentState!.validate()) return false;
    try {
      final uri = Uri.parse(folderController.text);
      final bytes = await UriContent().from(uri);
      _openCompleter = Completer<bool>();
      context.read<KeePassBloc>().add(
        LoadDatabase(bytes: bytes, password: passwordController.text),
      );
      return await _openCompleter!.future;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr("start_page.open_database_error")),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _authenticateWithBiometric() async {
    final password = await _biometricService.authenticateAndRetrievePassword(
      folderController.text,
    );
    if (password == null || password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr("start_page.biometric_error")),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    passwordController.text = password;
    _openDatabase();
  }

  Future<void> _onDatabaseLoaded() async {
    if (_hasBiometrics) {
      final alreadyAsked = preferences!.getBool('biometric_asked') ?? false;
      if (!alreadyAsked) {
        final result = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(tr("settings_page.biometric_login")),
            content: Text(tr("start_page.biometric_save_message")),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr("start_page.biometric_save_no")),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(tr("start_page.biometric_save_yes")),
              ),
            ],
          ),
        );
        await preferences!.setBool('biometric_login_enabled', result == true);
        await preferences!.setBool('biometric_asked', true);
      }
      await _biometricService.syncSavedPassword(
        folderController.text,
        enabled: preferences!.getBool('biometric_login_enabled') ?? false,
        password: passwordController.text,
      );
    }
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainTabsPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<KeePassBloc, KeePassState>(
      listener: (context, state) {
        if (state is KeePassLoaded) {
          _openCompleter?.complete(true);
          _openCompleter = null;
          _onDatabaseLoaded();
        }
        if (state is KeePassError) {
          _openCompleter?.complete(false);
          _openCompleter = null;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      builder: (context, state) {
        return Stack(
          fit: StackFit.expand,
          children: [
            _page(),
            LoadingOverlay(isLoading: state is KeePassLoading),
          ],
        );
      },
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
        _buildCreateDatabaseLink(),
      ],
    );
  }

  Widget _buildBottomGroup() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _buildBottomAction()),
        if (_showBiometricOption) ...[
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
      child: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilePickerRow(),
              if (_passwordMode) ...[
                const SizedBox(height: 16),
                _buildPasswordField(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilePickerRow() {
    return InkWell(
      onTap: () async {
        if (preferences == null) return;
        final safUri = await _safService.openDocument();
        if (safUri != null) {
          _onFilePicked(safUri);
        }
      },
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: folderController,
              enabled: false,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return tr("form_error.required");
                }
                return null;
              },
              decoration: InputDecoration(
                labelText: tr("start_page.folder_hint"),
              ),
            ),
          ),
        ],
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
    if (!_passwordMode && _showBiometricOption) {
      return _buildBiometricButton();
    }
    return SlideToOpenButton(
      label: tr("start_page.open_database"),
      enabled: _canOpenDatabase,
      onConfirmed: _openDatabase,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: passwordController,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return tr("form_error.required");
        }
        return null;
      },
      obscureText: obscurePassword,
      decoration: InputDecoration(
        labelText: tr("start_page.password_hint"),
        suffixIcon: IconButton(
          icon: Icon(
            obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () {
            setState(() {
              obscurePassword = !obscurePassword;
            });
          },
        ),
      ),
    );
  }

  Widget _buildBiometricButton() {
    return GestureDetector(
      onTap: _authenticateWithBiometric,
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

  Widget _buildCreateDatabaseLink() {
    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CreateDatabasePage()),
        );
      },
      child: Text(
        tr("start_page.create_database"),
        textAlign: TextAlign.center,
        style: TextStyle(color: context.appColors.secondaryText),
      ),
    );
  }
}
