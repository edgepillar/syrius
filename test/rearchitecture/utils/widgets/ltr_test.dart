import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/home/widgets/amount_text.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/infinite_scroll_table/cells/hash_cell.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/infinite_scroll_table/infinite_scroll_table.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/ltr.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/formatted_amount_with_tooltip.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_fields/disabled_address_field.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

const Key _box = Key('box');

/// [child] in a box [width] wide at the start corner of an interface that
/// runs in [direction].
Widget _host(TextDirection direction, Widget child, {double width = 400}) =>
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: Material(
        child: Directionality(
          textDirection: direction,
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: SizedBox(key: _box, width: width, child: child),
          ),
        ),
      ),
    );

/// The paragraph that draws the text [data].
RenderParagraph _paragraph(WidgetTester tester, String data) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text(data), matching: find.byType(RichText)),
    );

/// The left and right edges, in the paragraph, of its characters from
/// [start] up to [end].
({double left, double right}) _span(RenderParagraph p, int start, int end) {
  final List<TextBox> boxes = p.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: end),
  );
  expect(boxes, isNotEmpty);
  return (
    left: boxes.map((TextBox b) => b.left).reduce(math.min),
    right: boxes.map((TextBox b) => b.right).reduce(math.max),
  );
}

// 1,204.5 with 8 decimals.
final BigInt _raw = BigInt.parse('120450000000');
const String _amount = '1,204.5 ZNN';
const TextStyle _style = TextStyle(fontSize: 28);

// All digits: the hash whose two ends a right-to-left paragraph swaps.
final Hash _hash = Hash.parse('1234567890' * 6 + '1234');

void main() {
  tearDown(kAddressLabelMap.clear);

  group('what the pin is for', () {
    testWidgets('unpinned, a right-to-left interface draws the symbol before '
        'the digits and swaps the ends of a hash', (WidgetTester tester) async {
      final String short = _hash.toShortString();
      await tester.pumpWidget(
        _host(
          TextDirection.rtl,
          Column(children: <Widget>[const Text(_amount), Text(short)]),
        ),
      );
      final RenderParagraph amount = _paragraph(tester, _amount);
      expect(
        _span(amount, 8, 11).right,
        lessThanOrEqualTo(_span(amount, 0, 7).left),
      );

      final RenderParagraph hash = _paragraph(tester, short);
      expect(
        _span(hash, short.length - 6, short.length).right,
        lessThanOrEqualTo(_span(hash, 0, 6).left),
      );
    });
  });

  group('AmountText', () {
    testWidgets('reads digits then symbol under a right-to-left interface, '
        'at the right of the width it is given', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          TextDirection.rtl,
          AmountText(_raw, decimals: 8, style: _style, symbol: 'ZNN'),
        ),
      );
      final RenderParagraph p = _paragraph(tester, _amount);
      expect(p.textDirection, TextDirection.ltr);
      expect(_span(p, 0, 7).right, lessThanOrEqualTo(_span(p, 8, 11).left));

      // The app's start is the right side.
      expect(p.textAlign, TextAlign.right);
      expect(p.size.width, 400);
      expect(_span(p, 8, 11).right, moreOrLessEquals(400, epsilon: 0.5));
    });

    testWidgets('a negative amount keeps its sign in front', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TextDirection.rtl,
          AmountText(-_raw, decimals: 8, style: _style),
        ),
      );
      final RenderParagraph p = _paragraph(tester, '-1,204.5');
      expect(_span(p, 0, 1).right, lessThanOrEqualTo(_span(p, 1, 8).left));
    });

    testWidgets('is what it was under a left-to-right interface', (
      WidgetTester tester,
    ) async {
      // The widget as it was built before the pin.
      final Widget before = Text.rich(
        TextSpan(
          style: monoStyle(_style),
          children: const <InlineSpan>[
            TextSpan(text: '1,204.5'),
            TextSpan(
              text: ' ZNN',
              style: TextStyle(
                fontFamily: kSansFontFamily,
                fontSize: 28 * 0.53,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        key: const Key('before'),
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
      );
      await tester.pumpWidget(
        _host(
          TextDirection.ltr,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              before,
              AmountText(
                _raw,
                key: const Key('after'),
                decimals: 8,
                style: _style,
                symbol: 'ZNN',
              ),
            ],
          ),
        ),
      );
      RenderParagraph of(String key) => tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(RichText),
        ),
      );
      final RenderParagraph was = of('before');
      final RenderParagraph now = of('after');
      expect(now.textDirection, was.textDirection);
      expect(now.textDirection, TextDirection.ltr);
      expect(now.textAlign, was.textAlign);
      expect(now.size, was.size);
      expect(_span(now, 0, 7), _span(was, 0, 7));
      expect(_span(now, 8, 11), _span(was, 8, 11));
    });
  });

  group('a shortened hash or address', () {
    testWidgets('a hash of digits keeps its two ends in order, at the right '
        'of its row', (WidgetTester tester) async {
      final String short = _hash.toShortString();
      await tester.pumpWidget(
        _host(
          TextDirection.rtl,
          Row(children: <Widget>[HashCell(hash: _hash)]),
        ),
      );
      final RenderParagraph p = _paragraph(tester, short);
      expect(p.textDirection, TextDirection.ltr);
      expect(
        _span(p, 0, 6).right,
        lessThanOrEqualTo(_span(p, short.length - 6, short.length).left),
      );
      expect(
        tester.getTopRight(find.text(short)).dx,
        tester.getTopRight(find.byKey(_box)).dx,
      );
    });

    testWidgets('an address keeps its two ends in order; a label follows the '
        'app', (WidgetTester tester) async {
      final String short = emptyAddress.toShortString();
      await tester.pumpWidget(
        _host(
          TextDirection.rtl,
          Row(
            children: <Widget>[
              InfiniteScrollTableCell.textFromAddress(address: emptyAddress),
            ],
          ),
        ),
      );
      final RenderParagraph p = _paragraph(tester, short);
      expect(p.textDirection, TextDirection.ltr);
      expect(
        _span(p, 0, 7).right,
        lessThanOrEqualTo(_span(p, short.length - 6, short.length).left),
      );
      expect(
        tester.getTopRight(find.text(short)).dx,
        tester.getTopRight(find.byKey(_box)).dx,
      );

      kAddressLabelMap[emptyAddress.toString()] = 'Savings';
      await tester.pumpWidget(
        _host(
          TextDirection.rtl,
          Row(
            children: <Widget>[
              InfiniteScrollTableCell.textFromAddress(address: emptyAddress),
            ],
          ),
        ),
      );
      expect(_paragraph(tester, 'Savings').textDirection, TextDirection.rtl);
    });

    testWidgets('is what it was under a left-to-right interface', (
      WidgetTester tester,
    ) async {
      final String short = _hash.toShortString();
      await tester.pumpWidget(
        _host(
          TextDirection.ltr,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                short,
                key: const Key('before'),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: monoStyle(null),
              ),
              Row(children: <Widget>[HashCell(hash: _hash)]),
            ],
          ),
        ),
      );
      final List<RenderParagraph> both = tester
          .renderObjectList<RenderParagraph>(
            find.descendant(
              of: find.text(short),
              matching: find.byType(RichText),
            ),
          )
          .toList();
      expect(both, hasLength(2));
      expect(both[1].textDirection, both[0].textDirection);
      expect(both[1].textDirection, TextDirection.ltr);
      expect(both[1].textAlign, both[0].textAlign);
      expect(both[1].size, both[0].size);
    });
  });

  group('Figure', () {
    testWidgets('pins an amount and leaves a translated word to the app', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TextDirection.rtl,
          const Figure(label: 'Balance', value: _amount),
        ),
      );
      final RenderParagraph p = _paragraph(tester, _amount);
      expect(p.textDirection, TextDirection.ltr);
      expect(_span(p, 0, 7).right, lessThanOrEqualTo(_span(p, 8, 11).left));
      // At the app's start, the right side.
      expect(
        tester.getTopRight(find.text(_amount)).dx,
        tester.getTopRight(find.byKey(_box)).dx,
      );

      const String word = 'لا شيء بعد';
      await tester.pumpWidget(
        _host(TextDirection.rtl, const Figure(label: 'Balance', value: word)),
      );
      expect(_paragraph(tester, word).textDirection, TextDirection.rtl);
    });

    testWidgets('is what it was under a left-to-right interface', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TextDirection.ltr,
          const Figure(label: 'Balance', value: _amount),
        ),
      );
      final RenderParagraph p = _paragraph(tester, _amount);
      expect(p.textDirection, TextDirection.ltr);
      expect(p.textAlign, TextAlign.start);
      expect(tester.getTopLeft(find.text(_amount)).dx, 0);
    });
  });

  group('FormattedAmountWithTooltip', () {
    testWidgets('draws what its builder returns left to right', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TextDirection.rtl,
          Row(
            children: <Widget>[
              FormattedAmountWithTooltip(
                amount: '0.5',
                tokenSymbol: 'ZNN',
                builder: (String amount, String symbol) =>
                    Text('$amount $symbol'),
              ),
            ],
          ),
        ),
      );
      final RenderParagraph p = _paragraph(tester, '0.5 ZNN');
      expect(p.textDirection, TextDirection.ltr);
      expect(_span(p, 0, 3).right, lessThanOrEqualTo(_span(p, 4, 7).left));
      expect(
        tester.getTopRight(find.text('0.5 ZNN')).dx,
        tester.getTopRight(find.byKey(_box)).dx,
      );
      expect(find.byTooltip('0.5 ZNN'), findsOneWidget);
    });
  });

  group('DisabledAddressField', () {
    Future<EditableText> pump(
      WidgetTester tester,
      TextDirection direction,
      String label,
    ) async {
      final String address = emptyAddress.toString();
      kAddressLabelMap[address] = label;
      final TextEditingController controller = TextEditingController(
        text: address,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(direction, DisabledAddressField(controller)),
      );
      return tester.widget<EditableText>(find.byType(EditableText));
    }

    testWidgets("a Latin label runs left to right from the app's start", (
      WidgetTester tester,
    ) async {
      final EditableText rtl = await pump(
        tester,
        TextDirection.rtl,
        'Address 1',
      );
      expect(rtl.textDirection, TextDirection.ltr);
      expect(rtl.textAlign, TextAlign.right);

      final EditableText ltr = await pump(
        tester,
        TextDirection.ltr,
        'Address 1',
      );
      expect(ltr.textDirection, TextDirection.ltr);
      expect(ltr.textAlign, TextAlign.start);
    });

    testWidgets("a right-to-left label keeps the app's direction", (
      WidgetTester tester,
    ) async {
      final EditableText field = await pump(
        tester,
        TextDirection.rtl,
        'العنوان 1',
      );
      expect(field.textDirection, isNull);
      expect(field.textAlign, TextAlign.right);
    });
  });

  group('the helpers', () {
    testWidgets('Ltr gives its child a left-to-right direction', (
      WidgetTester tester,
    ) async {
      late TextDirection inside;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Ltr(
            child: Builder(
              builder: (BuildContext context) {
                inside = Directionality.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(inside, TextDirection.ltr);
    });

    testWidgets('ltrTextAlign turns start and end into sides only under a '
        'right-to-left interface', (WidgetTester tester) async {
      Future<BuildContext> under(TextDirection direction) async {
        late BuildContext inner;
        await tester.pumpWidget(
          Directionality(
            textDirection: direction,
            child: Builder(
              builder: (BuildContext context) {
                inner = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        return inner;
      }

      final BuildContext rtl = await under(TextDirection.rtl);
      expect(ltrTextAlign(rtl), TextAlign.right);
      expect(ltrTextAlign(rtl, TextAlign.start), TextAlign.right);
      expect(ltrTextAlign(rtl, TextAlign.end), TextAlign.left);
      expect(ltrTextAlign(rtl, TextAlign.center), TextAlign.center);
      expect(ltrTextAlign(rtl, TextAlign.left), TextAlign.left);

      final BuildContext ltr = await under(TextDirection.ltr);
      expect(ltrTextAlign(ltr), TextAlign.start);
      expect(ltrTextAlign(ltr, TextAlign.end), TextAlign.end);
      expect(ltrTextAlign(ltr, TextAlign.center), TextAlign.center);
    });

    test('ltrUnlessRtl pins everything but right-to-left script', () {
      for (final String figure in <String>[
        '',
        '1,204.5 ZNN',
        '-5.2',
        '33 of 97',
        'z1qqqqq...sggv2f',
        '12ab…9f00',
        '42%',
        'None yet',
      ]) {
        expect(ltrUnlessRtl(figure), TextDirection.ltr, reason: figure);
      }
      for (final String words in <String>['لا شيء بعد', '33 من 97', 'שלום']) {
        expect(ltrUnlessRtl(words), isNull, reason: words);
      }
    });
  });
}
