import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/accelerator_widgets/accelerator_action_controller.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/accelerator_widgets/accelerator_action_stepper.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/accelerator_widgets/project_creation_stepper.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/primary_pill.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/frosted_route.dart';

import '../../harness/app/fixtures/seed_policy.dart';
import '../../harness/app/fixtures/seed_project_presentation.dart';
import '../../harness/app/seed_project_presentation_binding.dart';
import '../../harness/bin/ci_wallet_reopen.dart' as reopen;
import '../../harness/bin/harness.dart' as cli;
import '../../harness/seed/restored_seed_workflow.dart';
import '../../harness/wallet_address_context.dart';
import '../accelerator_project_redesign/support.dart';

WalletAddressContext _context({
  int count = 2, int revision = 20, int owner = 1,
}) =>
    WalletAddressContext.parse(<String, dynamic>{
      'members': List<String>.generate(count, (int i) => 'synthetic-member-$i'),
      'selected': 'synthetic-member-1', 'saved': 'synthetic-member-1',
      'revision': revision, 'owner': owner,
    });

String _hash(int value) => List<String>.filled(64, '$value').join();

final class _Session {
  final WalletAddressContext original = _context();
  WalletAddressContext current = _context();
  final List<String> started = <String>[];
  bool alive = true;
  int preparations = 0;
  Future<void> Function()? duringRecipe;
  bool wrongDerivation = false;
  bool dieDuringPreparation = false;
  bool duplicateHash = false;
  Map<String, Object?> receiptChange = <String, Object?>{};

  RestoredSeedWorkflow workflow() => RestoredSeedWorkflow(
    original: original, parentAlive: () => alive,
    observe: () async => current,
    prepareAddress: (WalletAddressContext before) async {
      expect(before.same(original), isTrue);
      preparations++;
      current = _context(count: 3,
        revision: wrongDerivation ? 22 : 21);
      if (dieDuringPreparation) alive = false;
      return current;
    },
    recipe: (String id, Future<void> Function() check) async {
      await check();
      started.add(id);
      await duringRecipe?.call();
      return <String, dynamic>{
        'ok': true, 'confirmed': true, 'recipe': id,
        'hash': _hash(duplicateHash ? 1 : started.length), ...receiptChange,
      };
    },
  );
}

class _UnprintableSeedError implements Exception {
  @override
  String toString() => throw StateError('synthetic-private-value');
}

SeedProjectPresentation _projectPresentation({
  required Future<Object?> route,
  bool Function()? current,
  bool Function(String)? submitted,
  Future<void> Function(void Function())? tap,
  Duration timeout = const Duration(seconds: 5),
}) => SeedProjectPresentation(
  originalCurrent: current ?? () => true,
  submittedCurrent: submitted ?? (String hash) => hash == _hash(9),
  tapOriginalExit: tap ?? (void Function() admission) async => admission(),
  originalRouteCompleted: route, closeTimeout: timeout,
);




// Only decoration loading is held. The actual Project view, route, original
// source controller and pointer input remain in use; artwork is not qualified.
class _ProjectFilmBundle extends CachingAssetBundle {
  final Completer<ByteData> _film = Completer<ByteData>();

  @override
  Future<ByteData> load(String key) =>
      key.startsWith('assets/lottie/ic_anim_zts')
          ? _film.future : rootBundle.load(key);
}

Future<void> _projectFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
}

Future<void> _projectClose(WidgetTester tester, Future<void> original) async {
  bool settled = false;
  Object? error;
  StackTrace? trace;
  unawaited(original.then((_) { settled = true; },
    onError: (Object value, StackTrace stack) {
      error = value;
      trace = stack;
      settled = true;
    },
  ));
  for (int frame = 0; frame < 80 && !settled; frame++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 40));
  }
  expect(settled, isTrue);
  if (error != null) Error.throwWithStackTrace(error!, trace!);
}

Future<(SeedProjectPresentation, ModalRoute<dynamic>)> _submittedProject(
  WidgetTester tester, ActionSource source, VoidCallback exited,
) async {
  ModalRoute<dynamic>? originalRoute;
  await tester.pumpWidget(DefaultAssetBundle(
    bundle: _ProjectFilmBundle(),
    child: MaterialApp(
      locale: const Locale('en'), theme: AppTheme.darkTheme,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      home: Scaffold(body: Builder(builder: (BuildContext context) => Center(
        child: OutlinedButton(
          key: const Key('project_original_home'),
          onPressed: () {
            unawaited(showFrostedDialog<void>(context: context,
              builder: (BuildContext dialog) {
                originalRoute = ModalRoute.of(dialog);
                return Center(child: SizedBox(width: 1000, height: 700,
                  child: Material(child: ProjectCreationStepper(
                    source: source,
                  )),
                ));
              },
            ));
          },
          child: const Text('Open original Project'),
        ),
      ))),
    ),
  ));
  await tester.tap(find.byKey(const Key('project_original_home')));
  await _projectFrame(tester);
  expect(originalRoute, isA<FrostedDialogRoute<void>>());
  expect(find.byKey(const Key('project_original_home')).hitTestable(),
      findsNothing);
  Future<void> continueOriginal() async {
    final Finder button = find.widgetWithText(PrimaryPill, 'Continue');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await _projectFrame(tester);
  }
  await continueOriginal();
  final Finder fields = find.byType(TextField);
  expect(fields, findsNWidgets(5));
  const List<String> values = <String>[
    'Synthetic project', 'Synthetic project description',
    'https://example.test/project', '1', '0',
  ];
  for (int index = 0; index < values.length; index++) {
    await tester.ensureVisible(fields.at(index));
    await tester.enterText(fields.at(index), values[index]);
  }
  await _projectFrame(tester);
  await continueOriginal();
  final Finder submit = find.widgetWithText(PrimaryPill, 'Submit');
  await tester.ensureVisible(submit);
  final SeedProjectPresentation presentation = captureSeedProjectPresentation(
    tester.element(submit),
    tapOriginal: (Element element, VoidCallback admission) async {
      admission();
      final Finder button = find.byElementPredicate(
        (Element candidate) => identical(candidate, element),
      );
      expect(button.hitTestable(), findsOneWidget);
      final Offset point = tester.getCenter(button);
      final TestGesture pointer = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await pointer.addPointer(location: point);
      admission();
      await pointer.down(point);
      admission();
      await pointer.up();
      await pointer.removePointer();
      exited();
    },
  );
  expect(presentation.requireCaptured, returnsNormally);
  expect(source.publications, 0);
  await tester.tap(submit);
  await _projectFrame(tester);
  expect(source.publications, 1);
  expect(source.confirmedReads, isEmpty);
  final AcceleratorActionPresentationSource original = tester
      .state<State<AcceleratorActionStepper>>(
        find.byType(AcceleratorActionStepper),
      ) as AcceleratorActionPresentationSource;
  expect(original.actionPresentation.submittedWith(listHash(901)), isTrue);
  expect(find.byKey(const Key('acc_stepper_leave')).hitTestable(),
      findsOneWidget);
  return (presentation, originalRoute!);
}

void main() {
  test('one derived member precedes six exact ordered original receipts',
      () async {
    final _Session session = _Session();
    final Map<String, Object> result = await session.workflow().run(
      'synthetic-external-member',
    );
    expect(session.preparations, 1);
    expect(session.started, seedRecipeIds.toList());
    expect(result['members'], 3);
    expect(result['receipts'], hasLength(6));
    expect(result.toString(), isNot(contains('synthetic-member')));
  });

  test('a replaced initial owner receives no Settings or recipe input',
      () async {
    final _Session session = _Session()..current = _context(owner: 2);
    await expectLater(session.workflow().run('synthetic-external-member'),
      throwsA(isA<SeedRefused>()));
    expect(session.preparations, 0);
    expect(session.started, isEmpty);
  });

  test('an unrelated generation cannot admit the first seed recipe', () async {
    final _Session session = _Session()..wrongDerivation = true;
    await expectLater(session.workflow().run('synthetic-external-member'),
      throwsA(isA<SeedRefused>()));
    expect(session.started, isEmpty);
  });

  test('parent EOF during derivation admits no seed publication', () async {
    final _Session session = _Session()..dieDuringPreparation = true;
    await expectLater(session.workflow().run('synthetic-external-member'),
      throwsA(isA<SeedRefused>()));
    expect(session.started, isEmpty);
  });

  test('wrong recipe, unknown outcome and invalid hash hold later recipes',
      () async {
    for (final Map<String, Object?> change in <Map<String, Object?>>[
      <String, Object?>{'recipe': 'fuse'},
      <String, Object?>{'confirmed': false},
      <String, Object?>{'hash': _hash(0)},
    ]) {
      final _Session session = _Session()..receiptChange = change;
      await expectLater(session.workflow().run('synthetic-external-member'),
        throwsA(isA<SeedRefused>()));
      expect(session.started, <String>['stake']);
    }
  });

  test('the same accepted hash cannot qualify two different seed effects',
      () async {
    final _Session session = _Session()..duplicateHash = true;
    await expectLater(session.workflow().run('synthetic-external-member'),
      throwsA(isA<SeedRefused>()));
    expect(session.started, <String>['stake', 'fuse']);
  });

  test('a failed original is retained without another recipe or retry',
      () async {
    final _Session session = _Session()
      ..duringRecipe = () async { throw const FormatException('unknown'); };
    final RestoredSeedWorkflow workflow = session.workflow();
    await expectLater(workflow.run('synthetic-external-member'),
      throwsFormatException);
    session.duringRecipe = null;
    await expectLater(workflow.run('synthetic-external-member'),
      throwsA(isA<SeedRefused>()));
    expect(session.preparations, 1);
    expect(session.started, <String>['stake']);
  });

  test('a late result from a changed owner cannot start the next recipe',
      () async {
    final _Session session = _Session();
    final Completer<void> original = Completer<void>();
    session.duringRecipe = () => original.future;
    final Future<Map<String, Object>> result = session.workflow().run(
      'synthetic-external-member',
    );
    for (int turn = 0; turn < 10 && session.started.isEmpty; turn++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(session.started, <String>['stake']);
    session.current = _context(count: 3, revision: 22);
    original.complete();
    await expectLater(result, throwsA(isA<SeedRefused>()));
    expect(session.started, <String>['stake']);
  });

  test('a successful session cannot derive or publish a second time',
      () async {
    final _Session session = _Session();
    final RestoredSeedWorkflow workflow = session.workflow();
    await workflow.run('synthetic-external-member');
    await expectLater(workflow.run('synthetic-external-member'),
      throwsA(isA<SeedRefused>()));
    expect(session.preparations, 1);
    expect(session.started, hasLength(6));
  });

  test('seed failure snapshots remain immutable after later observations', () {
    final cli.SeedOperationTrace trace = cli.SeedOperationTrace('stake')
      ..at(cli.SeedOperationAction.check, cli.SeedOperationStep.owner,
          commandIndex: 2);
    final cli.SeedOperationFailure first = trace.failure(
      cli.Fail('synthetic-private-value'),
    );
    trace.at(cli.SeedOperationAction.command, cli.SeedOperationStep.execute,
        commandIndex: 9);
    expect(first.diagnostic['action'], 'check');
    expect(first.diagnostic['command_index'], 2);
    expect(() => first.diagnostic['command_index'] = 99,
        throwsUnsupportedError);
    expect(jsonEncode(first.diagnostic),
        isNot(contains('synthetic-private-value')));
  });

  test('seed failures retain only typed families without formatting errors',
      () {
    final List<(Object, String)> errors = <(Object, String)>[
      (cli.Fail('synthetic-private-value'), 'refused'),
      (const SeedRefused('exact-chain-321-lab-required'), 'refused'),
      (TimeoutException('synthetic-private-value'), 'timeout'),
      (const FormatException('synthetic-private-value'), 'format'),
      (RangeError('synthetic-private-value'), 'type'),
      (const FileSystemException('synthetic-private-value'), 'filesystem'),
      (StateError('synthetic-private-value'), 'state'),
      (_UnprintableSeedError(), 'other'),
    ];
    for (final (Object error, String kind) in errors) {
      final cli.SeedOperationFailure observed =
          cli.SeedOperationTrace('stake').failure(error);
      expect(observed.diagnostic['kind'], kind);
      expect(jsonEncode(observed.diagnostic),
          isNot(contains('synthetic-private-value')));
    }
  });

  test('seed reply codes use exact source labels and reject unknown material',
      () {
    final String code = cli.seedOperationReplyCodes.first;
    for (final String value in <String>[code, 'Seed refused: $code']) {
      final cli.SeedOperationTrace trace = cli.SeedOperationTrace('stake')
        ..at(cli.SeedOperationAction.begin, cli.SeedOperationStep.reply)
        ..refusedReply(value);
      expect(trace.failure(cli.Fail('synthetic-private-value'))
          .diagnostic['reason'], code);
    }
    for (final Object? value in <Object?>[
      null, true, 321, 'synthetic-private-value', '$code ',
      'Seed refused: synthetic-private-value', _UnprintableSeedError(),
    ]) {
      expect(cli.seedOperationReplyCode(value), 'unknown');
    }
  });

  test('publication entry describes the original call without acceptance', () {
    final cli.SeedOperationTrace trace = cli.SeedOperationTrace('stake')
      ..at(cli.SeedOperationAction.publish, cli.SeedOperationStep.owner,
          commandIndex: 7);
    final cli.SeedOperationFailure before = trace.failure(cli.Fail('private'));
    trace
      ..publicationCallEntered()
      ..at(cli.SeedOperationAction.publish, cli.SeedOperationStep.request);
    final cli.SeedOperationFailure after = trace.failure(cli.Fail('private'));
    expect(before.diagnostic['publication_call_entered'], isFalse);
    expect(after.diagnostic['publication_call_entered'], isTrue);
    expect(after.diagnostic['command_index'], 7);
    for (final cli.SeedOperationFailure failure in <cli.SeedOperationFailure>[
      before, after,
    ]) {
      expect(failure.diagnostic.containsKey('confirmed'), isFalse);
      expect(failure.diagnostic.containsKey('hash'), isFalse);
      expect(failure.diagnostic.containsKey('retry'), isFalse);
    }
  });

  test('seed child metadata is phase-bound and never fills an older refusal',
      () {
    final cli.SeedOperationFailure failure =
        cli.SeedOperationTrace('stake').failure(cli.Fail('private'));
    final Map<String, Object?> observed =
        reopen.restoredChildFailure('seed_stake', failure)!;
    expect(observed['kind'], 'HARNESS_REFUSED');
    expect(observed['code'], isNull);
    expect(observed['recipe'], isNull);
    expect(observed['seed'], failure.diagnostic);
    expect(reopen.restoredChildFailure('unlock', failure), isNull);
    final cli.SeedOperationTrace foreign = cli.SeedOperationTrace('private')
      ..at(cli.SeedOperationAction.command, cli.SeedOperationStep.execute,
          commandIndex: 100000);
    final cli.SeedOperationFailure held = foreign.failure(cli.Fail('private'));
    expect(held.diagnostic['recipe'], 'unknown');
    expect(held.diagnostic['command_index'], 0);
    expect(reopen.restoredChildFailure('seed_stake', held), isNull);
    final Map<String, Object?> original = reopen.restoredChildFailure(
      'seed_stake', cli.Fail('private'),
    )!;
    expect(original, <String, Object?>{
      'schema': 1, 'scope': 'owned_reopen_child_failure',
      'phase': 'seed_stake', 'kind': 'HARNESS_REFUSED',
      'code': null, 'recipe': null,
    });
  });

  test('original exhausted seed counts survive as an immutable failure', () {
    final Map<String, Object> counts = <String, Object>{
      'polls': 18, 'absent': 6, 'unconfirmed': 6,
      'effect_pending': 6, 'last': 'effect_pending',
    };
    final cli.SeedOperationTrace trace = cli.SeedOperationTrace('fuse')
      ..at(cli.SeedOperationAction.publish, cli.SeedOperationStep.reply,
          commandIndex: 7)
      ..publicationCallEntered()
      ..refusedReply('exact-confirmation-or-effect-pending',
          confirmation: counts);
    final cli.SeedOperationFailure first = trace.failure(cli.Fail('private'));
    final Map<String, Object> observed =
        first.diagnostic['confirmation']! as Map<String, Object>;
    counts['absent'] = 0;
    expect(observed['absent'], 6);
    expect(() => observed['polls'] = 0, throwsUnsupportedError);
    expect(reopen.restoredChildFailure('seed_fuse', first)!['seed'],
        first.diagnostic);
    trace.at(cli.SeedOperationAction.check, cli.SeedOperationStep.owner);
    expect(trace.failure(cli.Fail('private')).diagnostic
        .containsKey('confirmation'), isFalse);
    expect(observed['absent'], 6);
    expect(reopen.restoredChildFailure('seed_stake', first), isNull);
  });

  test('seed count labels cannot move across original reply boundaries', () {
    const Map<String, Object> counts = <String, Object>{
      'polls': 18, 'absent': 6, 'unconfirmed': 6,
      'effect_pending': 6, 'last': 'effect_pending',
    };
    for (final (cli.SeedOperationAction, cli.SeedOperationStep) boundary in
        <(cli.SeedOperationAction, cli.SeedOperationStep)>[
      (cli.SeedOperationAction.publish, cli.SeedOperationStep.owner),
      (cli.SeedOperationAction.publish, cli.SeedOperationStep.request),
      (cli.SeedOperationAction.command, cli.SeedOperationStep.execute),
      (cli.SeedOperationAction.finish, cli.SeedOperationStep.reply),
    ]) {
      final cli.SeedOperationTrace trace = cli.SeedOperationTrace('fuse')
        ..at(boundary.$1, boundary.$2, commandIndex: 7)
        ..publicationCallEntered()
        ..refusedReply('exact-confirmation-or-effect-pending',
            confirmation: counts);
      expect(trace.failure(cli.Fail('private')).diagnostic
          .containsKey('confirmation'), isFalse);
    }
    final cli.SeedOperationTrace trace = cli.SeedOperationTrace('fuse')
      ..at(cli.SeedOperationAction.publish, cli.SeedOperationStep.reply,
          commandIndex: 7)
      ..publicationCallEntered()
      ..refusedReply('unknown', confirmation: counts);
    expect(trace.failure(cli.Fail('private')).diagnostic
        .containsKey('confirmation'), isFalse);
    trace.refusedReply('exact-confirmation-or-effect-pending',
        confirmation: <String, Object>{...counts, 'path': 'private'});
    expect(trace.failure(cli.Fail('private')).diagnostic
        .containsKey('confirmation'), isFalse);
    trace.refusedReply('exact-confirmation-or-effect-pending',
        confirmation: counts);
    expect(trace.failure(TimeoutException('private')).diagnostic
        .containsKey('confirmation'), isFalse);
  });

  test('the confirmed original Project exit awaits its actual route once',
      () async {
    final Completer<Object?> route = Completer<Object?>();
    int exits = 0;
    int owners = 0;
    final SeedProjectPresentation presentation = _projectPresentation(
      route: route.future,
      tap: (void Function() admission) async {
        admission();
        exits++;
        admission();
      },
    );
    expect(presentation.requireCaptured, returnsNormally);
    final Future<void> original = presentation.close(_hash(9), () => owners++);
    await Future<void>.delayed(Duration.zero);
    expect(exits, 1);
    expect(presentation.closed, isFalse);
    route.complete(null);
    await original;
    expect(presentation.closed, isTrue);
    await presentation.close(_hash(9), () => owners++);
    expect(exits, 1);
    expect(owners, greaterThanOrEqualTo(3));
    await expectLater(presentation.close(_hash(8), () {}),
        throwsA(isA<SeedRefused>()));
    expect(presentation.closed, isTrue);
    expect(exits, 1);
  });

  test('a revoked Project view or owner cannot revive its original exit',
      () async {
    for (final String phase in <String>['before', 'release', 'owner']) {
      final Completer<Object?> route = Completer<Object?>();
      bool live = phase != 'before';
      bool owner = phase != 'owner';
      int exits = 0;
      final SeedProjectPresentation presentation = _projectPresentation(
        route: route.future, current: () => live,
        tap: (void Function() admission) async {
          admission();
          if (phase == 'release') live = false;
          admission();
          exits++;
        },
      );
      void current() {
        if (!owner) throw const SeedRefused('original-context-changed');
      }
      await expectLater(presentation.close(_hash(9), current),
          throwsA(isA<SeedRefused>()));
      live = true;
      owner = true;
      await expectLater(presentation.close(_hash(9), current),
          throwsA(isA<SeedRefused>()));
      expect(exits, 0);
      route.complete(null);
      await Future<void>.delayed(Duration.zero);
      expect(presentation.closed, isFalse);
    }
  });

  test('pending or failed original Project closure never authorizes a retry',
      () async {
    for (final bool fail in <bool>[false, true]) {
      final Completer<Object?> route = Completer<Object?>();
      int exits = 0;
      final SeedProjectPresentation presentation = _projectPresentation(
        route: route.future, timeout: const Duration(milliseconds: 1),
        tap: (void Function() admission) async {
          admission();
          exits++;
          if (fail) throw StateError('synthetic private close failure');
        },
      );
      await expectLater(presentation.close(_hash(9), () {}),
          throwsA(fail ? isA<StateError>() : isA<SeedRefused>()));
      expect(exits, 1);
      expect(presentation.closed, isFalse);
      route.complete(null);
      await Future<void>.delayed(Duration.zero);
      expect(presentation.closed, isFalse);
      await expectLater(presentation.close(_hash(9), () {}),
          throwsA(isA<SeedRefused>()));
      expect(exits, 1);
    }
    for (final Duration timeout in <Duration>[
      Duration.zero, const Duration(seconds: 6),
    ]) {
      expect(() => _projectPresentation(
        route: Future<Object?>.value(), timeout: timeout,
      ), throwsArgumentError);
    }
  });

  test('Project view evidence keeps opaque identities and immutable UI hashes',
      () {
    final Object owner = Object();
    final Object source = Object();
    final Object draft = Object();
    AcceleratorActionPresentation view({
      Object? ownerChange, Object? sourceChange, Object? draftChange,
      int epoch = 1, bool current = true, bool submitted = false,
      List<String> hashes = const <String>[],
    }) => AcceleratorActionPresentation(
      owner: ownerChange ?? owner, source: sourceChange ?? source,
      draft: draftChange ?? draft, epoch: epoch,
      kind: AcceleratorActionKind.createProject, current: current,
      submitted: submitted, hashes: hashes,
    );
    final AcceleratorActionPresentation original = view();
    expect(original.prepared, isTrue);
    expect(original.current, isTrue);
    expect(view(current: false).current, isFalse);
    final List<String> hashes = <String>[_hash(9)];
    final AcceleratorActionPresentation submitted = view(
      submitted: true, hashes: hashes,
    );
    hashes[0] = _hash(8);
    expect(submitted.sameOwner(original), isTrue);
    expect(submitted.submittedWith(_hash(9)), isTrue);
    expect(submitted.submittedWith(_hash(8)), isFalse);
    expect(submitted.prepared, isFalse);
    expect(submitted.toString(), isNot(contains(_hash(9))));
    for (final AcceleratorActionPresentation replacement in
        <AcceleratorActionPresentation>[
      view(ownerChange: Object()), view(sourceChange: Object()),
      view(draftChange: Object()), view(epoch: 2),
    ]) {
      expect(replacement.sameOwner(original), isFalse);
    }
    const Object first = ValueKey<String>('same synthetic value');
    final Object second = ValueKey<String>(
      String.fromCharCodes('same synthetic value'.codeUnits),
    );
    expect(first, second);
    expect(identical(first, second), isFalse);
    expect(view(draftChange: first).sameOwner(view(draftChange: second)),
        isFalse);
    expect(view(current: false, submitted: true,
        hashes: <String>[_hash(9)]).submittedWith(_hash(9)), isFalse);
    expect(view(submitted: true, hashes: <String>[_hash(9), _hash(8)])
        .submittedWith(_hash(9)), isFalse);
    for (final String code in <String>[
      'confirmed-project-presentation-required',
      'original-project-presentation-changed',
      'original-project-presentation-close-pending',
      'original-project-presentation-held',
      'original-project-presentation-required',
    ]) {
      expect(cli.seedOperationReplyCode(code), code);
    }
  });

  testWidgets('confirmed Project exits through its original view and route',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 780));
    final ActionSource source = ActionSource(scope: Object());
    int exits = 0;
    try {
      final (SeedProjectPresentation original, ModalRoute<dynamic> route) =
          await _submittedProject(tester, source, () => exits++);
      bool completed = false;
      unawaited(route.completed.then((_) { completed = true; }));
      expect(completed, isFalse);
      await _projectClose(tester, original.close(listHash(901), () {}));
      expect(original.closed, isTrue);
      expect(completed, isTrue);
      expect(exits, 1);
      expect(find.byType(ProjectCreationStepper), findsNothing);
      expect(find.byKey(const Key('project_original_home')).hitTestable(),
          findsOneWidget);
      await original.close(listHash(901), () {});
      expect(exits, 1);
      expect(source.publications, 1);
      expect(source.builders, hasLength(1));
      expect(source.confirmedReads, isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('a submitted Project UI hash alone cannot replace the original',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 780));
    final ActionSource source = ActionSource(scope: Object());
    int exits = 0;
    try {
      final (SeedProjectPresentation original, ModalRoute<dynamic> route) =
          await _submittedProject(tester, source, () => exits++);
      await expectLater(original.close(listHash(902), () {}),
          throwsA(isA<SeedRefused>()));
      await expectLater(original.close(listHash(901), () {}),
          throwsA(isA<SeedRefused>()));
      expect(original.closed, isFalse);
      expect(route.isCurrent, isTrue);
      expect(exits, 0);
      expect(find.byKey(const Key('acc_stepper_leave')), findsOneWidget);
      expect(find.byKey(const Key('project_original_home')).hitTestable(),
          findsNothing);
      expect(source.publications, 1);
      expect(source.confirmedReads, isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await tester.binding.setSurfaceSize(null);
    }
  });
}
