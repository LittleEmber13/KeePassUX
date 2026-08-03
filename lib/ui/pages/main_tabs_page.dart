import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_events.dart';
import 'package:keepassux/bloc/entries/keepass_states.dart';
import 'package:keepassux/ui/pages/about_page.dart';
import 'package:keepassux/ui/pages/entries_page.dart';
import 'package:keepassux/ui/pages/search_page.dart';
import 'package:keepassux/ui/pages/settings_page.dart';
import 'package:keepassux/ui/pages/start_page.dart';
import 'package:keepassux/services/auto_lock_controller.dart';
import 'package:keepassux/services/selection_mode_controller.dart';
import 'package:keepassux/ui/widgets/custom_bottom_navigation_bar.dart';
import 'package:keepassux/ui/widgets/loading_overlay.dart';
import 'package:keepassux/ui/widgets/move_mode_bar.dart';
import 'package:keepassux/ui/widgets/root_app_bar.dart';

class MainTabsPage extends StatefulWidget {
  const MainTabsPage({this.initialIndex = 0, super.key});

  final int initialIndex;

  @override
  State<MainTabsPage> createState() => _MainTabsPageState();
}

class _MainTabsPageState extends State<MainTabsPage>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  late int _currentIndex;
  Timer? _autoLockTimer;

  static const List<String> _titleKeys = [
    "entries_page.title",
    "search_page.title",
    "about_page.title",
    "settings_page.title",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _startAutoLockTimer();
  }

  @override
  void dispose() {
    _autoLockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoLockTimer() {
    _autoLockTimer?.cancel();
    _autoLockTimer = Timer.periodic(AutoLockController.checkInterval, (_) {
      if (autoLock.isExpired()) _lockAndLeave();
    });
  }

  void _lockAndLeave() {
    _autoLockTimer?.cancel();
    if (!mounted) return;
    context.read<KeePassBloc>().add(LockDatabase());
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => StartPage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _autoLockTimer?.cancel();
      return;
    }
    if (autoLock.isExpired()) {
      _lockAndLeave();
      return;
    }
    autoLock.registerInteraction();
    _startAutoLockTimer();
    context.read<KeePassBloc>().add(ReloadDatabase());
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  SelectionModeController get _selection => SelectionModeController.instance;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<KeePassBloc, KeePassState>(
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      bottomNavigationBar: _selection.isActive && !_selection.isTrash
          ? MoveModeBar(currentGroupUuid: null)
          : CustomBottomNavigationBar(
              selectedIndex: _currentIndex,
              onTabSelected: _onTabSelected,
            ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: 28,
                bottom: 6,
                left: 24,
                right: 24,
              ),
              child: RootAppBar(
                isExit: true,
                title: tr(_titleKeys[_currentIndex]),
                onTapExit: _lockAndLeave,
                onTapCloseSelection: _currentIndex == 0 && _selection.isActive
                    ? () => _selection.cancel()
                    : null,
                selectionActive: _selection.isActive,
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: _selection.isActive
                    ? const NeverScrollableScrollPhysics()
                    : null,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                children: const [
                  EntriesTab(),
                  SearchTab(),
                  AboutTab(),
                  SettingsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
