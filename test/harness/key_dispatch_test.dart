import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../harness/app/agent.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('handled hardware keys do not enter the legacy bridge twice', () async {
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
      expect(legacyCalls, 0);
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
}
