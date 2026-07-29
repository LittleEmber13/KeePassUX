import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:keepassux/ui/bloc/entries/keepass_bloc.dart';
import 'package:keepassux/ui/bloc/entries/keepass_events.dart';
import 'package:keepassux/ui/model/drag_item.dart';
import 'package:keepassux/ui/services/selection_mode_controller.dart';
import 'package:keepassux/ui/widgets/custom_app_scroll.dart';
import 'package:keepassux/ui/widgets/draggable_group_item.dart';
import 'package:keepassux/ui/widgets/fade_in_item.dart';
import 'package:keepassux/ui/widgets/draggable_entry_item.dart';
import 'package:keepassux/ui/widgets/trash_entry_item.dart';
import 'package:keepassux/ui/widgets/trash_group_item.dart';
import 'package:keepassux/ui/theme/theme.dart';

import '../model/db_entry.dart';
import '../model/db_group.dart';

class AnimatedEntryList extends StatefulWidget {
  const AnimatedEntryList({
    required this.group,
    required this.rootGroup,
    this.onGroupTap,
    this.onDragStarted,
    this.onDragEnded,
    this.parentGroup,
    this.showParentGroup = false,
    this.onParentGroupTap,
    this.onParentGroupDragAccept,
    this.trashGroup,
    this.isTrashMode = false,
    this.onDeleteEntry,
    this.onDeleteGroup,
    this.enableSelection = false,
    super.key,
  });

  final DbGroup? group;
  final DbGroup? rootGroup;
  final void Function(DbGroup group)? onGroupTap;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnded;
  final DbGroup? parentGroup;
  final bool showParentGroup;
  final VoidCallback? onParentGroupTap;
  final void Function(DragItem draggedItem)? onParentGroupDragAccept;
  final DbGroup? trashGroup;
  final bool isTrashMode;
  final void Function(String entryUuid)? onDeleteEntry;
  final void Function(String groupUuid)? onDeleteGroup;

  final bool enableSelection;

  @override
  State<AnimatedEntryList> createState() => _AnimatedEntryListState();
}

class _AnimatedEntryListState extends State<AnimatedEntryList> {
  final GlobalKey<AnimatedListState> _groupsListKey = GlobalKey<AnimatedListState>();
  final GlobalKey<AnimatedListState> _entriesListKey = GlobalKey<AnimatedListState>();

  List<DbGroup> _displayedGroups = [];
  List<DbEntry> _displayedEntries = [];
  bool _isDragging = false;

  SelectionModeController get _selection => SelectionModeController.instance;

  bool get _selectionActive => widget.enableSelection && _selection.isActive;

  @override
  void initState() {
    super.initState();
    _selection.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    _selection.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  bool get _trashHasItems {
    final trash = widget.trashGroup;
    if (trash == null) return false;
    return trash.entries.isNotEmpty || trash.groups.isNotEmpty;
  }

  void _handleDragStarted() {
    if (_selection.isActive) _selection.cancel();
    setState(() => _isDragging = true);
    widget.onDragStarted?.call();
  }

  void _activateSelection({String? entryUuid, String? groupUuid}) {
    if (!widget.enableSelection || widget.group == null) return;
    if (_selection.isActive) return;
    HapticFeedback.selectionClick();
    _selection.start(
      widget.group!.uuid,
      entryUuid: entryUuid,
      groupUuid: groupUuid,
    );
  }

  void _handleDragEnded() {
    setState(() => _isDragging = false);
    widget.onDragEnded?.call();
  }

  @override
  void didUpdateWidget(AnimatedEntryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.group != oldWidget.group) {
      _syncLists();
    }
  }

  void _syncLists() {
    if (widget.group == null) return;

    final newGroups = widget.isTrashMode
        ? widget.group!.groups.toList()
        : widget.group!.groups
            .where((g) => g.uuid != widget.trashGroup?.uuid)
            .toList();
    final newEntries = widget.group!.entries;

    _syncItems<DbGroup>(
      listKey: _groupsListKey,
      oldList: _displayedGroups,
      newList: newGroups,
      getUuid: (item) => item.uuid,
      onUpdated: (updated) => _displayedGroups = updated,
    );

    _syncItems<DbEntry>(
      listKey: _entriesListKey,
      oldList: _displayedEntries,
      newList: newEntries,
      getUuid: (item) => item.uuid,
      onUpdated: (updated) => _displayedEntries = updated,
    );
  }

  void _syncItems<T>({
    required GlobalKey<AnimatedListState> listKey,
    required List<T> oldList,
    required List<T> newList,
    required String Function(T) getUuid,
    required void Function(List<T>) onUpdated,
  }) {
    var oldUuids = oldList.map(getUuid).toList();
    final newUuids = newList.map(getUuid).toList();

    final itemsToRemove = <int>[];
    for (int i = oldUuids.length - 1; i >= 0; i--) {
      if (!newUuids.contains(oldUuids[i])) {
        itemsToRemove.add(i);
      }
    }

    for (final index in itemsToRemove) {
      final removedItem = oldList[index];
      listKey.currentState?.removeItem(
        index,
        (context, animation) => FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            child: _buildRemovedItem(removedItem),
          ),
        ),
        duration: const Duration(milliseconds: 300),
      );
      oldList.removeAt(index);
    }

    for (int i = 0; i < newList.length; i++) {
      final newItem = newList[i];
      final newItemUuid = getUuid(newItem);
      final oldIndex =
          oldList.indexWhere((item) => getUuid(item) == newItemUuid);
      if (oldIndex == -1) {
        listKey.currentState?.insertItem(i, duration: const Duration(milliseconds: 300));
        oldList.insert(i, newItem);
      } else if (oldIndex != i) {
        oldList.removeAt(oldIndex);
        oldList.insert(i, newItem);
      } else {
        oldList[i] = newItem;
      }
    }

    onUpdated(oldList);
  }

  Widget _buildRemovedItem(dynamic item) {
    if (item is DbGroup) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(FontAwesomeIcons.folder),
            SizedBox(width: 16),
            Expanded(
              child: Container(
                decoration: cardDecoration(context),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(item.name),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (item is DbEntry) {
      return DraggableEntryItem(
        entry: item,
        sourceGroupUuid: widget.group!.uuid,
        onDragStarted: null,
        onDragEnd: null,
      );
    }
    return SizedBox.shrink();
  }

  Widget _buildTrashGroupItem() {
    final trash = widget.trashGroup!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LongPressDraggable<DragItem>(
        data: DragItem(
          type: DragType.group,
          uuid: trash.uuid,
          sourceGroupUuid: widget.group!.uuid,
        ),
        onDragStarted: widget.onDragStarted,
        onDragUpdate: (details) =>
            DragAutoScroll.of(context)?.onDragUpdate(details.globalPosition),
        onDragEnd: (_) {
          DragAutoScroll.of(context)?.onDragEnd();
          widget.onDragEnded?.call();
        },
        feedback: _buildDragFeedback(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.7,
            decoration: BoxDecoration(
              color: context.appColors.cardBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Icon(
                    Icons.delete_outline,
                    color: context.appColors.secondaryText,
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.appColors.cardBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Text(trash.name),
                  ),
                ),
              ],
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.4,
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                color: context.appColors.secondaryText,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Container(
                  decoration: cardDecoration(context),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(trash.name),
                  ),
                ),
              ),
            ],
          ),
        ),
        child: DragTarget<DragItem>(
          onWillAccept: (draggedItem) {
            if (draggedItem == null) return false;
            if (draggedItem.type == DragType.group &&
                draggedItem.uuid == trash.uuid) {
              return false;
            }
            return true;
          },
          onAccept: (draggedItem) {
            _showMoveToTrashDialog(draggedItem);
          },
          builder: (context, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty;
            return Row(
              children: [
                Icon(
                  Icons.delete_outline,
                  color: context.appColors.secondaryText,
                ),
                SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: _selectionActive
                        ? null
                        : () => widget.onGroupTap?.call(trash),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      decoration: cardDecoration(context).copyWith(
                        color: isHovering
                            ? context.appColors.danger.withOpacity(0.1)
                            : null,
                        border: isHovering
                            ? Border.all(
                                color: context.appColors.danger,
                                width: 2,
                              )
                            : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(trash.name),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildParentGroupItem() {
    final parentGroup = widget.parentGroup!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DragTarget<DragItem>(
        onWillAcceptWithDetails: (details) {
          final draggedItem = details.data;
          if (draggedItem.type == DragType.group &&
              draggedItem.uuid == parentGroup.uuid) {
            return false;
          }
          return true;
        },
        onAcceptWithDetails: (details) {
          widget.onParentGroupDragAccept?.call(details.data);
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return Row(
            children: [
              Icon(FontAwesomeIcons.folder),
              SizedBox(width: 16),
              Expanded(
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  decoration: cardDecoration(context).copyWith(
                    color: isHovering
                        ? Colors.lightBlueAccent.withOpacity(0.15)
                        : context.appColors.cardBackground,
                    border: isHovering
                        ? Border.all(
                            color: Colors.lightBlueAccent,
                            width: 2,
                          )
                        : null,
                  ),
                  child: InkWell(
                    onTap: widget.onParentGroupTap,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text("..."),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDragFeedback({required Widget child}) {
    return Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: 0.85,
        child: Transform.scale(
          scale: 1.05,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: context.appColors.cardShadow,
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  void _showMoveToTrashDialog(DragItem draggedItem) {
    final isEntry = draggedItem.type == DragType.entry;
    final confirmMessage = isEntry
        ? tr("delete.confirm_entry")
        : tr("delete.confirm_group");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr("delete.title")),
        content: Text(confirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr("delete.cancel")),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (isEntry) {
                context.read<KeePassBloc>().add(
                  MoveEntry(
                    entryUuid: draggedItem.uuid,
                    fromGroupUuid: draggedItem.sourceGroupUuid,
                    toGroupUuid: widget.trashGroup!.uuid,
                  ),
                );
              } else {
                context.read<KeePassBloc>().add(
                  MoveGroup(
                    groupUuid: draggedItem.uuid,
                    fromGroupUuid: draggedItem.sourceGroupUuid,
                    toGroupUuid: widget.trashGroup!.uuid,
                  ),
                );
              }
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
    _syncLists();

    return CustomAppScroll(
      children: [
        if (!widget.isTrashMode &&
            widget.trashGroup != null &&
            (_trashHasItems || _isDragging))
          _buildTrashGroupItem(),
        if (widget.parentGroup != null)
          FadeInItem(
            child: widget.showParentGroup
                ? _buildParentGroupItem()
                : const SizedBox.shrink(),
          ),
        AnimatedList(
          key: _groupsListKey,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          initialItemCount: _displayedGroups.length,
          itemBuilder: (context, index, animation) {
            if (index >= _displayedGroups.length) {
              return SizedBox.shrink();
            }
            final currentGroup = _displayedGroups[index];
            if (widget.isTrashMode) {
              return SizeTransition(
                sizeFactor: animation,
              axisAlignment: -1.0,
                child: FadeTransition(
                  opacity: animation,
                  child: TrashGroupItem(
                    group: currentGroup,
                    sourceGroupUuid: widget.group!.uuid,
                    onTap: () => widget.onGroupTap?.call(currentGroup),
                    onDragStarted: widget.onDragStarted,
                    onDragEnd: widget.onDragEnded,
                    onDelete: () => widget.onDeleteGroup?.call(currentGroup.uuid),
                  ),
                ),
              );
            }
            final isGroupSelected = _selection.isGroupSelected(currentGroup.uuid);
            return SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1.0,
              child: FadeTransition(
                opacity: animation,
                child: DraggableGroupItem(
                  group: currentGroup,
                  sourceGroupUuid: widget.group!.uuid,
                  onTap: () => widget.onGroupTap?.call(currentGroup),
                  selectionEnabled: _selectionActive,
                  isSelected: isGroupSelected,
                  isTinted: isGroupSelected && _selection.isPasting,
                  isFaded:
                      isGroupSelected && _selection.isPasting && _selection.isCut,
                  onSelectionTap: _selection.isSelecting
                      ? () => _selection.toggleGroup(currentGroup.uuid)
                      : (_selection.isPasting && !isGroupSelected
                          ? () => widget.onGroupTap?.call(currentGroup)
                          : null),
                  onHoldSelect: widget.enableSelection
                      ? () => _activateSelection(groupUuid: currentGroup.uuid)
                      : null,
                  onDragStarted: _handleDragStarted,
                  onDragEnd: _handleDragEnded,
                  isDescendantOf: (ancestorUuid, descendantUuid) {
                    return widget.rootGroup
                            ?.findByUuid(ancestorUuid)
                            ?.isDescendantOf(descendantUuid) ??
                        false;
                  },
                  onAccept: (draggedItem) {
                    final currentGroupUuid = currentGroup.uuid;
                    if (draggedItem.type == DragType.entry) {
                      context.read<KeePassBloc>().add(
                        MoveEntry(
                          entryUuid: draggedItem.uuid,
                          fromGroupUuid: draggedItem.sourceGroupUuid,
                          toGroupUuid: currentGroupUuid,
                        ),
                      );
                    } else {
                      if (draggedItem.uuid == currentGroupUuid) return;
                      context.read<KeePassBloc>().add(
                        MoveGroup(
                          groupUuid: draggedItem.uuid,
                          fromGroupUuid: draggedItem.sourceGroupUuid,
                          toGroupUuid: currentGroupUuid,
                        ),
                      );
                    }
                  },
                ),
              ),
            );
          },
        ),
        AnimatedList(
          key: _entriesListKey,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          initialItemCount: _displayedEntries.length,
          itemBuilder: (context, index, animation) {
            if (index >= _displayedEntries.length) {
              return SizedBox.shrink();
            }
            final currentEntry = _displayedEntries[index];
            if (widget.isTrashMode) {
              return SizeTransition(
                sizeFactor: animation,
              axisAlignment: -1.0,
                child: FadeTransition(
                  opacity: animation,
                  child: TrashEntryItem(
                    entry: currentEntry,
                    sourceGroupUuid: widget.group!.uuid,
                    onDragStarted: widget.onDragStarted,
                    onDragEnd: widget.onDragEnded,
                  ),
                ),
              );
            }
            final isEntrySelected = _selection.isEntrySelected(currentEntry.uuid);
            return SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1.0,
              child: FadeTransition(
                opacity: animation,
                child: DraggableEntryItem(
                  entry: currentEntry,
                  sourceGroupUuid: widget.group!.uuid,
                  selectionEnabled: _selectionActive,
                  isSelected: isEntrySelected,
                  isTinted: isEntrySelected && _selection.isPasting,
                  isFaded:
                      isEntrySelected && _selection.isPasting && _selection.isCut,
                  onSelectionTap: _selection.isSelecting
                      ? () => _selection.toggleEntry(currentEntry.uuid)
                      : null,
                  onHoldSelect: widget.enableSelection
                      ? () => _activateSelection(entryUuid: currentEntry.uuid)
                      : null,
                  onDragStarted: _handleDragStarted,
                  onDragEnd: _handleDragEnded,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
