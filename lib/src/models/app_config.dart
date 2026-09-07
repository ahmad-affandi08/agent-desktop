import 'dart:convert';

class AppConfig {
  final int printPort;
  final int sidikJariPort;
  final bool autoStartServers;

  final String queuePrinterShare;
  final String barcodePrinterShares;
  final String linuxQueuePrinterName;
  final String linuxBarcodePrinterName;
  final int queueCopies;
  final int apmCopies;
  final int barcodeCopies;

  final String afterExePath;
  final String bpjsUsername;
  final String bpjsPassword;

  final String fristaExePath;
  final String fristaProcessName;
  final String fristaWindowTitle;
  final String fristaUsername;
  final String fristaPassword;

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
    this.fristaExePath = r'C:\Users\User\Documents\frista.exe',
    this.fristaProcessName = 'frista.exe',
    this.fristaWindowTitle = 'Frista (Face Recognition BPJS Kesehatan)',
    this.fristaUsername = '',
    this.fristaPassword = '',
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
    String? fristaExePath,
    String? fristaProcessName,
    String? fristaWindowTitle,
    String? fristaUsername,
    String? fristaPassword,
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
      fristaExePath: fristaExePath ?? this.fristaExePath,
      fristaProcessName: fristaProcessName ?? this.fristaProcessName,
      fristaWindowTitle: fristaWindowTitle ?? this.fristaWindowTitle,
      fristaUsername: fristaUsername ?? this.fristaUsername,
      fristaPassword: fristaPassword ?? this.fristaPassword,
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
    'fristaExePath': fristaExePath,
    'fristaProcessName': fristaProcessName,
    'fristaWindowTitle': fristaWindowTitle,
    'fristaUsername': fristaUsername,
    'fristaPassword': fristaPassword,
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
    fristaExePath:
        json['fristaExePath'] ?? r'C:\Users\User\Documents\frista.exe',
    fristaProcessName: json['fristaProcessName'] ?? 'frista.exe',
    fristaWindowTitle:
        json['fristaWindowTitle'] ?? 'Frista (Face Recognition BPJS Kesehatan)',
    fristaUsername: json['fristaUsername'] ?? '',
    fristaPassword: json['fristaPassword'] ?? '',
  );

  String encode() => jsonEncode(toJson());

  factory AppConfig.decode(String source) =>
      AppConfig.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
