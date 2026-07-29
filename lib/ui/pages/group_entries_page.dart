import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';
import 'package:keepassux/ui/bloc/entries/keepass_bloc.dart';
import 'package:keepassux/ui/bloc/entries/keepass_events.dart';
import 'package:keepassux/ui/bloc/entries/keepass_states.dart';
import 'package:keepassux/ui/model/drag_item.dart';
import 'package:keepassux/ui/services/selection_mode_controller.dart';
import 'package:keepassux/ui/widgets/animated_entry_list.dart';
import 'package:keepassux/ui/widgets/group_app_bar.dart';
import 'package:keepassux/ui/widgets/custom_bottom_navigation_bar.dart';
import 'package:keepassux/ui/widgets/loading_overlay.dart';
import 'package:keepassux/ui/widgets/move_mode_bar.dart';
import 'package:keepassux/ui/pages/add_group.dart';

import '../model/db_group.dart';

class GroupEntriesPage extends StatefulWidget {
  const GroupEntriesPage({required this.uuidGroup, super.key});

  final String uuidGroup;

  @override
  State<GroupEntriesPage> createState() => _GroupEntriesPageState();
}

class _GroupEntriesPageState extends State<GroupEntriesPage> {
  DbGroup? group;
  DbGroup? _rootGroup;
  bool _isDragging = false;

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
    if (_selection.isSelecting &&
        _selection.sourceGroupUuid == widget.uuidGroup) {
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
    if (_rootGroup!.uuid == widget.uuidGroup) return null;
    return _rootGroup!.findParentOf(widget.uuidGroup);
  }

  void _moveEntry(String entryUuid, String fromUuid, String toUuid) {
    context.read<KeePassBloc>().add(
      MoveEntry(
        entryUuid: entryUuid,
        fromGroupUuid: fromUuid,
        toGroupUuid: toUuid,
      ),
    );
  }

  void _moveGroup(String groupUuid, String fromUuid, String toUuid) {
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
              hideExit: _selection.isSelecting,
              onTapEdit: group != null
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddGroupPage(group: group),
                        ),
                      );
                    }
                  : null,
            ),
          ),
        ),
      ),
      bottomNavigationBar: _selection.isActive
          ? MoveModeBar(currentGroupUuid: widget.uuidGroup)
          : CustomBottomNavigationBar(
              uuidGroup: widget.uuidGroup,
              selectedIndex: 0,
            ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 8),
            AnimatedEntryList(
              group: group,
              rootGroup: _rootGroup,
              enableSelection: true,
              onGroupTap: (g) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupEntriesPage(
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
                      builder: (context) => GroupEntriesPage(
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
                  _moveEntry(
                    draggedItem.uuid,
                    draggedItem.sourceGroupUuid,
                    parentGroup.uuid,
                  );
                } else {
                  _moveGroup(
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
