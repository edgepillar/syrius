import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/wallet_ready_surface.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/entry_capture_source.dart';
import 'package:zenon_syrius_wallet_flutter/utils/reference_artwork_source.dart';
import 'package:zenon_syrius_wallet_flutter/utils/wallet_ready_binding.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/app_lottie.dart';

import '../../harness/app/capture_frame.dart';
import '../../harness/app/ready_reference_artwork.dart';

class _Bundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (!key.startsWith('assets/lottie/')) return rootBundle.load(key);
    return ByteData.sublistView(utf8.encode(
      '{"v":"5.7.4","fr":60,"ip":0,"op":120,"w":64,"h":64,'
      '"nm":"Ready artwork fixture","ddd":0,"assets":[],"layers":[]}',
    ));
  }
}

Widget _host(WalletReadyBinding binding, {bool light = false}) =>
    DefaultAssetBundle(
      bundle: _Bundle(),
      child: MaterialApp(
        theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WalletReadySurface(
          binding: binding,
          onOpen: () {},
          onCopy: (_) {},
          map: const AppLottie(AppLottieAsset.map, size: 64),
        ),
      ),
    );

class _Frames {
  final List<Completer<void>> original = <Completer<void>>[];
  final List<Completer<void>> deadline = <Completer<void>>[];
  late final CaptureFrameGate gate = CaptureFrameGate(
    waitForFrame: () {
      final Completer<void> value = Completer<void>();
      original.add(value);
      return value.future;
    },
    waitUntilDeadline: () {
      final Completer<void> value = Completer<void>();
      deadline.add(value);
      return value.future;
    },
  );

  void completeOriginal() {
    for (final Completer<void> value in original) {
      if (!value.isCompleted) {
        value.complete();
        return;
      }
    }
  }
}

Future<T> _finish<T>(WidgetTester tester, _Frames frames,
    Future<T> original) async {
  bool completed = false;
  unawaited(original.then<void>((_) { completed = true; },
    onError: (Object _) { completed = true; }));
  for (int index = 0; index < 30 && !completed; index++) {
    await tester.pump(const Duration(milliseconds: 16));
    frames.completeOriginal();
    await tester.pump();
  }
  expect(completed, isTrue);
  return original;
}

Future<void> _ready(WidgetTester tester, WalletReadyBinding binding,
    {bool light = false}) async {
  await tester.pumpWidget(_host(binding, light: light));
  final ReferenceArtworkSource map = tester.allStates
      .whereType<ReferenceArtworkSource>().singleWhere(
        (ReferenceArtworkSource source) => source.referenceArtworkKind ==
            ReferenceArtworkKind.walletReadyMap);
  final Future<Object?>? original = map.referenceArtworkReadiness;
  expect(original, isNotNull);
  final EntryCaptureCompletion loaded = EntryCaptureCompletion(original!);
  for (int frame = 0; frame < 200 &&
      loaded.status == EntryCaptureStatus.pending; frame++) {
    await tester.runAsync<void>(
      () => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump();
  }
  expect(loaded.status, EntryCaptureStatus.succeeded);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  void prepare(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(1200, 600)
      ..devicePixelRatio = 1;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.view.reset();
    });
  }

  testWidgets('Ready samples original renderers and restores before next theme',
      (WidgetTester tester) async {
    prepare(tester);
    final WalletReadyBinding binding = WalletReadyBinding(
      firstAddress: 'fixture-first-address', isCurrent: () => true);
    await _ready(tester, binding);
    final State<WalletReadySurface> owner =
        findReadyArtworkOwner(WidgetsBinding.instance.rootElement);
    final ReadyReferenceArtwork artwork = ReadyReferenceArtwork(
      owner: owner, admitted: () => true);
    final _Frames frames = _Frames();
    int reads = 0;
    for (final bool light in <bool>[false, true]) {
      if (light) await _ready(tester, binding, light: true);
      expect(findReadyArtworkOwner(WidgetsBinding.instance.rootElement),
        same(owner));
      final Lottie before = tester.widget<Lottie>(find.byType(Lottie));
      final AnimationController clock =
          before.controller! as AnimationController;
      final State<StatefulWidget> renderer = tester.state(find.byType(Lottie));
      final double start = clock.value;
      Lottie? sampled;
      bool? sampledClockRunning;
      bool? sampledOwnerMounted;
      expect(await _finish<int>(tester, frames, artwork.capture<int>(
        frames: frames.gate,
        readback: () async {
          reads++;
          // Read the original State here; assert after the pump driver returns.
          sampled = renderer.widget as Lottie;
          sampledClockRunning = clock.isAnimating;
          sampledOwnerMounted = renderer.mounted;
          return reads;
        },
      )), reads);
      final Lottie observed = sampled!;
      expect(observed.composition, same(before.composition));
      expect(tester.state(find.byType(Lottie)), same(renderer));
      expect(observed.controller, isNot(same(clock)));
      expect(observed.controller!.value, closeTo(60 / 119.99, 0.0000001));
      expect(sampledClockRunning, isTrue);
      expect(sampledOwnerMounted, isTrue);
      expect(tester.widget<Lottie>(find.byType(Lottie)).controller,
        same(clock));
      expect(clock.isAnimating, isTrue);
      expect(clock.value, isNot(start));
      expect(artwork.held, isFalse);
    }
    expect(reads, 2);
    expect(frames.original, hasLength(4));
  });

  testWidgets('lost Ready admission cannot be healed by a later owner check',
      (WidgetTester tester) async {
    prepare(tester);
    final WalletReadyBinding binding = WalletReadyBinding(
      firstAddress: 'fixture-first-address', isCurrent: () => true);
    await _ready(tester, binding);
    bool admitted = true;
    final ReadyReferenceArtwork artwork = ReadyReferenceArtwork(
      owner: findReadyArtworkOwner(WidgetsBinding.instance.rootElement),
      admitted: () => admitted);
    final _Frames frames = _Frames();
    int reads = 0;
    final Future<void> original = artwork.capture<void>(
      frames: frames.gate,
      readback: () async { reads++; admitted = false; },
    );
    final Future<void> refused = expectLater(original,
      throwsA(isA<ReadyReferenceArtworkRefused>()));
    await _finish<void>(tester, frames, refused);
    expect(artwork.held, isTrue);
    admitted = true;
    final int originalRequests = frames.original.length;
    await expectLater(artwork.capture<void>(frames: frames.gate,
      readback: () async { reads++; }),
      throwsA(isA<ReadyReferenceArtworkRefused>()));
    expect(frames.original, hasLength(originalRequests));
    expect(reads, 1);
  });

  testWidgets('a late original Ready frame grants no readback or replacement',
      (WidgetTester tester) async {
    prepare(tester);
    final WalletReadyBinding binding = WalletReadyBinding(
      firstAddress: 'fixture-first-address', isCurrent: () => true);
    await _ready(tester, binding);
    final ReadyReferenceArtwork artwork = ReadyReferenceArtwork(
      owner: findReadyArtworkOwner(WidgetsBinding.instance.rootElement),
      admitted: () => true);
    final _Frames frames = _Frames();
    int reads = 0;
    final Future<void> pending = artwork.capture<void>(frames: frames.gate,
      readback: () async { reads++; });
    final Future<void> refused = expectLater(pending,
      throwsA(isA<CaptureFrameRefused>()));
    for (int index = 0; index < 20 && frames.original.isEmpty; index++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(frames.original, hasLength(1));
    frames.deadline.single.complete();
    await tester.pump();
    await refused;
    expect(artwork.held, isTrue);
    expect(frames.gate.receipt!.status, CaptureFrameStatus.held);
    frames.original.single.complete();
    await tester.pump();
    await expectLater(artwork.capture<void>(frames: _Frames().gate,
      readback: () async { reads++; }),
      throwsA(isA<ReadyReferenceArtworkRefused>()));
    expect(reads, 0);
    expect(frames.original, hasLength(1));
    expect(frames.gate.receipt!.status, CaptureFrameStatus.held);
  });
}
