import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';
import 'package:keepassux/bloc/entries/keepass_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_events.dart';
import 'package:keepassux/bloc/entries/keepass_states.dart';
import 'package:keepassux/ui/pages/group_entries_page.dart';
import 'package:keepassux/ui/pages/trash_page.dart';
import 'package:keepassux/services/alert_service.dart';
import 'package:keepassux/services/biometric_service.dart';
import 'package:keepassux/ui/widgets/animated_entry_list.dart';
import 'package:keepassux/model/alert_item.dart';
import 'package:keepassux/ui/widgets/alert_stack.dart';
import 'package:keepassux/ui/widgets/fade_in_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../model/db_group.dart';

class EntriesTab extends StatefulWidget {
  const EntriesTab({super.key});

  @override
  State<EntriesTab> createState() => _EntriesTabState();
}

class _EntriesTabState extends State<EntriesTab>
    with AutomaticKeepAliveClientMixin {
  final AlertService _alertService = AlertService();
  final BiometricService _biometricService = BiometricService();

  DbGroup? group;
  DbGroup? _rootGroup;
  DbGroup? _trashGroup;
  List<AlertItem> _alerts = [];
  bool _hasBiometrics = false;
  bool _biometricLoginEnabled = false;
  late Future<void> _initFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initFuture = _initStateAsync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KeePassBloc>().add(GetRootGroup());
    });
  }

  Future<void> _initStateAsync() async {
    final prefs = await SharedPreferences.getInstance();
    _hasBiometrics = await _biometricService.canAuthenticate();
    _biometricLoginEnabled = prefs.getBool('biometric_login_enabled') ?? false;
  }

  Future<void> _loadAlerts(DbGroup? rootGroup) async {
    await _initFuture;
    final alerts = await _alertService.getAlerts(
      hasBiometrics: _hasBiometrics,
      biometricLoginEnabled: _biometricLoginEnabled,
      rootGroup: rootGroup,
    );
    if (!mounted) return;
    setState(() => _alerts = alerts);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocConsumer<KeePassBloc, KeePassState>(
      listener: (context, state) {
        if (state is KeePassRootGroup) {
          setState(() {
            _rootGroup = state.rootGroup;
            group = state.rootGroup;
            _trashGroup = state.rootGroup?.groups.firstWhereOrNull(
              (g) => g.isRecycleBin,
            );
          });
          _loadAlerts(state.rootGroup);
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
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 24, left: 24, right: 24),
              child: FadeInItem(
                child:
                    _alerts.isEmpty
                        ? const SizedBox.shrink()
                        : Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AlertStack(
                            alerts: _alerts,
                            onDismiss: (alertId) async {
                              await _alertService.dismissAlert(alertId);
                              setState(() {
                                _alerts =
                                    _alerts
                                        .where((a) => a.id != alertId)
                                        .toList();
                              });
                            },
                          ),
                        ),
              ),
            ),
            AnimatedEntryList(
              group: group,
              rootGroup: _rootGroup,
              trashGroup: _trashGroup,
              enableSelection: true,
              onGroupTap: (g) {
                if (g.isRecycleBin) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TrashPage()),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupEntriesPage(uuidGroup: g.uuid),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}
