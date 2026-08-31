import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../services/desktop/tray_service.dart';
import '../state/app_controller.dart';
import '../state/providers.dart';
import 'tabs/logs_tab.dart';
import 'tabs/settings_tab.dart';
import 'tabs/test_center_tab.dart';
import 'widgets/header_status_bar.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WindowListener, TrayListener {
  late final AppController controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    controller = ref.read(appControllerProvider);
    windowManager.addListener(this);
    trayManager.addListener(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await controller.init();
    controller.addListener(_onControllerChanged);

    await TrayService.init(
      onOpen: () async {
        await windowManager.show();
        await windowManager.focus();
      },
      onTogglePause: () async {
        await controller.togglePause();
      },
      onExit: () async {
        await controller.serverManager.stopAll();
        await windowManager.setPreventClose(false);
        await windowManager.destroy();
      },
    );

    if (mounted) setState(() => _ready = true);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // Minimize to tray instead of exiting the process.
    await windowManager.hide();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: HeaderStatusBar(controller: controller),
        body: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.terminal), text: 'Live Logs'),
                Tab(icon: Icon(Icons.settings), text: 'Settings'),
                Tab(icon: Icon(Icons.science), text: 'Test Center'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  const LogsTab(),
                  SettingsTab(controller: controller),
                  TestCenterTab(controller: controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
