import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_events.dart';
import 'package:keepassux/bloc/entries/keepass_states.dart';
import 'package:keepassux/ui/pages/add_entry.dart';
import 'package:keepassux/ui/theme/theme.dart';
import 'package:keepassux/ui/widgets/custom_app_scroll.dart';
import 'package:keepassux/ui/widgets/kdbx_icon_widget.dart';

import '../../model/db_entry.dart';

class EntryData extends StatefulWidget {
  const EntryData({required this.entry, this.showDelete = true, super.key});

  final DbEntry entry;
  final bool showDelete;

  @override
  State<EntryData> createState() => _EntryDataState();
}

class _EntryDataState extends State<EntryData> {
  bool obscurePassword = true;

  late TextEditingController _titleController;
  late TextEditingController _userController;
  late TextEditingController _urlController;
  late TextEditingController _notesController;
  late TextEditingController _passwordController;

  final _inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: Colors.transparent, width: 1),
  );

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry.label);
    _userController = TextEditingController(text: widget.entry.userName);
    _urlController = TextEditingController(text: widget.entry.url);
    _notesController = TextEditingController(text: widget.entry.notes);
    _passwordController = TextEditingController(text: widget.entry.password);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _userController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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
                    DeleteEntry(entryUuid: widget.entry.uuid),
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

  void _openEditPage() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEntryPage(entry: widget.entry)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<KeePassBloc, KeePassState>(
      listener: (context, state) {
        if (state is KeePassDeleteEntrySuccess) {
          Navigator.pop(context);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: const Icon(Icons.arrow_back),
              ),
              const Spacer(),
              KDBXIconWidget(
                icon: widget.entry.icon,
                customIconData: widget.entry.customIconData,
                size: 27,
              ),
            ],
          ),
          const SizedBox(height: 24),
          CustomAppScroll(
            horizontalPadding: 0,
            children: [
              _buildField(
                controller: _titleController,
                label: tr("entry_data.title"),
                showCopy: true,
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: widget.entry.label));
                },
              ),
              _buildField(
                controller: _userController,
                label: tr("entry_data.user"),
                showCopy: true,
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: widget.entry.userName));
                },
              ),
              _buildField(
                controller: _passwordController,
                label: tr("entry_data.password"),
                showCopy: true,
                obscure: obscurePassword,
                onToggleObscure: () {
                  setState(() {
                    obscurePassword = !obscurePassword;
                  });
                },
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: widget.entry.password));
                },
              ),
              _buildField(
                controller: _urlController,
                label: tr("entry_data.url"),
                showCopy: true,
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: widget.entry.url));
                },
              ),
              _buildField(
                controller: _notesController,
                label: tr("entry_data.notes"),
                showCopy: false,
                maxLines: null,
              ),
              const SizedBox(height: 8),
            ],
          ),
          const SizedBox(height: 8),
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                    onPressed: _openEditPage,
                    child: Text(
                      tr("entry_data.edit"),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                if (widget.showDelete) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.appColors.danger,
                        side: BorderSide(color: context.appColors.danger),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _showDeleteDialog,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(
                        tr("delete.delete"),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    bool showCopy = true,
    bool? obscure,
    VoidCallback? onToggleObscure,
    VoidCallback? onCopy,
    int? maxLines,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              readOnly: true,
              obscureText: obscure ?? false,
              maxLines: (obscure == true) ? 1 : maxLines,
              decoration: InputDecoration(
                labelText: label,
                suffixIcon:
                    onToggleObscure != null
                        ? IconButton(
                          icon: Icon(
                            obscure == true
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: onToggleObscure,
                        )
                        : null,
                enabledBorder: _inputBorder,
                focusedBorder: _inputBorder,
                disabledBorder: _inputBorder,
              ),
            ),
          ),
          if (showCopy && onCopy != null) ...[
            const SizedBox(width: 16),
            InkWell(onTap: onCopy, child: const Icon(Icons.copy)),
          ],
        ],
      ),
    );
  }
}
