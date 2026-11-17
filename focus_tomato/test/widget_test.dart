import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_tomato/main.dart';
import 'package:focus_tomato/system.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows 25:00, starts and pauses', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(FocusTomatoApp(prefs: prefs, system: SystemBridge()));

    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('Paused · Focus'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Start'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.bySemanticsLabel('Pause'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Pause'));
    await tester.pump();
    expect(find.bySemanticsLabel('Start'), findsOneWidget);

    await tester.tap(find.text('Short break'));
    await tester.pump();
    expect(find.text('05:00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // stop ticker
  });
}
