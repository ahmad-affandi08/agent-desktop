import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/logger_service.dart';
import '../../models/app_config.dart';
import '../../models/log_entry.dart';
import 'windows_automation_script.dart';

class SidikJariService {
  final AppConfig Function() getConfig;

  SidikJariService({required this.getConfig});

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

  Future<bool> checkAppRunning() async {
    if (!Platform.isWindows) return false;
    try {
      final result = await Process.run('tasklist', []);
      return (result.stdout as String).toLowerCase().contains('after.exe');
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
  }) async {
    Process? process;
    try {
      LoggerService.instance.info(
        LogSource.sidikJari,
        'Menjalankan auto-fill terintegrasi...',
      );

      final encoded = base64.encode(
        utf16leBytes(windowsSidikJariAutomationScript),
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
          'RSSG_SIDIKJARI_USERNAME': username,
          'RSSG_SIDIKJARI_PASSWORD': password,
          'RSSG_SIDIKJARI_IDENTIFIER': identifier,
          'RSSG_SIDIKJARI_IDENTIFIER_TYPE': useBpjs ? 'BPJS' : 'NIK',
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
          LoggerService.instance.info(LogSource.sidikJari, line.trim());
        }
      }

      if (timedOut) {
        LoggerService.instance.error(
          LogSource.sidikJari,
          'Auto-fill dihentikan karena melewati batas waktu 60 detik.',
        );
        return false;
      }

      if (exitCode != 0) {
        LoggerService.instance.error(
          LogSource.sidikJari,
          stderr.isEmpty
              ? 'Auto-fill gagal dengan exit code $exitCode.'
              : 'Auto-fill gagal: $stderr',
        );
        return false;
      }

      if (!stdout.contains('RSSG_AUTOMATION_SUCCESS')) {
        LoggerService.instance.error(
          LogSource.sidikJari,
          'Auto-fill selesai tanpa konfirmasi keberhasilan.',
        );
        return false;
      }
      return true;
    } catch (error) {
      process?.kill();
      LoggerService.instance.error(
        LogSource.sidikJari,
        'Error menjalankan auto-fill terintegrasi: $error',
      );
      return false;
    }
  }

  Future<Map<String, dynamic>> openSidikJari({
    required String? nik,
    required String? noBpjs,
    required String? nama,
  }) async {
    final normalizedBpjs = noBpjs?.trim() ?? '';
    final normalizedNik = nik?.trim() ?? '';
    final identifier = normalizedBpjs.isNotEmpty
        ? normalizedBpjs
        : normalizedNik;

    LoggerService.instance.info(
      LogSource.sidikJari,
      'Request: nik=$nik, no_bpjs=$noBpjs, nama=$nama',
    );

    if (identifier.isEmpty) {
      LoggerService.instance.error(
        LogSource.sidikJari,
        'Request ditolak: NIK dan nomor BPJS kosong.',
      );
      return {'success': false, 'message': 'NIK atau nomor BPJS wajib diisi.'};
    }

    if (isDuplicateRequest(identifier)) {
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

    return _enqueue(
      () => _openSidikJariWindows(
        nik: normalizedNik,
        noBpjs: normalizedBpjs,
        identifier: identifier,
        useBpjs: normalizedBpjs.isNotEmpty,
      ),
    );
  }

  Future<Map<String, dynamic>> _openSidikJariWindows({
    required String nik,
    required String noBpjs,
    required String identifier,
    required bool useBpjs,
  }) async {
    final cfg = getConfig();

    try {
      final running = await checkAppRunning();

      if (!running) {
        if (!await File(cfg.afterExePath).exists()) {
          LoggerService.instance.error(
            LogSource.sidikJari,
            'After.exe tidak ditemukan di "${cfg.afterExePath}".',
          );
          return {
            'success': false,
            'message': 'After.exe tidak ditemukan. Cek path di Settings.',
          };
        }

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

      final berhasil = await runIntegratedAutomation(
        username: cfg.bpjsUsername,
        password: cfg.bpjsPassword,
        identifier: identifier,
        useBpjs: useBpjs,
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
      }

      isLoggedIn = false;
      LoggerService.instance.error(
        LogSource.sidikJari,
        'Automation SidikJari gagal untuk $identifier.',
      );
      return {'success': false, 'message': 'Automation gagal'};
    } catch (error) {
      isLoggedIn = false;
      LoggerService.instance.error(LogSource.sidikJari, 'Error: $error');
      return {'success': false, 'message': 'Server error'};
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
    try {
      final result = await Process.run('taskkill', ['/F', '/IM', 'After.exe']);
      isLoggedIn = false;
      if (result.exitCode != 0) {
        final error = (result.stderr as String).trim();
        LoggerService.instance.warning(
          LogSource.sidikJari,
          error.isEmpty ? 'After.exe tidak sedang berjalan.' : error,
        );
        return {'success': false, 'message': 'Aplikasi tidak sedang berjalan'};
      }
      LoggerService.instance.success(
        LogSource.sidikJari,
        'Aplikasi After.exe ditutup paksa.',
      );
      return {'success': true, 'message': 'Aplikasi ditutup'};
    } catch (error) {
      LoggerService.instance.error(
        LogSource.sidikJari,
        'Gagal menutup aplikasi: $error',
      );
      return {'success': false, 'message': 'Gagal menutup aplikasi'};
    }
  }

  Future<Map<String, dynamic>> health() async {
    final appRunning = await checkAppRunning();
    final cfg = getConfig();
    return {
      'status': 'berjalan',
      'service': 'Sidikjari Service (Integrated Windows Automation)',
      'port': cfg.sidikJariPort,
      'automation': 'integrated',
      'helper_required': false,
      'app_running': appRunning,
      'logged_in': isLoggedIn,
    };
  }
}
