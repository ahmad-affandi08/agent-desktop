import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rssg_agent_desktop/src/models/app_config.dart';
import 'package:rssg_agent_desktop/src/services/sidikjari/sidikjari_service.dart';
import 'package:rssg_agent_desktop/src/services/sidikjari/windows_automation_script.dart';

void main() {
  test('UTF-16LE encoder produces bytes required by PowerShell', () {
    expect(
      SidikJariService.utf16leBytes('AĀ'),
      <int>[0x41, 0x00, 0x00, 0x01],
    );
  });

  test('integrated script fits the Windows process command-line limit', () {
    final encodedLength = base64
        .encode(
          SidikJariService.utf16leBytes(windowsSidikJariAutomationScript),
        )
        .length;

    // CreateProcess allows 32,767 characters. Leave room for the executable
    // name and all PowerShell flags used by SidikJariService.
    expect(encodedLength, lessThan(30000));
  });

  test('duplicate patient requests are rejected only during debounce window', () {
    final service = SidikJariService(getConfig: () => const AppConfig());

    expect(service.isDuplicateRequest('0001'), isFalse);
    expect(service.isDuplicateRequest('0001'), isTrue);
    expect(service.isDuplicateRequest('0002'), isFalse);
  });
}
