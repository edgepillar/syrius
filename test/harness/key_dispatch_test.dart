import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../harness/app/agent.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('handled hardware keys still enter the Focus bridge exactly once', () async {
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    final List<Type> events = <Type>[];
    bool handler(KeyEvent event) {
      events.add(event.runtimeType);
      return true;
    }
    // ignore: deprecated_member_use
    final KeyMessageHandler? original =
        // ignore: deprecated_member_use
        ServicesBinding.instance.keyEventManager.keyMessageHandler;
    int legacyCalls = 0;
    // ignore: deprecated_member_use
    ServicesBinding.instance.keyEventManager.keyMessageHandler = (_) {
      legacyCalls++;
      return false;
    };
    keyboard.addHandler(handler);
    try {
      final Map<String, Object?> reply = await HarnessAgent.forTest()
          .commandForTest(<String, dynamic>{
            'cmd': 'key', 'key': 'space', 'settleMs': 0,
          });
      expect(reply['handled'], isTrue);
      expect(events, <Type>[KeyDownEvent, KeyUpEvent]);
      expect(legacyCalls, 2);
      expect(keyboard.logicalKeysPressed.contains(LogicalKeyboardKey.space),
        isFalse);
    } finally {
      keyboard.removeHandler(handler);
      // ignore: deprecated_member_use
      ServicesBinding.instance.keyEventManager.keyMessageHandler = original;
    }
  });

  test('unhandled hardware keys retain the original legacy handled result',
    () async {
      final HardwareKeyboard keyboard = HardwareKeyboard.instance;
      bool handler(KeyEvent _) => false;
      // ignore: deprecated_member_use
      final KeyMessageHandler? original =
          // ignore: deprecated_member_use
          ServicesBinding.instance.keyEventManager.keyMessageHandler;
      int legacyCalls = 0;
      // ignore: deprecated_member_use
      ServicesBinding.instance.keyEventManager.keyMessageHandler = (_) {
        legacyCalls++;
        return true;
      };
      keyboard.addHandler(handler);
      try {
        final Map<String, Object?> reply = await HarnessAgent.forTest()
            .commandForTest(<String, dynamic>{
              'cmd': 'key', 'key': 'space', 'settleMs': 0,
            });
        expect(reply['handled'], isTrue);
        expect(legacyCalls, 2);
        expect(keyboard.logicalKeysPressed.contains(LogicalKeyboardKey.space),
          isFalse);
      } finally {
        keyboard.removeHandler(handler);
        // ignore: deprecated_member_use
        ServicesBinding.instance.keyEventManager.keyMessageHandler = original;
      }
    },
  );

  test('a key ignored by both destinations remains unhandled', () async {
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    bool handler(KeyEvent _) => false;
    // ignore: deprecated_member_use
    final KeyMessageHandler? original =
        // ignore: deprecated_member_use
        ServicesBinding.instance.keyEventManager.keyMessageHandler;
    int calls = 0;
    // ignore: deprecated_member_use
    ServicesBinding.instance.keyEventManager.keyMessageHandler = (_) {
      calls++;
      return false;
    };
    keyboard.addHandler(handler);
    try {
      final Map<String, Object?> reply = await HarnessAgent.forTest()
          .commandForTest(<String, dynamic>{
            'cmd': 'key', 'key': 'space', 'settleMs': 0,
          });
      expect(reply['handled'], isFalse);
      expect(calls, 2);
      expect(keyboard.logicalKeysPressed.contains(LogicalKeyboardKey.space),
        isFalse);
    } finally {
      keyboard.removeHandler(handler);
      // ignore: deprecated_member_use
      ServicesBinding.instance.keyEventManager.keyMessageHandler = original;
    }
  });

  testWidgets('a hardware consumer cannot starve the original focused receiver', (
    WidgetTester tester,
  ) async {
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    final FocusNode focus = FocusNode();
    int downs = 0;
    int ups = 0;
    bool handler(KeyEvent _) => true;
    keyboard.addHandler(handler);
    try {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Focus(
          focusNode: focus,
          onKeyEvent: (_, KeyEvent event) {
            if (event is KeyDownEvent) downs++;
            if (event is KeyUpEvent) ups++;
            return KeyEventResult.handled;
          },
          child: const SizedBox.shrink(),
        ),
      ));
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasPrimaryFocus, isTrue);
      final Map<String, Object?> reply = await HarnessAgent.forTest()
          .commandForTest(<String, dynamic>{
            'cmd': 'key', 'key': 'space', 'settleMs': 0,
          });
      expect(reply['handled'], isTrue);
      expect(downs, 1);
      expect(ups, 1);
      expect(keyboard.logicalKeysPressed.contains(LogicalKeyboardKey.space),
        isFalse);
    } finally {
      keyboard.removeHandler(handler);
      await tester.pumpWidget(const SizedBox.shrink());
      focus.dispose();
    }
  });
}
