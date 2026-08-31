import 'dart:convert';
import 'dart:typed_data';

/// Minimal ESC/POS command builder for 58mm thermal printers.
/// Ports the subset of node-thermal-printer behaviour used by
/// silentprintws/services/printService.js (align, bold, text size, cut).
class EscPosBuilder {
  final BytesBuilder _buf = BytesBuilder();

  EscPosBuilder() {
    // ESC @ : initialize printer
    _raw([0x1B, 0x40]);
  }

  void _raw(List<int> bytes) => _buf.add(bytes);

  /// Encode text. Falls back to UTF-8 bytes for characters outside Latin-1
  /// (thermal printers here are configured for a Latin codepage, matching
  /// the original SLOVENIA characterSet used by node-thermal-printer).
  List<int> _encode(String text) {
    try {
      return latin1.encode(text);
    } catch (_) {
      return utf8.encode(text);
    }
  }

  void alignCenter() => _raw([0x1B, 0x61, 0x01]);
  void alignLeft() => _raw([0x1B, 0x61, 0x00]);
  void alignRight() => _raw([0x1B, 0x61, 0x02]);

  void bold(bool on) => _raw([0x1B, 0x45, on ? 0x01 : 0x00]);

  /// width/height multipliers 0-7 (0 = normal 1x, matches
  /// node-thermal-printer's setTextSize(width, height) semantics).
  void setTextSize(int width, int height) {
    final w = width.clamp(0, 7);
    final h = height.clamp(0, 7);
    final n = ((w & 0x07) << 4) | (h & 0x07);
    _raw([0x1D, 0x21, n]);
  }

  void println(String text) {
    _buf.add(_encode(text));
    _raw([0x0A]);
  }

  void newLine() => _raw([0x0A]);

  /// Full cut with a short feed, GS V 66 n.
  void cut() {
    _raw([0x0A, 0x0A, 0x0A]);
    _raw([0x1D, 0x56, 0x42, 0x00]);
  }

  Uint8List getBuffer() => _buf.toBytes();
}
