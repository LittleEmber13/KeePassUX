import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';
import 'package:keepassux/bloc/entries/keepass_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_events.dart';
import 'package:keepassux/bloc/entries/keepass_states.dart';
import 'package:keepassux/model/db_group.dart';
import 'package:keepassux/model/drag_item.dart';
import 'package:keepassux/services/selection_mode_controller.dart';
import 'package:keepassux/ui/widgets/animated_entry_list.dart';
import 'package:keepassux/ui/widgets/group_app_bar.dart';
import 'package:keepassux/ui/widgets/trash_info_card.dart';
import 'package:keepassux/ui/widgets/custom_bottom_navigation_bar.dart';
import 'package:keepassux/ui/widgets/loading_overlay.dart';
import 'package:keepassux/ui/widgets/trash_selection_bar.dart';

class TrashGroupPage extends StatefulWidget {
  const TrashGroupPage({required this.uuidGroup, super.key});

  final String uuidGroup;

  @override
  State<TrashGroupPage> createState() => _TrashGroupPageState();
}

class _TrashGroupPageState extends State<TrashGroupPage> {
  DbGroup? group;
  DbGroup? _rootGroup;
  bool _isDragging = false;
  String? _pendingRestoreEntryUuid;
  String? _pendingRestoreGroupUuid;
  bool _pendingBulkRestore = false;

  SelectionModeController get _selection => SelectionModeController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KeePassBloc>().add(GetRootGroup());
    });
  }

  @override
  void dispose() {
    if (_selection.isTrash && _selection.sourceGroupUuid == widget.uuidGroup) {
      _selection.cancel();
    }
    super.dispose();
  }

  void _onDragStateChanged(bool dragging) {
    setState(() {
      _isDragging = dragging;
    });
  }

  DbGroup? _findParentGroup() {
    if (_rootGroup == null) return null;
    return _rootGroup!.findParentOf(widget.uuidGroup);
  }

  void _deleteEntry(String entryUuid) {
    context.read<KeePassBloc>().add(
      DeleteEntryPermanently(entryUuid: entryUuid),
    );
  }

  void _deleteGroup(String groupUuid) {
    context.read<KeePassBloc>().add(
      DeleteGroupPermanently(groupUuid: groupUuid),
    );
  }

  void _restoreEntryToPreviousGroup(String entryUuid) {
    _pendingRestoreEntryUuid = entryUuid;
    context.read<KeePassBloc>().add(RestoreEntry(entryUuid: entryUuid));
  }

  void _restoreGroupToPreviousGroup(String groupUuid) {
    _pendingRestoreGroupUuid = groupUuid;
    context.read<KeePassBloc>().add(RestoreGroup(groupUuid: groupUuid));
  }

  void _announceRestore() {
    final entryUuid = _pendingRestoreEntryUuid;
    final groupUuid = _pendingRestoreGroupUuid;
    final bulk = _pendingBulkRestore;
    _pendingRestoreEntryUuid = null;
    _pendingRestoreGroupUuid = null;
    _pendingBulkRestore = false;

    if (bulk) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr("trash.restored_items")),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final destination = entryUuid != null
        ? _rootGroup?.findGroupOfEntry(entryUuid)
        : (groupUuid != null ? _rootGroup?.findParentOf(groupUuid) : null);
    if (destination == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr("trash.restored_in", namedArgs: {"group": destination.name}),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _restoreEntry(String entryUuid, String fromUuid, String toUuid) {
    context.read<KeePassBloc>().add(
      MoveEntry(
        entryUuid: entryUuid,
        fromGroupUuid: fromUuid,
        toGroupUuid: toUuid,
      ),
    );
  }

  void _restoreGroup(String groupUuid, String fromUuid, String toUuid) {
    context.read<KeePassBloc>().add(
      MoveGroup(
        groupUuid: groupUuid,
        fromGroupUuid: fromUuid,
        toGroupUuid: toUuid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<KeePassBloc, KeePassState>(
      listener: (context, state) {
        if (state is KeePassRootGroup) {
          List<DbGroup> allGroups = state.rootGroup?.getAllGroups() ?? [];
          setState(() {
            _rootGroup = state.rootGroup;
            group = allGroups.firstWhereOrNull(
              (g) => g.uuid == widget.uuidGroup,
            );
          });
        }
        if (state is KeePassMoveSuccess) {
          _announceRestore();
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
        return ListenableBuilder(
          listenable: _selection,
          builder: (context, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                _page(),
                LoadingOverlay(isLoading: state is KeePassLoading),
              ],
            );
          },
        );
      },
    );
  }

  Widget _page() {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(100),
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
              title: group?.name ?? '',
              onTapExit: () => Navigator.pop(context),
              onTapCloseSelection:
                  _selection.isActive ? () => _selection.cancel() : null,
              selectionActive: _selection.isActive,
            ),
          ),
        ),
      ),
      bottomNavigationBar: _selection.isActive
          ? TrashSelectionBar(
              onRestore: () => _pendingBulkRestore = true,
            )
          : CustomBottomNavigationBar(
              uuidGroup: widget.uuidGroup,
              selectedIndex: 0,
            ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: TrashInfoCard(),
            ),
            const SizedBox(height: 8),
            AnimatedEntryList(
              group: group,
              rootGroup: _rootGroup,
              isTrashMode: true,
              enableSelection: true,
              onDeleteEntry: _deleteEntry,
              onDeleteGroup: _deleteGroup,
              onRestoreEntry: _restoreEntryToPreviousGroup,
              onRestoreGroup: _restoreGroupToPreviousGroup,
              onGroupTap: (g) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TrashGroupPage(
                      uuidGroup: g.uuid,
                    ),
                  ),
                );
              },
              onDragStarted: () => _onDragStateChanged(true),
              onDragEnded: () => _onDragStateChanged(false),
              parentGroup: _findParentGroup(),
              showParentGroup: _isDragging && _findParentGroup() != null,
              onParentGroupTap: () {
                final parentGroup = _findParentGroup();
                if (parentGroup != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TrashGroupPage(
                        uuidGroup: parentGroup.uuid,
                      ),
                    ),
                  );
                }
              },
              onParentGroupDragAccept: (draggedItem) {
                final parentGroup = _findParentGroup();
                if (parentGroup == null) return;
                if (draggedItem.type == DragType.entry) {
                  _restoreEntry(
                    draggedItem.uuid,
                    draggedItem.sourceGroupUuid,
                    parentGroup.uuid,
                  );
                } else {
                  _restoreGroup(
                    draggedItem.uuid,
                    draggedItem.sourceGroupUuid,
                    parentGroup.uuid,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
