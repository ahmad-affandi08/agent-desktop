import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_controller.dart';

final appControllerProvider = Provider<AppController>((ref) {
  final controller = AppController();
  ref.onDispose(controller.dispose);
  return controller;
});
