import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rssg_agent_desktop/src/models/app_config.dart';
import 'package:rssg_agent_desktop/src/services/frista/frista_service.dart';
import 'package:rssg_agent_desktop/src/services/frista/windows_frista_automation_script.dart';

void main() {
  test('UTF-16LE encoder produces bytes required by PowerShell for FRISTA', () {
    expect(
      FristaService.utf16leBytes('AĀ'),
      <int>[0x41, 0x00, 0x00, 0x01],
    );
  });

  test('integrated FRISTA script fits the Windows process command-line limit', () {
    final encodedLength = base64
        .encode(
          FristaService.utf16leBytes(windowsFristaAutomationScript),
        )
        .length;

    expect(encodedLength, lessThan(30000));
  });

  test('duplicate FRISTA requests are debounced properly', () {
    final service = FristaService(getConfig: () => const AppConfig());

    expect(service.isDuplicateRequest('0001'), isFalse);
    expect(service.isDuplicateRequest('0001'), isTrue);
    expect(service.isDuplicateRequest('0002'), isFalse);
  });
}
