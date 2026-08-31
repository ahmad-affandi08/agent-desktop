import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/logger_service.dart';
import '../../models/app_config.dart';
import '../../models/log_entry.dart';

/// Ports sidikjari-agent/index.js: process check, "NUCLEAR" PowerShell
/// window-focus trick, and the auto-fill helper launcher.
class SidikJariService {
  final AppConfig Function() getConfig;

  SidikJariService({required this.getConfig});

  bool isLoggedIn = false;
  final Map<String, DateTime> _recentRequests = {};

  /// A bare filename (the default, e.g. "sidikjari-autofill.exe") is
  /// resolved next to this agent's own executable — mirrors the original
  /// sidikjari-agent's `WORKING_DIR = path.dirname(process.execPath)`.
  /// An absolute (or explicitly relative) path from Settings is used as-is.
  String resolveHelperPath(String configured) {
    if (p.isAbsolute(configured) || configured.contains(p.separator)) {
      return configured;
    }
    final exeDir = p.dirname(Platform.resolvedExecutable);
    return p.join(exeDir, configured);
  }

  bool isDuplicateRequest(String identifier) {
    final now = DateTime.now();
    final last = _recentRequests[identifier];
    if (last != null && now.difference(last) < const Duration(seconds: 3)) {
      return true;
    }
    _recentRequests[identifier] = now;
    _recentRequests.removeWhere(
      (_, ts) => now.difference(ts) > const Duration(seconds: 10),
    );
    return false;
  }

  Future<bool> checkAppRunning() async {
    if (!Platform.isWindows) return false;
    try {
      final result = await Process.run(
        'tasklist',
        ['/FI', 'IMAGENAME eq After.exe'],
      );
      return (result.stdout as String).contains('After.exe');
    } catch (_) {
      return false;
    }
  }

  Future<void> forceFocusWindow() async {
    LoggerService.instance.info(
      LogSource.sidikJari,
      'Membawa window After.exe ke depan (mode NUCLEAR)...',
    );

    const psScript = r'''
    $code = '
      [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
      [DllImport("user32.dll")] public static extern int SetForegroundWindow(IntPtr hWnd);
      [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    '
    $type = Add-Type -MemberDefinition $code -Name Win32S -Namespace Native -PassThru
    $proc = Get-Process -Name "After" -ErrorAction SilentlyContinue
    if ($proc) {
        $hwnd = $proc.MainWindowHandle
        $type::ShowWindowAsync($hwnd, 6)
        Start-Sleep -Milliseconds 50
        $type::ShowWindowAsync($hwnd, 9)
        $type::SetWindowPos($hwnd, -1, 0, 0, 0, 0, 0x0043)
        $type::SetWindowPos($hwnd, -2, 0, 0, 0, 0, 0x0043)
        $type::SetForegroundWindow($hwnd)
    }
    ''';

    final encoded = base64.encode(utf16leBytes(psScript));

    try {
      await Process.run('powershell', ['-EncodedCommand', encoded]);
    } catch (e) {
      LoggerService.instance.warning(
        LogSource.sidikJari,
        'Gagal force focus window: $e',
      );
    }
  }

  static List<int> utf16leBytes(String s) {
    final bytes = <int>[];
    for (final codeUnit in s.codeUnits) {
      bytes.add(codeUnit & 0xFF);
      bytes.add((codeUnit >> 8) & 0xFF);
    }
    return bytes;
  }

  Future<bool> runHelper({
    required String username,
    required String password,
    required String noBpjs,
    required bool skipLogin,
  }) async {
    final cfg = getConfig();
    try {
      await forceFocusWindow();

      final helperPath = resolveHelperPath(cfg.helperExePath);

      if (!await File(helperPath).exists()) {
        LoggerService.instance.error(
          LogSource.sidikJari,
          'Helper tidak ditemukan di "$helperPath". Cek Settings > Path Helper Auto-Fill.',
        );
        return false;
      }

      LoggerService.instance.info(
        LogSource.sidikJari,
        'Menjalankan helper "$helperPath" (user=$username, skipLogin=$skipLogin)...',
      );

      final process = await Process.start(
        helperPath,
        [username, password, noBpjs, skipLogin.toString()],
        runInShell: true,
      );

      process.stdout.transform(utf8.decoder).listen((data) {
        final line = data.trim();
        if (line.isNotEmpty) {
          LoggerService.instance.info(LogSource.sidikJari, '[HELPER] $line');
        }
      });
      process.stderr.transform(utf8.decoder).listen((data) {
        final line = data.trim();
        if (line.isNotEmpty) {
          LoggerService.instance.error(LogSource.sidikJari, '[HELPER] $line');
        }
      });

      final code = await process.exitCode;
      LoggerService.instance.info(
        LogSource.sidikJari,
        'Helper selesai dengan exit code $code.',
      );
      return code == 0;
    } catch (e) {
      LoggerService.instance.error(
        LogSource.sidikJari,
        'Error menjalankan helper: $e',
      );
      return false;
    }
  }

  Future<Map<String, dynamic>> openSidikJari({
    required String? nik,
    required String? noBpjs,
    required String? nama,
  }) async {
    final identifier = (noBpjs?.isNotEmpty ?? false) ? noBpjs! : (nik ?? '');

    LoggerService.instance.info(
      LogSource.sidikJari,
      'Request: nik=$nik, no_bpjs=$noBpjs, nama=$nama',
    );

    if (identifier.isNotEmpty && isDuplicateRequest(identifier)) {
      LoggerService.instance.warning(
        LogSource.sidikJari,
        'Request duplikat diabaikan untuk $identifier.',
      );
      return {'success': true, 'message': 'Request duplicate diabaikan'};
    }

    if (!Platform.isWindows) {
      LoggerService.instance.warning(
        LogSource.sidikJari,
        'Automation SidikJari (After.exe) hanya didukung di Windows.',
      );
      return {
        'success': false,
        'message': 'SidikJari automation hanya didukung di Windows.',
      };
    }

    final cfg = getConfig();

    try {
      final running = await checkAppRunning();

      if (!running) {
        LoggerService.instance.info(
          LogSource.sidikJari,
          'Membuka aplikasi After.exe...',
        );
        await Process.start(
          cfg.afterExePath,
          [],
          mode: ProcessStartMode.detached,
        );
        isLoggedIn = false;
      } else {
        LoggerService.instance.info(
          LogSource.sidikJari,
          'Aplikasi sudah running, reuse instance.',
        );
      }

      final berhasil = await runHelper(
        username: cfg.bpjsUsername,
        password: cfg.bpjsPassword,
        noBpjs: identifier,
        skipLogin: isLoggedIn,
      );

      if (berhasil) {
        isLoggedIn = true;
        LoggerService.instance.success(
          LogSource.sidikJari,
          'Automation SidikJari sukses untuk $identifier.',
        );
        return {
          'success': true,
          'message': 'Sukses',
          'data': {'nik': nik, 'no_bpjs': noBpjs},
        };
      } else {
        LoggerService.instance.error(
          LogSource.sidikJari,
          'Automation SidikJari gagal untuk $identifier.',
        );
        return {'success': false, 'message': 'Automation gagal'};
      }
    } catch (e) {
      LoggerService.instance.error(LogSource.sidikJari, 'Error: $e');
      return {'success': false, 'message': 'Server error'};
    }
  }

  Future<Map<String, dynamic>> reset() async {
    if (!Platform.isWindows) {
      return {
        'success': false,
        'message': 'Reset hanya didukung di Windows.',
      };
    }
    try {
      await Process.run('taskkill', ['/F', '/IM', 'After.exe']);
      isLoggedIn = false;
      LoggerService.instance.success(
        LogSource.sidikJari,
        'Aplikasi After.exe ditutup paksa.',
      );
      return {'success': true, 'message': 'Aplikasi ditutup'};
    } catch (e) {
      LoggerService.instance.error(
        LogSource.sidikJari,
        'Gagal menutup aplikasi: $e',
      );
      return {'success': false, 'message': 'Gagal menutup aplikasi'};
    }
  }

  Future<Map<String, dynamic>> health() async {
    final appRunning = await checkAppRunning();
    final cfg = getConfig();
    return {
      'status': 'berjalan',
      'service': 'Sidikjari Service (Base64 Focus)',
      'port': cfg.sidikJariPort,
      'helper_path': resolveHelperPath(cfg.helperExePath),
      'app_running': appRunning,
      'logged_in': isLoggedIn,
    };
  }
}
