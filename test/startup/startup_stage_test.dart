import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart'
    show Layer, OffsetLayer, RenderImage, RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/shaders/shader_clock.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/entry_field.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/reference_artwork_source.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/launch_film.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/frosted_route.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/startup_stage.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/tab_children_widgets/lock_card.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/tab_children_widgets/lock_tab_child.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/window_frame.dart';

const String _asset = 'test/launch_film/fixtures/film.webp';
const MethodChannel _window = MethodChannel('window_manager');

Future<Uint8List> _stageShadowPixels(
  Size size,
  BorderRadius radius,
  void Function(Canvas) paintShadow,
) async {
  const double margin = 160;
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder)
    ..drawColor(const Color(0xff383838), BlendMode.src)
    ..translate(margin, margin);
  paintShadow(canvas);
  canvas.drawRRect(
    radius.toRRect(Offset.zero & size),
    Paint()..color = Colors.black,
  );
  final ui.Picture picture = recorder.endRecording();
  try {
    final ui.Image image = await picture.toImage(
      (size.width + 2 * margin).ceil(),
      (size.height + 2 * margin).ceil(),
    );
    try {
      final ByteData? pixels = await image.toByteData();
      return Uint8List.sublistView(pixels!);
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

class _FilmBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(await File(key).readAsBytes());
}

class _PendingBundle extends CachingAssetBundle {
  final Completer<ByteData> _bytes = Completer<ByteData>();

  @override
  Future<ByteData> load(String key) => _bytes.future;
}

class _Harness extends StatefulWidget {
  const _Harness({required this.session, required this.fillClient, super.key});

  final StartupStageSession session;
  final bool fillClient;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final ValueNotifier<int> _replay = ValueNotifier<int>(0);
  final List<String> unlocks = <String>[];
  int initialized = 0;
  int shellBuilds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.session.show(context);
    });
  }

  void adopt() {
    expect(
      widget.session.claim(
        afterUnlock: (String password) async => unlocks.add(password),
        afterInit: () => initialized++,
        replay: _replay,
      ),
      isTrue,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.session.moveAuthToShell();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.session.settle();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    shellBuilds++;
    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(child: widget.session.buildShellAuth()),
          // The real Windows Lock backdrop fills the entire caption body.
          // Other tests retain a smaller destination slot for reparenting.
          if (!widget.fillClient) const SizedBox(height: 40),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.session.dispose();
    _replay.dispose();
    super.dispose();
  }
}

StartupStageSession _session(VoidCallback done, {AssetBundle? bundle}) =>
    StartupStageSession(
      asset: _asset,
      wellAsset: _asset,
      bundle: bundle ?? _FilmBundle(),
      onDone: done,
      authBuilder: (_, StartupStageSession session) => LockTabChild(
        session.unlock,
        session.initialized,
        replay: session.replay,
        startup: session,
      ),
    );

Future<GlobalKey<_HarnessState>> _show(
  WidgetTester tester,
  StartupStageSession session, {
  bool light = false,
  bool reduced = false,
  bool withWindowFrame = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1280, 780);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  final GlobalKey<_HarnessState> key = GlobalKey<_HarnessState>();
  await tester.pumpWidget(
    MaterialApp(
      theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: withWindowFrame ? AppWindowFrame(child: child!) : child!,
      ),
      home: _Harness(key: key, session: session, fillClient: withWindowFrame),
    ),
  );
  await tester.pump();
  return key;
}

Future<void> _until(
  WidgetTester tester,
  bool Function() done, {
  Duration by = const Duration(milliseconds: 20),
}) async {
  for (int turn = 0; turn < 150 && !done(); turn++) {
    await tester.runAsync(
      () => Future<void>.delayed(
        const Duration(milliseconds: 10),
      ),
    );
    await tester.pump(by);
  }
  expect(done(), isTrue, reason: 'The original movie did not complete');
}

Future<void> _begin(
  WidgetTester tester,
  GlobalKey<_HarnessState> host,
) async {
  host.currentState!.adopt();
  // The real route registers adoption during its mounting frame.
  tester.binding.scheduleFrame();
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

Rect _stageRect(WidgetTester tester) => tester.getRect(
  find.byKey(const ValueKey<String>('startup_stage_rect')),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_window, (_) async => true);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_window, null);
  });

  for (final bool light in <bool>[false, true]) {
    testWidgets(
      'mounts the real auth owner before the first movie frame '
      'in ${light ? 'light' : 'dark'}',
      (
        WidgetTester tester,
      ) async {
        int done = 0;
        final StartupStageSession session = _session(() => done++);
        await _show(tester, session, light: light);
        final Finder auth = find.byType(LockTabChild);
        expect(auth, findsOneWidget);
        expect(tester.getSize(auth).isEmpty, isFalse);
        expect(
          find.ancestor(
            of: auth,
            matching: find.byWidgetPredicate(
              (Widget widget) => widget is Opacity && widget.opacity == 0,
            ),
          ),
          findsOneWidget,
        );
        expect(find.byType(LaunchFilm), findsOneWidget);
        final Finder coveredWell = find.byKey(session.wellKey);
        expect(tester.getSize(coveredWell), const Size(418, 118));
        expect(
          find.descendant(
            of: coveredWell,
            matching: find.byType(OverflowBox),
          ),
          findsNothing,
        );
        expect(
          tester.widget<LaunchFilm>(find.byType(LaunchFilm)).fit,
          BoxFit.cover,
        );
        expect(session.film.frame, -1);
        expect(find.text('Click or press a key to skip'), findsOneWidget);
        final Finder hint = find.byKey(
          const ValueKey<String>('launch_skip_hint'),
        );
        final TextStyle style = tester.widget<Text>(hint).style!;
        expect(style.inherit, isFalse);
        expect(style.fontWeight, FontWeight.w400);
        expect(style.decoration, TextDecoration.none);
        expect(
          tester.getRect(hint).bottom,
          754,
        );
        final LockCard card = tester.widget<LockCard>(find.byType(LockCard));
        expect(card.canUnlock, isFalse);
        card.passwordController.text = 'Synthetic input';
        card.onUnlock();
        await session.unlock('Synthetic input');
        session.initialized();
        await tester.pump();
        expect(card.passwordController.text, 'Synthetic input');
        expect(session.interactive, isFalse);
        expect(done, 0);
        expect(_stageRect(tester), const Rect.fromLTWH(0, 0, 1280, 780));
      },
    );
  }

  testWidgets(
    'Windows caption stays black through launch and restores at handoff',
    (WidgetTester tester) async {
      late StartupStageSession session;
      session = _session(() => session.wait());
      final GlobalKey<_HarnessState> host = await _show(
        tester,
        session,
        light: true,
        withWindowFrame: true,
      );
      final Finder caption = find.byKey(
        const ValueKey<String>('window-caption'),
      );
      final Finder backdrop = find.byKey(
        const ValueKey<String>('window-caption-backdrop'),
      );
      final Finder title = find.text('SYRIUS');
      final Finder stage = find.byKey(
        const ValueKey<String>('startup_stage_rect'),
      );
      final Rect full = _stageRect(tester);
      expect(full.top, 32);
      expect(tester.widget<ClipRRect>(stage).clipBehavior, Clip.none);
      final Finder filmFit = find.descendant(
        of: stage,
        matching: find.byType(FittedBox),
      );
      expect(tester.widget<FittedBox>(filmFit).clipBehavior, Clip.hardEdge);
      expect(tester.widget<Material>(caption).color, Colors.black);
      expect(tester.widget<Text>(title).style!.color, const Color(0xFF555555));
      expect(tester.widget<CustomPaint>(backdrop).painter, isNull);

      final Finder auth = find.byType(LockTabChild);
      final LockTabChild coveredAuth = tester.widget<LockTabChild>(auth);
      final State<StatefulWidget> authState = tester.state(auth);
      final CustomPaint shadowPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('lock_card_shadow')),
          matching: find.byType(CustomPaint),
        ),
      );
      final OuterShadowRaster shadowRaster =
          (shadowPaint.painter! as OuterShadowPainter).raster!;
      expect(coveredAuth.replay, isNull);
      expect(shadowRaster.debugRetainedImage, isNull);
      await tester.tapAt(const Offset(100, 100));
      await _until(tester, () => session.film.isDone);
      expect(session.motion.value, 0);
      final ui.Image? preparedShadow = shadowRaster.debugRetainedImage;
      expect(preparedShadow, isNotNull);
      expect(tester.widget<LockTabChild>(auth), same(coveredAuth));
      expect(tester.widget<Material>(caption).color, Colors.black);
      expect(_stageRect(tester), full);
      expect(tester.widget<ClipRRect>(stage).clipBehavior, Clip.none);

      await _begin(tester, host);
      expect(tester.state(auth), same(authState));
      expect(tester.widget<LockTabChild>(auth).replay,
          same(host.currentState!._replay));
      const AppTokens tokens = AppTokens.light;
      final int duration = tokens.launchSettleDuration.inMicroseconds;
      int low = 0;
      int high = duration;
      while (high - low > 1) {
        final int middle = (low + high) ~/ 2;
        if (tokens.launchSettleCurve.transform(middle / duration) < 0.4) {
          low = middle;
        } else {
          high = middle;
        }
      }
      final Duration referenceTime = Duration(microseconds: high);
      await tester.pump(referenceTime);
      expect(session.motion.value, closeTo(0.4, 0.004));
      expect(tester.getRect(find.byType(EntryField)),
          const Rect.fromLTWH(0, 32, 1280, 748));
      expect(shadowRaster.debugRetainedImage, same(preparedShadow));
      final Rect authored = _stageRect(tester);
      expect(authored.left, closeTo(250, 2));
      expect(authored.top, closeTo(148.6, 2));
      expect(authored.width, closeTo(780, 3));
      expect(authored.height, closeTo(330, 3));
      expect(tester.widget<ClipRRect>(stage).clipBehavior, Clip.antiAlias);
      expect(
        tester.widget<ClipRRect>(stage).borderRadius
            .resolve(TextDirection.ltr).topLeft.x,
        closeTo(14, 0.15),
      );
      final CustomPaint frame = tester.widget<CustomPaint>(
        find.ancestor(of: stage, matching: find.byType(CustomPaint)).first,
      );
      expect(frame.willChange, isTrue);
      final BorderRadius radius = tester
          .widget<ClipRRect>(stage)
          .borderRadius
          .resolve(TextDirection.ltr);
      final LaunchSettleReference reference = tokens.launchSettleReference;
      final double progress = session.motion.value;
      final bool approaching = progress <= reference.progress;
      final double fraction = approaching
          ? progress / reference.progress
          : (progress - reference.progress) / (1 - reference.progress);
      final double weight = approaching ? fraction : 1 - fraction;
      final BoxShadow shadow = reference.shadow;
      final BoxPainter original = BoxDecoration(
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: shadow.color.withValues(alpha: shadow.color.a * weight),
            offset: shadow.offset * weight,
            blurRadius: shadow.blurRadius * weight,
          ),
        ],
      ).createBoxPainter();
      addTearDown(original.dispose);
      final bool? pixelsMatch = await tester.runAsync(() async {
        final Uint8List before = await _stageShadowPixels(
          authored.size,
          radius,
          (Canvas canvas) => original.paint(
            canvas,
            Offset.zero,
            ImageConfiguration(
              size: authored.size,
              textDirection: TextDirection.ltr,
            ),
          ),
        );
        final Uint8List after = await _stageShadowPixels(
          authored.size,
          radius,
          (Canvas canvas) => frame.painter!.paint(canvas, authored.size),
        );
        return listEquals(before, after);
      });
      expect(pixelsMatch, isTrue);
      final OverflowBox artwork = tester.widget<OverflowBox>(
        find.descendant(of: stage, matching: find.byType(OverflowBox)),
      );
      expect(artwork.maxWidth, closeTo(1040, 3));
      expect(artwork.maxHeight, closeTo(585, 3));
      expect(
        tester.widget<Opacity>(
          find.ancestor(
            of: find.byKey(const ValueKey<String>('lock_card_surface')),
            matching: find.byType(Opacity),
          ).first,
        ).opacity,
        session.motion.value,
      );
      expect(tester.widget<EntryField>(find.byType(EntryField))
          .fadeLightsOnOpaqueBase, isTrue);
      expect(find.ancestor(of: find.byType(EntryField),
        matching: find.byType(Opacity)), findsNothing);
      final RenderRepaintBoundary entryPaint = tester.renderObject(
        find.descendant(
          of: find.byType(EntryField),
          matching: find.byType(RepaintBoundary),
        ),
      );
      final List<List<int>>? lights = await tester.runAsync(() async {
        final ui.Image image = await entryPaint.toImage();
        try {
          final ByteData bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          ))!;
          List<int> pixel(int x, int y) {
            final int offset = (y * image.width + x) * 4;
            return List<int>.generate(4, (int i) => bytes.getUint8(offset + i));
          }

          return <List<int>>[pixel(230, 190), pixel(945, 485)];
        } finally {
          image.dispose();
        }
      });
      final List<List<int>> sampledLights = lights!;
      final List<int> green = sampledLights[0];
      final List<int> blue = sampledLights[1];
      expect(green[3], greaterThan(8));
      expect(green[1], greaterThan(green[2]));
      expect(blue[3], greaterThan(8));
      expect(blue[2], greaterThan(blue[1]));
      final RenderRepaintBoundary captionPaint = tester.renderObject(
        find.ancestor(of: backdrop, matching: find.byType(RepaintBoundary))
            .first,
      );
      final List<int>? captionLight = await tester.runAsync(() async {
        final ui.Image image = await captionPaint.toImage();
        try {
          final ByteData bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          ))!;
          final int offset = (14 * image.width + 640) * 4;
          return List<int>.generate(4, (int i) => bytes.getUint8(offset + i));
        } finally {
          image.dispose();
        }
      });
      expect(captionLight![3], greaterThan(8));
      expect(captionLight[0], greaterThan(captionLight[1]));
      await tester.pump(const Duration(milliseconds: 200) - referenceTime);
      expect(_stageRect(tester).width, lessThan(full.width));
      expect(
        tester.widget<Material>(caption).color,
        AppTokens.light.windowCaptionBackground,
      );
      expect(tester.widget<Text>(title).style, AppTokens.light.windowTitleText);
      expect(tester.widget<CustomPaint>(backdrop).painter, isNotNull);
      final Finder field = find.byType(EntryField);
      final EntryField movingField = tester.widget<EntryField>(field);
      await tester.pump(const Duration(milliseconds: 200));
      expect(session.interactive, isTrue);
      expect(tester.widget<EntryField>(field), same(movingField));
      expect(captionPaint.size.height, tokens.windowCaptionHeight);
      final int priorPaints = captionPaint.debugAsymmetricPaintCount;
      await tester.pump(const Duration(milliseconds: 100));
      expect(captionPaint.debugAsymmetricPaintCount, greaterThan(priorPaints));
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant(
      <TargetPlatform>{TargetPlatform.windows},
    ),
  );

  testWidgets('pointer skip holds the original final frame and starts once', (
    WidgetTester tester,
  ) async {
    int done = 0;
    late StartupStageSession session;
    session = _session(() {
      done++;
      session.wait();
    });
    await _show(tester, session);
    await tester.tapAt(const Offset(100, 100));
    await _until(tester, () => session.film.isDone);
    expect(session.film.frame, 7);
    expect(done, 1);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Click or press a key to skip'), findsNothing);
    final Finder waiting = find.byKey(
      const ValueKey<String>('launch_waiting'),
    );
    final RenderRepaintBoundary waitingPaint =
        tester.renderObject<RenderRepaintBoundary>(waiting);
    expect(
      tester.getSize(waiting),
      tester.getSize(find.byType(LinearProgressIndicator)),
    );
    await tester.pump();
    final int priorPaints = waitingPaint.debugAsymmetricPaintCount;
    await tester.pump(const Duration(milliseconds: 100));
    expect(waitingPaint.debugAsymmetricPaintCount, greaterThan(priorPaints));
    expect(session.film.frame, 7);
    await tester.tapAt(const Offset(100, 100));
    await tester.pump(const Duration(seconds: 1));
    expect(done, 1);
    expect(session.interactive, isFalse);
  });

  testWidgets('any key skips without handing input to the password', (
    WidgetTester tester,
  ) async {
    int done = 0;
    final StartupStageSession session = _session(() => done++);
    await _show(tester, session);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
    await _until(tester, () => session.film.isDone);
    expect(done, 1);
    expect(session.film.frame, 7);
    expect(
      tester.widget<LockCard>(find.byType(LockCard)).passwordController.text,
      isEmpty,
    );
  });

  for (final bool reduced in <bool>[false, true]) {
    testWidgets(
      'retains both original States through the exact 400ms handoff '
      'with motion flag $reduced',
      (
        WidgetTester tester,
      ) async {
        int done = 0;
        final StartupStageSession session = _session(() => done++);
        final GlobalKey<_HarnessState> host = await _show(
          tester,
          session,
          reduced: reduced,
        );
        final State<StatefulWidget> auth = tester.state(
          find.byType(LockTabChild),
        );
        final State<StatefulWidget> film = tester.state(
          find.byType(LaunchFilm),
        );
        ShaderClock entryClock() {
          final ReferenceArtworkSource backdrop =
              tester.state(find.byType(EntryField)) as ReferenceArtworkSource;
          return backdrop.referenceArtworkGeneration as ShaderClock;
        }

        final ShaderClock originalBackdrop = entryClock();
        expect(originalBackdrop.isRunning, isFalse);
        final Finder filmBoundary = find.descendant(
          of: find.byType(LaunchFilm),
          matching: find.byType(RepaintBoundary),
        );
        await _until(tester, () => session.film.frame >= 0);
        expect(session.film.isDone, isFalse);
        expect(filmBoundary, findsNothing);
        await _until(tester, () => session.film.isDone);
        expect(filmBoundary, findsOneWidget);
        expect(originalBackdrop.value, 0);
        final Finder frame = find.descendant(
          of: find.byType(LaunchFilm),
          matching: find.byType(RawImage),
        );
        final RenderImage paintedFrame = tester.renderObject(frame);
        final Finder frameBoundary = find
            .ancestor(of: frame, matching: find.byType(RepaintBoundary))
            .first;
        final RenderRepaintBoundary framePaint = tester.renderObject(
          frameBoundary,
        );
        final Layer? originalFrameLayer = framePaint.debugLayer;
        expect(originalFrameLayer, isNotNull);
        final Size decodedSize = Size(
          paintedFrame.image!.width.toDouble(),
          paintedFrame.image!.height.toDouble(),
        );
        expect(paintedFrame.size, decodedSize);
        final Rect originalFrameBounds = tester.getRect(frame);
        final Rect full = _stageRect(tester);
        final int shellBuilds = host.currentState!.shellBuilds;
        await _begin(tester, host);
        expect(session.authInShell, isTrue);
        expect(host.currentState!.shellBuilds, shellBuilds);
        expect(
          identical(tester.state(find.byType(LockTabChild)), auth),
          isTrue,
        );
        expect(identical(tester.state(find.byType(LaunchFilm)), film), isTrue);
        await tester.pump(const Duration(milliseconds: 200));
        expect(entryClock(), same(originalBackdrop));
        expect(originalBackdrop.isRunning, isTrue);
        expect(_stageRect(tester).width, lessThan(full.width));
        expect(_stageRect(tester).width, greaterThan(418));
        expect(tester.renderObject(frame), same(paintedFrame));
        expect(paintedFrame.size, decodedSize);
        expect(
          tester.getRect(frame).width,
          lessThan(originalFrameBounds.width),
        );
        expect(session.interactive, isFalse);
        final Finder unlock = find.byKey(
          const ValueKey<String>('wallet_unlock_button'),
        );
        final Finder button = find.descendant(
          of: unlock,
          matching: find.byWidgetPredicate(
            (Widget widget) => widget is OutlinedButton,
          ),
        );
        final Finder unlockSurface = find.descendant(
          of: unlock,
          matching: find.byType(Opacity),
        );
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        expect(tester.widget<Opacity>(unlockSurface).opacity, 1);
        final Finder walletPickerArrow = find.byKey(
          const ValueKey<String>('lock_wallet_picker_arrow'),
        );
        final Finder passwordField = find.byKey(
          const ValueKey<String>('wallet_password_field'),
        );
        expect(walletPickerArrow, findsNothing);
        expect(
          tester.widget<TextField>(passwordField).decoration!.suffixIcon,
          isNull,
        );
        final Widget renderingFilm = tester.widget(find.byType(LaunchFilm));
        final Widget renderingField = tester.widget(find.byType(EntryField));
        const Key shadowKey = ValueKey<String>('lock_card_shadow');
        final Finder shadow = find.byKey(shadowKey);
        final Finder shadowOpacity = find.byWidgetPredicate(
          (Widget widget) =>
              widget is Opacity && widget.child?.key == shadowKey,
        );
        expect(tester.widget<Opacity>(shadowOpacity).opacity, 0);
        final RenderRepaintBoundary retainedShadow = tester.renderObject(
          shadow,
        );
        final Finder shadowPaint = find.descendant(
          of: shadow,
          matching: find.byType(CustomPaint),
        );
        OuterShadowRaster? shadowRaster() =>
            (tester.widget<CustomPaint>(shadowPaint).painter!
                    as OuterShadowPainter)
                .raster;
        final OuterShadowRaster? originalShadowRaster = shadowRaster();
        expect(originalShadowRaster, isNotNull);
        expect(tester.widget<CustomPaint>(shadowPaint).isComplex, isFalse);
        final Finder card = find.byKey(
          const ValueKey<String>('lock_card_surface'),
        );
        final Finder backdrop = find.descendant(
          of: card,
          matching: find.byType(BackdropFilter),
        );
        expect(tester.widget<BackdropFilter>(backdrop).enabled, isFalse);
        final RenderObject originalFilter = tester.renderObject(backdrop);
        final Finder foreground = find.byKey(
          const ValueKey<String>('lock_card_foreground'),
        );
        final RenderRepaintBoundary retainedForeground =
            tester.renderObject(foreground);
        final OffsetLayer foregroundLayer =
            retainedForeground.debugLayer! as OffsetLayer;
        final Layer? foregroundPaint = foregroundLayer.firstChild;
        expect(foregroundPaint, isNotNull);
        await tester.pump(const Duration(milliseconds: 100));
        expect(originalBackdrop.value, greaterThan(0));
        expect(paintedFrame.size, decodedSize);
        expect(retainedForeground.debugLayer, same(foregroundLayer));
        expect(foregroundLayer.firstChild, same(foregroundPaint));
        expect(tester.widget(find.byType(LaunchFilm)), same(renderingFilm));
        expect(tester.widget(find.byType(EntryField)), same(renderingField));
        await tester.pump(const Duration(milliseconds: 99));
        expect(session.interactive, isFalse);
        await tester.pump(const Duration(milliseconds: 1));
        expect(session.interactive, isTrue);
        expect(session.filmInWell, isTrue);
        expect(walletPickerArrow, findsOneWidget);
        expect(
          tester.widget<TextField>(passwordField).decoration!.suffixIcon,
          isA<IconButton>(),
        );
        expect(tester.renderObject(frame), same(paintedFrame));
        expect(paintedFrame.size, decodedSize);
        expect(tester.renderObject(frameBoundary), same(framePaint));
        expect(framePaint.debugLayer, same(originalFrameLayer));
        expect(entryClock(), same(originalBackdrop));
        expect(tester.renderObject(shadow), same(retainedShadow));
        expect(tester.widget<Opacity>(shadowOpacity).opacity, 1);
        expect(shadowRaster(), same(originalShadowRaster));
        expect(tester.renderObject(foreground), same(retainedForeground));
        expect(tester.renderObject(backdrop), same(originalFilter));
        expect(tester.widget<BackdropFilter>(backdrop).enabled, isTrue);
        expect(
          find.descendant(
            of: find.byKey(session.wellKey),
            matching: find.byType(OverflowBox),
          ),
          findsOneWidget,
        );
        final Rect cardBounds = tester.getRect(card);
        final Rect well = tester.getRect(
          find.byKey(const ValueKey<String>('lock_film_well')),
        );
        expect(
          tester.getRect(backdrop),
          Rect.fromLTRB(
            cardBounds.left,
            well.bottom,
            cardBounds.right,
            cardBounds.bottom,
          ),
        );
        expect(
          retainedShadow.size.width,
          greaterThan(cardBounds.width),
        );
        expect(
          tester.widget<LaunchFilm>(find.byType(LaunchFilm)).fit,
          BoxFit.contain,
        );
        expect(
          find.byKey(const ValueKey<String>('startup_stage_rect')),
          findsNothing,
        );
        expect(find.byType(LockTabChild), findsOneWidget);
        expect(find.byType(LaunchFilm), findsOneWidget);
        expect(
          identical(tester.state(find.byType(LockTabChild)), auth),
          isTrue,
        );
        expect(identical(tester.state(find.byType(LaunchFilm)), film), isTrue);
        expect(session.film.frame, 7);
        await session.unlock('Synthetic input');
        session.initialized();
        expect(host.currentState!.unlocks, <String>['Synthetic input']);
        expect(host.currentState!.initialized, 1);
        expect(done, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('the reference paint and resize preserve the handoff clock', (
    WidgetTester tester,
  ) async {
    final StartupStageSession session = _session(() {});
    final GlobalKey<_HarnessState> host = await _show(tester, session);
    final Rect full = _stageRect(tester);
    expect(session.requestHandoffReferenceFrame(), isTrue);
    expect(session.requestHandoffReferenceFrame(), isFalse);
    await _until(tester, () => session.film.isDone);
    await _begin(tester, host);
    await tester.pump(const Duration(milliseconds: 100));
    expect(session.motion.value, 0.4);
    expect(_stageRect(tester).width, 780);
    expect(_stageRect(tester).height, closeTo(330 * full.height / 748, .001));
    expect(session.interactive, isFalse);
    expect(session.requestHandoffReferenceFrame(), isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    expect(session.motion.value, greaterThan(0.4));
    tester.view.physicalSize = const Size(1200, 600);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 298));
    expect(session.interactive, isFalse);
    expect(session.entryStatusReady.value, isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    expect(session.interactive, isTrue);
    expect(session.entryStatusReady.value, isTrue);
    expect(tester.getSize(find.byKey(session.wellKey)).height, 118);
    expect(find.byType(LaunchFilm), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a second claimant cannot replace the original callbacks', (
    WidgetTester tester,
  ) async {
    final StartupStageSession session = _session(() {});
    final GlobalKey<_HarnessState> host = await _show(tester, session);
    await _until(tester, () => session.film.isDone);
    await _begin(tester, host);
    final ValueNotifier<int> replay = ValueNotifier<int>(0);
    expect(
      session.claim(
        afterUnlock: (_) async => fail('Replaced original unlock'),
        afterInit: () => fail('Replaced original init'),
        replay: replay,
      ),
      isFalse,
    );
    replay.dispose();
    await tester.pump(const Duration(milliseconds: 400));
    await session.unlock('Original callback');
    expect(host.currentState!.unlocks, <String>['Original callback']);
  });

  testWidgets('disposing a decoding stage removes only its own overlay', (
    WidgetTester tester,
  ) async {
    final StartupStageSession session = _session(
      () => fail('Disposed startup'),
      bundle: _PendingBundle(),
    );
    await _show(tester, session);
    final OverlayState overlay = Overlay.of(
      tester.element(find.byType(_Harness)),
    );
    final OverlayEntry other = OverlayEntry(
      builder: (_) => const Positioned(
        left: 0,
        top: 0,
        child: SizedBox(
          key: ValueKey<String>('independent_overlay'),
          width: 1,
          height: 1,
        ),
      ),
    );
    overlay.insert(other);
    await tester.pump();
    session.dispose();
    await tester.pump();
    expect(find.byType(LaunchFilm), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('independent_overlay')),
      findsOneWidget,
    );
    await session.unlock('Refused');
    other
      ..remove()
      ..dispose();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing midway leaves no film and never exposes auth', (
    WidgetTester tester,
  ) async {
    final StartupStageSession session = _session(() {});
    final GlobalKey<_HarnessState> host = await _show(tester, session);
    await _until(tester, () => session.film.isDone);
    await _begin(tester, host);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(session.interactive, isFalse);
    expect(session.isClosed, isTrue);
    expect(find.byType(LaunchFilm), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
