import 'package:flutter/foundation.dart';

import '../core/config_repository.dart';
import '../core/logger_service.dart';
import '../core/network_info.dart';
import '../models/app_config.dart';
import '../models/log_entry.dart';
import '../services/server/server_manager.dart';

/// Root app state: config, both HTTP servers, and derived status used by
/// the header bar / tabs. Plain ChangeNotifier so the UI can rebuild with a
/// simple ListenableBuilder, exposed to the tree via a Riverpod Provider.
class AppController extends ChangeNotifier {
  final ConfigRepository _repo = ConfigRepository();

  AppConfig config = const AppConfig();
  late final ServerManager serverManager;

  String localIp = '127.0.0.1';
  bool initialized = false;

  AppController() {
    serverManager = ServerManager(
      getConfig: () => config,
      onStatusChanged: notifyListeners,
    );
  }

  Future<void> init() async {
    config = await _repo.load();
    localIp = await NetworkInfo.localIPv4();
    initialized = true;
    notifyListeners();

    if (config.autoStartServers) {
      await serverManager.startAll();
    }
  }

  Future<void> saveConfig(AppConfig newConfig) async {
    config = newConfig;
    await _repo.save(config);
    LoggerService.instance.info(LogSource.system, 'Pengaturan disimpan.');
    notifyListeners();

    // Restart only the listeners that were already running, so new
    // ports/printer settings take effect without touching a service the
    // user deliberately left stopped.
    final wasPrintRunning = serverManager.printStatus == ServerStatus.running;
    final wasSidikJariRunning =
        serverManager.sidikJariStatus == ServerStatus.running;

    if (wasPrintRunning) {
      await serverManager.stopPrintServer();
      await serverManager.startPrintServer();
    }
    if (wasSidikJariRunning) {
      await serverManager.stopSidikJariServer();
      await serverManager.startSidikJariServer();
    }
  }

  /// Individually starts/stops the SilentPrint (port 3007) listener.
  Future<void> togglePrintServer() async {
    if (serverManager.printStatus == ServerStatus.running ||
        serverManager.printStatus == ServerStatus.starting) {
      await serverManager.stopPrintServer();
    } else {
      await serverManager.startPrintServer();
    }
  }

  /// Individually starts/stops the SidikJari (port 3009) listener.
  Future<void> toggleSidikJariServer() async {
    if (serverManager.sidikJariStatus == ServerStatus.running ||
        serverManager.sidikJariStatus == ServerStatus.starting) {
      await serverManager.stopSidikJariServer();
    } else {
      await serverManager.startSidikJariServer();
    }
  }

  /// Bulk start/stop used by the tray "Pause / Resume" menu item.
  Future<void> togglePause() async {
    if (serverManager.isAnyRunning) {
      await serverManager.stopAll();
      LoggerService.instance.warning(LogSource.system, 'Semua service dijeda.');
    } else {
      await serverManager.startAll();
      LoggerService.instance.success(LogSource.system, 'Semua service dilanjutkan.');
    }
  }

  Future<void> refreshLocalIp() async {
    localIp = await NetworkInfo.localIPv4();
    notifyListeners();
  }
}
