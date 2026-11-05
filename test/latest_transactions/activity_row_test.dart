import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart' as app;
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/home/widgets/amount_text.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/latest_transactions/model/activity_entry.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/latest_transactions/view/activity_row.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/eye_toggle.dart';
import 'package:zenon_syrius_wallet_flutter/seams/seam.dart';
import 'package:zenon_syrius_wallet_flutter/services/shared_prefs_service.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notifiers/balance_visibility.dart';
import 'package:zenon_syrius_wallet_flutter/utils/zts_utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

import 'activity_fixtures.dart';

final DateTime _now = DateTime.fromMillisecondsSinceEpoch(1800000240000);

Widget _host(
  Widget child, {
  bool light = false,
  double width = 734,
  TextDirection direction = TextDirection.ltr,
  double scale = 1,
}) => MaterialApp(
  theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
  localizationsDelegates: appLocalizationsDelegates,
  locale: const Locale('en'),
  supportedLocales: const <Locale>[Locale('en')],
  builder: (BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: Directionality(
      textDirection: direction,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          // Match vertical-list constraints without adding scroll semantics.
          child: UnconstrainedBox(
            constrainedAxis: Axis.horizontal,
            child: child,
          ),
        ),
      ),
    ),
  ),
);

String _number(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byType(AmountText),
        matching: find.byType(Text),
      ),
    )
    .textSpan!
    .toPlainText();

void _expectOriginalMarks(WidgetTester tester, {bool incoming = false}) {
  final AppTokens tokens = AppTokens.of(
    tester.element(find.byType(ActivityRow)),
  );
  final Finder symbols = find.descendant(
    of: find.byType(ActivityRow),
    matching: find.byType(SvgPicture),
  );
  expect(symbols, findsNWidgets(2));
  final List<SvgPicture> marks = tester
      .widgetList<SvgPicture>(symbols)
      .toList();
  for (final SvgPicture mark in marks) {
    expect(mark.width, tokens.activityIconSize);
    expect(mark.height, tokens.activityIconSize);
    expect(mark.excludeFromSemantics, isTrue);
  }
  expect(marks.first.colorFilter, ColorFilter.mode(
    incoming ? tokens.znnInk : tokens.dim, BlendMode.srcIn,
  ));
  expect(
    marks.last.colorFilter,
    ColorFilter.mode(tokens.faint, BlendMode.srcIn),
  );
}

void _expectReferenceRowGeometry(
  WidgetTester tester, {
  TextDirection direction = TextDirection.ltr,
  double scale = 1,
}) {
  final Rect mark = tester.getRect(find.descendant(
    of: find.byType(ActivityRow), matching: find.byType(SvgPicture),
  ).first);
  final Rect label = tester.getRect(find.text('Sent'));
  // The reference's .row has a 10 px gap and .i.s has a 14 px box.
  expect(direction == TextDirection.ltr
      ? label.left - mark.right : mark.left - label.right, closeTo(10, 0.1));
  expect(tester.getSize(find.byType(IconButton)), const Size.square(14));
  // Shape both reference fonts before adding the CSS insets and separator.
  double lineHeight = 0;
  for (final String family in <String>[kSansFontFamily, kMonoFontFamily]) {
    final TextPainter reference = TextPainter(
      text: TextSpan(text: 'Sent', style: TextStyle(
        fontFamily: family,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.45,
        leadingDistribution: TextLeadingDistribution.even,
        fontFeatures: const <ui.FontFeature>[ui.FontFeature.tabularFigures()],
      )),
      textDirection: direction,
      textScaler: TextScaler.linear(scale),
    )..layout();
    if (reference.height > lineHeight) lineHeight = reference.height;
    reference.dispose();
  }
  final double expectedHeight = lineHeight + 19 < 40 ? 40 : lineHeight + 19;
  foundation.debugPrintSynchronously('CI_ACTIVITY_FIXTURE:${jsonEncode(
    <String, Object>{
      'schema': 1,
      'kind': 'geometry',
      'light': Theme.of(tester.element(find.byType(ActivityRow))).brightness ==
          Brightness.light,
      'direction': direction.name,
      'scale': scale,
      'row_height': tester.getSize(find.byType(ActivityRow)).height,
      'reference_height': expectedHeight,
      'line_height': lineHeight,
    },
  )}');
  expect(tester.getSize(find.byType(ActivityRow)).height,
    closeTo(expectedHeight, 0.1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final String family in const <String>[
      kSansFontFamily, kMonoFontFamily,
    ]) {
      final FontLoader fonts = FontLoader(family);
      for (final String weight in const <String>[
        'Regular', 'Medium', 'SemiBold', 'Bold',
      ]) {
        fonts.addFont(rootBundle.load(
          'assets/fonts/$family-$weight.ttf',
        ));
      }
      await fonts.load();
    }
  });
  late SharedPrefsService? preferences;
  late BalanceVisibility visibility;
  late List<Uri> opened;

  setUp(() {
    preferences = app.sharedPrefsService;
    app.sharedPrefsService = null;
    visibility = BalanceVisibility();
    opened = <Uri>[];
  });

  tearDown(() {
    visibility.dispose();
    app.sharedPrefsService = preferences;
  });

  ActivityRow row({
    AccountBlock? block,
    int? chain = 1,
    ActivityZapPreview? preview,
    DateTime? now,
  }) => ActivityRow(
    entry: ActivityEntry.fromBlock(
      block ?? activityBlock(),
      zapPreview: preview,
    ),
    now: now ?? _now,
    chainId: chain,
    addressLabels: <String, String>{pillarAddress.toString(): 'Alice'},
    visibility: visibility,
    onOpenExplorer: opened.add,
  );

  for (final bool light in <bool>[false, true]) {
    testWidgets(
      'signed exact amounts and labelled recipients in theme $light',
      (WidgetTester tester) async {
        await tester.pumpWidget(_host(row(), light: light));
        expect(find.text('Sent'), findsOneWidget);
        expect(find.text('Alice'), findsOneWidget);
        expect(find.text('− '), findsOneWidget);
        expect(_number(tester), '12.5');
        expect(find.text('ZNN'), findsOneWidget);
        expect(find.text('4 min'), findsOneWidget);
        expect(find.text('Message'), findsNothing);
        final AppTokens tokens = AppTokens.of(
          tester.element(find.byType(ActivityRow)),
        );
        expect(
          tester.widget<AmountText>(find.byType(AmountText)).style.color,
          tokens.foreground,
        );
        _expectOriginalMarks(tester);
        _expectReferenceRowGeometry(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('receive uses incoming sign and links the exact receive hash', (
    WidgetTester tester,
  ) async {
    final AccountBlock receive = activityReceive();
    await tester.pumpWidget(_host(row(block: receive)));
    expect(find.text('Received'), findsOneWidget);
    expect(find.text('+ '), findsOneWidget);
    _expectOriginalMarks(tester, incoming: true);
    final Finder link = find.byKey(
      ValueKey<String>(
        'activity_explorer:${receive.hash}',
      ),
    );
    await tester.tap(link);
    expect(opened.single.pathSegments, <String>[
      'transaction',
      receive.hash.toString(),
    ]);
  });

  testWidgets(
    'shared masking removes amount and sign from paint and semantics',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_host(row()));
        foundation.debugPrintSynchronously('CI_ACTIVITY_FIXTURE:${jsonEncode(
          <String, Object>{
            'schema': 1,
            'kind': 'semantics',
            'visible_label_matches':
                find.semantics.byLabel('12.5').evaluate().length,
          },
        )}');
        expect(find.semantics.byLabel('12.5'), findsOne);
        visibility.set(true);
        await tester.pump();
        expect(find.text(kHiddenAmountDots), findsOneWidget);
        expect(find.semantics.byLabel(RegExp(r'12\.5|−')), findsNothing);
        expect(find.text('ZNN'), findsOneWidget);
        final Finder hidden = find.descendant(
          of: find.byType(HiddenAmount),
          matching: find.byType(Visibility),
        );
        expect(tester.widget<Visibility>(hidden).visible, isFalse);
        expect(
          tester
              .widgetList<Tooltip>(find.byType(Tooltip))
              .any(
                (Tooltip tooltip) => tooltip.message?.contains('12.5') ?? false,
              ),
          isFalse,
        );
        visibility.set(false);
        await tester.pump();
        expect(find.text(kHiddenAmountDots), findsNothing);
        expect(find.semantics.byLabel('12.5'), findsOne);
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets('dust and very large values keep every significant digit', (
    WidgetTester tester,
  ) async {
    for (final (BigInt, String) sample in <(BigInt, String)>[
      (BigInt.one, '0.00000001'),
      (BigInt.parse('900719925474099312345'), '9,007,199,254,740.99312345'),
      (BigInt.zero, '0'),
    ]) {
      await tester.pumpWidget(
        _host(row(block: activityBlock(amount: sample.$1))),
      );
      expect(_number(tester), sample.$2);
      if (sample.$1 == BigInt.zero) expect(find.text('− '), findsNothing);
    }
  });

  testWidgets('missing receive pair cannot render a fabricated zero amount', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        row(
          block: activityBlock(
            type: BlockTypeEnum.userReceive,
            amount: BigInt.zero,
            timestamp: null,
          ),
        ),
      ),
    );
    expect(find.text('Received'), findsOneWidget);
    expect(find.text('Units unavailable'), findsOneWidget);
    expect(find.byType(AmountText), findsNothing);
    expect(find.text('Pending'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'preview Message is drawn but rejects pointer, keys and semantics',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(row(preview: const ActivityZapPreview())),
        );
        await tester.pump();
        expect(find.text('Zap'), findsOneWidget);
        expect(find.text('Message'), findsOneWidget);
        await tester.tapAt(tester.getCenter(find.byType(SeamGate)));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        const ui.SemanticsAction action = ui.SemanticsAction.tap;
        final SemanticsNode node = tester.getSemantics(find.byType(SeamGate));
        expect(node.getSemanticsData().hasAction(action), isFalse);
        expect(
          node,
          isSemantics(
            label: 'Not yet',
            hasEnabledState: true,
            isEnabled: false,
          ),
        );
        node.owner!.performAction(node.id, action);
        await tester.pump();
        final TextButton button = tester.widget<TextButton>(
          find.byType(TextButton),
        );
        expect(button.onPressed, throwsA(isA<SeamNotBuilt>()));
        expect(opened, isEmpty);
        expect(tester.takeException(), isNull);
        final Iterable<Tooltip> hints = tester.widgetList<Tooltip>(
          find.descendant(
            of: find.byType(SeamGate),
            matching: find.byType(Tooltip),
          ),
        );
        expect(
          hints.any((Tooltip tooltip) => tooltip.message == 'Not yet'),
          isTrue,
        );
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets(
    'unknown and non-mainnet source chains disable explorer opening',
    (WidgetTester tester) async {
      for (final int? chain in <int?>[null, 321, 2]) {
        await tester.pumpWidget(_host(row(chain: chain)));
        expect(
          tester.widget<IconButton>(find.byType(IconButton)).onPressed,
          isNull,
        );
      }
      expect(opened, isEmpty);
    },
  );

  testWidgets(
    'relative time handles new, hourly, daily and future confirmations',
    (WidgetTester tester) async {
      for (final (int, String) sample in <(int, String)>[
        (1800000230, 'Now'),
        (1799996640, '1 h'),
        (1799913840, '1 d'),
        (1800000250, 'Now'),
      ]) {
        await tester.pumpWidget(
          _host(row(block: activityBlock(timestamp: sample.$1))),
        );
        expect(find.text(sample.$2), findsOneWidget);
      }
    },
  );

  testWidgets(
    'right-to-left layout retains figure direction and complete amount',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(row(), direction: TextDirection.rtl, width: 650, scale: 1.5),
      );
      final Text number = tester.widget<Text>(
        find.descendant(
          of: find.byType(AmountText),
          matching: find.byType(Text),
        ),
      );
      expect(number.textDirection, TextDirection.ltr);
      expect(_number(tester), '12.5');
      _expectReferenceRowGeometry(
        tester, direction: TextDirection.rtl, scale: 1.5,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'contract terms use decoded arguments and local beneficiary labels',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          row(
            block: activityBlock(
              to: stakeAddress,
              data: Definitions.stake.encodeFunction('Stake', <dynamic>[
                stakeTimeUnitSec * 6,
              ]),
            ),
          ),
        ),
      );
      expect(find.text('Staked'), findsOneWidget);
      expect(find.text('6 months'), findsOneWidget);
      _expectOriginalMarks(tester);
      await tester.pumpWidget(
        _host(
          row(
            block: activityBlock(
              to: pillarAddress,
              amount: BigInt.zero,
              data: Definitions.pillar.encodeFunction('Delegate', <dynamic>[
                'dev1',
              ]),
            ),
          ),
        ),
      );
      expect(find.text('Delegated'), findsOneWidget);
      expect(find.text('dev1'), findsOneWidget);
      _expectOriginalMarks(tester);
      await tester.pumpWidget(
        _host(
          row(
            block: activityBlock(
              to: plasmaAddress,
              token: kQsrCoin,
              data: Definitions.plasma.encodeFunction('Fuse', <dynamic>[
                pillarAddress,
              ]),
            ),
          ),
        ),
      );
      expect(find.text('Fused'), findsOneWidget);
      expect(find.text('Plasma, Alice'), findsOneWidget);
      _expectOriginalMarks(tester);
    },
  );
}
