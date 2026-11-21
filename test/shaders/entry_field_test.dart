import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/shaders/drift_raster_region.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/entry_field.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/hero_field.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/entry_card_surface.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/welcome_surface.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/launch_film.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/frosted_route.dart';

const MethodChannel _window = MethodChannel('window_manager');
const Size _size = Size(1280, 780);
const Key _clipFrame = Key('entry_field_clip_frame');

class _TestLaunchFilmController extends LaunchFilmController {
  int _shownFrame = -1;
  bool _finished = false;

  @override
  int get frame => _shownFrame;

  @override
  bool get isDone => _finished;

  void show(int index) {
    _shownFrame = index;
    notifyListeners();
  }

  void finish() {
    _finished = true;
    notifyListeners();
  }
}

Widget _host({
  Widget child = const EntryField(),
  bool light = false,
  bool enabled = true,
  bool disableAnimations = false,
  double pixelRatio = 1,
}) => MaterialApp(
  theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
  locale: const Locale('en'),
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: TickerMode(
    enabled: enabled,
    child: MediaQuery(
      data: MediaQueryData(
        size: _size,
        disableAnimations: disableAnimations,
        devicePixelRatio: pixelRatio,
      ),
      child: Scaffold(body: child),
    ),
  ),
);

void _prepare(WidgetTester tester) {
  tester.view
    ..physicalSize = _size
    ..devicePixelRatio = 1;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    tester.view.reset();
  });
}

Future<Uint8List> _pixels(WidgetTester tester, {Finder? surface}) async {
  final Finder target =
      surface ??
      find.descendant(
        of: find.byType(EntryField),
        matching: find.byType(RepaintBoundary),
      );
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(target);
  return (await tester.runAsync<Uint8List>(() async {
    final ui.Image image = await boundary.toImage();
    try {
      expect(image.width, _size.width);
      expect(image.height, _size.height);
      final ByteData? data = await image.toByteData();
      if (data == null) {
        throw StateError('The original pixels are unavailable');
      }
      return Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  }))!;
}

List<ui.Image> _watchEntryRasters() {
  final List<ui.Image> images = <ui.Image>[];
  final ui.ImageEventCallback? previous = ui.Image.onCreate;
  ui.Image.onCreate = (ui.Image image) {
    previous?.call(image);
    // Exclude the client-sized readbacks that _pixels owns and disposes.
    if (image.width != _size.width || image.height != _size.height) {
      images.add(image);
    }
  };
  addTearDown(() {
    ui.Image.onCreate = previous;
  });
  return images;
}

List<int> _rgba(Uint8List pixels, int x, int y) {
  final int offset = (y * _size.width.toInt() + x) * 4;
  return pixels.sublist(offset, offset + 4);
}

void _expectPaintEquivalent(Uint8List cached, Uint8List analytic) {
  for (final (int x, int y) in <(int, int)>[
    (1, 1), (1278, 1), (1, 778), (1278, 778), (120, 120),
    (380, 330), (640, 390), (900, 580), (1160, 660),
  ]) {
    final List<int> cachedPixel = _rgba(cached, x, y);
    final List<int> analyticPixel = _rgba(analytic, x, y);
    for (int channel = 0; channel < 4; channel++) {
      expect(cachedPixel[channel], closeTo(analyticPixel[channel], 2));
    }
  }
}

void _expectBackground(Uint8List pixels, bool light) {
  final Color background = light
      ? AppTokens.light.background
      : AppTokens.dark.background;
  final List<int> expected = <int>[
    (background.r * 255).round(),
    (background.g * 255).round(),
    (background.b * 255).round(),
  ];
  final List<int> corner = _rgba(pixels, 4, 775);
  for (int channel = 0; channel < 3; channel++) {
    expect(corner[channel], closeTo(expected[channel], 2));
  }
  expect(corner[3], 255);
}

void _expectBand(
  Uint8List pixels,
  int x,
  int y,
  List<List<int>> bands,
) {
  final List<int> pixel = _rgba(pixels, x, y);
  for (int channel = 0; channel < 3; channel++) {
    expect(
      pixel[channel],
      inInclusiveRange(bands[channel][0], bands[channel][1]),
      reason: 'Reference entry wash at $x,$y, channel $channel',
    );
  }
  expect(pixel[3], 255);
}

void _expectEntryWash(Uint8List pixels, bool light) {
  // Independent colour envelopes at the CSS field's initial light centres.
  // They allow blur/raster rounding, but reject a card base, a flat fallback
  // and gradients composited without the reference's grouped .35 opacity.
  _expectBand(
    pixels,
    230,
    205,
    light
        ? <List<int>>[
            <int>[200, 216],
            <int>[222, 237],
            <int>[197, 216],
          ]
        : <List<int>>[
            <int>[20, 31],
            <int>[45, 57],
            <int>[20, 38],
          ],
  );
  _expectBand(
    pixels,
    945,
    532,
    light
        ? <List<int>>[
            <int>[197, 218],
            <int>[211, 231],
            <int>[228, 238],
          ]
        : <List<int>>[
            <int>[19, 31],
            <int>[31, 43],
            <int>[47, 61],
          ],
  );
  _expectBand(
    pixels,
    676,
    41,
    light
        ? <List<int>>[
            <int>[232, 242],
            <int>[210, 225],
            <int>[217, 233],
          ]
        : <List<int>>[
            <int>[39, 56],
            <int>[22, 37],
            <int>[31, 45],
          ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_window, (MethodCall call) async {
          if (call.method == 'isFocused') {
            return true;
          }
          return null;
        });
  });

  tearDown(() {
    expect(FrostHold.count.value, 0);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_window, null);
  });

  test('the entry raster encloses the body and caption throughout drift', () {
    const Rect viewport = Rect.fromLTWH(0, -32, 1280, 780);
    const Rect wash = Rect.fromLTWH(-256, -149.6, 1792, 1047.2);
    final Offset center = wash.center;
    for (final double ratio in <double>[1, 1.25, 2]) {
      final DriftRasterRegion raster = driftRasterRegion(
        viewport: viewport, field: wash, blurBleed: 180, pixelRatio: ratio,
      )!;
      final Rect crop = raster.origin &
          Size(raster.width / ratio, raster.height / ratio);
      expect(crop.width * crop.height, lessThan(2152 * 1408 * 0.85));
      expect(
        crop.bottom,
        lessThan(1023),
        reason: 'The top caption does not add storage below the body.',
      );
      for (int step = 0; step <= 20; step++) {
        final double progress = step / 20;
        final double radians = fieldDriftAngle * progress;
        final Offset shift = Offset(
          wash.width * fieldDriftX * (2 * progress - 1),
          wash.height * fieldDriftY * (2 * progress - 1),
        );
        for (final Offset corner in <Offset>[
          viewport.topLeft, viewport.topRight,
          viewport.bottomLeft, viewport.bottomRight,
        ]) {
          final Offset point = corner - center - shift;
          final Offset sample = center + Offset(
            point.dx * math.cos(radians) + point.dy * math.sin(radians),
            -point.dx * math.sin(radians) + point.dy * math.cos(radians),
          );
          expect(crop.deflate(179).contains(sample), isTrue);
        }
      }
    }
  });

  for (final bool light in <bool>[false, true]) {
    final String name = light ? 'light' : 'dark';

    testWidgets('$name pixels keep the window base and restrained entry wash', (
      WidgetTester tester,
    ) async {
      _prepare(tester);
      await tester.pumpWidget(_host(light: light));
      await tester.pump();
      final Uint8List pixels = await _pixels(tester);
      _expectBackground(pixels, light);
      _expectEntryWash(pixels, light);
    });

    testWidgets(
      '$name painted drift alternates at 20 seconds and repeats at 40',
      (
        WidgetTester tester,
      ) async {
        _prepare(tester);
        final List<ui.Image> rasters = _watchEntryRasters();
        await tester.pumpWidget(_host(light: light));
        await tester.pump();
        final Uint8List start = await _pixels(tester);
        expect(rasters, hasLength(1));
        expect(
          rasters.single.width * rasters.single.height,
          lessThan(2152 * 1452 * 0.25),
        );
        expect(rasters.single.debugDisposed, isFalse);
        await tester.pump(const Duration(seconds: 20));
        final Uint8List end = await _pixels(tester);
        _expectBackground(end, light);
        expect(end, isNot(orderedEquals(start)));
        await tester.pump(const Duration(seconds: 20));
        expect(await _pixels(tester), orderedEquals(start));
        expect(rasters, hasLength(1));
        expect(rasters.single.debugDisposed, isFalse);
        await tester.pumpWidget(_host(light: light, pixelRatio: 100));
        await tester.pump();
        expect(rasters, hasLength(1));
        expect(rasters.single.debugDisposed, isTrue);
        _expectPaintEquivalent(start, await _pixels(tester));
        await tester.pump(const Duration(seconds: 20));
        _expectPaintEquivalent(end, await _pixels(tester));
      },
    );

    testWidgets('$name Welcome and entry card paint the real shared field', (
      WidgetTester tester,
    ) async {
      _prepare(tester);
      final List<WelcomeDestination> destinations = <WelcomeDestination>[];
      await tester.pumpWidget(
        _host(
          light: light,
          child: WelcomeSurface(
            source: Object(),
            onSelected: destinations.add,
            wrapImportDrop: (Widget child) => child,
            // Art/drop fixtures are inert; the backdrop is production.
            globe: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 401));
      expect(find.byType(EntryField), findsOneWidget);
      _expectBackground(await _pixels(tester), light);
      await tester.tap(find.byKey(const Key('welcome_import')));
      expect(destinations, <WelcomeDestination>[
        WelcomeDestination.importWallet,
      ]);
      expect(
        find.text('A seed, or a wallet file dropped here'),
        findsOneWidget,
      );
      expect(find.textContaining('dropped here'), findsOneWidget);

      int back = 0;
      await tester.pumpWidget(
        _host(
          light: light,
          child: EntryCardSurface(
            title: 'Import your wallet',
            steps: const <String>['Seed or file', 'Password', 'Ready'],
            step: 0,
            onBack: () => back++,
            marker: const Key('fixture_entry_card'),
            child: const Text('Seed or file'),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(EntryField), findsOneWidget);
      _expectBackground(await _pixels(tester), light);
      await tester.tap(find.byKey(const Key('entry_back')));
      expect(back, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('lock raster preparation waits for launch playback to finish', (
    WidgetTester tester,
  ) async {
    _prepare(tester);
    final ValueNotifier<double> progress = ValueNotifier<double>(0);
    final _TestLaunchFilmController film = _TestLaunchFilmController();
    addTearDown(progress.dispose);
    addTearDown(film.dispose);
    final List<ui.Image> rasters = _watchEntryRasters();
    await tester.pumpWidget(_host(
      child: ValueListenableBuilder<double>(
        valueListenable: progress,
        child: EntryField(captionProgress: progress, launchFilm: film),
        builder: (_, double value, Widget? child) => TickerMode(
          enabled: value > 0,
          child: Opacity(opacity: value, child: child),
        ),
      ),
    ));
    expect(rasters, isEmpty);
    // The real film reports each displayed frame from its ticker.
    tester.binding.scheduleFrameCallback((_) => film.show(0));
    await tester.pump();
    expect(rasters, isEmpty);
    tester.binding.scheduleFrameCallback((_) => film.show(1));
    await tester.pump();
    expect(rasters, isEmpty);
    tester.binding.scheduleFrameCallback((_) => film.finish());
    await tester.pump();
    expect(rasters, hasLength(1));
    expect(rasters.single.debugDisposed, isFalse);
    progress.value = 1;
    await tester.pump();
    final Uint8List pixels = await _pixels(tester);
    _expectBackground(pixels, false);
    _expectEntryWash(pixels, false);
    expect(rasters, hasLength(1));
    expect(rasters.single.debugDisposed, isFalse);
  });

  testWidgets(
    'OS animation flags keep the real field moving on its own clock',
    (
      WidgetTester tester,
    ) async {
      _prepare(tester);
      await tester.pumpWidget(_host(disableAnimations: true));
      await tester.pump();
      final Uint8List start = await _pixels(tester);
      await tester.pump(const Duration(seconds: 10));
      final Uint8List middle = await _pixels(tester);
      expect(middle, isNot(orderedEquals(start)));
      await tester.pump(const Duration(seconds: 20));
      expect(await _pixels(tester), orderedEquals(middle));
    },
  );

  testWidgets('hidden, inactive and covered time never advances the field', (
    WidgetTester tester,
  ) async {
    _prepare(tester);
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    final Uint8List before = await _pixels(tester);

    await tester.pumpWidget(_host(enabled: false));
    await tester.pump(const Duration(seconds: 30));
    expect(await _pixels(tester), orderedEquals(before));
    await tester.pumpWidget(_host());
    await tester.pump();
    expect(await _pixels(tester), orderedEquals(before));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 30));
    expect(await _pixels(tester), orderedEquals(before));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(await _pixels(tester), orderedEquals(before));

    FrostHold.acquire();
    FrostHold.acquire();
    try {
      await tester.pump(const Duration(seconds: 30));
      expect(await _pixels(tester), orderedEquals(before));
      FrostHold.release();
      await tester.pump(const Duration(seconds: 30));
      expect(await _pixels(tester), orderedEquals(before));
    } finally {
      FrostHold.release();
      FrostHold.release();
    }
    await tester.pump();
    expect(await _pixels(tester), orderedEquals(before));
    await tester.pump(const Duration(seconds: 5));
    expect(await _pixels(tester), isNot(orderedEquals(before)));
  });

  testWidgets(
    'a live theme change repaints the window base without a card flash',
    (
      WidgetTester tester,
    ) async {
      _prepare(tester);
      final List<ui.Image> rasters = _watchEntryRasters();
      await tester.pumpWidget(_host());
      await tester.pump();
      _expectBackground(await _pixels(tester), false);
      await tester.pumpWidget(_host(light: true));
      await tester.pump(const Duration(milliseconds: 300));
      _expectBackground(await _pixels(tester), true);
      await tester.pumpWidget(_host());
      await tester.pump(const Duration(milliseconds: 300));
      _expectBackground(await _pixels(tester), false);
      expect(find.byType(EntryField), findsOneWidget);
      // The themes share the three source colours, while the window base
      // repaints independently. Animation and a theme round-trip reuse it.
      expect(rasters, hasLength(1));
      tester.view
        ..physicalSize = _size * 2
        ..devicePixelRatio = 2;
      await tester.pumpWidget(_host(pixelRatio: 2));
      await tester.pump();
      final Uint8List scaled = await _pixels(tester);
      _expectBackground(scaled, false);
      _expectEntryWash(scaled, false);
      expect(rasters, hasLength(2));
      expect(rasters.first.debugDisposed, isTrue);
      expect(rasters.last.debugDisposed, isFalse);
      expect(rasters.last.width, closeTo(rasters.first.width * 2, 2));
      expect(rasters.last.height, closeTo(rasters.first.height * 2, 2));
      await tester.pump(const Duration(seconds: 1));
      expect(rasters, hasLength(2));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(rasters.every((ui.Image image) => image.debugDisposed), isTrue);
    },
  );

  testWidgets('launch lights fade over the same opaque shell in both themes', (
    WidgetTester tester,
  ) async {
    _prepare(tester);
    final ValueNotifier<double> progress = ValueNotifier<double>(0);
    addTearDown(progress.dispose);
    final Finder body = find.byKey(_clipFrame);
    for (final bool light in <bool>[false, true]) {
      // Each arm starts in its own settled theme. Carrying the MaterialApp
      // across arms would animate its tokens over a fixed new base color.
      await tester.pumpWidget(const SizedBox.shrink());
      final AppTokens tokens = light ? AppTokens.light : AppTokens.dark;
      final double checkpoint = tokens.launchSettleReference.progress;
      Widget surface(Widget field) => _host(
        light: light,
        enabled: false,
        child: RepaintBoundary(
          key: _clipFrame,
          child: ColoredBox(color: tokens.background, child: field),
        ),
      );
      for (final double weight in <double>[0, 0.5, 1]) {
        progress.value = checkpoint * weight;
        await tester.pumpWidget(surface(
          Opacity(opacity: weight, child: const EntryField()),
        ));
        await tester.pump();
        expect(AppTokens.of(tester.element(find.byType(EntryField))).background,
          tokens.background);
        final Uint8List reference = await _pixels(tester, surface: body);
        await tester.pumpWidget(surface(EntryField(
          captionProgress: progress,
          fadeLightsOnOpaqueBase: true,
        )));
        await tester.pump();
        final Uint8List paint = await _pixels(tester, surface: body);
        int maxError = 0;
        for (int i = 0; i < paint.length; i++) {
          maxError = math.max(maxError, (paint[i] - reference[i]).abs());
        }
        // Group opacity can introduce one extra 8-bit rounding step.
        expect(maxError, lessThanOrEqualTo(1),
          reason: '${light ? 'light' : 'dark'} weight $weight');
      }
    }
  });

  testWidgets(
    'the blurred paint stays clipped to its actual client rectangle',
    (
      WidgetTester tester,
    ) async {
      _prepare(tester);
      const Color outside = Color(0xFF9B743D);
      const List<Widget> fields = <Widget>[EntryField(), HeroField.home()];
      for (final Widget field in fields) {
        await tester.pumpWidget(
          _host(
            child: RepaintBoundary(
              key: _clipFrame,
              child: ColoredBox(
                color: outside,
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      left: 200,
                      top: 100,
                      width: 700,
                      height: 500,
                      child: field,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final Uint8List pixels = await _pixels(
          tester,
          surface: find.byKey(_clipFrame),
        );
        for (final Offset point in const <Offset>[
          Offset(199, 350),
          Offset(900, 350),
          Offset(550, 99),
          Offset(550, 600),
        ]) {
          expect(_rgba(pixels, point.dx.toInt(), point.dy.toInt()), <int>[
            155,
            116,
            61,
            255,
          ]);
        }
        expect(_rgba(pixels, 550, 350), isNot(<int>[155, 116, 61, 255]));
      }
    },
  );

  testWidgets('disposal leaves no clock callbacks or delayed painting', (
    WidgetTester tester,
  ) async {
    _prepare(tester);
    final List<ui.Image> rasters = _watchEntryRasters();
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(rasters, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 40));
    expect(tester.binding.transientCallbackCount, 0);
    expect(rasters.single.debugDisposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final bool light in <bool>[false, true]) {
    testWidgets(
      'Home reuses one raster through its 18/36 second drift, light=$light',
      (WidgetTester tester) async {
        _prepare(tester);
        final List<ui.Image> rasters = _watchEntryRasters();
        const Widget field = HeroField.home();
        Finder surface() => find.descendant(
          of: find.byType(HeroField),
          matching: find.byType(RepaintBoundary),
        );
        await tester.pumpWidget(_host(
          child: field, light: light, disableAnimations: true,
        ));
        await tester.pump();
        final CustomPaint homePaint = tester.widget<CustomPaint>(
          find.descendant(of: surface(), matching: find.byType(CustomPaint)),
        );
        expect(homePaint.willChange, isTrue);
        final Uint8List start = await _pixels(tester, surface: surface());
        expect(rasters, hasLength(1));
        expect(rasters.single.width, greaterThan(_size.width));
        expect(rasters.single.height, greaterThan(_size.height));
        expect(
          rasters.single.width * rasters.single.height,
          lessThan(2544 * 1644 * 0.55),
        );
        await tester.pump(const Duration(seconds: 18));
        final Uint8List turned = await _pixels(tester, surface: surface());
        expect(turned, isNot(orderedEquals(start)));
        await tester.pump(const Duration(seconds: 18));
        expect(await _pixels(tester, surface: surface()), orderedEquals(start));
        expect(rasters, hasLength(1));
        expect(rasters.single.debugDisposed, isFalse);

        // An oversized requested raster keeps the original analytic paint.
        await tester.pumpWidget(_host(
          child: field, light: light, pixelRatio: 100,
          disableAnimations: true,
        ));
        await tester.pump();
        expect(rasters, hasLength(1));
        expect(rasters.single.debugDisposed, isTrue);
        _expectPaintEquivalent(
          start, await _pixels(tester, surface: surface()),
        );
        await tester.pump(const Duration(seconds: 18));
        _expectPaintEquivalent(
          turned, await _pixels(tester, surface: surface()),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 36));
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Home retires rasters on DPR, geometry and owner changes', (
    WidgetTester tester,
  ) async {
    _prepare(tester);
    final List<ui.Image> rasters = _watchEntryRasters();
    const Widget field = HeroField.home();
    Finder surface() => find.descendant(
      of: find.byType(HeroField),
      matching: find.byType(RepaintBoundary),
    );
    await tester.pumpWidget(_host(child: field));
    await tester.pump();
    final Uint8List dark = await _pixels(tester, surface: surface());
    await tester.pumpWidget(_host(child: field, light: true));
    await tester.pump(const Duration(milliseconds: 300));
    final Uint8List light = await _pixels(tester, surface: surface());
    expect(light, isNot(orderedEquals(dark)));
    expect(rasters, hasLength(1));
    await tester.pumpWidget(_host(child: field));
    await tester.pump(const Duration(milliseconds: 300));
    expect(rasters, hasLength(1));

    tester.view
      ..physicalSize = _size * 2
      ..devicePixelRatio = 2;
    await tester.pumpWidget(_host(child: field, pixelRatio: 2));
    await tester.pump();
    expect(rasters, hasLength(2));
    expect(rasters.first.debugDisposed, isTrue);
    expect(rasters.last.debugDisposed, isFalse);
    expect(rasters.last.width, closeTo(rasters.first.width * 2, 2));
    expect(rasters.last.height, closeTo(rasters.first.height * 2, 2));
    expect(rasters.last.width * rasters.last.height,
      lessThanOrEqualTo(16 * 1024 * 1024));

    tester.view
      ..physicalSize = const Size(1200, 600)
      ..devicePixelRatio = 1;
    await tester.pumpWidget(_host(child: field));
    await tester.pump();
    expect(rasters, hasLength(3));
    expect(rasters[1].debugDisposed, isTrue);
    expect(rasters.last.debugDisposed, isFalse);
    expect(rasters.last.width, greaterThan(1200));
    expect(rasters.last.height, greaterThan(600));
    expect(
      rasters.last.width * rasters.last.height,
      lessThan(2400 * 1320 * 0.55),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 36));
    expect(rasters.every((ui.Image image) => image.debugDisposed), isTrue);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
