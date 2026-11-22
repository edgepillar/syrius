import 'dart:ui' as ui show Image, Tristate;

import 'package:flutter/rendering.dart'
    show RenderRepaintBoundary, debugDisableShadows;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/home/widgets/amount_text.dart';
import 'package:zenon_syrius_wallet_flutter/seams/missing_services.dart';
import 'package:zenon_syrius_wallet_flutter/seams/seam.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/zts_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/modals/swap_action_surface.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dialogs.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/frosted_route.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

import '../helpers/mockup_symbol.dart';
import 'support.dart';

Widget _surface(
  TextEditingController amount, {
  bool visible = true,
  SwapDollarBuilder dollars = fixtureDollars,
  VoidCallback? onClose,
  bool Function()? onToggleDetails,
}) => SwapTransferSurface(
  title: 'Start swap',
  marker: const Key('fixture_transfer'),
  onClose: onClose ?? () {},
  send: SwapAmountPane(
    label: 'You send',
    token: kZnnCoin,
    controller: amount,
    visible: visible,
    balance: BigInt.from(120450000000),
    party: const Text('Address 2'),
    dollars: dollars,
    choices: <Token>[kZnnCoin, kQsrCoin],
    onChanged: (_) {},
    onToken: (_) {},
    onMax: () {},
  ),
  receive: SwapAmountPane(
    label: 'You receive',
    token: kQsrCoin,
    amount: BigInt.from(100000000000),
    visible: visible,
    dollars: dollars,
  ),
  counterparty: SwapIdentifier(fixtureAddress(3)),
  rate: SwapRate(
    fromAmount: BigInt.from(10000000000),
    fromToken: kZnnCoin,
    toAmount: BigInt.from(100000000000),
    toToken: kQsrCoin,
  ),
  timing: '8 h initial · 1 h counter',
  primary: SeamGate(
    seam: Seam.swapTerms,
    child: SwapPrimaryAction(
      label: 'Start swap',
      onPressed: () {},
      compact: true,
    ),
  ),
  detailsSummary: 'Fixture summary',
  onToggleDetails: onToggleDetails ?? () => true,
  details: OutlinedButton(
    key: const Key('fixture_deposit'),
    onPressed: () {},
    child: const Text('Create deposit'),
  ),
);

void main() {
  for (final bool light in <bool>[false, true]) {
    testWidgets(
      'the ${light ? 'light' : 'dark'} surface uses 480 pixels and exact data',
      (WidgetTester tester) async {
        prepareSwapViewport(tester);
        final TextEditingController amount = TextEditingController(text: '100');
        addTearDown(amount.dispose);
        int cancels = 0;
        bool current = true;
        const Key sceneKey = Key('swap_scene');
        await tester.pumpWidget(
          RepaintBoundary(
            key: sceneKey,
            child: swapHost(
              Builder(
                builder: (BuildContext context) => TextButton(
                  onPressed: () => showCustomDialog(
                    context: context,
                    clipContent: false,
                    frostWindowCaption: true,
                    content: _surface(
                      amount,
                      onClose: () => cancels++,
                      onToggleDetails: () => current,
                    ),
                  ),
                  child: const Text('Open fixture'),
                ),
              ),
              light: light,
            ),
          ),
        );
        final Finder dialog = find.byKey(const Key('fixture_transfer'));
        final bool originalShadows = debugDisableShadows;
        debugDisableShadows = false;
        try {
          await tester.tap(find.text('Open fixture'));
          await tester.pumpAndSettle();
          final Rect bounds = tester.getRect(dialog);
          final RenderRepaintBoundary scene = tester.renderObject(
            find.byKey(sceneKey),
          );
          final ({int near, int far})? samples = await tester.runAsync(
            () async {
              final ui.Image image = await scene.toImage();
              try {
                final ByteData bytes = (await image.toByteData())!;
                int redAt(double x, double y) => bytes.getUint8(
                  (y.round() * image.width + x.round()) * 4,
                );
                return (
                  near: redAt(bounds.right + 12, bounds.center.dy),
                  far: redAt(bounds.right + 180, bounds.center.dy),
                );
              } finally {
                image.dispose();
              }
            },
          );
          expect(samples, isNotNull);
          expect(samples!.near, lessThan(samples.far));
        } finally {
          debugDisableShadows = originalShadows;
        }
        final FrostedDialogRoute<Object?> route =
            ModalRoute.of<Object?>(
                  tester.element(dialog),
                )!
                as FrostedDialogRoute<Object?>;
        expect(route.frostWindowCaption, isTrue);
        expect(tester.getSize(dialog).width, 480);
        final BoxDecoration border =
            tester.widget<DecoratedBox>(dialog).decoration as BoxDecoration;
        expect(border.borderRadius, BorderRadius.circular(12));

        final Finder cancel = find.byKey(const Key('swap_action_cancel'));
        final Finder primary = find.widgetWithText(
          OutlinedButton,
          'Start swap',
        );
        expect(tester.getSize(cancel).height, 38);
        expect(tester.getSize(primary).height, 38);
        expect(tester.getSize(primary).width, lessThan(240));
        expect(tester.getCenter(cancel).dy, tester.getCenter(primary).dy);
        expect(
          tester.getTopRight(cancel).dx,
          lessThan(tester.getTopLeft(primary).dx),
        );
        final Finder formScroll = find.byKey(const Key('swap_action_scroll'));
        expect(
          tester.widget<SingleChildScrollView>(formScroll).padding,
          const EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 16),
        );
        final Rect form = tester.getRect(formScroll);
        expect(form.width, 478);
        expect(form.center.dx, tester.getCenter(dialog).dx);
        final Finder help = find.byKey(const Key('swap_action_details_toggle'));
        expect(tester.getBottomRight(help).dy, lessThan(form.top));
        expect(
          find.descendant(of: help, matching: find.text('How it works')),
          findsOneWidget,
        );
        expect(tester.getTopLeft(primary).dy, greaterThan(form.bottom));

        final Finder warning = find.byType(SwapNotice);
        final AppTokens tokens = AppTokens.of(tester.element(warning));
        expectMockupSymbol(
          tester,
          within: warning,
          symbol: 'warn',
          size: 14,
          color: tokens.warn,
        );
        expect(
          tester.widget<Text>(find.text('8 h initial · 1 h counter')).style,
          tokens.transferCaptionText,
        );
        expect(find.text('1 ZNN = 10 QSR'), findsOneWidget);
        expect(find.byKey(const Key('fixture_dollars')), findsNWidgets(2));
        final Finder editor = find.byKey(const Key('swap_amount_input'));
        final InputDecoration decoration = tester
            .widget<InputDecorator>(
              find.descendant(
                of: editor,
                matching: find.byType(InputDecorator),
              ),
            )
            .decoration;
        expect(decoration.enabledBorder, InputBorder.none);
        expect(decoration.disabledBorder, InputBorder.none);
        expect(decoration.focusedBorder, InputBorder.none);
        expect(decoration.isCollapsed, isTrue);
        final Rect editorRect = tester.getRect(editor);
        final Finder send = find.ancestor(
          of: editor,
          matching: find.byType(SwapAmountPane),
        );
        final Finder receive = find.byType(SwapAmountPane).last;
        for (final Finder pane in <Finder>[send, receive]) {
          final Container container = tester.widget(
            find.descendant(of: pane, matching: find.byType(Container)).first,
          );
          expect(
            (container.decoration! as BoxDecoration).borderRadius,
            BorderRadius.circular(12),
          );
        }
        final Finder arrow = find.byKey(const Key('swap_action_direction'));
        final Rect sendRect = tester.getRect(send);
        final Rect receiveRect = tester.getRect(receive);
        final Rect arrowRect = tester.getRect(arrow);
        expect(receiveRect.top - sendRect.bottom, closeTo(20, 0.01));
        expect(arrowRect.size, const Size.square(32));
        expect(arrowRect.center.dx, closeTo(receiveRect.center.dx, 0.01));
        expect(
          arrowRect.center.dy,
          closeTo((sendRect.bottom + receiveRect.top) / 2, 0.01),
        );
        expect(arrowRect.overlaps(sendRect), isTrue);
        expect(arrowRect.overlaps(receiveRect), isTrue);
        final Widget receivePane = tester.widget(receive);
        final Stack panesOverlay = tester.widget(
          find.ancestor(
            of: arrow,
            matching: find.byWidgetPredicate(
              (Widget widget) =>
                  widget is Stack && widget.children.contains(receivePane),
            ),
          ),
        );
        expect(panesOverlay.children.first, same(receivePane));
        expect(panesOverlay.children.last, isA<Positioned>());
        expectMockupSymbol(
          tester,
          within: arrow,
          symbol: 'swap',
          size: 14,
          color: AppTokens.of(tester.element(arrow)).foreground,
        );
        final Finder sendingDollars = find.descendant(
          of: send,
          matching: find.byKey(const Key('fixture_dollars')),
        );
        expect(tester.getTopLeft(sendingDollars).dx, editorRect.left);
        expect(tester.getTopLeft(sendingDollars).dy, editorRect.bottom);
        final Finder balance = find.descendant(
          of: send,
          matching: find.byWidgetPredicate(
            (Widget widget) => widget is AmountText && widget.symbol == 'ZNN',
          ),
        );
        expect(tester.getBottomRight(balance).dy, lessThan(editorRect.top));
        final Finder party = find.text('Address 2');
        final TextStyle partyStyle = DefaultTextStyle.of(
          tester.element(party),
        ).style;
        expect(partyStyle.fontFamily, tokens.monoFontFamily);
        expect(partyStyle.fontSize, 11);
        expect(partyStyle.letterSpacing, 0.66);
        expect(tester.widget<AmountText>(balance).style, tokens.ledgerText);
        final Finder token = find.widgetWithText(OutlinedButton, 'ZNN');
        expect(tester.getCenter(party).dy, tester.getCenter(balance).dy);
        expect(
          tester.getTopRight(party).dx,
          lessThan(tester.getTopLeft(balance).dx),
        );
        expect(
          tester.getTopRight(token).dx,
          closeTo(tester.getTopRight(balance).dx, 0.01),
        );
        expect(find.byKey(const Key('fixture_deposit')), findsNothing);
        expect(find.text('Fixture summary'), findsOneWidget);
        await tester.tap(help);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 241));
        expect(find.byKey(const Key('fixture_deposit')), findsOneWidget);
        await tester.tap(help);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 241));
        expect(find.byKey(const Key('fixture_deposit')), findsNothing);
        current = false;
        tester.widget<TextButton>(help).onPressed!();
        await tester.pump(const Duration(milliseconds: 241));
        expect(find.byKey(const Key('fixture_deposit')), findsNothing);
        await tester.tap(cancel);
        expect(cancels, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final bool light in <bool>[false, true]) {
    testWidgets(
      'token choice keeps 34 px and ownership in compact density, $light',
      (WidgetTester tester) async {
        prepareSwapViewport(tester);
        final TextEditingController amount = TextEditingController(
          text: '7.00000001',
        );
        addTearDown(amount.dispose);
        final ThemeData theme =
            (light ? AppTheme.lightTheme : AppTheme.darkTheme).copyWith(
              visualDensity: VisualDensity.compact,
            );
        final List<String> selected = <String>[];
        final String qsr = kQsrCoin.tokenStandard.toString();
        bool editable = true;
        bool current = true;

        Future<void> show({double scale = 1}) async {
          await tester.pumpWidget(
            swapHost(
              Theme(
                data: theme,
                child: SizedBox(
                  width: 480,
                  child: SwapAmountPane(
                    label: 'You send',
                    token: kZnnCoin,
                    visible: false,
                    controller: amount,
                    choices: <Token>[kZnnCoin, kQsrCoin],
                    onChanged: editable ? (String _) {} : null,
                    onToken: editable ? selected.add : null,
                    canInteract: () => current,
                    dollars: fixtureDollars,
                  ),
                ),
              ),
              light: light,
              scale: scale,
            ),
          );
          await tester.pump();
        }

        final Finder button = find.descendant(
          of: find.byType(SwapChoice),
          matching: find.byType(OutlinedButton),
        );
        final Finder qsrItem = find.widgetWithText(MenuItemButton, 'QSR');
        await show();
        expect(
          Theme.of(tester.element(button)).visualDensity,
          VisualDensity.compact,
        );
        expect(tester.getSize(button).height, 34);
        final AppTokens tokens = AppTokens.of(tester.element(button));
        final ButtonStyle style = tester.widget<OutlinedButton>(button).style!;
        expect(style.backgroundColor!.resolve(<WidgetState>{}), tokens.card2);
        expect(
          style.backgroundColor!.resolve(<WidgetState>{WidgetState.disabled}),
          tokens.card2,
        );
        expect(style.side!.resolve(<WidgetState>{})!.color, tokens.faint);
        expectMockupSymbol(
          tester,
          within: button,
          symbol: 'chev',
          size: 12,
          color: tokens.faint,
        );
        expect(
          tester
              .widget<Text>(
                find.descendant(of: button, matching: find.text('ZNN')),
              )
              .style,
          tokens.bodyText,
        );
        expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
        await tester.tap(button);
        await tester.pump();
        expect(qsrItem, findsOneWidget);
        final VoidCallback retained = tester
            .widget<MenuItemButton>(qsrItem)
            .onPressed!;
        await tester.tap(qsrItem);
        await tester.pump(const Duration(milliseconds: 241));
        expect(selected, <String>[qsr]);
        expect(amount.text, '7.00000001');

        await tester.tap(button);
        await tester.pump();
        current = false;
        await tester.tap(qsrItem);
        await tester.pump(const Duration(milliseconds: 241));
        retained();
        await tester.tap(button);
        await tester.pump();
        expect(selected, <String>[qsr]);
        expect(find.byType(MenuItemButton), findsNothing);

        editable = false;
        await show();
        expect(tester.getSize(button).height, 34);
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        await tester.tap(button, warnIfMissed: false);
        await tester.pump();
        expect(find.byType(MenuItemButton), findsNothing);
        expect(selected, <String>[qsr]);

        current = true;
        editable = true;
        await show(scale: 2);
        final Rect bounds = tester.getRect(button);
        final Rect label = tester.getRect(
          find.descendant(of: button, matching: find.text('ZNN')),
        );
        expect(bounds.height, greaterThan(34));
        expect(label.top, greaterThanOrEqualTo(bounds.top));
        expect(label.bottom, lessThanOrEqualTo(bounds.bottom));
        editable = false;
        await show(scale: 2);
        expect(tester.getSize(button).height, greaterThan(34));
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        expect(amount.text, '7.00000001');
        expect(selected, <String>[qsr]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('scaled narrow RTL remains scrollable without overflowing', (
    WidgetTester tester,
  ) async {
    const Size size = Size(360, 620);
    prepareSwapViewport(tester, size: size);
    final TextEditingController amount = TextEditingController(
      text: '9007199254740993.12345678',
    );
    addTearDown(amount.dispose);
    await tester.pumpWidget(
      swapHost(_surface(amount), rtl: true, scale: 2.5, size: size),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('swap_action_scroll')), findsOneWidget);
    final TextField field = tester.widget<TextField>(
      find.byKey(const Key('swap_amount_input')),
    );
    expect(field.textDirection, TextDirection.ltr);
    await tester.drag(
      find.byKey(const Key('swap_action_scroll')),
      const Offset(0, -400),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('hidden or ticker-muted panes never construct dollar art', (
    WidgetTester tester,
  ) async {
    prepareSwapViewport(tester);
    final TextEditingController amount = TextEditingController(text: '100');
    addTearDown(amount.dispose);
    int constructed = 0;
    Widget dollars(BuildContext context, BigInt value, Token token) {
      constructed++;
      return const Text('Finite dollars');
    }

    await tester.pumpWidget(
      swapHost(_surface(amount, visible: false, dollars: dollars)),
    );
    expect(constructed, 0);
    await tester.pumpWidget(
      swapHost(_surface(amount, dollars: dollars), enabled: false),
    );
    expect(constructed, 0);
    await tester.pumpWidget(swapHost(_surface(amount, dollars: dollars)));
    expect(constructed, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'the offer gate denies pointer, keyboard and semantic activation',
    (WidgetTester tester) async {
      prepareSwapViewport(tester);
      final SemanticsHandle semantics = tester.ensureSemantics();
      try {
        int calls = 0;
        await tester.pumpWidget(
          swapHost(
            SeamGate(
              key: const Key('fixture_gate'),
              seam: Seam.swapTerms,
              child: SwapPrimaryAction(
                label: 'Start swap',
                onPressed: () => calls++,
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('fixture_gate')));
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(calls, 0);
        final SemanticsNode node = tester.getSemantics(
          find.byKey(const Key('fixture_gate')),
        );
        expect(node.flagsCollection.isEnabled, isNot(ui.Tristate.none));
        expect(node.flagsCollection.isEnabled, ui.Tristate.isFalse);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
      }
    },
  );

  test(
    'the direct offer service refuses before any UI or wallet work',
    () async {
      await expectLater(
        const UnbuiltSwapTermsService().start(),
        throwsA(
          isA<SeamNotBuilt>().having(
            (SeamNotBuilt value) => value.seam,
            'seam',
            Seam.swapTerms,
          ),
        ),
      );
    },
  );

  testWidgets(
    'Details keeps its full clock when OS animation effects are disabled',
    (WidgetTester tester) async {
      prepareSwapViewport(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(
        swapHost(
          SwapActionDetails(
            summary: 'Fixture',
            onToggle: () => true,
            child: const Text('Fixture details', key: Key('fixture_details')),
          ),
        ),
      );
      expect(find.byKey(const Key('fixture_details')), findsNothing);
      await tester.tap(find.byKey(const Key('swap_action_details_toggle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final SizeTransition transition = tester.widget<SizeTransition>(
        find.byType(SizeTransition),
      );
      expect(transition.sizeFactor.value, greaterThan(0));
      expect(transition.sizeFactor.value, lessThan(1));
      await tester.pump(const Duration(milliseconds: 121));
      expect(
        tester
            .widget<SizeTransition>(find.byType(SizeTransition))
            .sizeFactor
            .value,
        1,
      );
      await tester.tap(find.byKey(const Key('swap_action_details_toggle')));
      await tester.pump();
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .descendant(
                    of: find.byType(SwapActionDetails),
                    matching: find.byType(IgnorePointer),
                  )
                  .first,
            )
            .ignoring,
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 241));
      expect(find.byKey(const Key('fixture_details')), findsNothing);
    },
  );

  testWidgets('a stale Details toggle cannot reveal its actions', (
    WidgetTester tester,
  ) async {
    prepareSwapViewport(tester);
    bool current = true;
    await tester.pumpWidget(
      swapHost(
        SwapActionDetails(
          summary: 'Fixture',
          onToggle: () => current,
          child: const Text('Fixture details'),
        ),
      ),
    );
    final VoidCallback saved = tester
        .widget<OutlinedButton>(
          find.byKey(const Key('swap_action_details_toggle')),
        )
        .onPressed!;
    current = false;
    saved();
    await tester.pump(const Duration(milliseconds: 241));
    expect(find.text('Fixture details'), findsNothing);
  });

  testWidgets(
    'Tab and Enter reach a real close action without entering the offer',
    (WidgetTester tester) async {
      prepareSwapViewport(tester);
      int closed = 0;
      await tester.pumpWidget(
        swapHost(
          SwapDialogSurface(
            title: 'Fixture',
            marker: const Key('fixture'),
            onClose: () => closed++,
            primary: SeamGate(
              seam: Seam.swapTerms,
              child: SwapPrimaryAction(label: 'Start swap', onPressed: () {}),
            ),
            child: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(closed, 1);
    },
  );

  testWidgets('semantic errors use crimson rather than the reserved accent', (
    WidgetTester tester,
  ) async {
    prepareSwapViewport(tester);
    await tester.pumpWidget(
      swapHost(const SwapNotice('Synthetic refusal', error: true)),
    );
    final BuildContext context = tester.element(find.byType(SwapNotice));
    final Icon icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.color, AppTokens.of(context).error);
    expect(icon.color, isNot(AppTokens.of(context).pink));
  });
}
