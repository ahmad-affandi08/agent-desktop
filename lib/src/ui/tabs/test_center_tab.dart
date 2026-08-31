import 'package:flutter/material.dart';

import '../../core/logger_service.dart';
import '../../models/log_entry.dart';
import '../../state/app_controller.dart';

class TestCenterTab extends StatefulWidget {
  final AppController controller;

  const TestCenterTab({super.key, required this.controller});

  @override
  State<TestCenterTab> createState() => _TestCenterTabState();
}

class _TestCenterTabState extends State<TestCenterTab> {
  bool _busy = false;

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label: berhasil.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label: gagal — $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _section(String title, IconData icon, List<Widget> buttons) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: buttons),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final printService = widget.controller.serverManager.printService;
    final sidikJariService = widget.controller.serverManager.sidikJariService;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('Test Cetak (Port ${widget.controller.config.printPort})',
              Icons.print, [
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(
                      'Test Antrean',
                      () => printService.printQueueTicket(
                          '001', 'Poli Umum',
                          printLabel: 'Poli Tujuan')),
              icon: const Icon(Icons.confirmation_number),
              label: const Text('Test Cetak Antrean'),
            ),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(
                      'Test APM',
                      () => printService.printApmTicket({
                            'nomorantrean': 'A-001',
                            'namapolirs': 'Poli Gigi',
                            'huruf': 'B',
                            'antreanpoli': '012',
                          })),
              icon: const Icon(Icons.receipt_long),
              label: const Text('Test Cetak APM'),
            ),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(
                      'Test Barcode',
                      () => printService.printBarcodeLabel({
                            'peserta': {
                              'NORM': '000123',
                              'NAMA_LENGKAP': 'Pasien Uji Coba',
                              'JENIS_KELAMIN': 'L',
                              'TANGGAL_LAHIR': '1990-05-17',
                              'NIK': '3311xxxxxxxxxxxx',
                              'alamat': 'Jl. Contoh No. 1, Gemolong',
                            }
                          })),
              icon: const Icon(Icons.qr_code),
              label: const Text('Test Cetak Barcode'),
            ),
          ]),
          _section(
              'Test SidikJari BPJS (Port ${widget.controller.config.sidikJariPort})',
              Icons.fingerprint, [
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run('Test Open SidikJari', () async {
                        final result = await sidikJariService.openSidikJari(
                          nik: '3311010101900001',
                          noBpjs: '0001234567890',
                          nama: 'Pasien Uji Coba',
                        );
                        if (result['success'] != true) {
                          throw Exception(result['message']);
                        }
                      }),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Test Open SidikJari'),
            ),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(
                      'Reset SidikJari', () => sidikJariService.reset()),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset / Close After.exe'),
            ),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run('Health Check', () async {
                        final h = await sidikJariService.health();
                        LoggerService.instance.info(
                            LogSource.sidikJari, 'Health: $h');
                      }),
              icon: const Icon(Icons.health_and_safety),
              label: const Text('Health Check'),
            ),
          ]),
          if (_busy) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
