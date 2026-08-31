import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/logger_service.dart';
import '../../models/log_entry.dart';
import '../theme.dart';

enum _LogFilter { all, silentPrint, sidikJari }

class LogsTab extends StatefulWidget {
  const LogsTab({super.key});

  @override
  State<LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<LogsTab> {
  _LogFilter _filter = _LogFilter.all;
  final ScrollController _scrollController = ScrollController();
  late List<LogEntry> _entries;
  StreamSubscription<LogEntry>? _sub;

  @override
  void initState() {
    super.initState();
    _entries = List.of(LoggerService.instance.entries);
    _sub = LoggerService.instance.stream.listen((entry) {
      if (!mounted) return;
      setState(() => _entries.add(entry));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  bool _matchesFilter(LogEntry e) {
    switch (_filter) {
      case _LogFilter.all:
        return true;
      case _LogFilter.silentPrint:
        return e.source == LogSource.silentPrint;
      case _LogFilter.sidikJari:
        return e.source == LogSource.sidikJari;
    }
  }

  Color _levelColor(LogLevel l) {
    switch (l) {
      case LogLevel.success:
        return AppColors.success;
      case LogLevel.warning:
        return AppColors.warning;
      case LogLevel.error:
        return AppColors.error;
      case LogLevel.info:
        return AppColors.textPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _entries.where(_matchesFilter).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SegmentedButton<_LogFilter>(
                segments: const [
                  ButtonSegment(value: _LogFilter.all, label: Text('Semua')),
                  ButtonSegment(
                      value: _LogFilter.silentPrint, label: Text('SilentPrint')),
                  ButtonSegment(
                      value: _LogFilter.sidikJari, label: Text('SidikJari')),
                ],
                selected: {_filter},
                onSelectionChanged: (s) => setState(() => _filter = s.first),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                      ClipboardData(text: LoggerService.instance.exportAsText()));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Log disalin ke clipboard.')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_all),
                label: const Text('Copy Log'),
              ),
              TextButton.icon(
                onPressed: () {
                  LoggerService.instance.clear();
                  setState(() => _entries.clear());
                },
                icon: const Icon(Icons.delete_sweep),
                label: const Text('Clear'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: visible.isEmpty
                ? const Center(
                    child: Text('Belum ada log.',
                        style: TextStyle(color: AppColors.textSecondary)))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final e = visible[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 12.5),
                            children: [
                              TextSpan(
                                  text: '[${e.timeLabel}] ',
                                  style: const TextStyle(color: AppColors.textSecondary)),
                              TextSpan(
                                  text: '[${e.sourceLabel}] ',
                                  style: const TextStyle(color: AppColors.primary)),
                              TextSpan(
                                  text: e.message,
                                  style: TextStyle(color: _levelColor(e.level))),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
