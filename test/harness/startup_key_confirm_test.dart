import 'package:flutter_test/flutter_test.dart';

import 'startup_key_support.dart';

void main() {
  testWidgets('startup recipe acknowledges its original film skip effect',
      (WidgetTester tester) async {
    final StartupKeyFixture fixture = StartupKeyFixture();
    await fixture.mount(tester);
    expect(fixture.session.film.skipRequested, isFalse);
    expect(fixture.done, 0);
    final Map<String, Object?> reply = await fixture.press();
    expect(reply['acted'], isTrue);
    expect(fixture.session.film.skipRequested, isTrue);
    expect(fixture.session.film.clockTicking, isTrue);
    expect(fixture.session.film.framePending, isFalse);
    expect(fixture.done, 0);
    await fixture.finish(tester);
    expect(fixture.session.film.clockTicking, isFalse);
    expect((await fixture.observe())['startupFilmState'], 'ended');
  });
}
