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
  late String _biometricMode;

  @override
  void initState() {
    super.initState();
    final cfg = widget.controller.config;
    _biometricMode = cfg.biometricMode;
    _c = {
      'printPort': TextEditingController(text: '${cfg.printPort}'),
      'sidikJariPort': TextEditingController(text: '${cfg.sidikJariPort}'),
      'queuePrinterShare': TextEditingController(text: cfg.queuePrinterShare),
      'barcodePrinterShares': TextEditingController(
        text: cfg.barcodePrinterShares,
      ),
      'linuxQueuePrinterName': TextEditingController(
        text: cfg.linuxQueuePrinterName,
      ),
      'linuxBarcodePrinterName': TextEditingController(
        text: cfg.linuxBarcodePrinterName,
      ),
      'queueCopies': TextEditingController(text: '${cfg.queueCopies}'),
      'apmCopies': TextEditingController(text: '${cfg.apmCopies}'),
      'barcodeCopies': TextEditingController(text: '${cfg.barcodeCopies}'),
      'afterExePath': TextEditingController(text: cfg.afterExePath),
      'bpjsUsername': TextEditingController(text: cfg.bpjsUsername),
      'bpjsPassword': TextEditingController(text: cfg.bpjsPassword),
      'fristaExePath': TextEditingController(text: cfg.fristaExePath),
      'fristaProcessName': TextEditingController(text: cfg.fristaProcessName),
      'fristaWindowTitle': TextEditingController(text: cfg.fristaWindowTitle),
      'fristaUsername': TextEditingController(text: cfg.fristaUsername),
      'fristaPassword': TextEditingController(text: cfg.fristaPassword),
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
      biometricMode: _biometricMode,
      afterExePath: _c['afterExePath']!.text.trim().replaceAll('"', ''),
      bpjsUsername: _c['bpjsUsername']!.text.trim(),
      bpjsPassword: _c['bpjsPassword']!.text,
      fristaExePath: _c['fristaExePath']!.text.trim().replaceAll('"', ''),
      fristaProcessName: _c['fristaProcessName']!.text.trim(),
      fristaWindowTitle: _c['fristaWindowTitle']!.text.trim(),
      fristaUsername: _c['fristaUsername']!.text.trim(),
      fristaPassword: _c['fristaPassword']!.text,
    );
    try {
      await widget.controller.serverManager.printService
          .validatePrinterConfiguration(configuration: newConfig);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Konfigurasi printer ditolak: $e')),
        );
      }
      return;
    }

    await widget.controller.saveConfig(newConfig);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengaturan disimpan & service di-restart.'),
        ),
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

  Widget _field(
    String key,
    String label, {
    bool obscure = false,
    String? helperText,
  }) {
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
          _section(
            'Mode Biometrik BPJS (Port ${widget.controller.config.sidikJariPort})',
            [
              const Text(
                'Tentukan mode biometrik yang aktif untuk PC ini:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'both',
                      icon: Icon(Icons.all_inclusive),
                      label: Text('Keduanya Aktif'),
                    ),
                    ButtonSegment(
                      value: 'sidikjari',
                      icon: Icon(Icons.fingerprint),
                      label: Text('Hanya Sidik Jari'),
                    ),
                    ButtonSegment(
                      value: 'frista',
                      icon: Icon(Icons.face),
                      label: Text('Hanya FRISTA'),
                    ),
                  ],
                  selected: {_biometricMode},
                  onSelectionChanged: (set) =>
                      setState(() => _biometricMode = set.first),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _biometricMode == 'both'
                    ? 'Keduanya aktif: SIMRS dapat memanggil Sidik Jari atau FRISTA sesuai kondisi pasien (jika sidik jari bermasalah bisa langsung beralih ke wajah, atau sebaliknya).'
                    : _biometricMode == 'sidikjari'
                    ? 'Hanya Sidik Jari aktif: Semua request biometrik dari SIMRS akan membuka After.exe.'
                    : 'Hanya FRISTA aktif: Semua request biometrik dari SIMRS akan membuka frista.exe.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          _section('Pengaturan Server', [
            Row(
              children: [
                Expanded(child: _field('printPort', 'Port SilentPrint')),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    'sidikJariPort',
                    'Port Biometrik (SidikJari & FRISTA)',
                  ),
                ),
              ],
            ),
          ]),
          _section('Pengaturan Print — Windows (UNC Share)', [
            _field('queuePrinterShare', 'Nama Share Printer Antrean/APM'),
            _field(
              'barcodePrinterShares',
              'Nama Share Printer Barcode (pisahkan koma untuk fallback)',
            ),
          ]),
          _section('Pengaturan Print — Linux (CUPS)', [
            _field('linuxQueuePrinterName', 'Nama Printer CUPS Antrean/APM'),
            _field('linuxBarcodePrinterName', 'Nama Printer CUPS Barcode'),
          ]),
          _section('Jumlah Salinan Default', [
            Row(
              children: [
                Expanded(child: _field('queueCopies', 'Antrean')),
                const SizedBox(width: 12),
                Expanded(child: _field('apmCopies', 'APM')),
                const SizedBox(width: 12),
                Expanded(child: _field('barcodeCopies', 'Barcode')),
              ],
            ),
          ]),
          _section('Pengaturan SidikJari BPJS (Fingerprint)', [
            _field('afterExePath', 'Path After.exe'),
            _field('bpjsUsername', 'Username Login BPJS'),
            _field('bpjsPassword', 'Password BPJS', obscure: true),
          ]),
          _section('Pengaturan FRISTA BPJS (Face Recognition)', [
            _field('fristaExePath', 'Path frista.exe'),
            Row(
              children: [
                Expanded(
                  child: _field(
                    'fristaProcessName',
                    'Nama Proses (default: frista.exe)',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    'fristaWindowTitle',
                    'Kata Kunci Judul Window (default: frista)',
                  ),
                ),
              ],
            ),
            _field('fristaUsername', 'Username FRISTA (opsional)'),
            _field(
              'fristaPassword',
              'Password FRISTA (opsional)',
              obscure: true,
            ),
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
