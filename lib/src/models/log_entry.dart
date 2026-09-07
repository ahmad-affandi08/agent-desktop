enum LogLevel { info, success, warning, error }

enum LogSource { system, silentPrint, sidikJari, frista }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final LogSource source;
  final String message;

  LogEntry({
    required this.level,
    required this.source,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get sourceLabel {
    switch (source) {
      case LogSource.system:
        return 'SYSTEM';
      case LogSource.silentPrint:
        return 'SilentPrint';
      case LogSource.sidikJari:
        return 'SidikJari';
      case LogSource.frista:
        return 'FRISTA';
    }
  }

  String get timeLabel {
    final t = timestamp;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  String toString() => '[$timeLabel] [$sourceLabel] $message';
}
