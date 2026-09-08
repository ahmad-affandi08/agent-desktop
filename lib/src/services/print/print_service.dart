import 'dart:async';
import 'dart:io';

import '../../core/logger_service.dart';
import '../../models/app_config.dart';
import '../../models/log_entry.dart';
import 'escpos_builder.dart';
import 'printer_driver.dart';
import 'zpl_builder.dart';

/// Ports silentprintws/services/printService.js and barcodeService.js.
class PrintService {
  final AppConfig Function() getConfig;
  Future<void> _printTail = Future<void>.value();

  PrintService({required this.getConfig});

  /// Serializes every print type, including all copies of one request. The
  /// Windows spooler accepts jobs asynchronously, so concurrent HTTP calls
  /// can otherwise put ZPL between two ESC/POS copies.
  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = Completer<T>();
    final previous = _printTail;
    final finished = Completer<void>();
    _printTail = finished.future;

    () async {
      try {
        await previous;
      } catch (_) {
        // A failed job must not permanently block later print requests.
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

  static void _validateCopies(int copies, String kind) {
    if (copies < 1 || copies > 20) {
      throw ArgumentError('$kind harus antara 1 dan 20 salinan.');
    }
  }

  Future<void> validatePrinterConfiguration({
    AppConfig? configuration,
    bool validateBarcode = true,
  }) async {
    final cfg = configuration ?? getConfig();
    final queue = cfg.queuePrinterShare.trim();
    if (queue.isEmpty) {
      throw StateError('Nama share printer antrean wajib diisi.');
    }
    if (!validateBarcode) return;

    final barcodes = cfg.barcodePrinterShareList;
    if (barcodes.isEmpty) {
      throw StateError('Minimal satu share printer barcode wajib diisi.');
    }
    final queueKey = queue.toLowerCase();
    final duplicate = barcodes.firstWhere(
      (share) => share.toLowerCase() == queueKey,
      orElse: () => '',
    );
    if (duplicate.isNotEmpty) {
      throw StateError(
        'Share barcode "$duplicate" sama dengan share printer antrean "$queue".',
      );
    }
    final barcodeKeys = <String>{};
    for (final share in barcodes) {
      if (!barcodeKeys.add(share.toLowerCase())) {
        throw StateError(
          'Share printer barcode "$share" terdaftar lebih dari satu kali.',
        );
      }
    }
    if (Platform.isLinux) {
      final linuxQueue = cfg.linuxQueuePrinterName.trim();
      final linuxBarcode = cfg.linuxBarcodePrinterName.trim();
      if (linuxQueue.isEmpty || linuxBarcode.isEmpty) {
        throw StateError('Nama printer CUPS antrean dan barcode wajib diisi.');
      }
      if (linuxQueue.toLowerCase() == linuxBarcode.toLowerCase()) {
        throw StateError(
          'Nama printer CUPS barcode dan antrean tidak boleh sama.',
        );
      }
    }
    await PrinterDriver.validateWindowsPrinterSeparation(
      queueShare: queue,
      barcodeShares: barcodes,
    );
  }

  String _timestamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(now.day)}/${two(now.month)}/${now.year % 100} '
        '${two(now.hour)}.${two(now.minute)}';
  }

  Future<void> printQueueTicket(
    String queueNumber,
    String poliName, {
    String printLabel = 'Poli Tujuan',
    int? copies,
  }) {
    return _enqueue(() async {
      final cfg = getConfig();
      final n = copies ?? cfg.queueCopies;
      _validateCopies(n, 'Antrean');
      await validatePrinterConfiguration(
        configuration: cfg,
        validateBarcode: false,
      );

      LoggerService.instance.info(
        LogSource.silentPrint,
        'Menyiapkan $n salinan antrean untuk dicetak ($queueNumber / $poliName).',
      );

      final b = EscPosBuilder();
      b.alignCenter();
      b.bold(true);
      b.println('================================');
      b.println('  RSUD dr. Soeratno Gemolong  ');
      b.println('================================');
      b.bold(false);
      b.newLine();

      b.println('NOMOR ANTRIAN');
      b.setTextSize(4, 4);
      b.bold(true);
      b.println(queueNumber);
      b.bold(false);
      b.setTextSize(1, 1);
      b.newLine();

      b.println('================');
      b.println('${printLabel.toUpperCase()}:');
      b.bold(true);
      b.println(poliName.toUpperCase());
      b.bold(false);
      b.println('================');
      b.newLine();

      b.setTextSize(0, 0);
      b.println('Silakan tunggu panggilan Anda.');
      b.newLine();

      b.setTextSize(0, 0);
      b.println('Dicetak: ${_timestamp()}');
      b.newLine();

      b.cut();

      final buffer = b.getBuffer();
      PrinterDriver.validateEscPos(buffer);

      for (var i = 0; i < n; i++) {
        final copyNum = i + 1;
        try {
          await PrinterDriver.send(
            bytes: buffer,
            windowsShareName: cfg.queuePrinterShare,
            linuxPrinterName: cfg.linuxQueuePrinterName,
          );
          LoggerService.instance.success(
            LogSource.silentPrint,
            'Salinan antrean ke-$copyNum berhasil dicetak.',
          );
        } catch (e) {
          LoggerService.instance.error(
            LogSource.silentPrint,
            'Gagal cetak salinan antrean ke-$copyNum: $e',
          );
          rethrow;
        }
      }
    });
  }

  Future<void> printApmTicket(Map<String, dynamic> datas, {int? copies}) {
    return _enqueue(() async {
      final cfg = getConfig();
      final n = copies ?? cfg.apmCopies;
      _validateCopies(n, 'APM');
      await validatePrinterConfiguration(
        configuration: cfg,
        validateBarcode: false,
      );

      final queueNumber = (datas['nomorantrean'] ?? '').toString();
      final poliName = (datas['namapolirs'] ?? '').toString();
      final huruf = (datas['huruf'] ?? '').toString();
      final antreanPoli = (datas['antreanpoli'] ?? '').toString();

      LoggerService.instance.info(
        LogSource.silentPrint,
        'Menyiapkan print APM untuk: $queueNumber / $poliName.',
      );

      final b = EscPosBuilder();
      b.alignCenter();

      b.setTextSize(0, 0);
      b.println('Poliklinik');

      b.setTextSize(0, 0);
      b.bold(false);
      b.println('RSUD dr. Soeratno Gemolong');
      b.bold(false);

      b.setTextSize(0, 0);
      b.println('-------------------------------');
      b.println('Karcis Tunggu Loket');
      b.println('Pendaftaran Onsite');
      b.println('-------------------------------');

      b.newLine();
      b.setTextSize(3, 3);
      b.bold(true);
      b.println(queueNumber);
      b.bold(false);

      b.setTextSize(0, 0);
      b.println('-------------------------------');

      b.setTextSize(1, 1);
      b.println(poliName);

      b.setTextSize(0, 0);
      b.println('-------------------------------');

      final secondaryQueue = huruf.isNotEmpty
          ? '$huruf-$antreanPoli'
          : antreanPoli;
      if (secondaryQueue.trim().isNotEmpty && secondaryQueue.trim() != '-') {
        b.setTextSize(3, 3);
        b.bold(true);
        b.println(secondaryQueue);
        b.bold(false);
      }

      b.newLine();
      b.setTextSize(0, 0);
      b.println('Silakan menunggu nomor Anda dipanggil.');
      b.println('Dicetak: ${_timestamp()}');

      b.cut();

      final buffer = b.getBuffer();
      PrinterDriver.validateEscPos(buffer);

      for (var i = 0; i < n; i++) {
        final copyNum = i + 1;
        try {
          await PrinterDriver.send(
            bytes: buffer,
            windowsShareName: cfg.queuePrinterShare,
            linuxPrinterName: cfg.linuxQueuePrinterName,
          );
          LoggerService.instance.success(
            LogSource.silentPrint,
            'Salinan APM ke-$copyNum berhasil dicetak.',
          );
        } catch (e) {
          LoggerService.instance.error(
            LogSource.silentPrint,
            'Gagal cetak salinan APM ke-$copyNum: $e',
          );
          rethrow;
        }
      }
    });
  }

  Future<void> printBarcodeLabel(Map<String, dynamic> patientData) {
    return _enqueue(() async {
      final cfg = getConfig();
      final buffer = ZplBuilder.generateZPL(patientData);
      final copies = cfg.barcodeCopies;
      _validateCopies(copies, 'Barcode');
      await validatePrinterConfiguration(configuration: cfg);
      PrinterDriver.validateZpl(buffer);

      final options = Platform.isWindows
          ? cfg.barcodePrinterShareList
          : [cfg.linuxBarcodePrinterName];

      Object? lastError;
      for (final target in options) {
        try {
          for (var i = 0; i < copies; i++) {
            if (Platform.isWindows) {
              await PrinterDriver.sendRawWindowsShare(buffer, target);
            } else {
              await PrinterDriver.sendRawLinuxCups(buffer, target);
            }
          }
          LoggerService.instance.success(
            LogSource.silentPrint,
            'Label barcode ($copies salinan) berhasil dicetak via $target.',
          );
          return;
        } catch (e) {
          lastError = e;
          LoggerService.instance.warning(
            LogSource.silentPrint,
            'Printer barcode "$target" tidak merespon, mencoba fallback berikutnya jika ada. ($e)',
          );
          continue;
        }
      }

      final msg = 'Gagal mencetak: printer barcode tidak merespon. $lastError';
      LoggerService.instance.error(LogSource.silentPrint, msg);
      throw Exception(msg);
    });
  }
}
