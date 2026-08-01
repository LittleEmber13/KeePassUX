import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:keepassux/ui/theme/theme.dart';
import 'package:keepassux/utils/password_generator.dart';
import 'package:zxcvbnm/languages/en.dart' as en;
import 'package:zxcvbnm/languages/es_es.dart' as es;
import 'package:zxcvbnm/zxcvbnm.dart';

class PasswordGeneratorResult {
  final String password;
  final int length;
  final bool includeUppercase;
  final bool includeLowercase;
  final bool includeNumbers;
  final bool includeSpecial;

  const PasswordGeneratorResult({
    required this.password,
    required this.length,
    required this.includeUppercase,
    required this.includeLowercase,
    required this.includeNumbers,
    required this.includeSpecial,
  });
}

class PasswordGeneratorDialog extends StatefulWidget {
  const PasswordGeneratorDialog({
    required this.currentLength,
    required this.currentUppercase,
    required this.currentLowercase,
    required this.currentNumbers,
    required this.currentSpecial,
    super.key,
  });

  final int currentLength;
  final bool currentUppercase;
  final bool currentLowercase;
  final bool currentNumbers;
  final bool currentSpecial;

  static Future<PasswordGeneratorResult?> show(
    BuildContext context, {
    required int currentLength,
    required bool currentUppercase,
    required bool currentLowercase,
    required bool currentNumbers,
    required bool currentSpecial,
  }) {
    return showModalBottomSheet<PasswordGeneratorResult>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder:
          (_) => PasswordGeneratorDialog(
            currentLength: currentLength,
            currentUppercase: currentUppercase,
            currentLowercase: currentLowercase,
            currentNumbers: currentNumbers,
            currentSpecial: currentSpecial,
          ),
    );
  }

  @override
  State<PasswordGeneratorDialog> createState() =>
      _PasswordGeneratorDialogState();
}

class _PasswordGeneratorDialogState extends State<PasswordGeneratorDialog> {
  late int _length;
  late bool _uppercase;
  late bool _lowercase;
  late bool _numbers;
  late bool _special;
  late String _password;

  final Zxcvbnm _zxcvbnm = Zxcvbnm(
    dictionaries: <Dictionaries>{...en.dictionaries, ...es.dictionaries},
  );

  @override
  void initState() {
    super.initState();
    _length = widget.currentLength;
    _uppercase = widget.currentUppercase;
    _lowercase = widget.currentLowercase;
    _numbers = widget.currentNumbers;
    _special = widget.currentSpecial;
    _password = generatePassword(
      upperCase: _uppercase,
      lowerCase: _lowercase,
      numeric: _numbers,
      special: _special,
      length: _length,
    );
  }

  void _regenerate() {
    _password = generatePassword(
      upperCase: _uppercase,
      lowerCase: _lowercase,
      numeric: _numbers,
      special: _special,
      length: _length,
    );
    setState(() {});
  }

  void _confirm() {
    Navigator.pop(
      context,
      PasswordGeneratorResult(
        password: _password,
        length: _length,
        includeUppercase: _uppercase,
        includeLowercase: _lowercase,
        includeNumbers: _numbers,
        includeSpecial: _special,
      ),
    );
  }

  Color _getStrengthColor(BuildContext context, int score) {
    switch (score) {
      case 0:
        return context.appColors.danger;
      case 1:
        return Colors.orange;
      case 2:
        return Colors.yellow[700]!;
      case 3:
        return Colors.lightGreen;
      case 4:
        return Colors.green;
      default:
        return context.appColors.secondaryText;
    }
  }

  String _getStrengthLabel(int score) {
    switch (score) {
      case 0:
        return tr("password_generator.very_weak");
      case 1:
        return tr("password_generator.weak");
      case 2:
        return tr("password_generator.fair");
      case 3:
        return tr("password_generator.strong");
      case 4:
        return tr("password_generator.very_strong");
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _zxcvbnm(_password);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: 24,
                bottom: 16,
                left: 24,
                right: 24,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr("add_entry.generator_title"),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.appColors.inputFill,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _password,
                            style: const TextStyle(
                              fontSize: 16,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _regenerate,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.teal, width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.refresh,
                            color: Colors.teal,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(tr("add_entry.security")),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: (result.score + 1) / 5,
                          color: _getStrengthColor(context, result.score),
                          backgroundColor: context.appColors.border,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getStrengthLabel(result.score),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        _length.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Slider(
                          value: _length.toDouble(),
                          min: 4,
                          max: 32,
                          activeColor: Colors.teal,
                          onChanged: (v) {
                            setState(() {
                              _length = v.toInt();
                            });
                          },
                          onChangeEnd: (v) {
                            _length = v.toInt();
                            _regenerate();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildToggle("A-Z", _uppercase, (v) {
                    _uppercase = v;
                    _regenerate();
                  }),
                  _buildToggle("a-z", _lowercase, (v) {
                    _lowercase = v;
                    _regenerate();
                  }),
                  _buildToggle("0-9", _numbers, (v) {
                    _numbers = v;
                    _regenerate();
                  }),
                  _buildToggle(tr("add_entry.special_characters"), _special, (
                    v,
                  ) {
                    _special = v;
                    _regenerate();
                  }),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        tr("icon_picker.cancel"),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        tr("add_entry.apply"),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(String label, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.teal,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
