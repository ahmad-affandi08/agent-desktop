import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/logger_service.dart';
import '../../models/app_config.dart';
import '../../models/log_entry.dart';
import 'windows_frista_automation_script.dart';

class FristaService {
  final AppConfig Function() getConfig;

  FristaService({required this.getConfig});

  bool isLoggedIn = false;
  final Map<String, DateTime> _recentRequests = {};
  Future<void> _automationTail = Future<void>.value();

  bool isDuplicateRequest(String identifier) {
    final now = DateTime.now();
    final last = _recentRequests[identifier];
    if (last != null && now.difference(last) < const Duration(milliseconds: 1500)) {
      return true;
    }
    _recentRequests[identifier] = now;
    _recentRequests.removeWhere(
      (_, ts) => now.difference(ts) > const Duration(seconds: 10),
    );
    return false;
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = Completer<T>();
    final previous = _automationTail;
    final finished = Completer<void>();
    _automationTail = finished.future;

    () async {
      try {
        await previous;
      } catch (_) {
      }

      try {
        result.complete(await action());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      } finally {
        finished.complete();
      }
    }();

    return result.future;
  }

  Future<String?> resolveFristaExePath() async {
    final cfg = getConfig();
    final configured = cfg.fristaExePath.replaceAll('"', '').trim();
    if (configured.isNotEmpty && await File(configured).exists()) {
      return configured;
    }

    final userProfile = Platform.environment['USERPROFILE'] ?? '';
    final candidates = <String>[
      if (userProfile.isNotEmpty) ...[
        '$userProfile\\Documents\\frista.v.3.0.1\\frista.exe',
        '$userProfile\\Documents\\frista\\frista.exe',
        '$userProfile\\Documents\\frista.exe',
        '$userProfile\\Desktop\\frista.v.3.0.1\\frista.exe',
        '$userProfile\\Desktop\\frista\\frista.exe',
        '$userProfile\\Desktop\\frista.exe',
        '$userProfile\\Downloads\\frista.v.3.0.1\\frista.exe',
        '$userProfile\\Downloads\\frista\\frista.exe',
        '$userProfile\\Downloads\\frista.exe',
      ],
      r'C:\frista\frista.exe',
      r'C:\frista.v.3.0.1\frista.exe',
      r'C:\Program Files\frista\frista.exe',
      r'C:\Program Files (x86)\frista\frista.exe',
    ];

    for (final candidate in candidates) {
      if (await File(candidate).exists()) {
        return candidate;
      }
    }

    if (userProfile.isNotEmpty) {
      final docsDir = Directory('$userProfile\\Documents');
      if (await docsDir.exists()) {
        try {
          await for (final entity in docsDir.list(recursive: true, followLinks: false)) {
            if (entity is File && entity.path.toLowerCase().endsWith('frista.exe')) {
              return entity.path;
            }
          }
        } catch (_) {}
      }
    }

    return null;
  }

  Future<bool> checkAppRunning() async {
    if (!Platform.isWindows) return false;
    final cfg = getConfig();
    final processName = cfg.fristaProcessName.isEmpty ? 'frista.exe' : cfg.fristaProcessName;
    try {
      final result = await Process.run('tasklist', []);
      final output = (result.stdout as String).toLowerCase();
      final baseName = processName.replaceAll('.exe', '').toLowerCase();
      return output.contains(baseName);
    } catch (_) {
      return false;
    }
  }

  static List<int> utf16leBytes(String value) {
    final bytes = <int>[];
    for (final codeUnit in value.codeUnits) {
      bytes.add(codeUnit & 0xFF);
      bytes.add((codeUnit >> 8) & 0xFF);
    }
    return bytes;
  }

  Future<bool> runIntegratedAutomation({
    required String username,
    required String password,
    required String identifier,
    required bool useBpjs,
    bool isDualMode = false,
  }) async {
    Process? process;
    final cfg = getConfig();
    try {
      LoggerService.instance.info(
        LogSource.frista,
        'Menjalankan auto-fill FRISTA terintegrasi...',
      );

      final encoded = base64.encode(
        utf16leBytes(windowsFristaAutomationScript),
      );
      process = await Process.start(
        'powershell.exe',
        [
          '-NoLogo',
          '-NoProfile',
          '-NonInteractive',
          '-STA',
          '-WindowStyle',
          'Hidden',
          '-EncodedCommand',
          encoded,
        ],
        environment: {
          'RSSG_FRISTA_USERNAME': username,
          'RSSG_FRISTA_PASSWORD': password,
          'RSSG_FRISTA_IDENTIFIER': identifier,
          'RSSG_FRISTA_IDENTIFIER_TYPE': useBpjs ? 'BPJS' : 'NIK',
          'RSSG_FRISTA_WINDOW_TITLE': cfg.fristaWindowTitle,
          'RSSG_FRISTA_POS_X': isDualMode ? '685' : '100',
          'RSSG_FRISTA_POS_Y': isDualMode ? '0' : '30',
          'RSSG_FRISTA_WIDTH': isDualMode ? '680' : '850',
          'RSSG_FRISTA_HEIGHT': isDualMode ? '520' : '550',
        },
        includeParentEnvironment: true,
        runInShell: false,
      );

      final stdoutFuture = process.stdout.transform(utf8.decoder).join();
      final stderrFuture = process.stderr.transform(utf8.decoder).join();
      var timedOut = false;
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          timedOut = true;
          process?.kill();
          return -1;
        },
      );
      final stdout = (await stdoutFuture).trim();
      final stderr = (await stderrFuture).trim();

      for (final line in const LineSplitter().convert(stdout)) {
        if (line.trim().isNotEmpty) {
          LoggerService.instance.info(LogSource.frista, line.trim());
        }
      }

      if (timedOut) {
        LoggerService.instance.error(
          LogSource.frista,
          'Auto-fill FRISTA dihentikan karena batas waktu 60 detik terlampaui.',
        );
        return false;
      }

      if (exitCode != 0) {
        LoggerService.instance.error(
          LogSource.frista,
          stderr.isEmpty
              ? 'Auto-fill FRISTA gagal dengan exit code $exitCode.'
              : 'Auto-fill FRISTA gagal: $stderr',
        );
        return false;
      }

      if (!stdout.contains('RSSG_AUTOMATION_SUCCESS')) {
        LoggerService.instance.error(
          LogSource.frista,
          'Auto-fill FRISTA selesai tanpa konfirmasi keberhasilan.',
        );
        return false;
      }
      return true;
    } catch (error) {
      process?.kill();
      LoggerService.instance.error(
        LogSource.frista,
        'Error menjalankan auto-fill FRISTA: $error',
      );
      return false;
    }
  }

  Future<Map<String, dynamic>> openFrista({
    required String? nik,
    required String? noBpjs,
    required String? nama,
    bool isDualMode = false,
  }) async {
    final normalizedBpjs = noBpjs?.trim() ?? '';
    final normalizedNik = nik?.trim() ?? '';
    final identifier = normalizedNik.isNotEmpty
        ? normalizedNik
        : normalizedBpjs;

    LoggerService.instance.info(
      LogSource.frista,
      'Request FRISTA: nik=$nik, no_bpjs=$noBpjs, nama=$nama',
    );

    if (identifier.isEmpty) {
      LoggerService.instance.error(
        LogSource.frista,
        'Request ditolak: NIK dan nomor BPJS kosong.',
      );
      return {'success': false, 'message': 'NIK atau nomor BPJS wajib diisi.'};
    }

    if (isDuplicateRequest(identifier)) {
      LoggerService.instance.warning(
        LogSource.frista,
        'Request duplikat diabaikan untuk $identifier.',
      );
      return {'success': true, 'message': 'Request duplicate diabaikan'};
    }

    if (!Platform.isWindows) {
      LoggerService.instance.warning(
        LogSource.frista,
        'Automation FRISTA hanya didukung di Windows.',
      );
      return {
        'success': false,
        'message': 'FRISTA automation hanya didukung di Windows.',
      };
    }

    return _enqueue(
      () => _openFristaWindows(
        nik: normalizedNik,
        noBpjs: normalizedBpjs,
        identifier: identifier,
        useBpjs: normalizedBpjs.isNotEmpty && normalizedNik.isEmpty,
        isDualMode: isDualMode,
      ),
    );
  }

  Future<Map<String, dynamic>> _openFristaWindows({
    required String nik,
    required String noBpjs,
    required String identifier,
    required bool useBpjs,
    bool isDualMode = false,
  }) async {
    final cfg = getConfig();

    try {
      final running = await checkAppRunning();

      if (!running) {
        final resolvedExe = await resolveFristaExePath();
        if (resolvedExe == null) {
          LoggerService.instance.error(
            LogSource.frista,
            'Aplikasi FRISTA tidak ditemukan di "${cfg.fristaExePath}". Cek path di Settings.',
          );
          return {
            'success': false,
            'message': 'Aplikasi FRISTA tidak ditemukan. Cek path di Settings.',
          };
        }

        LoggerService.instance.info(
          LogSource.frista,
          'Membuka aplikasi FRISTA ($resolvedExe)...',
        );
        await Process.start(
          resolvedExe,
          [],
          mode: ProcessStartMode.detached,
        );
        isLoggedIn = false;
        await Future.delayed(const Duration(milliseconds: 1500));
      } else {
        LoggerService.instance.info(
          LogSource.frista,
          'Aplikasi FRISTA sudah running, menggunakan instance aktif.',
        );
      }

      final berhasil = await runIntegratedAutomation(
        username: cfg.fristaUsername,
        password: cfg.fristaPassword,
        identifier: identifier,
        useBpjs: useBpjs,
        isDualMode: isDualMode,
      );

      if (berhasil) {
        isLoggedIn = true;
        LoggerService.instance.success(
          LogSource.frista,
          'Automation FRISTA sukses untuk $identifier.',
        );
        return {
          'success': true,
          'message': 'Sukses',
          'data': {'nik': nik, 'no_bpjs': noBpjs},
        };
      }

      isLoggedIn = false;
      LoggerService.instance.error(
        LogSource.frista,
        'Automation FRISTA gagal untuk $identifier.',
      );
      return {'success': false, 'message': 'Automation FRISTA gagal'};
    } catch (error) {
      isLoggedIn = false;
      LoggerService.instance.error(LogSource.frista, 'Error: $error');
      return {'success': false, 'message': 'Server error: $error'};
    }
  }

  Future<Map<String, dynamic>> reset() {
    if (!Platform.isWindows) {
      return Future.value({
        'success': false,
        'message': 'Reset hanya didukung di Windows.',
      });
    }
    return _enqueue(_resetWindows);
  }

  Future<Map<String, dynamic>> _resetWindows() async {
    final cfg = getConfig();
    final processName = cfg.fristaProcessName.isEmpty ? 'frista.exe' : cfg.fristaProcessName;
    try {
      final result = await Process.run('taskkill', ['/F', '/IM', processName]);
      isLoggedIn = false;
      if (result.exitCode != 0) {
        final error = (result.stderr as String).trim();
        LoggerService.instance.warning(
          LogSource.frista,
          'Reset FRISTA: $error',
        );
      } else {
        LoggerService.instance.success(
          LogSource.frista,
          'Proses FRISTA berhasil dihentikan.',
        );
      }
      return {
        'success': true,
        'message': 'Proses FRISTA dihentikan.',
      };
    } catch (error) {
      LoggerService.instance.error(
        LogSource.frista,
        'Gagal menghentikan FRISTA: $error',
      );
      return {
        'success': false,
        'message': 'Gagal reset FRISTA: $error',
      };
    }
  }

  Future<Map<String, dynamic>> health() async {
    final cfg = getConfig();
    final running = await checkAppRunning();
    final resolved = await resolveFristaExePath();
    return {
      'status': running ? 'running' : 'stopped',
      'configured_path': cfg.fristaExePath,
      'resolved_path': resolved,
      'exists': resolved != null,
      'window_title': cfg.fristaWindowTitle,
      'process_name': cfg.fristaProcessName,
      'is_logged_in': isLoggedIn,
    };
  }
}
