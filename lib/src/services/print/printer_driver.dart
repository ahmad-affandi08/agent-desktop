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
  static Future<void> sendRawWindowsShare(
    Uint8List bytes,
    String shareName,
  ) async {
    final hostname = Platform.localHostname;
    final uncPath = '\\\\$hostname\\$shareName';
    await _sendViaCopy(bytes, uncPath);
  }

  static Future<void> _sendViaCopy(Uint8List bytes, String uncPath) async {
    final tempFile = File(p.join(
      Directory.systemTemp.path,
      'rssg-print-${DateTime.now().microsecondsSinceEpoch}.tmp',
    ));
    await tempFile.writeAsBytes(bytes);
    try {
      final result = await Process.run(
        'cmd',
        ['/c', 'copy', '/b', tempFile.path, uncPath],
        runInShell: false,
      );
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
    final tempFile = File(p.join(
      Directory.systemTemp.path,
      'rssg-print-${DateTime.now().microsecondsSinceEpoch}.tmp',
    ));
    await tempFile.writeAsBytes(bytes);
    try {
      final result = await Process.run(
        'lpr',
        ['-P', printerName, '-o', 'raw', tempFile.path],
      );
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
