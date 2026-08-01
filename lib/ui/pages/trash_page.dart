import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';
import 'package:keepassux/bloc/entries/keepass_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_events.dart';
import 'package:keepassux/bloc/entries/keepass_states.dart';
import 'package:keepassux/model/db_group.dart';
import 'package:keepassux/model/drag_item.dart';
import 'package:keepassux/ui/pages/trash_group_page.dart';
import 'package:keepassux/ui/widgets/animated_entry_list.dart';
import 'package:keepassux/ui/widgets/group_app_bar.dart';
import 'package:keepassux/ui/widgets/trash_info_card.dart';
import 'package:keepassux/ui/widgets/custom_bottom_navigation_bar.dart';
import 'package:keepassux/ui/widgets/loading_overlay.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({this.uuidGroup, super.key});

  final String? uuidGroup;

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  DbGroup? group;
  DbGroup? _rootGroup;
  DbGroup? _trashGroup;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KeePassBloc>().add(GetRootGroup());
    });
  }

  void _onDragStateChanged(bool dragging) {
    setState(() {
      _isDragging = dragging;
    });
  }

  DbGroup? _findParentGroup() {
    if (_rootGroup == null) return null;
    if (_rootGroup!.uuid == widget.uuidGroup) return null;
    return _rootGroup!.findParentOf(widget.uuidGroup ?? _trashGroup?.uuid ?? '');
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
            _trashGroup = state.rootGroup?.groups.firstWhereOrNull(
              (g) => g.isRecycleBin,
            );
            if (widget.uuidGroup == null) {
              group = _trashGroup;
            } else {
              group = allGroups.firstWhereOrNull(
                (g) => g.uuid == widget.uuidGroup,
              );
            }
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
              title: group?.name ?? tr("app_bar.trash"),
              onTapExit: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
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
              onDeleteEntry: _deleteEntry,
              onDeleteGroup: _deleteGroup,
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
