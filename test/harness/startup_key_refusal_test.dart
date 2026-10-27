import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../harness/app/agent.dart';
import 'startup_key_support.dart';

void main() {
  testWidgets('an early keyboard handler cannot confirm another film action',
      (WidgetTester tester) async {
    final StartupKeyFixture fixture = StartupKeyFixture();
    await fixture.mount(tester);
    int intercepted = 0;
    KeyEventResult foreign(KeyEvent event) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        intercepted++;
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    FocusManager.instance.addEarlyKeyEventHandler(foreign);
    addTearDown(() =>
      FocusManager.instance.removeEarlyKeyEventHandler(foreign));
    await expectLater(fixture.press(), throwsA(
      isA<HarnessError>().having((HarnessError value) => value.message,
        'original effect', 'wallet-recipe-startup-key-unconfirmed'),
    ));
    expect(intercepted, greaterThanOrEqualTo(2));
    expect(fixture.session.film.skipRequested, isFalse);
    expect(fixture.done, 0);
    expect(HardwareKeyboard.instance.physicalKeysPressed,
      isNot(contains(PhysicalKeyboardKey.space)));
  });
}
