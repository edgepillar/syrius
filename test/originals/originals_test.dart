import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/help_widgets/originals_card.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/launch_film.dart';

import '../settings_about_redesign/support.dart';

const String _movie = 'test/launch_film/fixtures/film.webp';

class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

Widget _art(BuildContext context, OriginalsArt art) => SizedBox(
  key: ValueKey<String>('fixture_art_${art.name}'),
  width: 16,
  height: 16,
);

Future<void> _movieUntil(WidgetTester tester, bool Function() done) async {
  for (int step = 0; step < 100 && !done(); step++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(
    done(),
    isTrue,
    reason: 'the tiny original movie finishes in finite frames',
  );
}

void main() {
  test('discovery is idempotent and ends with its Settings owner', () {
    final OriginalsController source = OriginalsController();
    int changes = 0;
    source
      ..addListener(() => changes++)
      ..reveal()
      ..reveal();
    expect(source.revealed, isTrue);
    expect(changes, 1);
    source
      ..dispose()
      ..reveal();
    expect(source.revealed, isFalse);
    expect(changes, 1);
    final OriginalsController next = OriginalsController();
    expect(next.revealed, isFalse);
    next.dispose();
  });

  testWidgets('only the exact discovery input reveals and clears silently', (
    WidgetTester tester,
  ) async {
    prepareAboutViewport(tester);
    final OriginalsController source = OriginalsController();
    addTearDown(source.dispose);
    bool current = true;
    await tester.pumpWidget(
      aboutHost(
        Column(
          children: <Widget>[
            OriginalsDiscovery(
              controller: source,
              isCurrent: () => current,
            ),
          ],
        ),
      ),
    );
    final Finder field = find.byKey(const Key('originals_discovery_field'));
    final Rect footer = tester.getRect(find.byType(OriginalsDiscovery));
    final Rect input = tester.getRect(field);
    expect(input.top - footer.top, 23);
    expect(footer.bottom - input.bottom, 26);
    final TextField widget = tester.widget<TextField>(field);
    expect(widget.decoration!.labelText, isNull);
    expect(widget.decoration!.hintText, isNull);
    expect(widget.decoration!.helperText, isNull);
    for (final String value in <String>[
      '3',
      '32',
      '123',
      '0321',
      '321 ',
      'text',
    ]) {
      await tester.enterText(field, value);
      await tester.pump();
      expect(source.revealed, isFalse);
      expect(widget.controller!.text, value);
      expect(tester.takeException(), isNull);
    }
    await tester.enterText(field, '321');
    expect(source.revealed, isFalse);
    expect(widget.controller!.text, isEmpty);
    current = false;
    await tester.pump();
    expect(source.revealed, isFalse);
    current = true;
    await tester.enterText(field, '321');
    tester.testTextInput.enterText('3');
    await tester.idle();
    await tester.pump();
    expect(source.revealed, isFalse);
    expect(widget.controller!.text, '3');
    await tester.enterText(field, '321');
    await tester.pump();
    expect(source.revealed, isTrue);
    expect(widget.controller!.text, isEmpty);
  });

  testWidgets('saved input cannot reveal a replaced or disposed controller', (
    WidgetTester tester,
  ) async {
    prepareAboutViewport(tester);
    final OriginalsController first = OriginalsController();
    final OriginalsController next = OriginalsController();
    addTearDown(first.dispose);
    addTearDown(next.dispose);
    await tester.pumpWidget(
      aboutHost(
        OriginalsDiscovery(
          controller: first,
          isCurrent: () => true,
        ),
      ),
    );
    final ValueChanged<String> old = tester
        .widget<TextField>(
          find.byKey(const Key('originals_discovery_field')),
        )
        .onChanged!;
    old('321');
    expect(first.revealed, isFalse);
    await tester.pumpWidget(
      aboutHost(
        OriginalsDiscovery(
          controller: next,
          isCurrent: () => true,
        ),
      ),
    );
    old('321');
    await tester.pump();
    expect(first.revealed, isFalse);
    expect(next.revealed, isFalse);
    final ValueChanged<String> saved = tester
        .widget<TextField>(
          find.byKey(const Key('originals_discovery_field')),
        )
        .onChanged!;
    saved('321');
    expect(next.revealed, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    saved('321');
    await tester.pump();
    expect(next.revealed, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a background round trip revokes the saved input callback', (
    WidgetTester tester,
  ) async {
    prepareAboutViewport(tester);
    final OriginalsController source = OriginalsController();
    addTearDown(source.dispose);
    await tester.pumpWidget(
      aboutHost(
        OriginalsDiscovery(
          controller: source,
          isCurrent: () => true,
        ),
      ),
    );
    final Finder field = find.byKey(const Key('originals_discovery_field'));
    final ValueChanged<String> old = tester.widget<TextField>(field).onChanged!;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    old('321');
    expect(source.revealed, isFalse);
    await tester.enterText(field, '321');
    expect(source.revealed, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(source.revealed, isFalse);
    await tester.enterText(field, '321');
    await tester.pump();
    expect(source.revealed, isTrue);
  });

  for (final bool light in <bool>[false, true]) {
    for (final bool scaledRtl in <bool>[false, true]) {
      testWidgets(
        'all original tiles fit, light $light, scaled RTL $scaledRtl',
        (WidgetTester tester) async {
          prepareAboutViewport(tester);
          final SemanticsHandle semantics = tester.ensureSemantics();
          try {
            await tester.pumpWidget(
              aboutHost(
                SingleChildScrollView(
                  child: OriginalsCard(
                    isCurrent: () => true,
                    artBuilder: _art,
                  ),
                ),
                light: light,
                rtl: scaledRtl,
                scale: scaledRtl ? 1.5 : 1,
                width: scaledRtl ? 640 : 1040,
              ),
            );
            await tester.pump(const Duration(milliseconds: 560));
            for (final OriginalsArt art in OriginalsArt.values) {
              expect(
                find.byKey(ValueKey<String>('fixture_art_${art.name}')),
                findsOneWidget,
              );
            }
            final Finder gallery = find.byType(OriginalsCard);
            final Rect tiles = tester.getRect(
              find.ancestor(
                of: find.byKey(const ValueKey<String>('fixture_art_launch')),
                matching: find.byType(Wrap),
              ).first,
            );
            final Rect footerRule = tester.getRect(
              find.descendant(of: gallery, matching: find.byType(Divider)).last,
            );
            expect(footerRule.top - tiles.bottom, closeTo(13, 0.001));
            final Finder eyeLabel = find.text('Hidden balances');
            final AppTokens tokens = AppTokens.of(tester.element(eyeLabel));
            for (final String label in <String>[
              'Generating plasma, in the strip',
              'Hidden balances',
              'Empty lists',
            ]) {
              final Text text = tester.widget<Text>(find.text(label));
              expect(text.style!.fontSize, 13);
              expect(text.style!.color, tokens.dim);
            }
            final Rect label = tester.getRect(eyeLabel);
            final Rect group = tester.getRect(
              find.ancestor(of: eyeLabel, matching: find.byType(Row)).first,
            );
            expect(
              scaledRtl ? group.right - label.right : label.left - group.left,
              closeTo(32, 0.001),
            );
            final Text hover = tester.widget<Text>(find.text('Hover to play'));
            expect(hover.style!.color, tokens.faint);
            expect(find.text('Play launch'), findsOneWidget);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
          }
        },
      );
    }
  }

  testWidgets(
    'replay uses only the original film and restores original focus',
    (WidgetTester tester) async {
      prepareAboutViewport(tester);
      final FocusNode originalFocus = FocusNode();
      addTearDown(originalFocus.dispose);
      LaunchFilmController? originalFilm;
      await tester.pumpWidget(
        aboutHost(
          SingleChildScrollView(
            child: Column(
              children: <Widget>[
                TextField(focusNode: originalFocus),
                OriginalsCard(
                  isCurrent: () => true,
                  artBuilder: _art,
                  replayBuilder:
                      (
                        BuildContext context,
                        LaunchFilmController film,
                        VoidCallback done,
                      ) {
                        originalFilm = film;
                        return LaunchFilm(
                          asset: _movie,
                          bundle: _FileBundle(),
                          controller: film,
                          onDone: done,
                        );
                      },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 560));
      originalFocus.requestFocus();
      await tester.pump();
      final Finder action = find.byKey(const Key('originals_play_launch'));
      final OutlinedButton button = tester.widget<OutlinedButton>(action);
      expect(tester.getSize(action).height, 26);
      expect(
        button.style!.padding!.resolve(<WidgetState>{}),
        const EdgeInsetsDirectional.symmetric(horizontal: 11),
      );
      expect(
        button.style!.textStyle!.resolve(<WidgetState>{})!.fontWeight,
        FontWeight.w500,
      );
      final VoidCallback replay = button.onPressed!;
      replay();
      replay();
      await tester.pump();
      expect(find.byKey(const Key('originals_movie_replay')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await _movieUntil(tester, () => originalFilm?.isDone ?? false);
      await tester.pump();
      expect(find.byKey(const Key('originals_movie_replay')), findsNothing);
      expect(originalFocus.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saved replay refuses a source that has left Settings', (
    WidgetTester tester,
  ) async {
    prepareAboutViewport(tester);
    bool current = true;
    await tester.pumpWidget(
      aboutHost(
        OriginalsCard(
          isCurrent: () => current,
          artBuilder: _art,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 560));
    final VoidCallback saved = tester
        .widget<OutlinedButton>(
          find.byKey(const Key('originals_play_launch')),
        )
        .onPressed!;
    current = false;
    saved();
    await tester.pump();
    expect(find.byKey(const Key('originals_movie_replay')), findsNothing);
  });
}
