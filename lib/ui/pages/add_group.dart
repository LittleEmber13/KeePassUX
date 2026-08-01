import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_events.dart';
import 'package:keepassux/bloc/entries/keepass_states.dart';
import 'package:keepassux/ui/widgets/group_app_bar.dart';
import 'package:keepassux/ui/widgets/custom_app_scroll.dart';
import 'package:keepassux/ui/widgets/loading_overlay.dart';
import 'package:keepassux/model/db_group.dart';
import 'package:keepassux/ui/theme/theme.dart';

class AddGroupPage extends StatefulWidget {
  const AddGroupPage({this.uuidGroup, this.group, super.key});

  final String? uuidGroup;
  final DbGroup? group;

  @override
  State<AddGroupPage> createState() => _AddGroupPageState();
}

class _AddGroupPageState extends State<AddGroupPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  TextEditingController titleController = TextEditingController();

  bool get _isEditing => widget.group != null;

  @override
  void initState() {
    super.initState();
    if (widget.group != null) {
      titleController.text = widget.group!.name;
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr("delete.title")),
        content: Text(tr("delete.confirm_group")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr("delete.cancel")),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<KeePassBloc>().add(
                DeleteGroup(groupUuid: widget.group!.uuid),
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
        if (state is KeePassAddGroupSuccess ||
            state is KeePassUpdateGroupSuccess ||
            state is KeePassDeleteGroupSuccess) {
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
                  ? tr("add_group.edit_group")
                  : tr("add_group.add_group"),
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
                      Text(tr("add_group.information")),
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
                          labelText: tr("add_group.title"),
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
                            UpdateGroup(
                              groupUuid: widget.group!.uuid,
                              name: titleController.text,
                            ),
                          );
                        } else {
                          context.read<KeePassBloc>().add(
                            AddGroup(
                              uuidGroup: widget.uuidGroup,
                              title: titleController.text,
                            ),
                          );
                        }
                      }
                    },
                    child: Text(
                      tr("add_group.save"),
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
}
