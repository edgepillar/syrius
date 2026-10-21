import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/input_validators.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notifiers/locale_notifier.dart';
import 'package:zenon_syrius_wallet_flutter/utils/zts_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_fields/amount_input_field.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_fields/input_field.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The line under an amount field after a refused comma.
const String _usePoint = 'Use a point for decimals';

/// The line after anything else that was refused.
const String _digitsOnly = 'Digits and a point only';

/// The line under the Fuse amount, which takes whole QSR.
const String _wholeOnly = 'Whole QSR only';

/// What the Fuse amount was given before, for the cases that must not have
/// changed.
List<TextInputFormatter> _wholeFormattersBefore(String replacementString) =>
    <TextInputFormatter>[
      FilteringTextInputFormatter.digitsOnly,
      FilteringTextInputFormatter.deny(
        RegExp(r'^0\d+'),
        replacementString: replacementString,
      ),
    ];

/// What every amount field was given before, for the cases that must not
/// have changed.
List<TextInputFormatter> _formattersBefore(String replacementString) =>
    <TextInputFormatter>[
      FilteringTextInputFormatter.allow(
        RegExp(r'^\d*\.?\d*?$'),
        replacementString: replacementString,
      ),
      FilteringTextInputFormatter.deny(
        RegExp(r'^0\d+'),
        replacementString: replacementString,
      ),
    ];

/// [inserted] put in at the caret of [old], over its selection if it has
/// one, and passed through [formatters] the way `EditableText` does it.
TextEditingValue _edit(
  TextEditingValue old,
  String inserted, {
  List<TextInputFormatter>? formatters,
}) {
  final TextSelection selection = old.selection.isValid
      ? old.selection
      : TextSelection.collapsed(offset: old.text.length);
  final String before = old.text.substring(0, selection.start);
  final String after = old.text.substring(selection.end);
  final TextEditingValue edited = TextEditingValue(
    text: '$before$inserted$after',
    selection: TextSelection.collapsed(
      offset: before.length + inserted.length,
    ),
  );
  return (formatters ?? FormatUtils.getAmountTextInputFormatters(old.text))
      .fold<TextEditingValue>(
        edited,
        (TextEditingValue value, TextInputFormatter formatter) =>
            formatter.formatEditUpdate(old, value),
      );
}

/// An empty field with the caret in it.
const TextEditingValue _empty = TextEditingValue(
  selection: TextSelection.collapsed(offset: 0),
);

/// A field holding [text] with the caret at [caret], or at its end.
TextEditingValue _field(String text, {int? caret}) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: caret ?? text.length),
);

/// [keys] pressed one after the other in an empty field.
TextEditingValue _type(
  String keys, {
  List<TextInputFormatter> Function(String)? formatters,
}) {
  TextEditingValue value = _empty;
  for (final int rune in keys.runes) {
    value = _edit(
      value,
      String.fromCharCode(rune),
      formatters: formatters?.call(value.text),
    );
  }
  return value;
}

/// The text a refused edit left behind, or null when the last edit went in.
String? get _refused => AmountInputRefusal.instance.keptText;

/// Why the last edit was refused, or null when it went in.
AmountRefusalReason? get _reason => AmountInputRefusal.instance.reason;

AccountInfo _account() => AccountInfo(
  address: emptyAddress.toString(),
  blockCount: 1,
  balanceInfoList: <BalanceInfoListItem>[
    BalanceInfoListItem(token: kZnnCoin, balance: BigInt.from(100000000000)),
    BalanceInfoListItem(token: kQsrCoin, balance: BigInt.from(100000000000)),
  ],
);

Widget _app(
  List<TextEditingController> controllers, {
  Locale locale = const Locale('en'),
}) => _page(
  locale: locale,
  child: Column(
    children: <Widget>[
      for (final TextEditingController controller in controllers)
        AmountInputField(controller: controller, accountInfo: _account()),
    ],
  ),
);

Widget _page({required Widget child, Locale locale = const Locale('en')}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

/// An amount field as the cards build it: a bare `TextField` rebuilt for
/// every change of its text, with its own error under it. [limit] is the
/// most it takes.
Widget _card(
  TextEditingController controller, {
  List<TextInputFormatter> Function(String) formatters =
      FormatUtils.getAmountTextInputFormatters,
  int limit = 1000,
}) => _page(
  child: ListenableBuilder(
    listenable: controller,
    builder: (_, _) => AmountRefusalScope(
      controller: controller,
      builder: (_, String? refusal) => TextField(
        controller: controller,
        inputFormatters: formatters(controller.text),
        decoration: InputDecoration(
          errorText:
              refusal ??
              ((num.tryParse(controller.text) ?? 0) > limit
                  ? 'Too much'
                  : null),
        ),
      ),
    ),
  ),
);

void main() {
  setUp(() {
    // The validators word their messages in the language of the notifier
    // made last.
    LocaleNotifier(AppLanguage.english);
    AmountInputRefusal.instance.clear();
  });

  group('typing', () {
    test('a comma is kept out and the refusal recorded, not dropped', () {
      TextEditingValue value = _edit(_empty, '1');
      expect(value.text, '1');
      expect(_refused, isNull);

      value = _edit(value, ',');
      expect(value.text, '1');
      expect(value.selection, const TextSelection.collapsed(offset: 1));
      expect(_refused, '1');
      expect(_reason, AmountRefusalReason.comma);

      // The 5 goes in, as a 5 typed after the line was shown. The last edit
      // is no refused one; the line under the field is the scope's to keep.
      value = _edit(value, '5');
      expect(value.text, '15');
      expect(_refused, isNull);
      expect(_reason, isNull);
    });

    test('a comma is told from anything else that is refused', () {
      for (final String comma in <String>[',', '1,5', '1.234,56', ' 0,5 ']) {
        _edit(_field('7'), comma);
        expect(_reason, AmountRefusalReason.comma, reason: '"$comma"');
      }
      for (final String other in <String>['a', ' ', '-', '1 000', '٬', '1e5']) {
        _edit(_field('7'), other);
        expect(_reason, AmountRefusalReason.notAmount, reason: '"$other"');
      }
      _edit(_field('1.5'), '.');
      expect(_reason, AmountRefusalReason.notAmount);
      _edit(_field('0'), '5');
      expect(_reason, AmountRefusalReason.notAmount);
    });

    test('a comma is not read as a decimal mark', () {
      expect(_type('1,5').text, isNot('1.5'));
    });

    test('a comma that would group the digits is refused all the same', () {
      final TextEditingValue value = _edit(_field('1204', caret: 1), ',');
      expect(value.text, '1204');
      expect(_refused, '1204');
    });

    test('a second point is refused', () {
      final TextEditingValue value = _edit(_field('1.5'), '.');
      expect(value.text, '1.5');
      expect(_refused, '1.5');
    });

    test('a letter, a space and a sign are refused', () {
      for (final String key in <String>['a', ' ', '-', '+', 'e', "'", '٬']) {
        AmountInputRefusal.instance.clear();
        expect(_edit(_field('12'), key).text, '12', reason: 'key "$key"');
        expect(_refused, '12', reason: 'key "$key"');
      }
    });

    test('a leading zero is refused, as before, and now says so', () {
      expect(_edit(_field('0'), '5').text, '0');
      expect(_refused, '0');
      // What was there before put `5.5.5` in the field here.
      expect(_edit(_field('5.5', caret: 0), '0').text, '5.5');
      expect(_refused, '5.5');
    });

    test('digits of another script go in as Latin digits', () {
      // Arabic-Indic, with the Arabic decimal separator U+066B.
      expect(_type('١٢٫٥').text, '12.5');
      // Extended Arabic-Indic (Persian, Urdu).
      expect(_type('۱۲.۵').text, '12.5');
      // Devanagari.
      expect(_type('१२.५').text, '12.5');
      expect(_refused, isNull);
      expect(_edit(_field('1'), '٢').selection.baseOffset, 2);
    });

    test('the Arabic decimal separator is a point, so a second is refused', () {
      expect(_edit(_field('1.5'), '٫').text, '1.5');
      expect(_refused, '1.5');
    });

    test('what was valid is taken exactly as before', () {
      for (final String keys in <String>[
        '0',
        '0.5',
        '.5',
        '.',
        '12',
        '12.',
        '12.50',
        '1204.5',
        '100000000.12345678',
        '1.123456789',
        // Refused then and now, with the same text left.
        '05',
        '00',
        '1..5',
        '1a2',
        '1 000',
        '1,5',
      ]) {
        expect(
          _type(keys).text,
          _type(keys, formatters: _formattersBefore).text,
          reason: 'keys "$keys"',
        );
      }
    });

    test('deleting is not an edit to refuse', () {
      const TextEditingValue old = TextEditingValue(
        text: '1.5',
        selection: TextSelection.collapsed(offset: 2),
      );
      final TextEditingValue value =
          const AmountInputFormatter().formatEditUpdate(
            old,
            const TextEditingValue(
              text: '15',
              selection: TextSelection.collapsed(offset: 1),
            ),
          );
      expect(value.text, '15');
      expect(_refused, isNull);
    });

    test('more decimals than the token has go in, and the validator '
        'still says so', () {
      expect(_type('1.123456789').text, '1.123456789');
      expect(_refused, isNull);
      expect(
        InputValidators.correctValue(
          '1.123456789',
          BigInt.from(100000000000),
          8,
          BigInt.zero,
        ),
        'Inputted number has too many decimals',
      );
    });
  });

  group('pasting', () {
    test('a number grouped as the wallet shows it loses its commas', () {
      TextEditingValue value = _edit(_empty, '1,204.5');
      expect(value.text, '1204.5');
      expect(value.selection, const TextSelection.collapsed(offset: 6));
      expect(_refused, isNull);

      value = _edit(_empty, '12,000');
      expect(value.text, '12000');
      expect(_edit(_empty, '1,234,567.89').text, '1234567.89');
      expect(_refused, isNull);
    });

    test('over the same number selected, it is still a paste', () {
      const TextEditingValue selected = TextEditingValue(
        text: '1204',
        selection: TextSelection(baseOffset: 0, extentOffset: 4),
      );
      expect(_edit(selected, '1,204').text, '1204');
      expect(_refused, isNull);
    });

    test('any other number with a comma is refused, not guessed at', () {
      for (final String pasted in <String>[
        '1.234,56',
        '1,5',
        '1,23',
        '1,2345',
        '1234,567',
        '0,500',
        ',204',
        '1,204,5',
        '1 204,5',
      ]) {
        AmountInputRefusal.instance.clear();
        final TextEditingValue value = _edit(_field('7'), pasted);
        expect(value.text, '7', reason: 'pasted "$pasted"');
        expect(value.selection.baseOffset, 1, reason: 'pasted "$pasted"');
        expect(_refused, '7', reason: 'pasted "$pasted"');
      }
    });

    test('into an empty field, a refused paste leaves it empty', () {
      expect(_edit(_empty, '1,5').text, '');
      expect(_refused, '');
    });

    test('the spaces around a number go', () {
      final TextEditingValue value = _edit(_empty, ' 12.5 ');
      expect(value.text, '12.5');
      expect(value.selection, const TextSelection.collapsed(offset: 4));
      expect(_edit(_empty, '\t1,204.5\r\n').text, '1204.5');
      // A no-break space, as a table cell on a web page has.
      expect(_edit(_empty, ' 12 ').text, '12');
      expect(_refused, isNull);
    });

    test('a space inside a number is refused', () {
      expect(_edit(_empty, '1 000').text, '');
      expect(_refused, '');
    });

    test('what is pasted is cleaned before it joins what is there', () {
      // Not the grouped 70,500: the paste itself is no grouped number.
      expect(_edit(_field('7'), '0,500').text, '7');
      expect(_refused, '7');
      expect(_edit(_field('1'), ',204.5').text, '1');
      expect(_refused, '1');

      final TextEditingValue value = _edit(_field('1.'), ' 25 ');
      expect(value.text, '1.25');
      expect(value.selection, const TextSelection.collapsed(offset: 4));
      expect(_edit(_field('75', caret: 1), '1,204').text, '712045');
      expect(_refused, isNull);
    });

    test('digits of another script go in as Latin digits', () {
      expect(_edit(_empty, '١٢٫٥').text, '12.5');
      expect(_edit(_empty, '۱۲.۵').text, '12.5');
      expect(_edit(_empty, '१२.५').text, '12.5');
      expect(_edit(_empty, ' १,२०४.५ ').text, '1204.5');
      expect(_refused, isNull);
    });

    test('a number in the Arabic grouping is refused', () {
      // U+066C groups thousands: not the form the wallet shows.
      expect(_edit(_empty, '١٬٢٠٤٫٥').text, '');
      expect(_refused, '');
    });

    test('text that is no number is refused', () {
      expect(_edit(_field('3'), 'abc').text, '3');
      expect(_refused, '3');
      expect(_edit(_field('3'), '1.2.3').text, '3');
      expect(_edit(_field('3'), '-5').text, '3');
      expect(_edit(_field('3'), '1e5').text, '3');
    });
  });

  group('a field of whole numbers', () {
    TextEditingValue whole(TextEditingValue old, String inserted) => _edit(
      old,
      inserted,
      formatters: FormatUtils.getPlasmaAmountTextInputFormatters(old.text),
    );

    test('a point is kept out and the refusal recorded, not dropped', () {
      TextEditingValue value = whole(_empty, '1');
      expect(value.text, '1');
      expect(_refused, isNull);

      // What was there before made 15 of 1.5 and said nothing.
      value = whole(value, '.');
      expect(value.text, '1');
      expect(value.selection, const TextSelection.collapsed(offset: 1));
      expect(_refused, '1');
      expect(_reason, AmountRefusalReason.notWhole);

      value = whole(value, '5');
      expect(value.text, '15');
      expect(_refused, isNull);
    });

    test('a comma, a letter and a pasted decimal are refused the same', () {
      for (final String inserted in <String>[',', 'a', ' ', '-', '1.5', '1,5']) {
        AmountInputRefusal.instance.clear();
        expect(whole(_field('12'), inserted).text, '12', reason: inserted);
        expect(_refused, '12', reason: inserted);
        expect(_reason, AmountRefusalReason.notWhole, reason: inserted);
      }
      expect(whole(_empty, '1,204.5').text, '');
      expect(_refused, '');
    });

    test('what was valid is taken exactly as before', () {
      for (final String keys in <String>[
        '0',
        '7',
        '12',
        '100',
        '1204',
        '100000000',
        // Refused then and now, with the same text left.
        '05',
        '00',
      ]) {
        expect(
          _type(
            keys,
            formatters: FormatUtils.getPlasmaAmountTextInputFormatters,
          ).text,
          _type(keys, formatters: _wholeFormattersBefore).text,
          reason: 'keys "$keys"',
        );
      }
    });

    test('what is put right in an amount is put right here', () {
      expect(whole(_empty, ' 12 ').text, '12');
      expect(whole(_empty, '1,204').text, '1204');
      expect(whole(_empty, '١٢').text, '12');
      expect(_refused, isNull);
    });
  });

  test('the notifier holds the last edit only: the next accepted one '
      'withdraws it, and listeners hear both', () {
    int heard = 0;
    void listener() => heard++;
    AmountInputRefusal.instance.addListener(listener);
    addTearDown(() => AmountInputRefusal.instance.removeListener(listener));

    TextEditingValue value = _edit(_field('1'), ',');
    expect(heard, 1);
    value = _edit(value, ',');
    expect(heard, 2);
    value = _edit(value, '.');
    expect(value.text, '1.');
    expect(heard, 3);
    expect(_refused, isNull);
    _edit(value, '5');
    expect(heard, 3);
  });

  group('AmountInputField', () {
    late TextEditingController controller;

    setUp(() => controller = TextEditingController());
    tearDown(() => controller.dispose());

    testWidgets('1 , 5 leaves 15 with the line still showing, and deleting '
        'the 5 to type .5 withdraws it', (WidgetTester tester) async {
      await tester.pumpWidget(_app(<TextEditingController>[controller]));
      final Finder field = find.byType(EditableText);

      await tester.enterText(field, '1');
      await tester.pump();
      expect(find.text(_usePoint), findsNothing);

      await tester.enterText(field, '1,');
      await tester.pump();
      expect(controller.text, '1');
      expect(find.text(_usePoint), findsOneWidget);

      // The number in the field is not the one that was typed: this is when
      // the line is needed.
      await tester.enterText(field, '15');
      await tester.pump();
      expect(controller.text, '15');
      expect(find.text(_usePoint), findsOneWidget);

      await tester.enterText(field, '156');
      await tester.pump();
      expect(find.text(_usePoint), findsOneWidget);

      await tester.enterText(field, '1');
      await tester.pump();
      expect(find.text(_usePoint), findsOneWidget);

      await tester.enterText(field, '1.');
      await tester.pump();
      expect(find.text(_usePoint), findsNothing);

      await tester.enterText(field, '1.5');
      await tester.pump();
      expect(controller.text, '1.5');
      expect(find.text(_usePoint), findsNothing);
    });

    testWidgets('a point put between the digits withdraws it', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app(<TextEditingController>[controller]));
      final Finder field = find.byType(EditableText);

      await tester.enterText(field, '1');
      await tester.enterText(field, '1,');
      await tester.enterText(field, '15');
      await tester.pump();
      expect(find.text(_usePoint), findsOneWidget);

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '1.5',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pump();
      expect(controller.text, '1.5');
      expect(find.text(_usePoint), findsNothing);
    });

    testWidgets('emptying the field withdraws it', (WidgetTester tester) async {
      await tester.pumpWidget(_app(<TextEditingController>[controller]));
      final Finder field = find.byType(EditableText);

      await tester.enterText(field, '1');
      await tester.enterText(field, '1,');
      await tester.enterText(field, '15');
      await tester.pump();
      expect(find.text(_usePoint), findsOneWidget);

      await tester.enterText(field, '');
      await tester.pump();
      expect(find.text(_usePoint), findsNothing);

      await tester.enterText(field, '15');
      await tester.pump();
      expect(find.text(_usePoint), findsNothing);
    });

    testWidgets('a letter gets the other line', (WidgetTester tester) async {
      await tester.pumpWidget(_app(<TextEditingController>[controller]));
      final Finder field = find.byType(EditableText);

      await tester.enterText(field, '12');
      await tester.enterText(field, '12a');
      await tester.pump();
      expect(controller.text, '12');
      expect(find.text(_digitsOnly), findsOneWidget);
      expect(find.text(_usePoint), findsNothing);

      // The refusal of a later key replaces the line.
      await tester.enterText(field, '12,');
      await tester.pump();
      expect(find.text(_usePoint), findsOneWidget);
      expect(find.text(_digitsOnly), findsNothing);
    });

    testWidgets('says it over the validator, and gives the validator back', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app(<TextEditingController>[controller]));
      final Finder field = find.byType(EditableText);

      // More than the balance of 1000.
      await tester.enterText(field, '5000');
      await tester.pump();
      expect(find.text('Value must be between 0 and 1000'), findsOneWidget);

      await tester.enterText(field, '5000,');
      await tester.pump();
      expect(controller.text, '5000');
      expect(find.text(_usePoint), findsOneWidget);
      expect(find.text('Value must be between 0 and 1000'), findsNothing);

      await tester.enterText(field, '50005');
      await tester.pump();
      expect(find.text(_usePoint), findsOneWidget);
      expect(find.text('Value must be between 0 and 1000'), findsNothing);

      // In the frame the line goes, not one key later.
      await tester.enterText(field, '5000.5');
      await tester.pump();
      expect(find.text(_usePoint), findsNothing);
      expect(find.text('Value must be between 0 and 1000'), findsOneWidget);
    });

    testWidgets('is drawn left to right under a right-to-left interface', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _app(<TextEditingController>[controller], locale: const Locale('ar')),
      );
      final EditableText field = tester.widget(find.byType(EditableText));
      expect(
        Directionality.of(tester.element(find.byType(AmountInputField))),
        TextDirection.rtl,
      );
      expect(field.textDirection, TextDirection.ltr);
      expect(field.textAlign, TextAlign.right);
    });

    testWidgets('says it for a first paste, into a field never changed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app(<TextEditingController>[controller]));
      final Finder field = find.byType(EditableText);

      await tester.enterText(field, '1.234,56');
      await tester.pump();
      expect(controller.text, '');
      expect(find.text(_usePoint), findsOneWidget);

      await tester.enterText(field, '1,204.5');
      await tester.pump();
      expect(controller.text, '1204.5');
      expect(find.text(_usePoint), findsNothing);
    });

    testWidgets('Max withdraws it', (WidgetTester tester) async {
      await tester.pumpWidget(_app(<TextEditingController>[controller]));
      final Finder field = find.byType(EditableText);

      await tester.enterText(field, '2');
      await tester.enterText(field, '2,');
      await tester.enterText(field, '25');
      await tester.pump();
      expect(find.text(_usePoint), findsOneWidget);

      await tester.tap(find.text('MAX'));
      await tester.pump();
      expect(controller.text, '1000');
      expect(find.text(_usePoint), findsNothing);
    });

    testWidgets('a second field holding the same amount says nothing, '
        'leaving the field leaves the line, and a text set from code '
        'withdraws it', (WidgetTester tester) async {
      final TextEditingController other = TextEditingController(text: '2');
      addTearDown(other.dispose);
      await tester.pumpWidget(
        _app(<TextEditingController>[controller, other]),
      );
      final Finder first = find.byType(EditableText).first;
      final Finder second = find.byType(EditableText).last;

      await tester.enterText(first, '2');
      await tester.enterText(first, '2,');
      await tester.pump();
      expect(find.text(_usePoint), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AmountInputField).first,
          matching: find.text(_usePoint),
        ),
        findsOneWidget,
      );

      Finder lineOf(int field) => find.descendant(
        of: find.byType(AmountInputField).at(field),
        matching: find.text(_usePoint),
      );

      await tester.showKeyboard(second);
      await tester.pump();
      expect(lineOf(0), findsOneWidget);

      // A refusal in the other field is the other field's.
      await tester.enterText(second, '2,');
      await tester.pump();
      expect(lineOf(0), findsOneWidget);
      expect(lineOf(1), findsOneWidget);

      // An accepted key in the other field is not this one's either.
      await tester.enterText(second, '2.');
      await tester.pump();
      expect(lineOf(0), findsOneWidget);
      expect(lineOf(1), findsNothing);

      // A draft put back, or the form cleared, while the field is not the
      // one typed in.
      controller.text = '7';
      await tester.pump();
      expect(find.text(_usePoint), findsNothing);
    });
  });

  group('the field of a card', () {
    late TextEditingController controller;

    setUp(() => controller = TextEditingController());
    tearDown(() => controller.dispose());

    testWidgets('1 , 5 leaves 15 with the line still showing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_card(controller));
      final Finder field = find.byType(EditableText);

      await tester.enterText(field, '1');
      await tester.enterText(field, '1,');
      await tester.pump();
      expect(controller.text, '1');
      expect(find.text(_usePoint), findsOneWidget);

      await tester.enterText(field, '15');
      await tester.pump();
      expect(controller.text, '15');
      expect(find.text(_usePoint), findsOneWidget);

      await tester.enterText(field, '1');
      await tester.enterText(field, '1.');
      await tester.enterText(field, '1.5');
      await tester.pump();
      expect(controller.text, '1.5');
      expect(find.text(_usePoint), findsNothing);
    });

    testWidgets('the line stands over the card\'s own error, which comes '
        'back', (WidgetTester tester) async {
      await tester.pumpWidget(_card(controller));
      final Finder field = find.byType(EditableText);

      await tester.enterText(field, '5000');
      await tester.pump();
      expect(find.text('Too much'), findsOneWidget);

      await tester.enterText(field, '5000,');
      await tester.pump();
      expect(find.text(_usePoint), findsOneWidget);
      expect(find.text('Too much'), findsNothing);

      // Max, as every card sets it.
      controller.text = '9000';
      await tester.pump();
      expect(find.text(_usePoint), findsNothing);
      expect(find.text('Too much'), findsOneWidget);
    });

    testWidgets('a field of whole numbers says so for 1.5, and keeps saying '
        'it over 15', (WidgetTester tester) async {
      await tester.pumpWidget(
        _card(
          controller,
          formatters: FormatUtils.getPlasmaAmountTextInputFormatters,
        ),
      );
      final Finder field = find.byType(EditableText);

      await tester.enterText(field, '1');
      await tester.pump();
      expect(find.text(_wholeOnly), findsNothing);

      await tester.enterText(field, '1.');
      await tester.pump();
      expect(controller.text, '1');
      expect(find.text(_wholeOnly), findsOneWidget);

      await tester.enterText(field, '15');
      await tester.pump();
      expect(controller.text, '15');
      expect(find.text(_wholeOnly), findsOneWidget);

      await tester.enterText(field, '1,');
      await tester.pump();
      expect(controller.text, '15');
      expect(find.text(_wholeOnly), findsOneWidget);

      await tester.enterText(field, '');
      await tester.pump();
      expect(find.text(_wholeOnly), findsNothing);

      await tester.enterText(field, '15');
      await tester.pump();
      expect(find.text(_wholeOnly), findsNothing);
    });
  });

  group('InputField', () {
    late TextEditingController controller;

    setUp(() => controller = TextEditingController());
    tearDown(() => controller.dispose());

    // The Accelerator steppers: an InputField in a Form of its own, given
    // the amount formatters and nothing else.
    Widget form({required bool amount}) => _page(
      child: Form(
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: InputField(
          controller: controller,
          inputFormatters: amount
              ? FormatUtils.getAmountTextInputFormatters(controller.text)
              : null,
          validator: (String? value) => value == '5000' ? 'Too much' : null,
        ),
      ),
    );

    testWidgets('given the amount formatters, says why a key did nothing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(form(amount: true));
      final Finder field = find.byType(EditableText);

      // A first paste, into a field the form has not validated yet.
      await tester.enterText(field, '1.234,56');
      await tester.pump();
      expect(controller.text, '');
      expect(find.text(_usePoint), findsOneWidget);

      await tester.enterText(field, '5');
      await tester.enterText(field, '50');
      await tester.enterText(field, '500');
      await tester.enterText(field, '5000');
      await tester.pump();
      expect(find.text(_usePoint), findsOneWidget);
      expect(find.text('Too much'), findsNothing);

      await tester.enterText(field, '');
      await tester.enterText(field, '5000');
      await tester.pump();
      expect(find.text(_usePoint), findsNothing);
      expect(find.text('Too much'), findsOneWidget);
    });

    testWidgets('given no amount formatter, is as it was', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(form(amount: false));
      expect(find.byType(AmountRefusalScope), findsNothing);

      await tester.enterText(find.byType(EditableText), '1,5');
      await tester.pump();
      expect(controller.text, '1,5');
      expect(find.text(_usePoint), findsNothing);
    });
  });
}
