import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:keepassux/services/autofill_settings_service.dart';
import 'package:keepassux/ui/theme/theme.dart';
import 'package:keepassux/ui/widgets/custom_app_scroll.dart';
import 'package:keepassux/ui/widgets/group_app_bar.dart';

class AutofillSettingsPage extends StatefulWidget {
  const AutofillSettingsPage({super.key});

  @override
  State<AutofillSettingsPage> createState() => _AutofillSettingsPageState();
}

class _AutofillSettingsPageState extends State<AutofillSettingsPage> {
  final AutofillSettingsService _autofillService = AutofillSettingsService();

  bool _autofillSupported = false;
  bool _autofillEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final autofillSupported = await _autofillService.isSupported;
    final autofillEnabled = autofillSupported ? await _autofillService.isEnabled : false;
    if (!mounted) return;
    setState(() {
      _autofillSupported = autofillSupported;
      _autofillEnabled = autofillEnabled;
    });
  }

  Future<void> _onAutofillToggle(bool value) async {
    if (value) {
      await _autofillService.requestEnable();
    } else {
      await _autofillService.disable();
    }
    final enabled = await _autofillService.isEnabled;
    if (mounted) setState(() => _autofillEnabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, left: 24, right: 24),
              child: GroupAppBar(
                onTapExit: () => Navigator.pop(context),
                title: tr("autofill_settings_page.title"),
              ),
            ),
            CustomAppScroll(
              children: [
                Text(
                  tr("autofill_settings_page.intro"),
                  style: TextStyle(color: context.appColors.secondaryText),
                ),
                const SizedBox(height: 16),
                if (_autofillSupported)
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          title: Text(tr("autofill_settings_page.autofill_toggle_title")),
                          value: _autofillEnabled,
                          onChanged: _onAutofillToggle,
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr("autofill_settings_page.autofill_toggle_description"),
                          style: TextStyle(color: context.appColors.secondaryText),
                        ),
                      ],
                    ),
                  ),
                if (_autofillSupported) ...[
                  const SizedBox(height: 12),
                  _buildBrowserNote(context),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ],
        ),
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

  Widget _buildBrowserNote(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.appColors.infoCardBackground,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: context.appColors.cardShadow,
            blurRadius: 5,
            spreadRadius: 1,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: context.appColors.secondaryText),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr("autofill_settings_page.browser_note_title"),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  tr("autofill_settings_page.browser_note_description"),
                  style: TextStyle(fontSize: 13, color: context.appColors.secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
