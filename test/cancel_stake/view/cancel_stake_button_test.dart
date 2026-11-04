import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart' as app;
import
    'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/wallet_context_revision.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/tabs.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

import '../../helpers/hydrated_bloc.dart';
import '../../publication_session/support.dart';

class _Embedded extends Mock implements EmbeddedApi {}
class _Stake extends Mock implements StakeApi {}

class _Balances extends ZenonAddressUtils {
  int refreshes = 0;

  @override
  void refreshBalance() => refreshes++;
}

// The real bloc and dialog use a recording publisher without wallet I/O.
class _Publisher extends AccountBlockUtils {
  final Completer<AccountBlockTemplate> reply =
      Completer<AccountBlockTemplate>();
  int calls = 0;
  AccountBlockTemplate? block;
  Address? owner;
  bool Function()? guard;
  bool? wait;

  @override
  Future<AccountBlockTemplate> createAccountBlock(
    AccountBlockTemplate transactionParams,
    String purpose, {
    Address? address,
    bool waitForRequiredPlasma = false,
    bool Function()? canPublish,
  }) {
    calls++;
    block = transactionParams;
    owner = address;
    guard = canPublish;
    wait = waitForRequiredPlasma;
    expect(canPublish?.call(), isTrue);
    return reply.future;
  }
}

class _Fixture {
  _Fixture() {
    app.zenon = node;
    kWalletFile = file;
    kWalletInitCompleted = true;
    kWalletPath = 'isolated-stake-fixture';
    kSelectedAddress = owner;
    kDefaultAddressList = <String?>[owner];
    kCurrentPage = Tabs.staking;
    kCurrentNode = 'isolated-node';
    kNodeChainId = 321;
    setChainIdentifier(chainIdentifier: 321);
    when(() => node.embedded).thenReturn(embedded);
    when(() => embedded.stake).thenReturn(stake);
    when(() => stake.cancel(any())).thenAnswer((Invocation call) {
      hashes.add((call.positionalArguments.single as Hash).toString());
      return template;
    });
    bloc = CancelStakeBloc(
      accountBlockUtils: publisher, zenon: node, zenonAddressUtils: balances,
    );
  }

  final PublicationGlobals globals = PublicationGlobals();
  final MockPublicationZenon node = MockPublicationZenon();
  final MockPublicationFile file = MockPublicationFile();
  final _Embedded embedded = _Embedded();
  final _Stake stake = _Stake();
  final _Publisher publisher = _Publisher();
  final _Balances balances = _Balances();
  final String owner = emptyAddress.toString();
  final Hash hash = Hash.parse('1'.padLeft(64, '0'));
  final AccountBlockTemplate template = AccountBlockTemplate(blockType: 2)
    ..chainIdentifier = 321;
  final List<String> hashes = <String>[];
  late final CancelStakeBloc bloc;
  int cancelled = 0;
  bool visible = true;

  Widget host({bool light = false}) => MaterialApp(
    theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
    locale: const Locale('en'),
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: TickerMode(
      enabled: visible,
      child: CancelStakeButton(
        ownerAddress: owner, stakeHash: hash,
        amount: BigInt.from(200) * BigInt.from(10).pow(kZnnCoin.decimals),
        onCancelled: () => cancelled++, bloc: bloc,
      ),
    ))),
  );

  Future<void> dispose() async {
    if (!publisher.reply.isCompleted) publisher.reply.complete(template);
    await bloc.close();
    globals.restore();
    WalletContextRevision.invalidate();
  }
}

Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<_Fixture> _prepare(WidgetTester tester, {bool light = false}) async {
  final _Fixture source = _Fixture();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await source.dispose();
  });
  await tester.pumpWidget(source.host(light: light));
  await _frames(tester);
  return source;
}

Future<void> _answer(WidgetTester tester, bool yes) async {
  await tester.tap(find.byKey(Key(yes ? 'dialog_yes_button' :
      'dialog_no_button')));
  await _frames(tester);
}

void main() {
  initHydratedStorage();
  setUpAll(() => registerFallbackValue(emptyHash));

  for (final bool light in <bool>[false, true]) {
    testWidgets('confirmed cancellation keeps original account, $light',
        (WidgetTester tester) async {
      final _Fixture source = await _prepare(tester, light: light);
      final VoidCallback original = tester.widget<OutlinedButton>(
        find.byType(OutlinedButton),
      ).onPressed!;
      original();
      original();
      await _frames(tester);
      expect(find.text('Cancel the stake of 200 ZNN?'), findsOneWidget);
      expect(find.byKey(const Key('dialog_yes_button')), findsOneWidget);
      await _answer(tester, true);
      expect(source.hashes, <String>[source.hash.toString()]);
      expect(source.publisher.calls, 1);
      expect(source.publisher.block, same(source.template));
      expect(source.publisher.owner.toString(), source.owner);
      expect(source.publisher.wait, isTrue);
      expect(source.publisher.guard?.call(), isTrue);
      original();
      await _frames(tester);
      expect(source.publisher.calls, 1);
      expect(find.byKey(const Key('dialog_yes_button')), findsNothing);
      source.publisher.reply.complete(source.template);
      await _frames(tester);
      expect(source.balances.refreshes, 1);
      expect(source.cancelled, 1);
      verifyNever(source.file.open);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('No leaves the original row without preparing a block',
      (WidgetTester tester) async {
    final _Fixture source = await _prepare(tester);
    await tester.tap(find.byType(OutlinedButton));
    await _frames(tester);
    await _answer(tester, false);
    expect(source.hashes, isEmpty);
    expect(source.publisher.calls, 0);
    expect(source.cancelled, 0);
    expect(tester.widget<OutlinedButton>(
      find.byType(OutlinedButton),
    ).onPressed, isNotNull);
    verifyNever(source.file.open);
  });

  testWidgets('an old painted callback refuses a context round trip',
      (WidgetTester tester) async {
    final _Fixture source = await _prepare(tester);
    final VoidCallback original = tester.widget<OutlinedButton>(
      find.byType(OutlinedButton),
    ).onPressed!;
    source.visible = false;
    await tester.pumpWidget(source.host());
    original();
    await _frames(tester);
    expect(find.byKey(const Key('dialog_yes_button')), findsNothing);
    source.visible = true;
    await tester.pumpWidget(source.host());
    WalletContextRevision.invalidate();
    original();
    await _frames(tester);
    expect(find.byKey(const Key('dialog_yes_button')), findsNothing);
    expect(source.hashes, isEmpty);
    expect(source.publisher.calls, 0);
  });

  testWidgets('an account round trip revokes an open confirmation',
      (WidgetTester tester) async {
    final _Fixture source = await _prepare(tester);
    await tester.tap(find.byType(OutlinedButton));
    await _frames(tester);
    kSelectedAddress = 'another-fixture-account';
    WalletContextRevision.invalidate();
    kSelectedAddress = source.owner;
    await _answer(tester, true);
    expect(source.hashes, isEmpty);
    expect(source.publisher.calls, 0);
    expect(source.cancelled, 0);
    verifyNever(source.file.open);
  });

  testWidgets('removing the original view revokes a pending publication guard',
      (WidgetTester tester) async {
    final _Fixture source = await _prepare(tester);
    await tester.tap(find.byType(OutlinedButton));
    await _frames(tester);
    await _answer(tester, true);
    expect(source.publisher.calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(source.publisher.guard?.call(), isFalse);
    source.publisher.reply.complete(source.template);
    await tester.pump();
    expect(source.balances.refreshes, 0);
    expect(source.cancelled, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a late accepted original cannot refresh a replacement context',
      (WidgetTester tester) async {
    final _Fixture source = await _prepare(tester);
    await tester.tap(find.byType(OutlinedButton));
    await _frames(tester);
    await _answer(tester, true);
    expect(source.publisher.calls, 1);
    WalletContextRevision.invalidate();
    expect(source.publisher.guard?.call(), isFalse);
    source.publisher.reply.complete(source.template);
    await _frames(tester);
    expect(source.balances.refreshes, 0);
    expect(source.cancelled, 0);
    expect(source.bloc.state, const CancelStakeInitial());
    expect(tester.takeException(), isNull);
    verifyNever(source.file.open);
  });
}
