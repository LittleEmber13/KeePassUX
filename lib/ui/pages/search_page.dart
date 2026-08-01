import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:keepassux/bloc/entries/keepass_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_events.dart';
import 'package:keepassux/bloc/entries/keepass_states.dart';
import 'package:keepassux/model/db_entry.dart';
import 'package:keepassux/model/db_group.dart';
import 'package:keepassux/ui/pages/group_entries_page.dart';
import 'package:keepassux/ui/widgets/custom_app_scroll.dart';
import 'package:keepassux/ui/widgets/entry_data.dart';
import 'package:keepassux/ui/widgets/kdbx_icon_widget.dart';
import 'package:keepassux/ui/widgets/loading_overlay.dart';
import 'package:keepassux/ui/theme/theme.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  DbGroup? _rootGroup;
  List<DbGroup> _filteredGroups = [];
  List<DbEntry> _filteredEntries = [];
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KeePassBloc>().add(GetRootGroup());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    if (_rootGroup == null || query.isEmpty) {
      setState(() {
        _query = query;
        _filteredGroups = [];
        _filteredEntries = [];
      });
      return;
    }

    final searchQuery = query.toLowerCase();

    final allGroups = <DbGroup>[];
    final allEntries = <DbEntry>[..._rootGroup!.entries];
    void collect(DbGroup parent) {
      for (final child in parent.groups) {
        if (child.isRecycleBin) continue;
        allGroups.add(child);
        allEntries.addAll(child.entries);
        collect(child);
      }
    }

    collect(_rootGroup!);

    setState(() {
      _query = query;
      _filteredGroups =
          allGroups
              .where((g) => g.name.toLowerCase().contains(searchQuery))
              .toList();
      _filteredEntries =
          allEntries
              .where((e) => e.label.toLowerCase().contains(searchQuery))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocConsumer<KeePassBloc, KeePassState>(
      listener: (context, state) {
        if (state is KeePassRootGroup) {
          setState(() {
            _rootGroup = state.rootGroup;
          });
          _performSearch(_searchController.text);
        }
      },
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                decoration: cardDecoration(context),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: _performSearch,
                          decoration: InputDecoration(
                            hintText: tr("search_page.hint"),
                            contentPadding: EdgeInsets.all(0),
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Icon(Icons.search),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child:
                  _query.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search,
                              size: 64,
                              color: context.appColors.secondaryText
                                  .withOpacity(0.5),
                            ),
                            SizedBox(height: 16),
                            Text(
                              tr("search_page.hint"),
                              style: TextStyle(
                                color: context.appColors.secondaryText,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                      : _filteredGroups.isEmpty && _filteredEntries.isEmpty
                      ? Center(
                        child: Text(
                          tr("search_page.no_results"),
                          style: TextStyle(
                            color: context.appColors.secondaryText,
                            fontSize: 16,
                          ),
                        ),
                      )
                      : CustomAppScroll(
                        children: [
                          if (_filteredGroups.isNotEmpty) ...[
                            ..._filteredGroups.map(
                              (group) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(FontAwesomeIcons.folder),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) => GroupEntriesPage(
                                                    uuidGroup: group.uuid,
                                                  ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          decoration: cardDecoration(context),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Text(group.name),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (_filteredEntries.isNotEmpty) ...[
                            ..._filteredEntries.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor:
                                          Theme.of(context).colorScheme.surface,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(20),
                                        ),
                                      ),
                                      isScrollControlled: true,
                                      builder: (BuildContext ctx) {
                                        return SizedBox(
                                          height:
                                              MediaQuery.of(
                                                context,
                                              ).size.height *
                                              0.75,
                                          child: BlocBuilder<
                                            KeePassBloc,
                                            KeePassState
                                          >(
                                            builder: (context, state) {
                                              return Stack(
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          24,
                                                        ),
                                                    child: EntryData(
                                                      entry: entry,
                                                    ),
                                                  ),
                                                  LoadingOverlay(
                                                    isLoading:
                                                        state is KeePassLoading,
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  child: Container(
                                    decoration: cardDecoration(context),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          KDBXIconWidget(
                                            icon: entry.icon,
                                            customIconData:
                                                entry.customIconData,
                                            size: 24,
                                            color: Colors.lightBlueAccent,
                                          ),
                                          SizedBox(width: 16),
                                          Text(entry.label),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
            ),
          ],
        );
      },
    );
  }
}
