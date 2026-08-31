import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/services/desktop/window_service.dart';
import 'src/ui/app_shell.dart';
import 'src/ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WindowService.init();
  runApp(const ProviderScope(child: RssgAgentApp()));
}

class RssgAgentApp extends StatelessWidget {
  const RssgAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RSSG Agent Desktop',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppShell(),
    );
  }
}
