import 'package:flutter/material.dart';

import '../../models/app_config.dart';
import '../../state/app_controller.dart';

class SettingsTab extends StatefulWidget {
  final AppController controller;

  const SettingsTab({super.key, required this.controller});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  late final Map<String, TextEditingController> _c;

  @override
  void initState() {
    super.initState();
    final cfg = widget.controller.config;
    _c = {
      'printPort': TextEditingController(text: '${cfg.printPort}'),
      'sidikJariPort': TextEditingController(text: '${cfg.sidikJariPort}'),
      'queuePrinterShare': TextEditingController(text: cfg.queuePrinterShare),
      'barcodePrinterShares':
          TextEditingController(text: cfg.barcodePrinterShares),
      'linuxQueuePrinterName':
          TextEditingController(text: cfg.linuxQueuePrinterName),
      'linuxBarcodePrinterName':
          TextEditingController(text: cfg.linuxBarcodePrinterName),
      'queueCopies': TextEditingController(text: '${cfg.queueCopies}'),
      'apmCopies': TextEditingController(text: '${cfg.apmCopies}'),
      'barcodeCopies': TextEditingController(text: '${cfg.barcodeCopies}'),
      'afterExePath': TextEditingController(text: cfg.afterExePath),
      'helperExePath': TextEditingController(text: cfg.helperExePath),
      'bpjsUsername': TextEditingController(text: cfg.bpjsUsername),
      'bpjsPassword': TextEditingController(text: cfg.bpjsPassword),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _int(String key, int fallback) =>
      int.tryParse(_c[key]!.text.trim()) ?? fallback;

  Future<void> _save() async {
    final cfg = widget.controller.config;
    final newConfig = AppConfig(
      printPort: _int('printPort', cfg.printPort),
      sidikJariPort: _int('sidikJariPort', cfg.sidikJariPort),
      autoStartServers: cfg.autoStartServers,
      queuePrinterShare: _c['queuePrinterShare']!.text.trim(),
      barcodePrinterShares: _c['barcodePrinterShares']!.text.trim(),
      linuxQueuePrinterName: _c['linuxQueuePrinterName']!.text.trim(),
      linuxBarcodePrinterName: _c['linuxBarcodePrinterName']!.text.trim(),
      queueCopies: _int('queueCopies', cfg.queueCopies),
      apmCopies: _int('apmCopies', cfg.apmCopies),
      barcodeCopies: _int('barcodeCopies', cfg.barcodeCopies),
      afterExePath: _c['afterExePath']!.text.trim(),
      helperExePath: _c['helperExePath']!.text.trim(),
      bpjsUsername: _c['bpjsUsername']!.text.trim(),
      bpjsPassword: _c['bpjsPassword']!.text,
    );
    await widget.controller.saveConfig(newConfig);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengaturan disimpan & service di-restart.')),
      );
    }
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _field(String key, String label,
      {bool obscure = false, String? helperText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _c[key],
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('Pengaturan Server', [
            Row(children: [
              Expanded(child: _field('printPort', 'Port SilentPrint')),
              const SizedBox(width: 12),
              Expanded(child: _field('sidikJariPort', 'Port SidikJari')),
            ]),
          ]),
          _section('Pengaturan Print — Windows (UNC Share)', [
            _field('queuePrinterShare', 'Nama Share Printer Antrean/APM'),
            _field('barcodePrinterShares',
                'Nama Share Printer Barcode (pisahkan koma untuk fallback)'),
          ]),
          _section('Pengaturan Print — Linux (CUPS)', [
            _field('linuxQueuePrinterName', 'Nama Printer CUPS Antrean/APM'),
            _field('linuxBarcodePrinterName', 'Nama Printer CUPS Barcode'),
          ]),
          _section('Jumlah Salinan Default', [
            Row(children: [
              Expanded(child: _field('queueCopies', 'Antrean')),
              const SizedBox(width: 12),
              Expanded(child: _field('apmCopies', 'APM')),
              const SizedBox(width: 12),
              Expanded(child: _field('barcodeCopies', 'Barcode')),
            ]),
          ]),
          _section('Pengaturan SidikJari BPJS', [
            _field('afterExePath', 'Path After.exe'),
            _field(
              'helperExePath',
              'Path Helper Auto-Fill (exe / script)',
              helperText: 'Nama file saja = dicari otomatis di folder aplikasi ini. '
                  'Isi path lengkap kalau helper ada di lokasi lain.',
            ),
            _field('bpjsUsername', 'Username Login BPJS'),
            _field('bpjsPassword', 'Password BPJS', obscure: true),
          ]),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Simpan Pengaturan'),
          ),
        ],
      ),
    );
  }
}
