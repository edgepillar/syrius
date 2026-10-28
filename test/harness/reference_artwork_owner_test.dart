import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/shaders/shader_clock.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/entry_field.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/reference_artwork_source.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/app_lottie.dart';

class _Bundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (!key.startsWith('assets/lottie/')) return rootBundle.load(key);
    return ByteData.sublistView(utf8.encode(
      '{"v":"5.7.4","fr":60,"ip":0,"op":120,"w":64,"h":64,'
      '"nm":"Artwork owner fixture","ddd":0,"assets":[],"layers":[]}',
    ));
  }
}

Widget _host(Widget child) => DefaultAssetBundle(
  bundle: _Bundle(),
  child: MaterialApp(theme: AppTheme.darkTheme, home: child),
);

ReferenceArtworkSource _source(WidgetTester tester) =>
    tester.allStates.whereType<ReferenceArtworkSource>().single;

Future<void> _loaded(WidgetTester tester) async {
  final Future<Object?>? original = _source(tester).referenceArtworkReadiness;
  expect(original, isNotNull);
  await tester.runAsync<Object?>(() => original!);
  await tester.pump();
  expect(find.byType(Lottie), findsOneWidget);
}

Future<Uint8List> _pixels(WidgetTester tester) async {
  final Finder painter = find.descendant(
    of: find.byType(EntryField), matching: find.byType(RepaintBoundary),
  );
  final RenderRepaintBoundary original =
      tester.renderObject<RenderRepaintBoundary>(painter);
  return (await tester.runAsync<Uint8List>(() async {
    final ui.Image image = await original.toImage();
    try {
      final ByteData? data = await image.toByteData();
      if (data == null) throw StateError('Original artwork pixels unavailable');
      return Uint8List.fromList(data.buffer.asUint8List(
        data.offsetInBytes, data.lengthInBytes,
      ));
    } finally {
      image.dispose();
    }
  }))!;
}

void main() {
  const MethodChannel window = MethodChannel('window_manager');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(window, (MethodCall call) async =>
            call.method == 'isFocused' ? true : null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(window, null);
  });

  void prepare(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(256, 160)
      ..devicePixelRatio = 1;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.view.reset();
    });
  }

  testWidgets('globe sampling preserves its original clock and Future', (
    WidgetTester tester,
  ) async {
    prepare(tester);
    await tester.pumpWidget(_host(const AppLottie(
      AppLottieAsset.globe, size: 64,
    )));
    await _loaded(tester);
    final ReferenceArtworkSource source = _source(tester);
    final Lottie before = tester.widget<Lottie>(find.byType(Lottie));
    final Object renderer = tester.state(find.byType(Lottie));
    final AnimationController clock = before.controller! as AnimationController;
    bool completed = false;
    bool canceled = false;
    unawaited(clock.forward(from: 0).orCancel.then<void>(
      (_) { completed = true; },
      onError: (Object _) { canceled = true; },
    ));
    final ReferenceArtworkFrame frame = source.captureReferenceArtwork()!;
    expect(frame.observed, isFalse);
    await tester.pump(const Duration(milliseconds: 250));
    expect(frame.observed, isTrue);
    expect(frame.observation, <String, Object>{
      'kind': 'welcome_globe', 'frame': 48, 'frame_count': 120,
    });
    final Lottie sampled = tester.widget<Lottie>(find.byType(Lottie));
    expect(sampled.composition, same(before.composition));
    expect(tester.state(find.byType(Lottie)), same(renderer));
    expect(sampled.controller!.value, closeTo(48 / 119.99, 0.0000001));
    expect(sampled.frameRate, FrameRate.max);
    expect(clock.isAnimating, isTrue);
    expect(clock.value, greaterThan(0));
    expect(completed || canceled, isFalse);
    expect(frame.restore(), isTrue);
    expect(frame.restored, isFalse);
    await tester.pump(const Duration(milliseconds: 16));
    expect(frame.restored, isTrue);
    final Lottie restored = tester.widget<Lottie>(find.byType(Lottie));
    expect(restored.controller, same(clock));
    expect(restored.composition, same(before.composition));
    expect(restored.frameRate, before.frameRate);
    expect(tester.state(find.byType(Lottie)), same(renderer));
    await tester.pump(const Duration(seconds: 3));
    expect(completed, isTrue);
    expect(canceled, isFalse);
  });

  testWidgets('asset replacement permanently retires an earlier sample', (
    WidgetTester tester,
  ) async {
    prepare(tester);
    await tester.pumpWidget(_host(const AppLottie(
      AppLottieAsset.globe, size: 64,
    )));
    await _loaded(tester);
    final ReferenceArtworkFrame frame =
        _source(tester).captureReferenceArtwork()!;
    await tester.pump();
    expect(frame.observed, isTrue);
    await tester.pumpWidget(_host(const AppLottie(
      AppLottieAsset.zts, size: 64,
    )));
    await _loaded(tester);
    expect(frame.isCurrent, isFalse);
    expect(frame.restore(), isFalse);
    expect(frame.restored, isFalse);
    expect(_source(tester).captureReferenceArtwork(), isNull);
  });

  testWidgets('field sampling holds pixels while its original clock advances', (
    WidgetTester tester,
  ) async {
    prepare(tester);
    await tester.pumpWidget(_host(const EntryField()));
    await tester.pump(const Duration(milliseconds: 16));
    final ReferenceArtworkSource source = _source(tester);
    final ShaderClock clock = source.referenceArtworkGeneration as ShaderClock;
    final ReferenceArtworkFrame frame = source.captureReferenceArtwork()!;
    expect(frame.observed, isFalse);
    await tester.pump();
    expect(frame.observed, isTrue);
    final Uint8List first = await _pixels(tester);
    final double before = clock.value;
    await tester.pump(const Duration(seconds: 1));
    expect(clock.value, greaterThan(before));
    expect(clock.isRunning, isTrue);
    expect(await _pixels(tester), orderedEquals(first));
    expect(frame.restore(), isTrue);
    expect(frame.restored, isFalse);
    await tester.pump(const Duration(seconds: 10));
    expect(frame.restored, isTrue);
    expect(await _pixels(tester), isNot(orderedEquals(first)));
    expect(_source(tester), same(source));
    expect(source.referenceArtworkGeneration, same(clock));
    expect(clock.value, greaterThan(before));
  });

  testWidgets('a disposed field cannot restore through a replacement owner', (
    WidgetTester tester,
  ) async {
    prepare(tester);
    await tester.pumpWidget(_host(const EntryField()));
    await tester.pump(const Duration(milliseconds: 16));
    final ReferenceArtworkFrame frame =
        _source(tester).captureReferenceArtwork()!;
    await tester.pump();
    expect(frame.observed, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_host(const EntryField()));
    expect(frame.isCurrent, isFalse);
    expect(frame.restore(), isFalse);
    expect(frame.restored, isFalse);
    expect(_source(tester).referenceArtworkGeneration,
      isNot(same(frame.generation)));
  });
}
