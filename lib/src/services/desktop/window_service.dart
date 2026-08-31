import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Sets up the native window: fixed reasonable size, and intercepts the
/// close (X) button so it hides to the system tray instead of exiting.
class WindowService {
  static Future<void> init() async {
    await windowManager.ensureInitialized();

    const options = WindowOptions(
      size: Size(1100, 720),
      minimumSize: Size(900, 600),
      center: true,
      backgroundColor: Colors.transparent,
      title: 'RSSG Agent Desktop',
      titleBarStyle: TitleBarStyle.normal,
    );

    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    await windowManager.setPreventClose(true);
  }
}
