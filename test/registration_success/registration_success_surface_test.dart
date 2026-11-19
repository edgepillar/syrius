import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/create_pillar_stepper/widgets/pillar_registered_success.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/create_sentinel_stepper/widgets/sentinel_registered_success.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/create_token_stepper/widgets/token_created_success.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/registration_success/registration_confirmation.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/registration_success/registration_success_surface.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/wallet_action_context.dart';
import 'package:zenon_syrius_wallet_flutter/utils/wallet_context_revision.dart';
import 'package:zenon_syrius_wallet_flutter/utils/wallet_flight_registry.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/app_lottie.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/rail.dart'
    show ShellSymbol;
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class _Context extends Mock implements WalletActionContext {}

Widget _host(
  Widget child, {
  bool light = false,
  double textScale = 1,
}) => MaterialApp(
  theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
    ),
    child: child!,
  ),
  home: Scaffold(
    // Playback has its own F14 tests. This fixture inspects assembly admission
    // and element identity without decoding the original image masters.
    body: TickerMode(enabled: false, child: child),
  ),
);

void main() {
  for (final bool light in <bool>[false, true]) {
    for (final AppLottieAsset asset in <AppLottieAsset>[
      AppLottieAsset.pillar,
      AppLottieAsset.sentinel,
      AppLottieAsset.zts,
    ]) {
      testWidgets('${asset.name} waits for its exact block in theme $light', (
        WidgetTester tester,
      ) async {
        await _withRegistrationFixture(tester, (
          _RegistrationFixture fixture,
        ) async {
          int another = 0;
          final Widget surface = switch (asset) {
            AppLottieAsset.pillar => PillarRegisteredSuccess(
              confirmation: fixture.confirmation,
              onRegisterAnotherPressed: () => another++,
              onViewPillarsPressed: () {},
            ),
            AppLottieAsset.sentinel => SentinelRegisteredSuccess(
              confirmation: fixture.confirmation,
              onViewSentinelsPressed: () {},
            ),
            _ => TokenCreatedSuccess(
              confirmation: fixture.confirmation,
              onCreateAnotherTokenPressed: () => another++,
              onViewTokensPressed: () {},
            ),
          };
          await tester.pumpWidget(_host(surface, light: light));
          final Finder caption = find.byKey(
            const Key('registration_confirmation_caption'),
          );
          final Finder checks = find.byType(ShellSymbol);
          expect(find.byKey(const Key('registration_waiting')), findsOneWidget);
          expect(find.byType(AppLottie), findsNothing);
          expect(caption, findsNothing);
          expect(checks, findsNWidgets(3));
          expect(find.byKey(const Key('registration_another')), findsNothing);
          expect(fixture.requests, <(int, Hash)>[(321, fixture.hash)]);
          await tester.pump(const Duration(minutes: 5));
          expect(find.byType(AppLottie), findsNothing);
          expect(another, 0);

          fixture.reply.complete(true);
          await _completeOnWidgetClock(
            tester,
            fixture.originalCheck,
            operation: 'Registration confirmation',
          );
          await tester.pump();
          expect(find.byKey(const Key('registration_waiting')), findsNothing);
          expect(
            caption,
            asset == AppLottieAsset.pillar ? findsOneWidget : findsNothing,
          );
          expect(checks, findsNWidgets(4));
          expect(tester.getSize(checks.first), const Size.square(12));
          final AppTokens tokens = AppTokens.of(tester.element(checks.first));
          final Row firstRow = tester
              .element(checks.first)
              .findAncestorWidgetOfExactType<Row>()!;
          final Row secondRow = tester
              .element(checks.at(1))
              .findAncestorWidgetOfExactType<Row>()!;
          expect(
            tester.getSize(find.byWidget(firstRow.children.first)),
            const Size.square(22),
          );
          expect(
            tester.getTopLeft(find.byWidget(secondRow)).dy -
                tester.getBottomLeft(find.byWidget(firstRow)).dy,
            closeTo(tokens.registrationActionGap, .01),
          );
          final Finder rail = find.ancestor(
            of: checks.first,
            matching: find.byType(SingleChildScrollView),
          );
          final Row lastRow = tester
              .element(checks.last)
              .findAncestorWidgetOfExactType<Row>()!;
          final Finder separator = find.descendant(
            of: rail,
            matching: find.byType(Divider),
          );
          expect(
            tester.getTopLeft(find.byWidget(firstRow)).dy -
                tester.getTopLeft(rail).dy,
            closeTo(24, .01),
          );
          expect(
            tester.getTopLeft(separator).dy -
                tester.getBottomLeft(find.byWidget(lastRow)).dy,
            closeTo(22, .01),
          );
          final AppLottie art = tester.widget<AppLottie>(
            find.byType(AppLottie),
          );
          expect(art.asset, asset);
          expect(art.size, 340);
          expect(art.repeat, isFalse);
          expect(tester.getSize(find.byType(AppLottie)), const Size(340, 340));
          final String heading = switch (asset) {
            AppLottieAsset.pillar => 'pillar is registered',
            AppLottieAsset.sentinel => 'Sentinel registered',
            _ => 'Token created',
          };
          final Text title = tester.widget<Text>(find.text(heading));
          expect(title.style!.fontSize, 22);
          expect(title.style!.fontWeight, FontWeight.w600);
          final Finder artwork = find.byType(AppLottie);
          final Rect viewport = tester.getRect(
            find.ancestor(
              of: artwork,
              matching: find.byType(SingleChildScrollView),
            ),
          );
          final Rect actions = tester.getRect(
            find.ancestor(
              of: find.widgetWithText(OutlinedButton, 'Done'),
              matching: find.byType(Wrap),
            ),
          );
          final double artTop = tester.getTopLeft(artwork).dy;
          expect(
            artTop - viewport.top - tokens.registrationPadding.top,
            closeTo(
              viewport.bottom -
                  tokens.registrationPadding.bottom -
                  actions.bottom,
              .01,
            ),
          );
          expect(
            tester.getTopLeft(find.text(heading)).dy - artTop,
            closeTo(
              tokens.registrationArtSize +
                  tokens.registrationGap +
                  tokens.registrationHeadingOffset,
              .01,
            ),
          );
          final Finder table = find.byType(Table);
          final Finder chain = find.text('CHAIN');
          final Finder chainValue = find.text('321');
          final Finder blockValue = find.text('666666…6666');
          expect(find.descendant(of: table, matching: chain), findsOneWidget);
          expect(tester.widget<Text>(chainValue).style!.fontSize, 13);
          expect(tester.widget<Text>(blockValue).style!.fontSize, 13);
          expect(
            tester.getCenter(chain).dy,
            closeTo(tester.getCenter(chainValue).dy, .01),
          );
          expect(
            tester.getTopLeft(chainValue).dx,
            tester.getTopLeft(blockValue).dx,
          );
          final Element original = tester.element(find.byType(AppLottie));
          await tester.pumpWidget(_host(surface, light: light));
          await tester.pump(const Duration(seconds: 1));
          expect(tester.element(find.byType(AppLottie)), same(original));
          await tester.pumpWidget(
            _host(surface, light: light, textScale: 2),
          );
          expect(table, findsNothing);
          expect(
            tester.getTopLeft(chainValue).dy,
            greaterThan(tester.getBottomLeft(chain).dy),
          );
          expect(tester.element(find.byType(AppLottie)), same(original));
          expect(another, 0);
          await tester.pumpWidget(const SizedBox.shrink());
          expect(tester.takeException(), isNull);
        });
      });
    }
  }

  testWidgets('revoked confirmation cannot expose art or another action', (
    WidgetTester tester,
  ) async {
    await _withRegistrationFixture(tester, (
      _RegistrationFixture fixture,
    ) async {
      fixture.current = false;
      fixture.reply.complete(true);
      await _completeOnWidgetClock(
        tester,
        fixture.originalCheck,
        operation: 'Revoked registration confirmation',
      );
      await tester.pumpWidget(
        _host(
          PillarRegisteredSuccess(
            confirmation: fixture.confirmation,
            onRegisterAnotherPressed: () {},
            onViewPillarsPressed: () {},
          ),
        ),
      );
      expect(find.byType(AppLottie), findsNothing);
      expect(find.byKey(const Key('registration_another')), findsNothing);
      expect(
        find.byKey(const Key('pillar_registration_confirmed')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('Another restores real Tab traversal and the original listener', (
    WidgetTester tester,
  ) async {
    int presses = 0;
    final ValueNotifier<bool> published = ValueNotifier<bool>(false);
    final StreamController<void> events = StreamController<void>.broadcast(
      sync: true,
    );
    final GlobalKey<_RetainedProbeState> probe =
        GlobalKey<_RetainedProbeState>();
    await _withRegistrationFixture(
      tester,
      (_RegistrationFixture fixture) async {
        fixture.reply.complete(true);
        await _completeOnWidgetClock(
          tester,
          fixture.originalCheck,
          operation: 'Retained registration confirmation',
        );
        await tester.pumpWidget(
          _host(
            ValueListenableBuilder<bool>(
              valueListenable: published,
              builder: (BuildContext context, bool value, _) =>
                  RegistrationRetainedFlow(
                    published: value,
                    form: _RetainedProbe(
                      key: probe,
                      events: events.stream,
                      onPress: () {
                        presses++;
                        published.value = true;
                      },
                    ),
                    receipt: PillarRegisteredSuccess(
                      confirmation: fixture.confirmation,
                      onRegisterAnotherPressed: () {
                        if (fixture.confirmation.resetForAnother()) {
                          published.value = false;
                        }
                      },
                      onViewPillarsPressed: () {},
                    ),
                  ),
            ),
          ),
        );
        final _RetainedProbeState original = probe.currentState!;
        await tester.enterText(
          find.byKey(const Key('retained_first')),
          'Kept draft',
        );
        final Finder register = find.byKey(const Key('retained_register'));
        final Offset oldAction = tester.getCenter(register);
        await tester.tap(register);
        await tester.pump();
        expect(presses, 1);
        events.add(null);
        expect(probe.currentState, same(original));
        expect(original.eventsReceived, 1);
        expect(register, findsNothing);
        expect(find.text('Register'), findsOneWidget);
        await tester.tapAt(oldAction);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(presses, 1);
        await tester.tap(find.byKey(const Key('registration_another')));
        await tester.pump();
        expect(probe.currentState, same(original));
        expect(original.eventsReceived, 1);
        expect(original.draft.text, 'Kept draft');
        await tester.tap(find.byKey(const Key('retained_first')));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(original.second.hasFocus, isTrue);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        expect(original.first.hasFocus, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      afterUnmount: () async {
        published.dispose();
        await _completeOnWidgetClock(
          tester,
          events.close(),
          operation: 'Retained form stream close',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('a shared context revision removes already mounted art', (
    WidgetTester tester,
  ) async {
    await _withRegistrationFixture(tester, (
      _RegistrationFixture fixture,
    ) async {
      fixture.reply.complete(true);
      await _completeOnWidgetClock(
        tester,
        fixture.originalCheck,
        operation: 'Mounted registration confirmation',
      );
      await tester.pumpWidget(
        _host(
          TokenCreatedSuccess(
            confirmation: fixture.confirmation,
            onCreateAnotherTokenPressed: () {},
            onViewTokensPressed: () {},
          ),
        ),
      );
      expect(find.byType(AppLottie), findsOneWidget);
      fixture.current = false;
      WalletContextRevision.invalidate();
      await tester.pump();
      expect(find.byType(AppLottie), findsNothing);
      expect(find.byKey(const Key('registration_waiting')), findsOneWidget);
      expect(find.byKey(const Key('registration_another')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

class _RegistrationFixture {
  _RegistrationFixture() {
    when(() => context.ownerAddress).thenReturn(owner);
    when(() => context.isCurrent).thenAnswer((_) => current);
    registry = WalletFlightRegistry(
      currentChainId: () => 321,
      lookup: (int chainId, Hash hash) {
        requests.add((chainId, hash));
        return reply.future;
      },
    );
    confirmation = RegistrationConfirmation(
      context: context,
      chainId: 321,
      walletAddresses: <String>[owner],
      registry: registry,
    );
    final AccountBlockTemplate block =
        AccountBlockTemplate(
            blockType: BlockTypeEnum.userSend.index,
            amount: BigInt.from(15),
          )
          ..hash = hash
          ..address = Address.parse(owner)
          ..chainIdentifier = 321;
    confirmation.accept(
      RegistrationPublication(accountBlock: block, name: 'pillar'),
    );
    originalCheck = confirmation.check();
  }

  final String owner = emptyAddress.toString();
  final Hash hash = Hash.parse(List<String>.filled(64, '6').join());
  final _Context context = _Context();
  final Completer<bool> reply = Completer<bool>();
  final List<(int, Hash)> requests = <(int, Hash)>[];
  bool current = true;
  late final WalletFlightRegistry registry;
  late final RegistrationConfirmation confirmation;
  late final Future<void> originalCheck;
}

Future<void> _completeOnWidgetClock(
  WidgetTester tester,
  Future<void> original, {
  required String operation,
}) async {
  bool settled = false;
  (Object, StackTrace)? failure;
  final Future<void> observed = original.then<void>(
    (_) {
      settled = true;
    },
    onError: (Object error, StackTrace stackTrace) {
      failure = (error, stackTrace);
      settled = true;
    },
  );
  for (int tick = 0; tick < 100 && !settled; tick++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  if (!settled) {
    fail('$operation did not settle within 100 widget-clock ticks');
  }
  await observed;
  if (failure case (final Object error, final StackTrace stackTrace)) {
    Error.throwWithStackTrace(error, stackTrace);
  }
}

Future<void> _withRegistrationFixture(
  WidgetTester tester,
  Future<void> Function(_RegistrationFixture) body, {
  Future<void> Function()? afterUnmount,
}) async {
  // The reply, registry and first check share the test's fake clock.
  // A root-zone reply cannot be drained by bounded widget pumps.
  final _RegistrationFixture fixture = _RegistrationFixture();
  final List<(Object, StackTrace)> failures = <(Object, StackTrace)>[];
  Future<void> retainFailure(FutureOr<void> Function() action) async {
    try {
      await action();
    } on Object catch (error, stackTrace) {
      failures.add((error, stackTrace));
    }
  }

  await retainFailure(() => body(fixture));
  await retainFailure(() => tester.pumpWidget(const SizedBox.shrink()));
  if (afterUnmount != null) await retainFailure(afterUnmount);
  await retainFailure(() async {
    if (!fixture.reply.isCompleted) fixture.reply.complete(false);
    await _completeOnWidgetClock(
      tester,
      fixture.originalCheck,
      operation: 'Registration fixture close',
    );
  });
  await retainFailure(fixture.confirmation.dispose);
  await retainFailure(fixture.registry.dispose);
  await retainFailure(AppLottie.debugClear);
  await retainFailure(() => expect(tester.takeException(), isNull));
  if (failures.isNotEmpty) {
    for (final (Object error, StackTrace stackTrace) in failures.skip(1)) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          context: ErrorDescription('while closing the registration fixture'),
        ),
      );
    }
    final (Object error, StackTrace stackTrace) = failures.first;
    Error.throwWithStackTrace(error, stackTrace);
  }
}

class _RetainedProbe extends StatefulWidget {
  const _RetainedProbe({
    required this.events,
    required this.onPress,
    super.key,
  });

  final Stream<void> events;
  final VoidCallback onPress;

  @override
  State<_RetainedProbe> createState() => _RetainedProbeState();
}

class _RetainedProbeState extends State<_RetainedProbe> {
  late final StreamSubscription<void> subscription;
  final FocusNode first = FocusNode();
  final FocusNode second = FocusNode();
  final TextEditingController draft = TextEditingController();
  int eventsReceived = 0;

  @override
  void initState() {
    super.initState();
    subscription = widget.events.listen((_) => eventsReceived++);
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextField(
          key: const Key('retained_first'),
          focusNode: first,
          controller: draft,
        ),
        TextField(key: const Key('retained_second'), focusNode: second),
        TextButton(
          key: const Key('retained_register'),
          onPressed: widget.onPress,
          child: const Text('Register'),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    unawaited(subscription.cancel());
    first.dispose();
    second.dispose();
    draft.dispose();
    super.dispose();
  }
}
