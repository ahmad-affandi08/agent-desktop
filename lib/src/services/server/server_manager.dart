import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../../core/logger_service.dart';
import '../../models/app_config.dart';
import '../../models/log_entry.dart';
import '../frista/frista_service.dart';
import '../print/print_service.dart';
import '../sidikjari/sidikjari_service.dart';
import 'http_utils.dart';

enum ServerStatus { stopped, starting, running, error }

class ServerManager {
  final AppConfig Function() getConfig;
  late final PrintService printService;
  late final SidikJariService sidikJariService;
  late final FristaService fristaService;

  HttpServer? _printServer;
  HttpServer? _sidikJariServer;

  ServerStatus printStatus = ServerStatus.stopped;
  ServerStatus sidikJariStatus = ServerStatus.stopped;

  final void Function() onStatusChanged;

  ServerManager({required this.getConfig, required this.onStatusChanged}) {
    printService = PrintService(getConfig: getConfig);
    sidikJariService = SidikJariService(getConfig: getConfig);
    fristaService = FristaService(getConfig: getConfig);
  }

  bool get isAnyRunning =>
      printStatus == ServerStatus.running ||
      sidikJariStatus == ServerStatus.running;

  Router _buildPrintRouter() {
    final router = Router();

    router.post('/print', (Request request) async {
      LoggerService.instance.info(
        LogSource.silentPrint,
        'Menerima request cetak antrean.',
      );
      final body = await readJsonBody(request);
      final queueNumber = body['queueNumber']?.toString();
      final poliName = body['poliName']?.toString();
      final printLabel = body['printLabel']?.toString();
      final copies = body['copies'] is int ? body['copies'] as int : null;

      if (queueNumber == null ||
          queueNumber.isEmpty ||
          poliName == null ||
          poliName.isEmpty) {
        return jsonResponse({
          'success': false,
          'message': 'queueNumber dan poliName wajib diisi.',
        }, status: 400);
      }

      try {
        await printService.printQueueTicket(
          queueNumber,
          poliName,
          printLabel: printLabel ?? 'Poli Tujuan',
          copies: copies,
        );
        return jsonResponse({
          'success': true,
          'message': 'Perintah cetak berhasil diproses.',
        });
      } catch (e) {
        return jsonResponse({
          'success': false,
          'message': 'Gagal mencetak.',
          'error': e.toString(),
        }, status: 500);
      }
    });

    router.post('/print/apm', (Request request) async {
      LoggerService.instance.info(
        LogSource.silentPrint,
        'Menerima request cetak APM.',
      );
      final body = await readJsonBody(request);
      final datas = body['datas'];
      final copies = body['copies'] is int ? body['copies'] as int : null;

      if (datas is! Map) {
        return jsonResponse({
          'success': false,
          'message': 'datas field wajib diisi untuk route /print/apm',
        }, status: 400);
      }

      try {
        await printService.printApmTicket(
          datas.cast<String, dynamic>(),
          copies: copies,
        );
        return jsonResponse({'success': true, 'message': 'Cetak APM berhasil.'});
      } catch (e) {
        return jsonResponse({
          'success': false,
          'message': 'Gagal mencetak APM.',
          'error': e.toString(),
        }, status: 500);
      }
    });

    router.post('/print/barcode', (Request request) async {
      LoggerService.instance.info(
        LogSource.silentPrint,
        'Menerima request cetak barcode.',
      );
      final body = await readJsonBody(request);
      final patientData = body['patientData'];

      if (patientData is! Map) {
        return jsonResponse({
          'success': false,
          'message': 'patientData wajib diisi untuk route /print/barcode',
        }, status: 400);
      }

      try {
        await printService.printBarcodeLabel(patientData.cast<String, dynamic>());
        return jsonResponse({
          'success': true,
          'message': 'Cetak barcode berhasil.',
        });
      } catch (e) {
        return jsonResponse({
          'success': false,
          'message': 'Gagal mencetak barcode.',
          'error': e.toString(),
        }, status: 500);
      }
    });

    return router;
  }

  Router _buildSidikJariRouter() {
    final router = Router();

    router.post('/open-sidikjari', (Request request) async {
      final body = await readJsonBody(request);
      final result = await sidikJariService.openSidikJari(
        nik: body['nik']?.toString(),
        noBpjs: body['no_bpjs']?.toString(),
        nama: body['nama']?.toString(),
      );
      return jsonResponse(result);
    });

    router.post('/open-frista', (Request request) async {
      final body = await readJsonBody(request);
      final result = await fristaService.openFrista(
        nik: body['nik']?.toString(),
        noBpjs: body['no_bpjs']?.toString(),
        nama: body['nama']?.toString(),
      );
      return jsonResponse(result);
    });

    router.post('/open-biometric', (Request request) async {
      final body = await readJsonBody(request);
      final type = body['type']?.toString().toLowerCase();
      if (type == 'frista' || type == 'face') {
        final result = await fristaService.openFrista(
          nik: body['nik']?.toString(),
          noBpjs: body['no_bpjs']?.toString(),
          nama: body['nama']?.toString(),
        );
        return jsonResponse(result);
      }
      final result = await sidikJariService.openSidikJari(
        nik: body['nik']?.toString(),
        noBpjs: body['no_bpjs']?.toString(),
        nama: body['nama']?.toString(),
      );
      return jsonResponse(result);
    });

    router.post('/reset', (Request request) async {
      final result = await sidikJariService.reset();
      return jsonResponse(result);
    });

    router.get('/health', (Request request) async {
      final result = await sidikJariService.health();
      return jsonResponse(result);
    });

    router.post('/frista/reset', (Request request) async {
      final result = await fristaService.reset();
      return jsonResponse(result);
    });

    router.get('/frista/health', (Request request) async {
      final result = await fristaService.health();
      return jsonResponse(result);
    });

    return router;
  }

  Future<void> startAll() async {
    await startPrintServer();
    await startSidikJariServer();
  }

  Future<void> stopAll() async {
    await stopPrintServer();
    await stopSidikJariServer();
  }

  Future<void> restartAll() async {
    await stopAll();
    await startAll();
  }

  Future<void> startPrintServer() async {
    if (_printServer != null) return;
    final cfg = getConfig();
    printStatus = ServerStatus.starting;
    onStatusChanged();
    try {
      final handler =
          const Pipeline().addMiddleware(corsMiddleware()).addHandler(
                _buildPrintRouter().call,
              );
      _printServer = await shelf_io.serve(
        handler,
        InternetAddress.anyIPv4,
        cfg.printPort,
      );
      printStatus = ServerStatus.running;
      LoggerService.instance.success(
        LogSource.system,
        'SilentPrint service berjalan di port ${cfg.printPort}.',
      );
    } catch (e) {
      printStatus = ServerStatus.error;
      LoggerService.instance.error(
        LogSource.system,
        'Gagal start SilentPrint service: $e',
      );
    }
    onStatusChanged();
  }

  Future<void> startSidikJariServer() async {
    if (_sidikJariServer != null) return;
    final cfg = getConfig();
    sidikJariStatus = ServerStatus.starting;
    onStatusChanged();
    try {
      final handler =
          const Pipeline().addMiddleware(corsMiddleware()).addHandler(
                _buildSidikJariRouter().call,
              );
      _sidikJariServer = await shelf_io.serve(
        handler,
        InternetAddress.anyIPv4,
        cfg.sidikJariPort,
      );
      sidikJariStatus = ServerStatus.running;
      LoggerService.instance.success(
        LogSource.system,
        'SidikJari & FRISTA service berjalan di port ${cfg.sidikJariPort}.',
      );
    } catch (e) {
      sidikJariStatus = ServerStatus.error;
      LoggerService.instance.error(
        LogSource.system,
        'Gagal start SidikJari & FRISTA service: $e',
      );
    }
    onStatusChanged();
  }

  Future<void> stopPrintServer() async {
    await _printServer?.close(force: true);
    _printServer = null;
    printStatus = ServerStatus.stopped;
    LoggerService.instance.warning(LogSource.system, 'SilentPrint service dihentikan.');
    onStatusChanged();
  }

  Future<void> stopSidikJariServer() async {
    await _sidikJariServer?.close(force: true);
    _sidikJariServer = null;
    sidikJariStatus = ServerStatus.stopped;
    LoggerService.instance.warning(LogSource.system, 'SidikJari & FRISTA service dihentikan.');
    onStatusChanged();
  }
}
