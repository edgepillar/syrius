import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cryptography/dart.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hex/hex.dart';
import 'package:lottie/lottie.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/shaders/shader_clock.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/entry_field.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/entry_capture_source.dart';
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
  final EntryCaptureCompletion observed = EntryCaptureCompletion(original!);
  for (int frame = 0; frame < 200 &&
      observed.status == EntryCaptureStatus.pending; frame++) {
    await tester.runAsync<void>(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
  expect(observed.status, EntryCaptureStatus.succeeded);
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

const String _trimAsset = 'assets/lottie/ic_anim_welcome.json';
const String _trimSha =
    'cb655bfa87969f8c91fd45f57fb03e1c592cc524f7e11bced97b03f4b69114af';
const int _trimEdge = 470;
const int _trimFrame = 720;

String _trimHash(Uint8List bytes) =>
    HEX.encode(const DartSha256().hashSync(bytes).bytes);

Future<Uint8List> _trimRender(LottieComposition composition) async {
  final LottieDrawable drawable = LottieDrawable(
    composition, frameRate: FrameRate.max,
  )
    ..filterQuality = ui.FilterQuality.medium
    ..setProgress(_trimFrame / composition.durationFrames);
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder)
    ..clipRect(const ui.Rect.fromLTWH(0, 0, 470, 470))
    ..translate(-(836 - 470) / 2, 0);
  drawable.draw(canvas, const ui.Rect.fromLTWH(0, 0, 836, 470),
      fit: BoxFit.contain, alignment: Alignment.center);
  final ui.Picture picture = recorder.endRecording();
  try {
    final ui.Image image = await picture.toImage(_trimEdge, _trimEdge);
    try {
      final ByteData data = (await image.toByteData())!;
      return Uint8List.fromList(data.buffer.asUint8List(
        data.offsetInBytes, data.lengthInBytes,
      ));
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

Future<Uint8List> _trimReference(String theme) async {
  final File original = File(
    'mockups/redesign/shots/44-welcome-$theme.png',
  );
  expect(await original.length(), lessThan(1024 * 1024));
  final Uint8List encoded = await original.readAsBytes();
  expect(_trimHash(encoded), theme == 'dark'
      ? '4ffec4db314a53d10ea672cc57e7f7e931b0824bea34ca410522811b679c2181'
      : '4698832240fb65ae6880c1b0a38bbfd777e3670721239828a1738bbf6d91b08c');
  final ui.Codec codec = await ui.instantiateImageCodec(encoded);
  try {
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;
    try {
      expect(image.width, 1280);
      expect(image.height, 780);
      final ByteData data = (await image.toByteData())!;
      final Uint8List rgba = data.buffer.asUint8List(
        data.offsetInBytes, data.lengthInBytes,
      );
      // The original 906 px row is centred in 1280 px. Its 470 px globe
      // viewport is centred in the 748 px body beneath the 32 px caption.
      final Uint8List crop = Uint8List(_trimEdge * _trimEdge * 4);
      for (int y = 0; y < _trimEdge; y++) {
        final int offset = ((171 + y) * 1280 + 187) * 4;
        crop.setRange(y * _trimEdge * 4, (y + 1) * _trimEdge * 4,
            rgba, offset);
      }
      return crop;
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

List<bool> _trimGreen(Uint8List rgba, int threshold) => <bool>[
  for (int offset = 0; offset < rgba.length; offset += 4)
    rgba[offset + 3] > 0 && rgba[offset + 1] >= threshold &&
        rgba[offset + 1] > rgba[offset] + 20 &&
        rgba[offset + 1] > rgba[offset + 2] + 20,
];

Map<String, int> _trimOverlap(List<bool> actual, List<bool> reference) {
  int present = 0;
  int expected = 0;
  int overlap = 0;
  for (int index = 0; index < actual.length; index++) {
    if (actual[index]) present++;
    if (reference[index]) expected++;
    if (actual[index] && reference[index]) overlap++;
  }
  return <String, int>{'present': present, 'expected': expected,
    'overlap': overlap, 'extra': present - overlap,
    'missing': expected - overlap};
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
    // Give the original forward ticker its first frame before measuring it.
    await tester.pump();
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
  testWidgets('original Welcome trim bounds have a bounded renderer probe', (
    WidgetTester tester,
  ) async {
    final ByteData asset = await rootBundle.load(_trimAsset);
    final Uint8List bytes = asset.buffer.asUint8List(
      asset.offsetInBytes, asset.lengthInBytes,
    );
    expect(bytes.length, 2189249);
    expect(_trimHash(bytes), _trimSha);
    final Map<String, dynamic> variant =
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final List<dynamic> layers = variant['layers'] as List<dynamic>;
    expect(layers.length, 9);
    final Map<String, dynamic> first = layers.first as Map<String, dynamic>;
    expect(first['nm'], 'moving line');
    int swaps = 0;
    void visit(dynamic value) {
      if (value is Map<String, dynamic>) {
        if (value['ty'] == 'tm' && value['m'] == 2) {
          final dynamic start = value['s'];
          value['s'] = value['e'];
          value['e'] = start;
          swaps++;
        }
        value.values.forEach(visit);
      } else if (value is List<dynamic>) {
        value.forEach(visit);
      }
    }
    // This variant exists only in test memory. Swapping entire channels
    // keeps their original keyframe timing and the independent offset.
    visit(first);
    expect(swaps, 2);
    final LottieComposition original = LottieComposition.parseJsonBytes(bytes);
    final LottieComposition sorted = LottieComposition.parseJsonBytes(
      utf8.encode(jsonEncode(variant)),
    );
    expect(original.bounds, sorted.bounds);
    expect(original.durationFrames, sorted.durationFrames);
    expect(original.durationFrames, closeTo(1799.99, .00001));
    final List<Map<String, Object>> samples = <Map<String, Object>>[];
    final List<Uint8List> rendered = (await tester.runAsync(() async =>
        <Uint8List>[await _trimRender(original), await _trimRender(sorted)]))!;
    for (final String theme in <String>['dark', 'light']) {
      final Uint8List reference = (await tester.runAsync(
        () => _trimReference(theme),
      ))!;
      for (final int threshold in <int>[96, 160]) {
        final List<bool> mask = _trimGreen(reference, threshold);
        final Map<String, int> before = _trimOverlap(
          _trimGreen(rendered[0], threshold), mask,
        );
        final Map<String, int> after = _trimOverlap(
          _trimGreen(rendered[1], threshold), mask,
        );
        samples.add(<String, Object>{'theme': theme,
          'threshold': threshold, 'original': before, 'sorted': after});
      }
    }
    expect(_trimHash(bytes), _trimSha);
    // Numeric diagnostics cannot grant a visual match or establish the
    // normal application's animation-clock behaviour.
    // ignore: avoid_print
    print('CI_WELCOME_TRIM_METRICS:${jsonEncode(<String, Object>{
      'schema': 1, 'frame': _trimFrame, 'frame_count': 1800,
      'edge': _trimEdge, 'swapped_channels': swaps, 'samples': samples,
    })}');
    for (final Map<String, Object> sample in samples) {
      final Map<String, int> before = sample['original']! as Map<String, int>;
      final Map<String, int> after = sample['sorted']! as Map<String, int>;
      expect(before['present'], greaterThan(0));
      expect(before['expected'], greaterThan(0));
      expect(after['present'], greaterThan(0));
    }
  });
}
