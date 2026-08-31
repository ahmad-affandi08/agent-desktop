import 'dart:io';

import 'package:tray_manager/tray_manager.dart';

class TrayService {
  static Future<void> init({
    required Future<void> Function() onOpen,
    required Future<void> Function() onTogglePause,
    required Future<void> Function() onExit,
  }) async {
    final iconPath = Platform.isWindows ? 'assets/tray_icon.ico' : 'assets/tray_icon.png';
    await trayManager.setIcon(iconPath);

    // setToolTip isn't implemented by the Linux tray_manager backend; guard
    // it (and setTitle, also platform-dependent) so init never crashes here.
    try {
      await trayManager.setToolTip('RSSG Agent Desktop');
    } catch (_) {}
    try {
      await trayManager.setTitle('RSSG Agent Desktop');
    } catch (_) {}

    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: 'open',
            label: 'Open Control Center',
            onClick: (_) => onOpen(),
          ),
          MenuItem(
            key: 'pause',
            label: 'Pause / Resume Services',
            onClick: (_) => onTogglePause(),
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit',
            label: 'Exit',
            onClick: (_) => onExit(),
          ),
        ],
      ),
    );
  }
}
