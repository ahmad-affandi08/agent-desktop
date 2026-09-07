import 'package:flutter_test/flutter_test.dart';
import 'package:rssg_agent_desktop/src/models/app_config.dart';

void main() {
  test('legacy helper path is ignored when loading saved configuration', () {
    final config = AppConfig.decode('''
      {
        "printPort": 3017,
        "helperExePath": "C:\\\\old\\\\sidikjari-autofill.exe"
      }
    ''');

    expect(config.printPort, 3017);
    expect(config.toJson().containsKey('helperExePath'), isFalse);
  });

  test('biometricMode defaults to both and preserves custom values', () {
    const defaultConfig = AppConfig();
    expect(defaultConfig.biometricMode, 'both');

    final configFrista = AppConfig.decode('{"biometricMode": "frista"}');
    expect(configFrista.biometricMode, 'frista');

    final configSidikJari = AppConfig.decode('{"biometricMode": "sidikjari"}');
    expect(configSidikJari.biometricMode, 'sidikjari');
  });
}
