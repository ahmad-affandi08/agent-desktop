// Basic smoke test. AppShell talks to native window/tray plugins and binds
// real HTTP ports on init, so it isn't exercised here — this just confirms
// the widget tree renders under MaterialApp without a native platform.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a basic widget tree', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('RSSG Agent Desktop')),
      ),
    );

    expect(find.text('RSSG Agent Desktop'), findsOneWidget);
  });
}
