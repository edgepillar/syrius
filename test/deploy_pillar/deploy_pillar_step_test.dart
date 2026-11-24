import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/registration_success/registration_success_surface.dart';
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
    final StreamController<FetchState<CreatePillarQsrInfoData>> qsrUpdates =
        StreamController<FetchState<CreatePillarQsrInfoData>>.broadcast();
    addTearDown(qsrUpdates.close);
    when(() => deploy.state).thenReturn(const DeployPillarInitial());
    whenListen(
      slotFee,
      qsrUpdates.stream,
      initialState: const FetchInitial<CreatePillarQsrInfoData>(),
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
    int exits = 0;
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
                onBackPressed: () => exits++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder deposited = find.text('Deposited');
    expect(deposited, findsNothing);
    for (final (String? address, int amount, bool visible)
        in <(String?, int, bool)>[
          (null, 100, false),
          (plasmaAddress.toString(), 100, false),
          (owner, 99, false),
          (owner, 100, true),
        ]) {
      qsrUpdates.add(
        FetchPopulated<CreatePillarQsrInfoData>(
          data: CreatePillarQsrInfoData(
            cost: BigInt.from(100),
            deposit: BigInt.from(amount),
            observedAddress: address,
          ),
        ),
      );
      await tester.pump();
      expect(deposited, visible ? findsOneWidget : findsNothing);
    }

    final Finder facts = find.byType(RegistrationFacts);
    final Finder amounts = find.descendant(
      of: facts,
      matching: find.byType(AmountText),
    );
    expect(amounts, findsNWidgets(3));
    expect(find.text('LOCKS'), findsOneWidget);
    final double valueStart = tester.getTopLeft(amounts.first).dx;
    for (int index = 1; index < 3; index++) {
      expect(tester.getTopLeft(amounts.at(index)).dx, closeTo(valueStart, .01));
    }

    final Finder deposit = find.text('Deposit QSR');
    final Finder details = find.text('Name and addresses');
    final Row depositRow = tester
        .element(deposit)
        .findAncestorWidgetOfExactType<Row>()!;
    final Row detailsRow = tester
        .element(details)
        .findAncestorWidgetOfExactType<Row>()!;
    for (final Row step in <Row>[depositRow, detailsRow]) {
      final Finder mark = find.byWidget(step.children.first);
      expect(tester.getSize(mark), const Size.square(22));
    }
    // The default test font may wrap a label. Measure the actual row gap.
    expect(
      tester.getTopLeft(find.byWidget(detailsRow)).dy -
          tester.getBottomLeft(find.byWidget(depositRow)).dy,
      closeTo(14, .01),
    );

    final Finder name = find.byKey(const Key('pillar_name_field'));
    final Finder nameValid = find.byKey(const Key('pillar_name_valid'));
    final Finder nameEditor = find.descendant(
      of: name,
      matching: find.byType(EditableText),
    );
    final AppTokens tokens = AppTokens.of(tester.element(nameEditor));
    final Finder producer = find.byKey(
      const Key('pillar_producer_address_field'),
    );
    final AppLocalizations l10n = AppLocalizations.of(tester.element(name))!;
    final Finder nameHelp = find.text(l10n.createPillarNameHelp);
    final Finder producerHelp = find.text(l10n.createPillarProducerHelp);
    final Finder producerPaste = find.descendant(
      of: producer,
      matching: find.byType(PasteContentButton),
    );
    final Finder producerClear = find.descendant(
      of: producer,
      matching: find.byType(ClearContentButton),
    );
    final Finder reward = find.byKey(const Key('pillar_reward_address_field'));
    final Finder ownerChip = find.byKey(const Key('pillar_use_owner_address'));
    final Finder rewardTools = find.descendant(
      of: reward,
      matching: find.byType(ClearContentButton),
    );
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
    final Finder back = find.widgetWithText(OutlinedButton, 'Back');
    final Element originalName = tester.element(name);
    expect(
      tester.getTopLeft(producer).dy,
      lessThan(tester.getTopLeft(reward).dy),
    );
    expect(register.hitTestable(), findsNothing);
    expect(slider.hitTestable(), findsNothing);
    expect(find.text('PRODUCER ADDRESS'), findsOneWidget);
    expect(find.text('REWARD ADDRESS'), findsOneWidget);
    expect(requests, isEmpty);
    expect(nameValid, findsNothing);
    expect(tester.widget<TextField>(name).decoration!.enabledBorder, isNull);
    for (final (Finder field, Finder caption) in <(Finder, Finder)>[
      (name, nameHelp),
      (producer, producerHelp),
    ]) {
      final Rect fieldRect = tester.getRect(field);
      final Rect captionRect = tester.getRect(caption);
      final TextStyle style = tester.widget<Text>(caption).style!;
      expect(captionRect.left, closeTo(fieldRect.left, .01));
      expect(captionRect.top - fieldRect.bottom, closeTo(6, .01));
      expect(style.fontSize, 12.5);
      expect(style.color, tokens.faint);
    }
    expect(
      tester.widget<TextField>(producer).decoration!.enabledBorder,
      isNull,
    );
    expect(
      InputDecorator.containerOf(tester.element(nameEditor))?.size.height,
      closeTo(tokens.fieldHeight, .01),
    );
    await tester.tap(back);
    expect(exits, 1);

    expect(tester.widget(ownerChip), isA<OutlinedButton>());
    expect(tester.getSize(ownerChip).height, closeTo(22, .01));
    expect(rewardTools, findsNothing);
    expect(producerClear, findsNothing);
    expect(producerPaste.hitTestable(), findsOneWidget);
    final Element originalProducerPaste = tester.element(producerPaste);
    await tester.tap(reward);
    await tester.pump();
    expect(rewardTools.hitTestable(), findsOneWidget);
    await tester.enterText(name, '?invalid');
    await tester.pump();
    expect(rewardTools, findsNothing);
    expect(nameValid, findsNothing);
    expect(tester.widget<TextField>(name).decoration!.errorText, isNotNull);
    expect(nameHelp, findsNothing);
    expect(tester.widget<TextField>(name).decoration!.enabledBorder, isNull);
    await tester.enterText(name, 'pillar');
    await tester.enterText(producer, owner);
    await tester.pump();
    expect(producerClear.hitTestable(), findsOneWidget);
    expect(nameValid, findsOneWidget);
    expect(nameHelp, findsOneWidget);
    expect(producerHelp, findsNothing);
    expect(
      InputDecorator.containerOf(tester.element(nameEditor))?.size.height,
      closeTo(tokens.fieldHeight, .01),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(sharingNext.hitTestable(), findsNothing);
    await tester.tap(producerClear);
    await tester.pump();
    expect(tester.widget<TextField>(producer).controller!.text, isEmpty);
    expect(producerClear, findsNothing);
    await tester.enterText(producer, pillarAddress.toString());
    await tester.enterText(reward, plasmaAddress.toString());
    await tester.pump();
    expect(producerClear, findsNothing);
    expect(tester.element(producerPaste), same(originalProducerPaste));
    await tester.tap(ownerChip);
    await tester.pump();
    expect(tester.widget<TextField>(reward).controller!.text, owner);
    for (final Finder field in <Finder>[name, producer, reward]) {
      expect(
        tester.widget<TextField>(field).decoration!.enabledBorder?.borderSide,
        BorderSide(color: tokens.faint),
      );
    }
    expect(tester.getSize(reward).height, closeTo(tokens.fieldHeight, .01));
    expect(
      tester.getTopLeft(detailsNext).dy - tester.getBottomLeft(reward).dy,
      closeTo(22, .01),
    );
    final OutlinedButton backButton = tester.widget(back);
    expect(
      backButton.style?.padding?.resolve(<WidgetState>{}),
      const EdgeInsets.symmetric(horizontal: 17),
    );

    await tester.tap(detailsNext);
    await tester.pumpAndSettle();
    expect(slider.hitTestable(), findsOneWidget);
    expect(register.hitTestable(), findsNothing);
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(exits, 1);
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
