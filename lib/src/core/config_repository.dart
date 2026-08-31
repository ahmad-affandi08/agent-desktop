import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_config.dart';

class ConfigRepository {
  static const _prefsKey = 'rssg_agent_config_v1';

  Future<AppConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return const AppConfig();
    try {
      return AppConfig.decode(raw);
    } catch (_) {
      return const AppConfig();
    }
  }

  Future<void> save(AppConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, config.encode());
  }
}
