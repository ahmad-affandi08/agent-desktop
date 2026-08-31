import 'dart:async';
import 'dart:collection';

import '../models/log_entry.dart';

/// Central in-memory log bus. Both HTTP modules and the UI read/write here.
class LoggerService {
  LoggerService._();
  static final LoggerService instance = LoggerService._();

  static const int maxEntries = 1000;

  final ListQueue<LogEntry> _entries = ListQueue<LogEntry>();
  final StreamController<LogEntry> _controller =
      StreamController<LogEntry>.broadcast();

  Stream<LogEntry> get stream => _controller.stream;
  List<LogEntry> get entries => List.unmodifiable(_entries);

  void log(LogSource source, String message, {LogLevel level = LogLevel.info}) {
    final entry = LogEntry(level: level, source: source, message: message);
    _entries.addLast(entry);
    while (_entries.length > maxEntries) {
      _entries.removeFirst();
    }
    _controller.add(entry);
  }

  void info(LogSource s, String m) => log(s, m, level: LogLevel.info);
  void success(LogSource s, String m) => log(s, m, level: LogLevel.success);
  void warning(LogSource s, String m) => log(s, m, level: LogLevel.warning);
  void error(LogSource s, String m) => log(s, m, level: LogLevel.error);

  void clear() {
    _entries.clear();
  }

  String exportAsText() => _entries.map((e) => e.toString()).join('\n');
}
