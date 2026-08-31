import 'dart:io';

class NetworkInfo {
  /// Best-effort first non-loopback IPv4 address, for display in the header.
  static Future<String> localIPv4() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {
      // fall through
    }
    return '127.0.0.1';
  }
}
