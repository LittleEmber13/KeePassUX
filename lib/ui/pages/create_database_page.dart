import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_states.dart';
import 'package:keepassux/ui/pages/main_tabs_page.dart';
import 'package:keepassux/ui/pages/start_page.dart';
import 'package:keepassux/services/saf_service.dart';
import 'package:keepassux/ui/theme/theme.dart';
import 'package:keepassux/ui/widgets/app_logo.dart';
import 'package:keepassux/ui/widgets/loading_overlay.dart';
import 'package:keepassux/ui/widgets/slide_to_open_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../bloc/entries/keepass_events.dart';

class CreateDatabasePage extends StatefulWidget {
  const CreateDatabasePage({super.key});

  @override
  State<CreateDatabasePage> createState() => _CreateDatabasePageState();
}

class _CreateDatabasePageState extends State<CreateDatabasePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final SafService _safService = SafService();

  TextEditingController nameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;

  SharedPreferences? preferences;

  bool get _canCreateDatabase =>
      nameController.text.isNotEmpty && passwordController.text.isNotEmpty;

  @override
  void initState() {
    SharedPreferences.getInstance().then((preferences) {
      this.preferences = preferences;
    });
    nameController.addListener(_onCredentialsChanged);
    passwordController.addListener(_onCredentialsChanged);
    super.initState();
  }

  void _onCredentialsChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    nameController.removeListener(_onCredentialsChanged);
    passwordController.removeListener(_onCredentialsChanged);
    nameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<KeePassBloc, KeePassState>(
      listener: (context, state) {
        if (state is KeePassCreated) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainTabsPage()),
          );
        }
        if (state is KeePassError) {
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
        Text(
          tr("create_database_page.title"),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            color: context.appColors.secondaryText,
          ),
        ),
        const SizedBox(height: 16),
        _buildFormCard(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildBottomGroup() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _buildCreateAction()),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: () async {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const StartPage(),
                ),
              );
            },
            child: Text(
              tr("create_database_page.open_database"),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appColors.secondaryText),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCreateAction() {
    return SlideToOpenButton(
      label: tr("create_database_page.create_database"),
      enabled: _canCreateDatabase,
      onConfirmed: _createDatabase,
    );
  }

  Future<bool> _createDatabase() async {
    if (!_formKey.currentState!.validate()) return false;
    if (preferences == null) return false;
    final safUri = await _safService.createDocument(
      "${nameController.text}.kdbx",
    );
    if (safUri == null) return false;
    if (!mounted) return false;
    context.read<KeePassBloc>().add(
      CreateDatabase(
        uri: safUri,
        password: passwordController.text,
      ),
    );
    return true;
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
              TextFormField(
                controller: nameController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return tr("form_error.required");
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: tr("create_database_page.name_hint"),
                ),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return tr("form_error.required");
                  }
                  return null;
                },
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: tr("create_database_page.password_hint"),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword == true
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
