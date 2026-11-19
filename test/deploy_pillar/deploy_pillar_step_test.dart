import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class _Deploy extends MockBloc<DeployPillarEvent, DeployPillarState>
    implements DeployPillarBloc {}

class _SlotFee extends MockBloc<FetchEvent, FetchState<CreatePillarQsrInfoData>>
    implements CreatePillarQsrInfoBloc {}

void main() {
  testWidgets('Pillar drafts survive Back and publish only from review', (
    WidgetTester tester,
  ) async {
    final String owner = emptyAddress.toString();
    final String? savedAddress = kSelectedAddress;
    final List<String?> savedAddresses = kDefaultAddressList;
    addTearDown(() {
      kSelectedAddress = savedAddress;
      kDefaultAddressList = savedAddresses;
    });
    kSelectedAddress = owner;
    kDefaultAddressList = <String?>[owner];

    final _Deploy deploy = _Deploy();
    final _SlotFee slotFee = _SlotFee();
    when(() => deploy.state).thenReturn(const DeployPillarInitial());
    when(() => slotFee.state).thenReturn(
      const FetchInitial<CreatePillarQsrInfoData>(),
    );
    final DeployPillarRequested expected = DeployPillarRequested(
      blockProducingAddress: pillarAddress,
      giveBlockRewardPercentage: 0,
      giveDelegateRewardPercentage: 0,
      pillarName: 'pillar',
      rewardAddress: emptyAddress,
    );
    registerFallbackValue(expected);
    final List<DeployPillarEvent> requests = <DeployPillarEvent>[];
    when(() => deploy.add(any())).thenAnswer((Invocation call) {
      requests.add(call.positionalArguments.single as DeployPillarEvent);
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<DeployPillarBloc>.value(
            value: deploy,
            child: BlocProvider<CreatePillarQsrInfoBloc>.value(
              value: slotFee,
              child: DeployPillarStep(
                ownerAddress: owner,
                availableZnn: BigInt.zero,
                onDeployDone: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder name = find.byKey(const Key('pillar_name_field'));
    final Finder nameValid = find.byKey(const Key('pillar_name_valid'));
    final Finder producer = find.byKey(
      const Key('pillar_producer_address_field'),
    );
    final Finder reward = find.byKey(const Key('pillar_reward_address_field'));
    final Finder detailsNext = find.byKey(
      const Key('pillar_details_next_button'),
    );
    final Finder sharingNext = find.byKey(
      const Key('pillar_sharing_next_button'),
    );
    final Finder register = find.byKey(const Key('pillar_register_button'));
    final Finder slider = find.byKey(
      const Key('pillar_momentum_reward_slider'),
    );
    final Finder back = find.widgetWithText(TextButton, 'Go back');
    final Element originalName = tester.element(name);
    expect(
      tester.getTopLeft(producer).dy,
      lessThan(tester.getTopLeft(reward).dy),
    );
    expect(register.hitTestable(), findsNothing);
    expect(slider.hitTestable(), findsNothing);
    expect(requests, isEmpty);
    expect(nameValid, findsNothing);

    await tester.enterText(name, 'x');
    await tester.pump();
    expect(nameValid, findsNothing);
    await tester.enterText(name, 'pillar');
    await tester.enterText(producer, owner);
    await tester.pump();
    expect(nameValid, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(sharingNext.hitTestable(), findsNothing);
    await tester.enterText(producer, pillarAddress.toString());
    await tester.enterText(reward, plasmaAddress.toString());
    await tester.pump();
    await tester.tap(find.byKey(const Key('pillar_use_owner_address')));
    await tester.pump();
    expect(tester.widget<TextField>(reward).controller!.text, owner);

    await tester.tap(detailsNext);
    await tester.pumpAndSettle();
    expect(slider.hitTestable(), findsOneWidget);
    expect(register.hitTestable(), findsNothing);
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(tester.element(name), same(originalName));
    expect(tester.widget<TextField>(name).controller!.text, 'pillar');
    expect(
      tester.widget<TextField>(producer).controller!.text,
      pillarAddress.toString(),
    );

    await tester.tap(detailsNext);
    await tester.pumpAndSettle();
    await tester.tap(sharingNext);
    await tester.pumpAndSettle();
    expect(register.hitTestable(), findsOneWidget);
    expect(name.hitTestable(), findsNothing);
    expect(slider.hitTestable(), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(requests, isEmpty);

    final Finder action = find.descendant(
      of: register,
      matching: find.byType(LoadingButton),
    );
    await tester.tap(action);
    await tester.pump();
    expect(requests, <DeployPillarEvent>[expected]);
    expect(tester.widget<LoadingButton>(action).onPressed, isNull);
  });
}
