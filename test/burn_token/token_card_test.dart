import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart'
    show PrimaryPill;
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

import '../token_actions_redesign/support.dart';

void main() {
  const String owner = 'z1qq6eg8n43g032hanpsfp02qcdmv7zfj3y2lt5d';
  const String holder = 'z1qp3yph55qgresyytz83anynr2f4z39x2z3ej3e';

  setUp(() {
    kSelectedAddress = holder;
    kDefaultAddressList = <String?>[holder];
    kAddressLabelMap = <String, String>{holder: 'Holder'};
  });

  tearDown(() {
    kSelectedAddress = null;
    kDefaultAddressList = <String?>[];
    kAddressLabelMap = <String, String>{};
  });

  testWidgets('allows a non-owner to burn a publicly burnable token', (
    WidgetTester tester,
  ) async {
    final ActionFixture fixture = await _pumpTokenCard(
      tester,
      _buildToken(owner: owner, isBurnable: true),
    );

    expect(
      tester.widget<PrimaryPill>(find.byKey(const Key('token_burn_submit')))
          .onPressed,
      isNotNull,
    );
    expect(fixture.transport.calls, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('allows the owner to burn an owner-only token', (
    WidgetTester tester,
  ) async {
    kSelectedAddress = owner;
    kDefaultAddressList = <String?>[owner];
    kAddressLabelMap = <String, String>{owner: 'Owner'};

    final ActionFixture fixture = await _pumpTokenCard(
      tester,
      _buildToken(owner: owner, isBurnable: false),
    );

    expect(
      tester.widget<PrimaryPill>(find.byKey(const Key('token_burn_submit')))
          .onPressed,
      isNotNull,
    );
    expect(fixture.transport.calls, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('refuses owner-only burn for the selected non-owner', (
    WidgetTester tester,
  ) async {
    kDefaultAddressList = <String?>[holder, owner];
    kAddressLabelMap = <String, String>{
      holder: 'Holder',
      owner: 'Owner',
    };

    final ActionFixture fixture = await _pumpTokenCard(
      tester,
      _buildToken(owner: owner, isBurnable: false),
    );

    expect(
      tester.widget<PrimaryPill>(find.byKey(const Key('token_burn_submit')))
          .onPressed,
      isNull,
    );
    expect(fixture.transport.calls, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Token _buildToken({required String owner, required bool isBurnable}) => Token(
  'Test Token',
  'TST',
  'zenon.org',
  BigInt.from(85),
  0,
  Address.parse(owner),
  znnZts,
  BigInt.from(100),
  isBurnable,
  false,
  true,
);

Future<ActionFixture> _pumpTokenCard(
  WidgetTester tester,
  Token token,
) async {
  final ActionFixture fixture = ActionFixture(
    initialToken: token,
    ownerAddress: kSelectedAddress,
  );
  addTearDown(fixture.close);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 700,
          height: 500,
          child: TokenCard(
            token: token,
            favoritesCallback: () {},
            favoriteRepository: _Favorites(),
            publisher: fixture.publisher,
            isCurrent: () => fixture.active,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  // The collapsed ledger has one detail control and its independent star.
  expect(find.byTooltip('Mint'), findsNothing);
  expect(find.byTooltip('Burn'), findsNothing);
  expect(find.byTooltip('Transfer token ownership'), findsNothing);
  final Finder disclosure = find.byKey(const Key('token_detail_button'));
  expect(disclosure, findsOneWidget);
  expect(tester.getSize(disclosure), const Size.square(32));
  expect(fixture.tokenReads, 0);
  await tester.tap(disclosure);
  await pumpActionUntil(tester, () => fixture.tokenReads == 1);
  await tester.pump(const Duration(milliseconds: 260));
  await tester.tap(find.byKey(const Key('token_action_mode_burn')));
  await tester.pump(const Duration(milliseconds: 260));
  await tester.enterText(find.byKey(const Key('burn_amount_field')), '1');
  await tester.pump();
  expect(fixture.tokenReads, 1);
  expect(fixture.accountReads, 1);
  return fixture;
}

class _Favorites implements FavoriteTokensRepository {
  @override
  bool contains(TokenStandard standard) => false;
  @override
  Future<void> add(TokenStandard standard) async {}
  @override
  Future<void> remove(TokenStandard standard) async {}
}
