import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexoratv/ui/widgets.dart';

void main() {
  Future<List<String>> pumpFocusedRow(WidgetTester tester) async {
    final events = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListRow(
            onTap: () => events.add('tap'),
            onLongPress: () => events.add('long'),
            child: const Text('Chaîne'),
          ),
        ),
      ),
    );
    // Focus sur la ligne, comme au D-pad.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    return events;
  }

  testWidgets('OK court sur une ligne = clic', (tester) async {
    final events = await pumpFocusedRow(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 600));
    expect(events, ['tap']);
  });

  testWidgets('OK maintenu sur une ligne = appui long, une seule fois', (
    tester,
  ) async {
    final events = await pumpFocusedRow(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(events, ['long']);
  });
}
