import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_events.dart';
import 'package:keepassux/bloc/entries/keepass_states.dart';
import 'package:keepassux/services/biometric_service.dart';
import 'package:keepassux/ui/theme/theme.dart';
import 'package:keepassux/ui/widgets/custom_app_scroll.dart';
import 'package:keepassux/ui/widgets/loading_overlay.dart';
import 'package:keepassux/ui/widgets/group_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final BiometricService _biometricService = BiometricService();

  final TextEditingController currentPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool obscureCurrentPassword = true;
  bool obscureNewPassword = true;
  bool obscureConfirmPassword = true;

  final OutlineInputBorder _inputBorder = const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onSuccess() async {
    final preferences = await SharedPreferences.getInstance();
    final uri = preferences.getString('kdbx_uri') ?? '';
    if (uri.isNotEmpty && await _biometricService.hasSavedPassword(uri)) {
      await _biometricService.savePassword(uri, newPasswordController.text);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr("change_password_page.success")),
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<KeePassBloc, KeePassState>(
      listener: (context, state) {
        if (state is KeePassChangeMasterPasswordSuccess) {
          _onSuccess();
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, left: 24, right: 24),
                child: GroupAppBar(
                  onTapExit: () => Navigator.pop(context),
                  title: tr("change_password_page.title"),
                ),
              ),
              CustomAppScroll(
                children: [
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPasswordField(
                          controller: currentPasswordController,
                          labelText: tr("change_password_page.current_password_hint"),
                          obscure: obscureCurrentPassword,
                          onToggleObscure: () {
                            setState(() {
                              obscureCurrentPassword = !obscureCurrentPassword;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return tr("form_error.required");
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildPasswordField(
                          controller: newPasswordController,
                          labelText: tr("change_password_page.new_password_hint"),
                          obscure: obscureNewPassword,
                          onToggleObscure: () {
                            setState(() {
                              obscureNewPassword = !obscureNewPassword;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return tr("form_error.required");
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildPasswordField(
                          controller: confirmPasswordController,
                          labelText: tr("change_password_page.confirm_password_hint"),
                          obscure: obscureConfirmPassword,
                          onToggleObscure: () {
                            setState(() {
                              obscureConfirmPassword = !obscureConfirmPassword;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return tr("form_error.required");
                            }
                            if (value != newPasswordController.text) {
                              return tr("change_password_page.error_mismatch");
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          context.read<KeePassBloc>().add(
                            ChangeMasterPassword(
                              oldPassword: currentPasswordController.text,
                              newPassword: newPasswordController.text,
                            ),
                          );
                        }
                      },
                      child: Text(tr("change_password_page.save")),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String labelText,
    required bool obscure,
    required VoidCallback onToggleObscure,
    required FormFieldValidator<String> validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        labelText: labelText,
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          onPressed: onToggleObscure,
        ),
        enabledBorder: _inputBorder,
        focusedBorder: _inputBorder,
        disabledBorder: _inputBorder,
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}
