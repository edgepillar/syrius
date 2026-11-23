import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/model/new_token_data.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/create_token_stepper/create_token_stepper.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/create_token_stepper/widgets/token_create_frame.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/registration_success/registration_success_surface.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/token_favorite/token_favorite.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/custom_slider.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

import '../helpers/mockup_symbol.dart';
import 'support.dart';

class _IssueBloc extends MockBloc<IssueTokenEvent, IssueTokenState>
    implements IssueTokenBloc {}

class _Favorites extends Mock implements FavoriteTokensRepository {}

/// Positive, finite widget clocks include the exact shared-axis endpoint.
Future<void> _clock(WidgetTester tester, {int frames = 8}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Widget _host(
  Widget child, {
  bool light = false,
  TextDirection direction = TextDirection.ltr,
  double scale = 1,
}) => MaterialApp(
  theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: Directionality(textDirection: direction, child: child!),
  ),
  home: Scaffold(body: child),
);

Finder _field(String key, {bool offstage = false}) =>
    find.byKey(Key(key), skipOffstage: !offstage);

Finder _frame(String key, {bool offstage = false}) =>
    find.byKey(Key('token_create_$key'), skipOffstage: !offstage);

Finder _action(String step) => find.descendant(
  of: _frame(step),
  matching: find.byType(OutlinedButton),
);

bool _active(WidgetTester tester, String name) => tester
    .widget<TokenCreateFrame>(
      _frame(name, offstage: true),
    )
    .active;

Future<void> _details(WidgetTester tester) async {
  await tester.enterText(_field('token_name_field'), 'MoonTokens');
  await tester.enterText(_field('token_symbol_field'), 'MOON');
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> _supply(WidgetTester tester, {String total = '10'}) async {
  await _details(tester);
  await tester.tap(_action('details'));
  await _clock(tester);
  expect(_active(tester, 'supply'), isTrue);
  await tester.enterText(_field('token_total_supply_field'), total);
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> _options(WidgetTester tester) async {
  await _supply(tester);
  await tester.tap(_action('supply'));
  await _clock(tester);
  expect(_active(tester, 'options'), isTrue);
}

Future<void> _issue(WidgetTester tester) async {
  await _options(tester);
  await tester.tap(_action('options'));
  await _clock(tester);
  expect(_active(tester, 'issue'), isTrue);
}

void _viewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  for (final bool light in <bool>[false, true]) {
    testWidgets('option events retain earlier choices in theme $light', (
      WidgetTester tester,
    ) async {
      _viewport(tester, const Size(1100, 650));
      final TokenCreateFixture fixture = TokenCreateFixture();
      final List<NewTokenData> submissions = <NewTokenData>[];
      try {
        await tester.pumpWidget(_host(
          CreateTokenStepperView(
            preflight: fixture.preflight,
            onIssue: submissions.add,
          ),
          light: light,
        ));
        await _clock(tester);
        final AppTokens tokens = AppTokens.of(tester.element(_frame('rail')));
        final Finder badge = _frame('preview_badge');
        expect(_frame('retry'), findsNothing);
        final Finder firstMark = find.descendant(
          of: _frame('step_0'),
          matching: find.byType(Container),
        );
        BoxDecoration firstDecoration() =>
            tester.widget<Container>(firstMark).decoration! as BoxDecoration;
        expect(firstDecoration().color, Colors.transparent);
        expect((firstDecoration().border! as Border).top.color, tokens.znn);
        expect(
          find.descendant(
            of: badge,
            matching: find.byIcon(Icons.token_outlined),
          ),
          findsOneWidget,
        );
        await _options(tester);
        expect(firstDecoration().color, tokens.znn);
        expect(
          find.descendant(of: badge, matching: find.text('M')),
          findsOneWidget,
        );
        expect(tester.getSize(badge), const Size.square(26));
        expect(
          (tester.widget<Container>(badge).decoration! as BoxDecoration).color,
          tokens.pink,
        );
        final ValueChanged<bool?> mint = tester
            .widget<Checkbox>(_field('token_mintable_checkbox')).onChanged!;
        final ValueChanged<bool?> burn = tester
            .widget<Checkbox>(_field('token_burnable_checkbox')).onChanged!;
        final ValueChanged<bool?> utility = tester
            .widget<Checkbox>(_field('token_utility_checkbox')).onChanged!;
        // All callbacks come from one rendered frame, in both event orders.
        if (light) {
          utility(false);
          burn(true);
          mint(true);
        } else {
          mint(true);
          burn(true);
          utility(false);
        }
        await tester.pump();
        expect(tester.widget<Checkbox>(
          _field('token_mintable_checkbox'),
        ).value, isTrue);
        expect(tester.widget<Checkbox>(
          _field('token_burnable_checkbox'),
        ).value, isTrue);
        expect(tester.widget<Checkbox>(
          _field('token_utility_checkbox'),
        ).value, isFalse);
        expect(find.text('Review supply'), findsOneWidget);
        await tester.tap(_action('options'));
        await _clock(tester);
        expect(_active(tester, 'supply'), isTrue);
        // Retained callbacks cannot alter an inactive Options step.
        mint(false);
        burn(false);
        utility(true);
        await tester.enterText(_field('token_max_supply_field'), '20');
        await tester.pump();
        await tester.tap(_action('supply'));
        await _clock(tester);
        await tester.tap(_action('options'));
        await _clock(tester);
        expect(_active(tester, 'issue'), isTrue);
        await tester.tap(_action('issue'));
        await _clock(tester);
        expect(submissions, hasLength(1));
        expect(submissions.single.isMintable, isTrue);
        expect(submissions.single.isBurnable, isTrue);
        expect(submissions.single.isUtility, isFalse);
        expect(submissions.single.totalSupply, BigInt.from(10));
        expect(submissions.single.maxSupply, BigInt.from(20));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      }
    });
  }

  for (final bool light in <bool>[false, true]) {
    for (final TextDirection direction in TextDirection.values) {
      for (final double scale in <double>[1, 1.6]) {
        testWidgets(
          'four-step geometry in theme $light, $direction, scale $scale',
          (WidgetTester tester) async {
            _viewport(tester, const Size(1100, 380));
            final TokenCreateFixture fixture = TokenCreateFixture();
            try {
              await tester.pumpWidget(
                _host(
                  CreateTokenStepperView(
                    preflight: fixture.preflight,
                    onIssue: (_) {},
                  ),
                  light: light,
                  direction: direction,
                  scale: scale,
                ),
              );
              await _clock(tester);
              for (int i = 0; i < 4; i++) {
                expect(find.byKey(Key('token_create_step_$i')), findsOneWidget);
              }
              expect(find.text('Plasma Check'), findsNothing);
              expect(
                tester
                    .getSize(find.byKey(const Key('token_create_rail')))
                    .width,
                300,
              );
              expect(tester.takeException(), isNull);
              await _options(tester);
              expect(_active(tester, 'options'), isTrue);
              expect(tester.takeException(), isNull);
              final Rect action = tester.getRect(_action('options'));
              expect(action.bottom, lessThanOrEqualTo(380));
              expect(action.top, greaterThanOrEqualTo(0));
            } finally {
              await tester.pumpWidget(const SizedBox.shrink());
              await _clock(tester, frames: 2);
              fixture.dispose();
            }
            expect(tester.binding.transientCallbackCount, 0);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets(
    'first Continue needs valid details and fresh sufficient facts, '
    'including a blank domain',
    (WidgetTester tester) async {
      _viewport(tester, const Size(1100, 650));
      final TokenCreateFixture fixture = TokenCreateFixture();
      final Completer<AccountInfo> pending = Completer<AccountInfo>();
      fixture.accountRead = () => pending.future;
      try {
        await tester.pumpWidget(
          _host(
            CreateTokenStepperView(
              preflight: fixture.preflight,
              onIssue: (_) {},
            ),
          ),
        );
        await _clock(tester);
        await _details(tester);
        expect(
          tester.widget<OutlinedButton>(_action('details')).onPressed,
          isNull,
        );
        expect(fixture.preflight.znn, isNull);
        final Finder refresh = _frame('retry');
        expect(tester.widget<TextButton>(refresh).onPressed, isNull);
        expect(
          tester.getBottomLeft(_frame('preview_badge')).dy,
          lessThan(tester.getTopLeft(refresh).dy),
        );
        pending.complete(tokenCreateAccount());
        await _clock(tester);
        expect(refresh, findsNothing);
        expect(
          tester.widget<OutlinedButton>(_action('details')).onPressed,
          isNotNull,
        );
        expect(
          tester
              .widget<TextField>(_field('token_domain_field'))
              .controller!
              .text,
          isEmpty,
        );
        fixture.accountRead = null;
        await tester.tap(_action('details'));
        await _clock(tester);
        expect(_active(tester, 'supply'), isTrue);
        expect(fixture.accountReads, 2);
        expect(fixture.plasmaReads, 2);
      } finally {
        if (!pending.isCompleted) pending.complete(tokenCreateAccount());
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      }
    },
  );

  testWidgets(
    'name fields traverse with Tab and Shift-Tab, Enter advances once',
    (WidgetTester tester) async {
      _viewport(tester, const Size(1100, 650));
      final TokenCreateFixture fixture = TokenCreateFixture();
      try {
        await tester.pumpWidget(
          _host(
            CreateTokenStepperView(
              preflight: fixture.preflight,
              onIssue: (_) {},
            ),
          ),
        );
        await _clock(tester);
        final Finder symbol = _field('token_symbol_field');
        for (final String key in <String>[
          'token_name_field',
          'token_symbol_field',
          'token_domain_field',
        ]) {
          final Finder field = _field(key);
          final Finder editor = find.descendant(
            of: field, matching: find.byType(EditableText),
          );
          final double minHeight =
              AppTokens.of(tester.element(field)).fieldHeight;
          final double? paintedHeight =
              InputDecorator.containerOf(tester.element(editor))?.size.height;
          expect(paintedHeight, greaterThanOrEqualTo(minHeight - 0.01));
        }
        InputDecoration symbolDecoration() =>
            tester.widget<TextField>(symbol).decoration!;
        expect(symbolDecoration().suffixIcon, isNull);
        expect(symbolDecoration().enabledBorder, isNull);
        final AppTokens tokens = AppTokens.of(tester.element(symbol));
        final Finder note = find.text(
          AppLocalizations.of(tester.element(symbol))!.tokenCreateDomainNote,
        );
        expect(
          tester.getTopLeft(_action('details')).dy -
              tester.getBottomLeft(note).dy,
          closeTo(tokens.registrationActionGap + tokens.inlineGap, 0.01),
        );
        await tester.enterText(symbol, '!');
        await tester.pump();
        expect(symbolDecoration().errorText, isNotNull);
        expect(symbolDecoration().suffixIcon, isNull);
        await _details(tester);
        expect(symbolDecoration().errorText, isNull);
        for (final String key in <String>[
          'token_name_field', 'token_symbol_field',
        ]) {
          final InputDecoration decoration =
              tester.widget<TextField>(_field(key)).decoration!;
          expect(decoration.enabledBorder?.borderSide.color, tokens.faint);
        }
        expect(tester.widget<TextField>(_field('token_domain_field'))
            .decoration?.enabledBorder, isNull);
        expectMockupSymbol(
          tester,
          within: symbol,
          symbol: 'check',
          size: 14,
          color: AppTokens.of(tester.element(symbol)).znnInk,
        );
        await tester.tap(_field('token_name_field'));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump(const Duration(milliseconds: 1));
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: _field('token_symbol_field'),
                  matching: find.byType(EditableText),
                ),
              )
              .focusNode
              .hasFocus,
          isTrue,
        );
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump(const Duration(milliseconds: 1));
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: _field('token_name_field'),
                  matching: find.byType(EditableText),
                ),
              )
              .focusNode
              .hasFocus,
          isTrue,
        );
        // A valid retained Supply makes a leaked repeated Enter observable.
        tester
                .widget<TextField>(
                  _field('token_total_supply_field', offstage: true),
                )
                .controller!
                .text =
            '10';
        await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
        await _clock(tester);
        expect(_active(tester, 'supply'), isTrue);
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
        await _clock(tester, frames: 2);
        expect(_active(tester, 'supply'), isTrue);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await _clock(tester);
        expect(_active(tester, 'options'), isTrue);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      }
    },
  );

  testWidgets(
    'mintable options redirect to Supply '
    'and retain the exact slider and controllers',
    (WidgetTester tester) async {
      _viewport(tester, const Size(1100, 650));
      final TokenCreateFixture fixture = TokenCreateFixture();
      final List<NewTokenData> submissions = <NewTokenData>[];
      try {
        await tester.pumpWidget(
          _host(
            CreateTokenStepperView(
              preflight: fixture.preflight,
              onIssue: submissions.add,
            ),
          ),
        );
        await _clock(tester);
        await _supply(tester);
        final TextEditingController original = tester
            .widget<TextField>(
              _field('token_total_supply_field'),
            )
            .controller!;
        final State slider = tester.state(
          find.byType(CustomSlider, skipOffstage: false),
        );
        tester.widget<Slider>(_field('token_decimals_slider')).onChanged!(8);
        await tester.enterText(
          _field('token_total_supply_field'),
          '9007199254740993.00000001',
        );
        await tester.pump(const Duration(milliseconds: 1));
        await tester.tap(_action('supply'));
        await _clock(tester);
        await tester.tap(_field('token_mintable_checkbox'));
        await tester.pump(const Duration(milliseconds: 1));
        expect(find.text('Review supply'), findsOneWidget);
        await tester.tap(_action('options'));
        await _clock(tester);
        expect(_active(tester, 'supply'), isTrue);
        expect(
          tester.state(find.byType(CustomSlider, skipOffstage: false)),
          same(slider),
        );
        expect(
          tester
              .widget<TextField>(_field('token_total_supply_field'))
              .controller,
          same(original),
        );
        expect(tester.widget<Slider>(_field('token_decimals_slider')).value, 8);
        await tester.enterText(
          _field('token_max_supply_field'),
          '9007199254740994.00000001',
        );
        await tester.pump();
        expect(
          tester.widget<OutlinedButton>(_action('supply')).onPressed,
          isNotNull,
        );
        await tester.tap(_action('supply'));
        await _clock(tester);
        await tester.tap(_action('options'));
        await _clock(tester);
        await tester.tap(_action('issue'));
        await _clock(tester);
        expect(submissions, hasLength(1));
        expect(
          submissions.single.totalSupply,
          BigInt.parse('900719925474099300000001'),
        );
        expect(
          submissions.single.maxSupply,
          BigInt.parse('900719925474099400000001'),
        );
        expect(submissions.single.isMintable, isTrue);
        expect(submissions.single.tokenDomain, isEmpty);
        expect(fixture.accountReads, 3);
        expect(fixture.plasmaReads, 3);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      }
    },
  );

  testWidgets(
    'Issue reads again and refuses insufficient Plasma '
    'without a presentation callback',
    (WidgetTester tester) async {
      _viewport(tester, const Size(1100, 650));
      final TokenCreateFixture fixture = TokenCreateFixture();
      int submissions = 0;
      try {
        await tester.pumpWidget(
          _host(
            CreateTokenStepperView(
              preflight: fixture.preflight,
              onIssue: (_) => submissions++,
            ),
          ),
        );
        await _clock(tester);
        await _issue(tester);
        fixture.plasma = tokenCreatePlasma(0);
        await tester.tap(_action('issue'));
        await _clock(tester);
        expect(submissions, 0);
        expect(_active(tester, 'issue'), isTrue);
        expect(fixture.plasmaReads, 3);
        final Finder refresh = _frame('retry');
        expect(tester.widget<TextButton>(refresh).onPressed, isNotNull);
        fixture.plasma = tokenCreatePlasma();
        await tester.tap(_action('issue'));
        await _clock(tester);
        expect(submissions, 1);
        expect(fixture.plasmaReads, 4);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      }
    },
  );

  testWidgets(
    'authority departure while Issue reads cannot call a stale presentation',
    (WidgetTester tester) async {
      _viewport(tester, const Size(1100, 650));
      final TokenCreateFixture fixture = TokenCreateFixture();
      final Completer<AccountInfo> pending = Completer<AccountInfo>();
      int submissions = 0;
      try {
        await tester.pumpWidget(
          _host(
            CreateTokenStepperView(
              preflight: fixture.preflight,
              onIssue: (_) => submissions++,
            ),
          ),
        );
        await _clock(tester);
        await _issue(tester);
        fixture.accountRead = () => pending.future;
        await tester.tap(_action('issue'));
        await tester.pump(const Duration(milliseconds: 1));
        fixture.revoke();
        pending.complete(tokenCreateAccount());
        await _clock(tester);
        expect(submissions, 0);
        expect(fixture.preflight.znn, isNull);
        expect(fixture.preflight.plasma, isNull);
        expect(tester.takeException(), isNull);
      } finally {
        if (!pending.isCompleted) pending.complete(tokenCreateAccount());
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      }
    },
  );

  testWidgets(
    'an Issue read cannot submit while the original pane is covered',
    (WidgetTester tester) async {
      _viewport(tester, const Size(1100, 650));
      final TokenCreateFixture fixture = TokenCreateFixture();
      final Completer<AccountInfo> pending = Completer<AccountInfo>();
      bool visible = true;
      int submissions = 0;
      try {
        await tester.pumpWidget(
          _host(
            CreateTokenStepperView(
              preflight: fixture.preflight,
              isPresentationCurrent: () => visible,
              onIssue: (_) => submissions++,
            ),
          ),
        );
        await _clock(tester);
        await _issue(tester);
        fixture.accountRead = () => pending.future;
        await tester.tap(_action('issue'));
        await tester.pump(const Duration(milliseconds: 1));
        expect(fixture.accountReads, 3);
        visible = false;
        pending.complete(tokenCreateAccount());
        await _clock(tester);
        expect(fixture.preflight.sufficient, isTrue);
        expect(submissions, 0);
        visible = true;
        fixture.accountRead = null;
        await tester.tap(_action('issue'));
        await _clock(tester);
        expect(fixture.accountReads, 4);
        expect(submissions, 1);
        expect(tester.takeException(), isNull);
      } finally {
        if (!pending.isCompleted) pending.complete(tokenCreateAccount());
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      }
    },
  );

  testWidgets(
    'disposing a deferred Issue revokes dispatch and never calls presentation',
    (WidgetTester tester) async {
      _viewport(tester, const Size(1100, 650));
      final TokenCreateFixture fixture = TokenCreateFixture();
      final Completer<AccountInfo> pending = Completer<AccountInfo>();
      int submissions = 0;
      try {
        await tester.pumpWidget(
          _host(
            CreateTokenStepperView(
              preflight: fixture.preflight,
              onIssue: (_) => submissions++,
            ),
          ),
        );
        await _clock(tester);
        await _issue(tester);
        fixture.accountRead = () => pending.future;
        await tester.tap(_action('issue'));
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
        pending.complete(tokenCreateAccount());
        await _clock(tester);
        expect(submissions, 0);
        expect(fixture.preflight.sufficient, isFalse);
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      } finally {
        if (!pending.isCompleted) pending.complete(tokenCreateAccount());
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      }
    },
  );

  testWidgets(
    'one genuine issue listener survives Back, refresh and the receipt',
    (WidgetTester tester) async {
      _viewport(tester, const Size(1100, 650));
      final TokenCreateFixture fixture = TokenCreateFixture();
      final _IssueBloc bloc = _IssueBloc();
      final _Favorites favorites = _Favorites();
      int listens = 0;
      int cancellations = 0;
      final StreamController<IssueTokenState> states =
          StreamController<IssueTokenState>.broadcast(
            onListen: () => listens++,
            onCancel: () => cancellations++,
          );
      when(() => bloc.state).thenReturn(const IssueTokenInitial());
      when(() => bloc.stream).thenAnswer((_) => states.stream);
      when(() => favorites.add(znnZts)).thenAnswer((_) async {});
      try {
        await tester.pumpWidget(
          RepositoryProvider<FavoriteTokensRepository>.value(
            value: favorites,
            child: BlocProvider<IssueTokenBloc>.value(
              value: bloc,
              child: _host(
                CreateTokenStepperView(
                  preflight: fixture.preflight,
                  receipt: const Center(child: Text('Original receipt')),
                ),
              ),
            ),
          ),
        );
        await _clock(tester);
        expect(listens, 1);
        final State original = tester.state(
          find.byType(CreateTokenStepperView),
        );
        await _issue(tester);
        await tester.tap(
          find.descendant(
            of: _frame('issue'),
            matching: find.byType(TextButton),
          ),
        );
        await _clock(tester);
        expect(_active(tester, 'options'), isTrue);
        await fixture.preflight.refresh();
        await tester.pump(const Duration(milliseconds: 1));
        expect(listens, 1);
        await tester.tap(_action('options'));
        await _clock(tester);
        await tester.tap(_action('issue'));
        await _clock(tester);
        final AccountBlockTemplate accepted =
            AccountBlockTemplate(blockType: BlockTypeEnum.userSend.index)
              ..address = emptyAddress
              ..chainIdentifier = 321
              ..hash = Hash.parse(List<String>.filled(64, '8').join());
        states.add(
          IssueTokenDone(accountBlock: accepted, newTokenStandard: znnZts),
        );
        await _clock(tester);
        expect(find.text('Original receipt'), findsOneWidget);
        expect(
          tester.state(find.byType(CreateTokenStepperView)),
          same(original),
        );
        expect(listens, 1);
        expect(cancellations, 0);
        verify(() => favorites.add(znnZts)).called(1);
        states.add(
          IssueTokenDone(accountBlock: accepted, newTokenStandard: znnZts),
        );
        await _clock(tester, frames: 2);
        verifyNever(() => favorites.add(znnZts));
        await tester.pumpWidget(const SizedBox.shrink());
        expect(cancellations, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await states.close();
        await bloc.close();
        fixture.dispose();
      }
    },
  );

  testWidgets(
    'Continue accepts only an empty field or a valid token domain',
    (WidgetTester tester) async {
      _viewport(tester, const Size(1100, 650));
      final TokenCreateFixture fixture = TokenCreateFixture();
      try {
        await tester.pumpWidget(
          _host(
            CreateTokenStepperView(
              preflight: fixture.preflight,
              onIssue: (_) {},
            ),
          ),
        );
        await _clock(tester);
        await _details(tester);
        final Finder domain = _field('token_domain_field');
        for (final String invalid in <String>[
          'bad domain',
          'https://example.invalid',
          'example.invalid/path',
          '${'a' * 63}.${'b' * 61}.com',
        ]) {
          await tester.enterText(domain, invalid);
          await tester.pump(const Duration(milliseconds: 1));
          expect(
            tester.widget<OutlinedButton>(_action('details')).onPressed,
            isNull,
            reason: invalid,
          );
        }
        for (final String valid in <String>['sub.example.invalid', '']) {
          await tester.enterText(domain, valid);
          await tester.pump(const Duration(milliseconds: 1));
          expect(
            tester.widget<OutlinedButton>(_action('details')).onPressed,
            isNotNull,
            reason: valid,
          );
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      }
    },
  );

  testWidgets(
    'the waiting receipt rail retains exactly the four submitted stages',
    (WidgetTester tester) async {
      _viewport(tester, const Size(1100, 650));
      int another = 0;
      try {
        await tester.pumpWidget(
          _host(
            TokenCreatedSuccess(
              onCreateAnotherTokenPressed: () => another++,
              onViewTokensPressed: () {},
            ),
          ),
        );
        await _clock(tester);
        final RegistrationSuccessSurface receipt = tester
            .widget<RegistrationSuccessSurface>(
              find.byType(RegistrationSuccessSurface),
            );
        expect(receipt.steps, <String>[
          'Name and symbol',
          'Supply',
          'Options',
          'Issue',
        ]);
        expect(find.byKey(const Key('registration_waiting')), findsOneWidget);
        expect(find.byKey(const Key('registration_another')), findsNothing);
        expect(another, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'an uncertain original failure retains fields '
    'and refuses a stale Issue callback',
    (WidgetTester tester) async {
      _viewport(tester, const Size(1100, 650));
      final TokenCreateFixture fixture = TokenCreateFixture();
      final StateError originalFailure = StateError(
        'Original uncertain attempt',
      );
      final List<NewTokenData> submitted = <NewTokenData>[];
      Object? retainedFailure;
      bool canStart = true;
      bool uncertain = false;
      try {
        await tester.pumpWidget(
          _host(
            CreateTokenStepperView(
              preflight: fixture.preflight,
              canStartIssue: () => canStart,
              isIssueUncertain: () => uncertain,
              onIssue: (NewTokenData draft) {
                submitted.add(draft);
                retainedFailure = originalFailure;
                canStart = false;
                uncertain = true;
                throw originalFailure;
              },
            ),
          ),
        );
        await _clock(tester);
        await _issue(tester);
        final VoidCallback staleIssue = tester
            .widget<TokenCreateFrame>(_frame('issue'))
            .onSubmit!;
        final TextEditingController name = tester
            .widget<TextField>(
              _field('token_name_field', offstage: true),
            )
            .controller!;
        final TextEditingController supply = tester
            .widget<TextField>(
              _field('token_total_supply_field', offstage: true),
            )
            .controller!;
        await tester.tap(_action('issue'));
        await _clock(tester);
        expect(retainedFailure, same(originalFailure));
        expect(submitted, hasLength(1));
        expect(submitted.single.tokenName, 'MoonTokens');
        expect(submitted.single.tokenSymbol, 'MOON');
        expect(submitted.single.totalSupply.toString(), '10');
        expect(
          tester.widget<OutlinedButton>(_action('issue')).onPressed,
          isNull,
        );
        expect(find.text('Unknown'), findsOneWidget);
        expect(name.text, 'MoonTokens');
        expect(supply.text, '10');
        final int accountReads = fixture.accountReads;
        final int plasmaReads = fixture.plasmaReads;
        staleIssue();
        await _clock(tester);
        expect(submitted, hasLength(1));
        expect(retainedFailure, same(originalFailure));
        expect(fixture.accountReads, accountReads);
        expect(fixture.plasmaReads, plasmaReads);
        expect(
          tester
              .widget<TextField>(_field('token_name_field', offstage: true))
              .controller,
          same(name),
        );
        expect(
          tester
              .widget<TextField>(
                _field('token_total_supply_field', offstage: true),
              )
              .controller,
          same(supply),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      }
    },
  );

  testWidgets(
    'a whitespace name refuses Continue and a valid correction '
    'retains fresh preflight admission',
    (WidgetTester tester) async {
      _viewport(tester, const Size(1100, 650));
      final TokenCreateFixture fixture = TokenCreateFixture();
      int submissions = 0;
      try {
        await tester.pumpWidget(
          _host(
            CreateTokenStepperView(
              preflight: fixture.preflight,
              onIssue: (_) => submissions++,
            ),
          ),
        );
        await _clock(tester);
        await _details(tester);
        expect(fixture.preflight.sufficient, isTrue);
        expect(
          tester.widget<OutlinedButton>(_action('details')).onPressed,
          isNotNull,
        );
        await tester.enterText(_field('token_name_field'), 'Moon Tokens');
        await tester.pump(const Duration(milliseconds: 1));
        expect(
          tester.widget<OutlinedButton>(_action('details')).onPressed,
          isNull,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await _clock(tester);
        expect(_active(tester, 'details'), isTrue);
        expect(fixture.accountReads, 1);
        expect(fixture.plasmaReads, 1);
        expect(submissions, 0);
        await tester.enterText(_field('token_name_field'), 'MoonTokens');
        await tester.pump(const Duration(milliseconds: 1));
        expect(
          tester.widget<OutlinedButton>(_action('details')).onPressed,
          isNotNull,
        );
        await tester.tap(_action('details'));
        await _clock(tester);
        expect(_active(tester, 'supply'), isTrue);
        expect(fixture.accountReads, 2);
        expect(fixture.plasmaReads, 2);
        expect(submissions, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      }
    },
  );
}
