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

  late TextEditingController _notesController;

  final _inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: Colors.transparent, width: 1),
  );

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.entry.notes);
  }

  @override
  void dispose() {
    _notesController.dispose();
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
                value: widget.entry.label,
                label: tr("entry_data.title"),
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: widget.entry.label));
                },
              ),
              _buildField(
                value: widget.entry.userName,
                label: tr("entry_data.user"),
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: widget.entry.userName));
                },
              ),
              _buildField(
                value: widget.entry.password,
                label: tr("entry_data.password"),
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
                value: widget.entry.url,
                label: tr("entry_data.url"),
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: widget.entry.url));
                },
              ),
              _buildNotesField(),
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
    required String value,
    required String label,
    bool? obscure,
    VoidCallback? onToggleObscure,
    VoidCallback? onCopy,
  }) {
    final text = obscure == true ? '•' * value.length : value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: InputDecorator(
              isEmpty: value.isEmpty,
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
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
          if (onCopy != null) ...[
            const SizedBox(width: 16),
            InkWell(onTap: onCopy, child: const Icon(Icons.copy)),
          ],
        ],
      ),
    );
  }

  Widget _buildNotesField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: _notesController,
        readOnly: true,
        minLines: 2,
        maxLines: null,
        decoration: InputDecoration(
          labelText: tr("entry_data.notes"),
          enabledBorder: _inputBorder,
          focusedBorder: _inputBorder,
          disabledBorder: _inputBorder,
        ),
      ),
    );
  }
}
