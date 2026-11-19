import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/help_widgets/originals_card.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/app_lottie.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/launch_film.dart';

import '../../harness/app/capture_frame.dart';
import '../../harness/app/ready_reference_artwork.dart';

class _Bundle extends CachingAssetBundle {
  Future<void>? filmReady;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'assets/images/launch_well.webp') {
      final Future<void>? ready = filmReady;
      if (ready != null) await ready;
      return ByteData.sublistView(
        File('test/launch_film/fixtures/film.webp').readAsBytesSync(),
      );
    }
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
      AppLottie.debugClear();
      tester.view.reset();
    });
  }

  testWidgets('Pillar samples the 99% frame and restores playback', (
    WidgetTester tester,
  ) async {
    prepare(tester);
    const Key receipt = Key('confirmed_pillar_fixture');
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _Bundle(),
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              key: receipt,
              child: AppLottie(AppLottieAsset.pillar, size: 340, repeat: false),
            ),
          ),
        ),
      ),
    );
    final ReferenceArtworkSource source = tester.allStates
        .whereType<ReferenceArtworkSource>()
        .single;
    final EntryCaptureCompletion loaded = EntryCaptureCompletion(
      source.referenceArtworkReadiness!,
    );
    for (int frame = 0; frame < 200 &&
        loaded.status == EntryCaptureStatus.pending; frame++) {
      await tester.runAsync<void>(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    expect(loaded.status, EntryCaptureStatus.succeeded);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    final Finder lottie = find.byType(Lottie);
    final Animation<double> original =
        tester.widget<Lottie>(lottie).controller!;
    expect(original.status, AnimationStatus.completed);
    final Element owner = tester.element(find.byKey(receipt));
    final PillarReferenceArtwork artwork = PillarReferenceArtwork(
      owner: owner,
      admitted: () => true,
    );
    final _Frames frames = _Frames();
    await _finish<void>(
      tester,
      frames,
      artwork.capture<void>(
        frames: frames.gate,
        readback: () async {
          expect(artwork.isReadingSample(owner), isTrue);
          final Lottie held = tester.widget<Lottie>(lottie);
          expect(held.controller, isNot(same(original)));
          expect(
            held.controller!.value * held.composition!.durationFrames,
            closeTo(118, .0001),
          );
          expect(original.status, AnimationStatus.completed);
        },
      ),
    );
    expect(artwork.isReadingSample(owner), isFalse);
    expect(tester.widget<Lottie>(lottie).controller, same(original));
  });

  testWidgets('Originals samples the film and its eight Lotties', (
    WidgetTester tester,
  ) async {
    prepare(tester);
    final _Bundle bundle = _Bundle();
    await tester.pumpWidget(DefaultAssetBundle(
      bundle: bundle,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: OriginalsCard(isCurrent: () => true)),
      ),
    ));
    final List<ReferenceArtworkSource> sources = tester.allStates
        .whereType<ReferenceArtworkSource>()
        .where((ReferenceArtworkSource source) =>
            source.referenceArtworkKind ==
            ReferenceArtworkKind.originalsGallery)
        .toList();
    expect(sources, hasLength(8));
    final Finder galleryFilm = find.byType(LaunchFilm);
    final LaunchFilmController movie =
        tester.widget<LaunchFilm>(galleryFilm).controller!;
    final ReferenceArtworkSource film = movie.originalsReferenceArtwork!;
    final EntryCaptureCompletion loaded = EntryCaptureCompletion(
      Future.wait(<Future<Object?>>[
        film.referenceArtworkReadiness!,
        for (final ReferenceArtworkSource source in sources)
          source.referenceArtworkReadiness!,
      ]),
    );
    for (int frame = 0; frame < 200 &&
        loaded.status == EntryCaptureStatus.pending; frame++) {
      await tester.runAsync<void>(
        () => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(loaded.status, EntryCaptureStatus.succeeded);
    await tester.pump(const Duration(milliseconds: 400));
    final Finder picture = find.descendant(
      of: galleryFilm,
      matching: find.byType(RawImage),
    );
    expect(tester.getSize(picture), const Size(420, 236));
    final Element pictureElement = tester.element(picture);
    final ReferenceArtworkFrame preview = film.captureReferenceArtwork()!;
    expect(preview.observation, <String, Object>{
      'kind': 'originals_launch', 'frame': 3, 'frame_count': 8,
    });
    await tester.pump();
    expect(preview.observed, isTrue);
    final Object? previewImage = tester.widget<RawImage>(picture).image;
    expect(previewImage, isNotNull);
    expect(preview.restore(), isTrue);
    await tester.pump();
    expect(preview.restored, isTrue);
    expect(tester.widget<RawImage>(picture).image, isNot(same(previewImage)));
    final Finder players = find.byType(Lottie);
    final List<State<StatefulWidget>> originalStates =
        tester.stateList(players).toList();
    final List<Animation<double>?> clocks = tester.widgetList<Lottie>(players)
        .map((Lottie player) => player.controller).toList();
    final OriginalsReferenceArtwork artwork = OriginalsReferenceArtwork(
      root: WidgetsBinding.instance.rootElement,
      admitted: () => true,
    );
    final _Frames frames = _Frames();
    Object? capturedFilm;
    final List<Lottie> sampled = await _finish<List<Lottie>>(
      tester,
      frames,
      artwork.capture<List<Lottie>>(
        frames: frames.gate,
        readback: () async {
          capturedFilm = (pictureElement.widget as RawImage).image;
          return <Lottie>[
            for (final State<StatefulWidget> original in originalStates)
              original.widget as Lottie,
          ];
        },
      ),
    );
    const List<int> expectedFrames = <int>[48, 60, 118, 118, 118, 54, 48, 24];
    expect(capturedFilm, same(previewImage));
    expect(tester.widget<RawImage>(picture).image, isNot(same(previewImage)));
    expect(sampled, hasLength(expectedFrames.length));
    expect(tester.stateList(players), orderedEquals(originalStates));
    for (int index = 0; index < sampled.length; index++) {
      final Lottie player = sampled[index];
      expect(player.controller, isA<AlwaysStoppedAnimation<double>>());
      final double frame =
          player.controller!.value * player.composition!.durationFrames;
      expect(frame, closeTo(expectedFrames[index], 0.000001));
      expect((originalStates[index].widget as Lottie).controller,
        same(clocks[index]));
    }

    final Completer<void> delayedDecode = Completer<void>();
    bundle.filmReady = delayedDecode.future;
    movie.play();
    final ReferenceArtworkSource replay = movie.originalsReferenceArtwork!;
    expect(replay, isNot(same(film)));
    final int previousFrameRequests = frames.original.length;
    final Future<bool> replayResult = artwork.capture<bool>(
      frames: frames.gate,
      readback: () async => (pictureElement.widget as RawImage).image != null,
    );
    final EntryCaptureCompletion capture = EntryCaptureCompletion(replayResult);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    expect(capture.status, EntryCaptureStatus.pending);
    expect(frames.original.length, previousFrameRequests);
    delayedDecode.complete();
    final EntryCaptureCompletion replayReady =
        EntryCaptureCompletion(replay.referenceArtworkReadiness!);
    for (int frame = 0; frame < 120 &&
        replayReady.status == EntryCaptureStatus.pending; frame++) {
      await tester.runAsync<void>(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(replayReady.status, EntryCaptureStatus.succeeded);
    expect(await _finish<bool>(tester, frames, replayResult), isTrue);
    expect(tester.takeException(), isNull);
  });

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
