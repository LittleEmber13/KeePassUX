import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_events.dart';
import 'package:keepassux/bloc/entries/keepass_states.dart';
import 'package:keepassux/model/kdf_info.dart';
import 'package:keepassux/ui/theme/theme.dart';
import 'package:keepassux/ui/widgets/custom_app_scroll.dart';
import 'package:keepassux/ui/widgets/group_app_bar.dart';
import 'package:keepassux/ui/widgets/loading_overlay.dart';

const int _minMemoryMib = 1;
const int _maxMemoryMib = 128;
const int _warnMemoryMib = 64;
const int _minIterations = 1;
const int _maxIterations = 20;
const int _warnIterations = 10;
const int _minParallelism = 1;
const int _maxParallelism = 8;

class KdfSettingsPage extends StatefulWidget {
  const KdfSettingsPage({super.key});

  @override
  State<KdfSettingsPage> createState() => _KdfSettingsPageState();
}

class _KdfSettingsPageState extends State<KdfSettingsPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController memoryController = TextEditingController();
  final TextEditingController iterationsController = TextEditingController();
  final TextEditingController parallelismController = TextEditingController();

  bool _loadedOnce = false;
  bool _isAes = false;

  bool get _isHeavy {
    final memoryMib = int.tryParse(memoryController.text) ?? 0;
    final iterations = int.tryParse(iterationsController.text) ?? 0;
    return memoryMib > _warnMemoryMib || iterations > _warnIterations;
  }

  final OutlineInputBorder _inputBorder = const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );

  @override
  void initState() {
    super.initState();
    context.read<KeePassBloc>().add(GetKdfParameters());
  }

  @override
  void dispose() {
    memoryController.dispose();
    iterationsController.dispose();
    parallelismController.dispose();
    super.dispose();
  }

  void _applyInfo(KdfInfo info) {
    _isAes = info.kdfType == 'aes';
    memoryController.text = (info.memoryBytes / (1024 * 1024)).round().toString();
    iterationsController.text = info.iterations.toString();
    parallelismController.text = info.parallelism.toString();
    _loadedOnce = true;
  }

  void _onSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr("kdf_settings_page.success")),
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<KeePassBloc, KeePassState>(
      listener: (context, state) {
        if (state is KeePassKdfParameters) {
          setState(() => _applyInfo(state.info));
        }
        if (state is KeePassChangeKdfParametersSuccess) {
          _onSuccess();
        }
        if (state is KeePassError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              duration: const Duration(seconds: 2),
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
                  title: tr("kdf_settings_page.title"),
                ),
              ),
              CustomAppScroll(
                children: [
                  if (_loadedOnce && _isAes)
                    _buildCard(
                      child: Text(
                        tr("kdf_settings_page.error_unsupported_aes"),
                        style: TextStyle(color: context.appColors.secondaryText),
                      ),
                    )
                  else ...[
                    Text(
                      tr("kdf_settings_page.help_text"),
                      style: TextStyle(color: context.appColors.secondaryText),
                    ),
                    const SizedBox(height: 16),
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildNumberField(
                            controller: memoryController,
                            labelText: tr("kdf_settings_page.memory_hint"),
                            min: _minMemoryMib,
                            max: _maxMemoryMib,
                          ),
                          const SizedBox(height: 16),
                          _buildNumberField(
                            controller: iterationsController,
                            labelText: tr("kdf_settings_page.iterations_hint"),
                            min: _minIterations,
                            max: _maxIterations,
                          ),
                          const SizedBox(height: 16),
                          _buildNumberField(
                            controller: parallelismController,
                            labelText: tr("kdf_settings_page.parallelism_hint"),
                            min: _minParallelism,
                            max: _maxParallelism,
                          ),
                        ],
                      ),
                    ),
                    if (_isHeavy) ...[
                      const SizedBox(height: 16),
                      _buildCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tr("kdf_settings_page.warning_heavy"),
                                style: TextStyle(
                                  color: context.appColors.secondaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                            final memoryMib = int.parse(memoryController.text);
                            context.read<KeePassBloc>().add(
                              ChangeKdfParameters(
                                memoryBytes: memoryMib * 1024 * 1024,
                                iterations: int.parse(iterationsController.text),
                                parallelism: int.parse(parallelismController.text),
                              ),
                            );
                          }
                        },
                        child: Text(tr("kdf_settings_page.save")),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String labelText,
    required int min,
    required int max,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => setState(() {}),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return tr("form_error.required");
        }
        final parsed = int.tryParse(value);
        if (parsed == null || parsed < min || parsed > max) {
          return tr("kdf_settings_page.error_out_of_range", args: ['$min', '$max']);
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: labelText,
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
