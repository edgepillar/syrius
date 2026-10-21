import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hex/hex.dart';
import 'package:intl/intl.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/extensions.dart';

/// Why [AmountInputFormatter] refused an edit: which line goes under the
/// field.
enum AmountRefusalReason {
  /// A comma was typed or pasted where the wallet takes a point.
  comma,

  /// Anything else an amount cannot hold: a letter, a space, a sign, a
  /// second point, a zero before another digit.
  notAmount,

  /// The field takes whole numbers, and the edit was not one.
  notWhole,
}

/// The last edit of an amount field, when [AmountInputFormatter] refused it.
///
/// A formatter that refuses an edit can only hand the old text back: it has
/// no way to the line under the field. It records the refusal here, and what
/// draws the field listens and says why nothing happened
/// (`AmountRefusalScope`).
///
/// One for the whole app, because a formatter is made again at every build
/// and is never told which field it serves. The listener decides whether the
/// refusal was its own field's: it had the focus, and [keptText] is its text.
///
/// This holds the last edit only. How long the line stays under the field
/// is the listener's business: it outlasts the edits accepted after it.
class AmountInputRefusal extends ChangeNotifier {
  AmountInputRefusal._();

  /// The one the formatter tells and the fields listen to.
  static final AmountInputRefusal instance = AmountInputRefusal._();

  String? _keptText;
  AmountRefusalReason? _reason;

  /// The text the field was left with by its last edit, when that edit was
  /// refused. Null once an edit has been accepted.
  String? get keptText => _keptText;

  /// Why the last edit was refused. Null with [keptText].
  AmountRefusalReason? get reason => _reason;

  /// Listeners hear every refusal, a second one of the same text included.
  void refuse(String keptText, AmountRefusalReason reason) {
    _keptText = keptText;
    _reason = reason;
    notifyListeners();
  }

  /// An edit went in: the last edit is not a refused one.
  void clear() {
    if (_keptText == null) {
      return;
    }
    _keptText = null;
    _reason = null;
    notifyListeners();
  }
}

/// An amount as the wallet takes it in every language: Latin digits, and a
/// point before the decimals.
///
/// An edit that would leave anything else is refused whole: the text stays
/// as it was, and [AmountInputRefusal] is told. What this replaces dropped
/// the one character it did not know and kept the rest, so that `1,5` typed
/// with a decimal comma became `15` with nothing on screen to say so.
///
/// A comma is never read as a decimal mark, and never dropped from what was
/// typed: `1,5` is one and a half in most languages and `1,234` is a
/// thousand in English, and the field cannot know which was meant.
///
/// Three things are put right instead of refused, since none can change the
/// number:
///  - Arabic-Indic, Extended Arabic-Indic and Devanagari digits become
///    Latin, and the Arabic decimal separator (U+066B) a point;
///  - the spaces around a pasted number go;
///  - a pasted number grouped as the wallet itself shows amounts, `1,204.5`,
///    loses its commas, because that is what is copied out of the wallet.
///
/// With [whole], the same for a field that takes no decimals: a point is
/// refused like a comma. What that replaces dropped both, so that `1.5`
/// became `15`.
class AmountInputFormatter extends TextInputFormatter {
  /// Holds no text: what it refuses goes to [AmountInputRefusal].
  const AmountInputFormatter({this.whole = false});

  /// Whether the field takes whole numbers only.
  final bool whole;

  static final RegExp _amount = RegExp(r'^\d*\.?\d*$');
  static final RegExp _wholeAmount = RegExp(r'^\d*$');
  static final RegExp _leadingZero = RegExp(r'^0\d');
  // Groups of three after the first, as `1,204.5` and `12,000`. Not `1,5`,
  // `1,23` or `1.234,56`.
  static final RegExp _grouped = RegExp(r'^[1-9]\d{0,2}(,\d{3})+(\.\d*)?$');

  static const int _comma = 0x2C;
  static const int _point = 0x2E;
  static const int _zero = 0x30;

  bool _isAmount(String text) =>
      (whole ? _wholeAmount : _amount).hasMatch(text) &&
      !_leadingZero.hasMatch(text);

  /// [unit] in Latin, when it is a digit or the decimal mark of another
  /// script. All of them are in the basic plane: one code unit each.
  static int _toLatin(int unit) {
    for (final int zero in const <int>[0x0660, 0x06F0, 0x0966]) {
      if (unit >= zero && unit <= zero + 9) {
        return _zero + unit - zero;
      }
    }
    return unit == 0x066B ? _point : unit;
  }

  /// The part of [text] the edit put in: one character for a key, more for
  /// a paste.
  ///
  /// The selection of [oldValue] is what the edit replaced. Comparing the
  /// two texts alone would call `1,204` pasted over a selected `1204` a
  /// typed comma.
  static TextRange _inserted(TextEditingValue oldValue, String text) {
    final String old = oldValue.text;
    final TextSelection replaced = oldValue.selection;
    if (replaced.isValid && replaced.end <= old.length) {
      final String before = old.substring(0, replaced.start);
      final String after = old.substring(replaced.end);
      if (text.length >= before.length + after.length &&
          text.startsWith(before) &&
          text.endsWith(after)) {
        return TextRange(
          start: before.length,
          end: text.length - after.length,
        );
      }
    }
    int prefix = 0;
    while (prefix < old.length &&
        prefix < text.length &&
        old.codeUnitAt(prefix) == text.codeUnitAt(prefix)) {
      prefix++;
    }
    int suffix = 0;
    while (suffix < old.length - prefix &&
        suffix < text.length - prefix &&
        old.codeUnitAt(old.length - 1 - suffix) ==
            text.codeUnitAt(text.length - 1 - suffix)) {
      suffix++;
    }
    return TextRange(start: prefix, end: text.length - suffix);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String edited = newValue.text;
    if (edited == oldValue.text) {
      return newValue;
    }
    final AmountInputRefusal refusal = AmountInputRefusal.instance;
    if (_isAmount(edited)) {
      refusal.clear();
      return newValue;
    }

    // What a paste brought is cleaned by itself, before it joins the text
    // around it: `0,500` pasted after a `7` is not the grouped `70,500`.
    final TextRange inserted = _inserted(oldValue, edited);
    final bool pasted = inserted.end - inserted.start > 1;
    int start = inserted.start;
    int end = inserted.end;
    if (pasted) {
      final String paste = inserted.textInside(edited);
      end = start + paste.trimRight().length;
      start += paste.length - paste.trimLeft().length;
      if (start > end) {
        start = end;
      }
    }
    String latin(int from, int to) => String.fromCharCodes(<int>[
      for (int i = from; i < to; i++) _toLatin(edited.codeUnitAt(i)),
    ]);
    final bool grouped = pasted && _grouped.hasMatch(latin(start, end));
    // The places in [edited] of the characters that are kept.
    final List<int> kept = <int>[
      for (int i = 0; i < inserted.start; i++) i,
      for (int i = start; i < end; i++)
        if (!grouped || edited.codeUnitAt(i) != _comma) i,
      for (int i = inserted.end; i < edited.length; i++) i,
    ];
    final String text = String.fromCharCodes(<int>[
      for (final int i in kept) _toLatin(edited.codeUnitAt(i)),
    ]);
    if (!_isAmount(text)) {
      refusal.refuse(
        oldValue.text,
        whole
            ? AmountRefusalReason.notWhole
            : inserted.textInside(edited).contains(',')
            ? AmountRefusalReason.comma
            : AmountRefusalReason.notAmount,
      );
      return oldValue;
    }
    refusal.clear();

    // A caret keeps its place among the characters that are left.
    int moved(int offset) => kept.where((int i) => i < offset).length;
    final TextSelection selection = newValue.selection;
    return TextEditingValue(
      text: text,
      selection: selection.isValid
          ? selection.copyWith(
              baseOffset: moved(selection.baseOffset),
              extentOffset: moved(selection.extentOffset),
            )
          : selection,
    );
  }
}

class FormatUtils {
  /// The formatters of every amount field. See [AmountInputFormatter].
  ///
  /// [replacementString] is no longer read: a refused edit leaves the text
  /// the field had, which the formatter is handed with the edit. It stays so
  /// that the call sites stay as they are.
  static List<TextInputFormatter> getAmountTextInputFormatters(
    String replacementString,
  ) =>
      const <TextInputFormatter>[AmountInputFormatter()];

  /// The formatters of the amount of QSR to fuse, which is whole: see
  /// [AmountInputFormatter.whole]. [replacementString] is no longer read, as
  /// above.
  static List<TextInputFormatter> getPlasmaAmountTextInputFormatters(
    String replacementString,
  ) =>
      const <TextInputFormatter>[AmountInputFormatter(whole: true)];

  static String encodeHexString(List<int> input) => HEX.encode(input);

  static List<int> decodeHexString(String input) => HEX.decode(input);

  static bool _dateSymbolsLoaded = false;

  /// intl knows a language's month names and its order of day, month and
  /// year only once they are loaded, and throws for anything but `en_US`
  /// until then. In the app `GlobalMaterialLocalizations` loads them all
  /// when `MaterialApp` is first built; this loads the same ones for a call
  /// that comes before that, or in a test with no app around it.
  static void _loadDateSymbols() {
    if (_dateSymbolsLoaded) {
      return;
    }
    unawaited(GlobalMaterialLocalizations.delegate.load(const Locale('en')));
    _dateSymbolsLoaded = true;
  }

  /// A format for a date or a time that is read, in the language of [locale]
  /// (the app's, when null) with Latin digits.
  ///
  /// [skeletons] name what is shown and leave the order and the words to the
  /// language: `yMMMd` is `Oct 13, 2026`, `13 oct 2026`, `2026年10月13日`.
  /// More than one are joined by [separator].
  ///
  /// [english] is the pattern English keeps where the wallet has always
  /// worded a date another way than the English skeleton does: `13 Oct`,
  /// where the skeleton says `Oct 13`. Without it English takes the skeleton
  /// like every other language.
  ///
  /// Only the language code is passed on, never a region, and the digits are
  /// set apart from it: the symbols loaded in the app are Flutter's own, and
  /// its `ar` counts in Arabic-Indic digits. A date in the wallet stands
  /// beside amounts and heights, which are Latin in every language.
  static DateFormat _shown(
    List<String> skeletons, {
    Locale? locale,
    String? english,
    String separator = ' ',
  }) {
    _loadDateSymbols();
    final String code = (locale ?? currentAppLocale).languageCode;
    final DateFormat format;
    if (english != null && code == 'en') {
      format = DateFormat(english, code);
    } else {
      format = DateFormat(skeletons.first, code);
      for (final String skeleton in skeletons.skip(1)) {
        format.addPattern(skeleton, separator);
      }
    }
    return format..useNativeDigits = false;
  }

  static DateTime _at(int millis) =>
      DateTime.fromMillisecondsSinceEpoch(millis);

  /// [date] in a fixed [pattern], for a string a program reads or compares
  /// and no person does: English symbols and Latin digits whatever the
  /// language, so that it is the same string on every wallet.
  static String _fixed(DateTime date, String pattern) {
    _loadDateSymbols();
    return (DateFormat(pattern, 'en')..useNativeDigits = false).format(date);
  }

  /// The time in the name of an exported wallet file: `2026-10-13-1405`.
  static String fileStamp(DateTime date) => _fixed(date, 'yyyy-MM-dd-HHmm');

  /// A string that is the same for two times on the same day and differs
  /// for any other: `13 Oct, 2026`. Compared, never shown.
  static String dayKey(DateTime date) => _fixed(date, 'd MMM, yyyy');

  /// A date: `Oct 13, 2026`.
  ///
  /// [dateFormat] is what this took before dates followed the language: a
  /// fixed pattern, which now comes out in English whatever the language.
  /// One caller is left, the error of a swap that cannot be recovered yet
  /// (`recover_htlc_swap_funds_bloc.dart`, with [kDefaultDateTimeFormat]).
  /// It should take [formatDeadline], and this parameter go.
  static String formatDate(
    int timestampMillis, {
    Locale? locale,
    String? dateFormat,
  }) {
    final DateTime date = _at(timestampMillis);
    if (dateFormat != null) {
      return _fixed(date, dateFormat);
    }
    return _shown(<String>['yMMMd'], locale: locale).format(date);
  }

  /// A date and the time of day: `Oct 13, 2026 2:05 PM`.
  static String formatDateTime(int timestampMillis, {Locale? locale}) =>
      _shown(
        <String>['yMMMd', 'jm'],
        locale: locale,
      ).format(_at(timestampMillis));

  /// A date and the time to the second, on a 24-hour clock:
  /// `Oct 13, 2026 14:05:09`. The whole of what a table's short date stands
  /// for, in its tooltip.
  static String formatDateTimeSeconds(int timestampMillis, {Locale? locale}) =>
      _shown(
        <String>['yMMMd', 'Hms'],
        locale: locale,
      ).format(_at(timestampMillis));

  /// The time to the second, on a 24-hour clock: `14:05:09`.
  static String formatTimeSeconds(int timestampMillis, {Locale? locale}) =>
      _shown(<String>['Hms'], locale: locale).format(_at(timestampMillis));

  /// The day and the month under a chart's axis: `13 Oct`.
  static String formatDayMonth(int timestampMillis, {Locale? locale}) =>
      _shown(
        <String>['MMMd'],
        locale: locale,
        english: 'd MMM',
      ).format(_at(timestampMillis));

  /// The day, the month and the time on a 24-hour clock, for a time within
  /// the year, such as when a WalletConnect session expires: `13 Oct 14:05`.
  static String formatDayMonthTime(int timestampMillis, {Locale? locale}) =>
      _shown(
        <String>['MMMd', 'Hm'],
        locale: locale,
        english: 'd MMM HH:mm',
      ).format(_at(timestampMillis));

  /// When a notification was made: `13 Oct 2026  02:05 PM`.
  static String formatNotificationStamp(
    int timestampMillis, {
    Locale? locale,
  }) => _shown(
    <String>['yMMMd', 'jm'],
    locale: locale,
    english: 'd MMM yyyy  hh:mm aaa',
    separator: '  ',
  ).format(_at(timestampMillis));

  /// The moment something runs out, in a sentence: `2026-10-13 02:05 PM`.
  static String formatDeadline(int timestampMillis, {Locale? locale}) => _shown(
    <String>['yMMMd', 'jm'],
    locale: locale,
    english: kDefaultDateTimeFormat,
  ).format(_at(timestampMillis));

  static String extractNameFromEnum<T>(T enumValue) {
    final String valueName = enumValue.toString().split('.')[1];
    if (RegExp('^[a-z]+[A-Z]+').hasMatch(valueName)) {
      final List<String> parts = valueName
          .split(RegExp('(?<=[a-z])(?=[A-Z])'))
          .map((String e) => e.toLowerCase())
          .toList();
      parts.first = parts.first.capitalize();
      return parts.join(' ');
    }
    return valueName.capitalize();
  }

  static int subtractDaysFromDate(int numDays, DateTime referenceDate) {
    return referenceDate
        .subtract(
          Duration(
            days: kStandardChartNumDays.toInt() - 1 - numDays,
          ),
        )
        .millisecondsSinceEpoch;
  }

  /// When a transaction was made, in a narrow column: how long ago within a
  /// day (`5 h ago`), then the day (`Oct 13`), with its year once that is
  /// not this one (`Oct 13, 2025`).
  ///
  /// [now] is the clock, for a test.
  static String formatDateForTable(
    int transactionMillis, {
    Locale? locale,
    DateTime? now,
  }) {
    final DateTime clock = now ?? DateTime.now();
    final int currentMillis = clock.millisecondsSinceEpoch;
    if (currentMillis - transactionMillis <=
        const Duration(days: 1).inMilliseconds) {
      return formatDataShort(currentMillis - transactionMillis, locale: locale);
    }

    final DateTime date = _at(transactionMillis);
    return _shown(
      <String>[if (date.year == clock.year) 'MMMd' else 'yMMMd'],
      locale: locale,
    ).format(date);
  }

  /// How long ago, [i] milliseconds back, in the largest whole unit: `5 h
  /// ago`, `12 min ago`, `30 s ago`.
  static String formatDataShort(int i, {Locale? locale}) {
    final Duration duration = Duration(milliseconds: i);
    final AppLocalizations l10n = locale == null
        ? currentL10n
        : lookupAppLocalizations(Locale(locale.languageCode));
    if (duration.inHours > 0) {
      return l10n.timeAgoHours(duration.inHours);
    }
    if (duration.inMinutes > 0) {
      return l10n.timeAgoMinutes(duration.inMinutes);
    }
    return l10n.timeAgoSeconds(duration.inSeconds);
  }

  /// [d] in its largest unit alone, in [l10n]'s language: `12 d`, `5 h`,
  /// `40 min`, `30 s`. Nothing under zero. For a line with room for one
  /// unit, and one that is not drawn again as the time passes.
  static String formatDurationCoarse(AppLocalizations l10n, Duration d) {
    if (d.isNegative) {
      return l10n.durationSeconds(0);
    }
    if (d.inDays > 0) {
      return l10n.durationDays(d.inDays);
    }
    if (d.inHours > 0) {
      return l10n.durationHours(d.inHours);
    }
    if (d.inMinutes > 0) {
      return l10n.durationMinutes(d.inMinutes);
    }
    return l10n.durationSeconds(d.inSeconds);
  }

  /// [d] as a clock that counts down every second, with the days before it
  /// while there are any: `2 d 03:04:05`, `03:04:05`. Nothing under zero.
  ///
  /// The clock is digits and colons in every language; the unit of the days
  /// is [l10n]'s.
  static String formatCountdownClock(AppLocalizations l10n, Duration d) {
    final Duration left = d.isNegative ? Duration.zero : d;
    String two(int n) => n.toString().padLeft(2, '0');
    final String clock =
        '${two(left.inHours.remainder(Duration.hoursPerDay))}'
        ':${two(left.inMinutes.remainder(Duration.minutesPerHour))}'
        ':${two(left.inSeconds.remainder(Duration.secondsPerMinute))}';
    return left.inDays > 0
        ? l10n.durationDaysClock(left.inDays, clock)
        : clock;
  }

  /// [d] in its two largest units, in [l10n]'s language: `214 d 3 h`,
  /// `9 h 52 m`, `14 m 32 s`, `32 s`. Nothing under zero.
  ///
  /// The one place a length of time is worded. A widget passes
  /// `context.l10n`, so that it is rebuilt when the language changes.
  static String formatDuration(AppLocalizations l10n, Duration d) {
    if (d.isNegative) {
      return l10n.durationSeconds(0);
    }
    final int days = d.inDays;
    final int hours = d.inHours.remainder(Duration.hoursPerDay);
    final int minutes = d.inMinutes.remainder(Duration.minutesPerHour);
    final int seconds = d.inSeconds.remainder(Duration.secondsPerMinute);
    if (days > 0) {
      return l10n.durationDaysHours(days, hours);
    }
    if (hours > 0) {
      return l10n.durationHoursMinutes(hours, minutes);
    }
    if (minutes > 0) {
      return l10n.durationMinutesSeconds(minutes, seconds);
    }
    return l10n.durationSeconds(seconds);
  }
}
