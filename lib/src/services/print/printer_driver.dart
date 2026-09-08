import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Cross-platform raw byte printer driver.
///
/// Windows: writes the buffer to a temp file and copies it byte-for-byte
/// into the shared printer's UNC path (`\\HOSTNAME\SHARE`), the same
/// mechanism as the original print.bat (`COPY /B`).
/// Linux: writes the buffer to a temp file and sends it through CUPS via
/// `lpr -P <printer> -o raw <file>`.
class PrinterDriver {
  /// Verifies that a buffer is an ESC/POS job before it can reach the queue
  /// printer. This prevents a raw ZPL label from being sent through the
  /// receipt-printer route after a caller/configuration mix-up.
  static void validateEscPos(Uint8List bytes) {
    if (bytes.length < 2 || bytes[0] != 0x1B || bytes[1] != 0x40) {
      throw const FormatException(
        'Payload printer antrean bukan ESC/POS yang valid.',
      );
    }
    final text = String.fromCharCodes(bytes);
    if (text.contains('^XA') || text.contains('^XZ')) {
      throw const FormatException(
        'Payload ZPL terdeteksi pada jalur printer antrean.',
      );
    }
  }

  /// Verifies that a buffer is a complete ZPL label before it can reach a
  /// barcode printer.
  static void validateZpl(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: false).trim();
    if (!text.startsWith('^XA') || !text.endsWith('^XZ')) {
      throw const FormatException('Payload barcode bukan ZPL lengkap.');
    }
    if (bytes.length >= 2 && bytes[0] == 0x1B && bytes[1] == 0x40) {
      throw const FormatException(
        'Payload ESC/POS terdeteksi pada jalur printer barcode.',
      );
    }
  }

  /// Rejects aliases that resolve to the same physical Windows printer port.
  /// Share names can be different while still targeting the same device.
  static Future<void> validateWindowsPrinterSeparation({
    required String queueShare,
    required List<String> barcodeShares,
  }) async {
    if (!Platform.isWindows) return;

    final result = await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r"Get-CimInstance Win32_Printer | Select-Object Name,ShareName,PortName | ConvertTo-Json -Compress",
    ], runInShell: false);
    if (result.exitCode != 0) {
      throw StateError(
        'Tidak dapat memvalidasi pemetaan printer Windows: ${result.stderr}',
      );
    }

    final output = (result.stdout as String).trim();
    if (output.isEmpty) {
      throw StateError('Daftar printer Windows kosong.');
    }
    final decoded = jsonDecode(output);
    final rows = decoded is List ? decoded : [decoded];
    Map<String, dynamic>? rowFor(String share) {
      final wanted = share.trim().toLowerCase();
      for (final row in rows) {
        if (row is Map &&
            (row['ShareName'] ?? '').toString().trim().toLowerCase() ==
                wanted) {
          return row.cast<String, dynamic>();
        }
      }
      return null;
    }

    final queue = rowFor(queueShare);
    if (queue == null) {
      throw StateError(
        'Share printer antrean "$queueShare" tidak ditemukan di Windows.',
      );
    }
    final queuePort = (queue['PortName'] ?? '').toString().trim().toLowerCase();
    if (queuePort.isEmpty) {
      throw StateError(
        'Port printer antrean "$queueShare" tidak dapat diketahui.',
      );
    }

    for (final share in barcodeShares) {
      final barcode = rowFor(share);
      if (barcode == null) {
        throw StateError(
          'Share printer barcode "$share" tidak ditemukan di Windows.',
        );
      }
      final barcodePort = (barcode['PortName'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (barcodePort.isEmpty) {
        throw StateError(
          'Port printer barcode "$share" tidak dapat diketahui.',
        );
      }
      if (barcodePort == queuePort) {
        throw StateError(
          'Printer barcode "$share" dan antrean "$queueShare" memakai '
          'port fisik yang sama ($queuePort). Job ditolak untuk mencegah '
          'ZPL tercetak sebagai teks antrean.',
        );
      }
    }
  }

  static Future<void> sendRawWindowsShare(
    Uint8List bytes,
    String shareName,
  ) async {
    final hostname = Platform.localHostname;
    final uncPath = '\\\\$hostname\\$shareName';
    await _sendViaCopy(bytes, uncPath);
  }

  static Future<void> _sendViaCopy(Uint8List bytes, String uncPath) async {
    final tempFile = File(
      p.join(
        Directory.systemTemp.path,
        'rssg-print-${DateTime.now().microsecondsSinceEpoch}.tmp',
      ),
    );
    await tempFile.writeAsBytes(bytes);
    try {
      final result = await Process.run('cmd', [
        '/c',
        'copy',
        '/b',
        tempFile.path,
        uncPath,
      ], runInShell: false);
      if (result.exitCode != 0) {
        throw Exception(
          'Gagal cetak ke $uncPath (exit ${result.exitCode}): ${result.stderr}',
        );
      }
    } finally {
      if (await tempFile.exists()) await tempFile.delete();
    }
  }

  static Future<void> sendRawLinuxCups(
    Uint8List bytes,
    String printerName,
  ) async {
    final tempFile = File(
      p.join(
        Directory.systemTemp.path,
        'rssg-print-${DateTime.now().microsecondsSinceEpoch}.tmp',
      ),
    );
    await tempFile.writeAsBytes(bytes);
    try {
      final result = await Process.run('lpr', [
        '-P',
        printerName,
        '-o',
        'raw',
        tempFile.path,
      ]);
      if (result.exitCode != 0) {
        throw Exception(
          'Gagal cetak via lpr ke $printerName (exit ${result.exitCode}): ${result.stderr}',
        );
      }
    } finally {
      if (await tempFile.exists()) await tempFile.delete();
    }
  }

  /// Sends [bytes] using the correct driver for the current OS, targeting
  /// [windowsShareName] on Windows or [linuxPrinterName] on Linux.
  static Future<void> send({
    required Uint8List bytes,
    required String windowsShareName,
    required String linuxPrinterName,
  }) async {
    if (Platform.isWindows) {
      await sendRawWindowsShare(bytes, windowsShareName);
    } else if (Platform.isLinux) {
      await sendRawLinuxCups(bytes, linuxPrinterName);
    } else {
      throw UnsupportedError(
        'Platform ${Platform.operatingSystem} tidak didukung untuk cetak.',
      );
    }
  }

  static Future<void> sendCopies({
    required Uint8List bytes,
    required String windowsShareName,
    required String linuxPrinterName,
    required int copies,
  }) async {
    for (var i = 0; i < copies; i++) {
      await send(
        bytes: bytes,
        windowsShareName: windowsShareName,
        linuxPrinterName: linuxPrinterName,
      );
    }
  }
}
