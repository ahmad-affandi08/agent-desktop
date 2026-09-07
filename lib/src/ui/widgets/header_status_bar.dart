import 'package:flutter/material.dart';

import '../../services/server/server_manager.dart';
import '../../state/app_controller.dart';
import '../theme.dart';

class HeaderStatusBar extends StatelessWidget implements PreferredSizeWidget {
  final AppController controller;

  const HeaderStatusBar({super.key, required this.controller});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  Color _statusColor(ServerStatus s) {
    switch (s) {
      case ServerStatus.running:
        return AppColors.success;
      case ServerStatus.starting:
        return AppColors.warning;
      case ServerStatus.error:
        return AppColors.error;
      case ServerStatus.stopped:
        return AppColors.textSecondary;
    }
  }

  String _statusLabel(ServerStatus s) {
    switch (s) {
      case ServerStatus.running:
        return 'Active';
      case ServerStatus.starting:
        return 'Starting';
      case ServerStatus.error:
        return 'Error';
      case ServerStatus.stopped:
        return 'Stopped';
    }
  }

  Widget _badge({
    required String label,
    required int port,
    required ServerStatus status,
    required VoidCallback onToggle,
  }) {
    final isOn = status == ServerStatus.running || status == ServerStatus.starting;
    final busy = status == ServerStatus.starting;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: _statusColor(status)),
          const SizedBox(width: 8),
          Text('$label :$port — ${_statusLabel(status)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Transform.scale(
            scale: 0.7,
            child: Switch(
              value: isOn,
              onChanged: busy ? null : (_) => onToggle(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sm = controller.serverManager;
    return AppBar(
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          const Icon(Icons.dns_rounded),
          const SizedBox(width: 10),
          const Text('RSSG Agent Desktop'),
          const SizedBox(width: 20),
          _badge(
            label: 'SilentPrint',
            port: controller.config.printPort,
            status: sm.printStatus,
            onToggle: controller.togglePrintServer,
          ),
          const SizedBox(width: 10),
          _badge(
            label: 'SidikJari & FRISTA',
            port: controller.config.sidikJariPort,
            status: sm.sidikJariStatus,
            onToggle: controller.toggleSidikJariServer,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi, size: 14),
                const SizedBox(width: 6),
                Text('http://${controller.localIp}', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
