import 'dart:convert';

/// Persisted configuration for both modules. Mirrors the settings that used
/// to be hardcoded across silentprintws and sidikjari-agent.
class AppConfig {
  // Server
  final int printPort;
  final int sidikJariPort;
  final bool autoStartServers;

  // Print module
  final String queuePrinterShare; // Windows UNC share name, e.g. SILENTPRINTER
  final String barcodePrinterShares; // comma separated fallback list
  final String linuxQueuePrinterName; // CUPS printer name
  final String linuxBarcodePrinterName; // CUPS printer name
  final int queueCopies;
  final int apmCopies;
  final int barcodeCopies;

  // SidikJari module
  final String afterExePath;
  final String bpjsUsername;
  final String bpjsPassword;

  const AppConfig({
    this.printPort = 3007,
    this.sidikJariPort = 3009,
    this.autoStartServers = true,
    this.queuePrinterShare = 'SILENTPRINTER',
    this.barcodePrinterShares = 'BARCODEPRINTER,XPRINTER',
    this.linuxQueuePrinterName = 'SILENTPRINTER',
    this.linuxBarcodePrinterName = 'BARCODEPRINTER',
    this.queueCopies = 2,
    this.apmCopies = 1,
    this.barcodeCopies = 6,
    this.afterExePath =
        r'C:\Program Files (x86)\Aplikasi Sidik Jari BPJS Kesehatan\After.exe',
    this.bpjsUsername = 'ahmad-0154r002',
    this.bpjsPassword = 'Ahmad321#',
  });

  List<String> get barcodePrinterShareList => barcodePrinterShares
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  AppConfig copyWith({
    int? printPort,
    int? sidikJariPort,
    bool? autoStartServers,
    String? queuePrinterShare,
    String? barcodePrinterShares,
    String? linuxQueuePrinterName,
    String? linuxBarcodePrinterName,
    int? queueCopies,
    int? apmCopies,
    int? barcodeCopies,
    String? afterExePath,
    String? bpjsUsername,
    String? bpjsPassword,
  }) {
    return AppConfig(
      printPort: printPort ?? this.printPort,
      sidikJariPort: sidikJariPort ?? this.sidikJariPort,
      autoStartServers: autoStartServers ?? this.autoStartServers,
      queuePrinterShare: queuePrinterShare ?? this.queuePrinterShare,
      barcodePrinterShares: barcodePrinterShares ?? this.barcodePrinterShares,
      linuxQueuePrinterName:
          linuxQueuePrinterName ?? this.linuxQueuePrinterName,
      linuxBarcodePrinterName:
          linuxBarcodePrinterName ?? this.linuxBarcodePrinterName,
      queueCopies: queueCopies ?? this.queueCopies,
      apmCopies: apmCopies ?? this.apmCopies,
      barcodeCopies: barcodeCopies ?? this.barcodeCopies,
      afterExePath: afterExePath ?? this.afterExePath,
      bpjsUsername: bpjsUsername ?? this.bpjsUsername,
      bpjsPassword: bpjsPassword ?? this.bpjsPassword,
    );
  }

  Map<String, dynamic> toJson() => {
    'printPort': printPort,
    'sidikJariPort': sidikJariPort,
    'autoStartServers': autoStartServers,
    'queuePrinterShare': queuePrinterShare,
    'barcodePrinterShares': barcodePrinterShares,
    'linuxQueuePrinterName': linuxQueuePrinterName,
    'linuxBarcodePrinterName': linuxBarcodePrinterName,
    'queueCopies': queueCopies,
    'apmCopies': apmCopies,
    'barcodeCopies': barcodeCopies,
    'afterExePath': afterExePath,
    'bpjsUsername': bpjsUsername,
    'bpjsPassword': bpjsPassword,
  };

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
    printPort: json['printPort'] ?? 3007,
    sidikJariPort: json['sidikJariPort'] ?? 3009,
    autoStartServers: json['autoStartServers'] ?? true,
    queuePrinterShare: json['queuePrinterShare'] ?? 'SILENTPRINTER',
    barcodePrinterShares:
        json['barcodePrinterShares'] ?? 'BARCODEPRINTER,XPRINTER',
    linuxQueuePrinterName: json['linuxQueuePrinterName'] ?? 'SILENTPRINTER',
    linuxBarcodePrinterName:
        json['linuxBarcodePrinterName'] ?? 'BARCODEPRINTER',
    queueCopies: json['queueCopies'] ?? 2,
    apmCopies: json['apmCopies'] ?? 1,
    barcodeCopies: json['barcodeCopies'] ?? 6,
    afterExePath:
        json['afterExePath'] ??
        r'C:\Program Files (x86)\Aplikasi Sidik Jari BPJS Kesehatan\After.exe',
    bpjsUsername: json['bpjsUsername'] ?? 'ahmad-0154r002',
    bpjsPassword: json['bpjsPassword'] ?? 'Ahmad321#',
  );

  String encode() => jsonEncode(toJson());

  factory AppConfig.decode(String source) =>
      AppConfig.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
