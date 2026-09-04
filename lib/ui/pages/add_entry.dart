import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_events.dart';
import 'package:keepassux/bloc/entries/keepass_states.dart';
import 'package:keepassux/ui/widgets/icon_picker_dialog.dart';
import 'package:keepassux/ui/widgets/password_generator_dialog.dart';
import 'package:keepassux/ui/widgets/kdbx_icon_widget.dart';
import 'package:keepassux/ui/widgets/group_app_bar.dart';
import 'package:keepassux/ui/widgets/custom_app_scroll.dart';
import 'package:keepassux/ui/widgets/loading_overlay.dart';
import 'package:keepassux/model/db_entry.dart';
import 'package:keepassux/ui/theme/theme.dart';

class AddEntryPage extends StatefulWidget {
  const AddEntryPage({
    this.uuidGroup,
    this.entry,
    this.prefillTitle,
    this.prefillUsername,
    this.prefillPassword,
    this.prefillUrl,
    super.key,
  });

  final String? uuidGroup;
  final DbEntry? entry;
  final String? prefillTitle;
  final String? prefillUsername;
  final String? prefillPassword;
  final String? prefillUrl;

  @override
  State<AddEntryPage> createState() => _AddEntryPageState();
}

class _AddEntryPageState extends State<AddEntryPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  int passwordLength = 14;
  bool includeUppercase = true;
  bool includeLowercase = true;
  bool includeNumbers = true;
  bool includeSpecial = false;

  TextEditingController titleController = TextEditingController();
  TextEditingController userController = TextEditingController();
  TextEditingController urlController = TextEditingController();
  TextEditingController notesController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;

  int? _selectedIcon;
  Uint8List? _selectedCustomIconData;

  bool get _isEditing => widget.entry != null;

  final OutlineInputBorder _inputBorder = const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide(color: Colors.transparent, width: 1),
  );

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      final e = widget.entry!;
      titleController.text = e.label;
      userController.text = e.userName;
      urlController.text = e.url;
      notesController.text = e.notes;
      passwordController.text = e.password;
      _selectedIcon = e.icon;
      _selectedCustomIconData = e.customIconData;
    } else {
      titleController.text = widget.prefillTitle ?? '';
      userController.text = widget.prefillUsername ?? '';
      urlController.text = widget.prefillUrl ?? '';
      passwordController.text = widget.prefillPassword ?? '';
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    userController.dispose();
    urlController.dispose();
    notesController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _openIconPicker() async {
    final result = await IconPickerDialog.show(
      context,
      currentIcon: _selectedIcon ?? widget.entry?.icon ?? 0,
      currentCustomIconData:
          _selectedCustomIconData ?? widget.entry?.customIconData,
    );
    if (result != null) {
      setState(() {
        _selectedIcon = result.icon;
        _selectedCustomIconData = result.customIconData;
      });
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr("delete.title")),
        content: Text(tr("delete.confirm_entry")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr("delete.cancel")),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<KeePassBloc>().add(
                DeleteEntry(entryUuid: widget.entry!.uuid),
              );
            },
            child: Text(
              tr("delete.delete"),
              style: TextStyle(color: context.appColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<KeePassBloc, KeePassState>(
      listener: (context, state) {
        if (state is KeePassAddEntrySuccess ||
            state is KeePassUpdateEntrySuccess ||
            state is KeePassDeleteEntrySuccess) {
          Navigator.pop(context);
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
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(116),
        child: Container(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.only(
              top: 52,
              bottom: 6,
              left: 24,
              right: 24,
            ),
            child: GroupAppBar(
              onTapExit: () {
                Navigator.pop(context);
              },
              onTapDelete: _isEditing ? _showDeleteDialog : null,
              title: _isEditing
                  ? tr("add_entry.edit_entry")
                  : tr("add_entry.add_entry"),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              CustomAppScroll(
                children: [
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: _openIconPicker,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.teal,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: KDBXIconWidget(
                                  icon: _selectedIcon ?? widget.entry?.icon ?? 0,
                                  customIconData:
                                      _selectedCustomIconData ??
                                      widget.entry?.customIconData,
                                  size: 27,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: _openIconPicker,
                              child: Text(tr("add_entry.edit_icon")),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: titleController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return tr("form_error.required");
                            }
                            return null;
                          },
                          maxLines: 1,
                          decoration: InputDecoration(
                            labelText: tr("add_entry.title"),
                            enabledBorder: _inputBorder,
                            focusedBorder: _inputBorder,
                            disabledBorder: _inputBorder,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: userController,
                          maxLines: 1,
                          decoration: InputDecoration(
                            labelText: tr("add_entry.user"),
                            enabledBorder: _inputBorder,
                            focusedBorder: _inputBorder,
                            disabledBorder: _inputBorder,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: passwordController,
                                obscureText: obscurePassword,
                                decoration: InputDecoration(
                                  labelText: tr("add_entry.password_hint"),
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
                                  enabledBorder: _inputBorder,
                                  focusedBorder: _inputBorder,
                                  disabledBorder: _inputBorder,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _openPasswordGeneratorDialog,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.teal,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.casino_outlined,
                                  color: Colors.teal,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: urlController,
                          maxLines: 1,
                          decoration: InputDecoration(
                            labelText: tr("add_entry.url"),
                            enabledBorder: _inputBorder,
                            focusedBorder: _inputBorder,
                            disabledBorder: _inputBorder,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: notesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: tr("add_entry.notes"),
                            enabledBorder: _inputBorder,
                            focusedBorder: _inputBorder,
                            disabledBorder: _inputBorder,
                          ),
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
                          if (_isEditing) {
                            context.read<KeePassBloc>().add(
                              UpdateEntry(
                                entryUuid: widget.entry!.uuid,
                                title: titleController.text,
                                userName: userController.text,
                                url: urlController.text,
                                notes: notesController.text,
                                password: passwordController.text,
                                icon: _selectedIcon,
                                customIconData: _selectedCustomIconData,
                              ),
                            );
                          } else {
                            context.read<KeePassBloc>().add(
                              AddEntry(
                                uuidGroup: widget.uuidGroup,
                                title: titleController.text,
                                userName: userController.text,
                                url: urlController.text,
                                notes: notesController.text,
                                password: passwordController.text,
                                icon: _selectedIcon,
                                customIconData: _selectedCustomIconData,
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        tr("add_entry.save"),
                        style: TextStyle(fontSize: 16),
                      ),
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

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(context),
      child: child,
    );
  }

  Future<void> _openPasswordGeneratorDialog() async {
    final result = await PasswordGeneratorDialog.show(
      context,
      currentLength: passwordLength,
      currentUppercase: includeUppercase,
      currentLowercase: includeLowercase,
      currentNumbers: includeNumbers,
      currentSpecial: includeSpecial,
    );
    if (result != null) {
      setState(() {
        passwordLength = result.length;
        includeUppercase = result.includeUppercase;
        includeLowercase = result.includeLowercase;
        includeNumbers = result.includeNumbers;
        includeSpecial = result.includeSpecial;
        passwordController.text = result.password;
      });
    }
  }
}
