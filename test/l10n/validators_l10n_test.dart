import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/utils/extensions.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/input_validators.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notifiers/locale_notifier.dart';
import 'package:znn_ledger_dart/znn_ledger_dart.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The texts the wallet showed before they were moved into `app_en.arb`,
/// written out here so that a change of a single character fails.

/// `InputValidators.correctValue` with whole-number amounts.
String? _correct(
  String? value, {
  required int max,
  required int min,
  bool canBeEqualToMin = false,
}) => InputValidators.correctValue(
  value,
  BigInt.from(max),
  0,
  BigInt.from(min),
  canBeEqualToMin: canBeEqualToMin,
);

/// A hash lock no secret in these tests opens.
HtlcInfo _htlc() => HtlcInfo(
  id: emptyHash,
  timeLocked: emptyAddress,
  hashLocked: emptyAddress,
  tokenStandard: znnZts,
  amount: BigInt.one,
  expirationTime: 0,
  hashType: htlcHashTypeSha3,
  keyMaxSize: 32,
  hashLock: List<int>.filled(32, 0),
);

/// What `main.dart` gives `MaterialApp` for the language, and no more.
Widget _app(LocaleNotifier notifier) =>
    ChangeNotifierProvider<LocaleNotifier>.value(
      value: notifier,
      child: Consumer<LocaleNotifier>(
        builder: (_, LocaleNotifier localeNotifier, _) => MaterialApp(
          locale: localeNotifier.locale,
          localeListResolutionCallback: resolveAppLocale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SizedBox(key: Key('home')),
        ),
      ),
    );

void main() {
  final String ownAddress = emptyAddress.toString();

  setUp(() {
    // The language is the one of the notifier made last.
    LocaleNotifier(AppLanguage.english);
    kDefaultAddressList = <String?>[ownAddress];
  });

  tearDown(() {
    kDefaultAddressList = <String?>[];
  });

  group('validators, in English', () {
    test('evmAddress', () {
      expect(InputValidators.evmAddress('0x${'a' * 40}'), isNull);
      expect(InputValidators.evmAddress('nope'), 'Invalid address');
      expect(InputValidators.evmAddress(null), 'Invalid address');
    });

    test('node', () {
      expect(InputValidators.node('ws://127.0.0.1:35998'), isNull);
      expect(InputValidators.node('nope'), 'Invalid Node');
    });

    test('recipientAddress', () {
      expect(InputValidators.recipientAddress(ownAddress), isNull);
      expect(
        InputValidators.recipientAddress('z1nope'),
        'Must be an address from your wallet',
      );
    });

    test('notEmpty', () {
      expect(InputValidators.notEmpty('Token name', 'ZNN'), isNull);
      expect(
        InputValidators.notEmpty('Token name', ''),
        'Token name must not be empty',
      );
      expect(
        InputValidators.notEmpty('Secret', null),
        'Secret must not be empty',
      );
    });

    test('validateNumber', () {
      expect(InputValidators.validateNumber('12'), isNull);
      expect(InputValidators.validateNumber(''), 'Number required');
      expect(InputValidators.validateNumber(null), 'Number required');
      expect(
        InputValidators.validateNumber('1.5'),
        'Input is not a valid number',
      );
    });

    test('validateAmount', () {
      expect(InputValidators.validateAmount('12'), isNull);
      expect(InputValidators.validateAmount(''), 'Invalid amount');
      expect(InputValidators.validateAmount('x'), 'Error');
      expect(InputValidators.validateAmount(null), 'Value is null');
    });

    test('correctValue', () {
      expect(_correct('7', max: 20, min: 5), isNull);
      expect(_correct('7', max: 0, min: 0), 'Empty balance');
      expect(_correct('', max: 20, min: 5), 'Enter a valid amount');
      expect(
        _correct('7.5', max: 20, min: 5),
        'Inputted number has too many decimals',
      );
      expect(
        _correct('7', max: 5, min: 10),
        'Your available balance must be at least 10',
      );
      expect(_correct('3', max: 5, min: 5), 'Value must be 5');
      // Two spaces, as it always was; see validatorValueMustBeMinAllowed.
      expect(
        _correct('3', max: 5, min: 5, canBeEqualToMin: true),
        'Value must be  5',
      );
      expect(
        _correct('30', max: 20, min: 5),
        'Value must be between 5 and 20',
      );
      expect(
        _correct('30', max: 20, min: 5, canBeEqualToMin: true),
        'Value must be between 5 and 20',
      );
      expect(_correct('x', max: 20, min: 5), 'Error');
      expect(_correct(null, max: 20, min: 5), "Value can't be empty");
    });

    test('correctValue words an amount with its decimals', () {
      expect(
        InputValidators.correctValue(
          '1',
          BigInt.from(100000000),
          8,
          BigInt.from(150000000),
        ),
        'Your available balance must be at least 1.5',
      );
    });

    test('checkAddress', () {
      expect(InputValidators.checkAddress(ownAddress), isNull);
      expect(InputValidators.checkAddress(''), 'Enter an address');
      expect(InputValidators.checkAddress('nope'), 'Invalid address');
      expect(InputValidators.checkAddress(null), 'Value is null');
    });

    test('checkPasswordMatch', () {
      expect(InputValidators.checkPasswordMatch('a', 'a'), isNull);
      expect(
        InputValidators.checkPasswordMatch('a', 'b'),
        'Passwords do not match',
      );
    });

    test('validatePassword', () {
      expect(InputValidators.validatePassword('Abcdef1!'), isNull);
      expect(
        InputValidators.validatePassword('short'),
        'Password not strong enough',
      );
      expect(
        InputValidators.validatePassword('longenough'),
        'Invalid password',
      );
      expect(InputValidators.validatePassword(null), 'Value is null');
    });

    test('validatePillarMomentumAddress', () {
      kDefaultAddressList = <String?>[];
      expect(InputValidators.validatePillarMomentumAddress(ownAddress), isNull);
      kDefaultAddressList = <String?>[ownAddress];
      expect(
        InputValidators.validatePillarMomentumAddress(ownAddress),
        'Pillar producer address must be generated from a different seed',
      );
      expect(
        InputValidators.validatePillarMomentumAddress('nope'),
        'Invalid address',
      );
      expect(
        InputValidators.validatePillarMomentumAddress(''),
        'Enter an address',
      );
      expect(
        InputValidators.validatePillarMomentumAddress(null),
        'Value is null',
      );
    });

    test('isMaxSupplyZero', () {
      expect(InputValidators.isMaxSupplyZero('0'), isNull);
      expect(
        InputValidators.isMaxSupplyZero('1'),
        'Max supply must be 0 for non-mintable tokens',
      );
      expect(InputValidators.isMaxSupplyZero('x'), 'Error');
      expect(InputValidators.isMaxSupplyZero(null), 'Value is null');
    });

    test('checkUrl', () {
      expect(InputValidators.checkUrl('https://zenon.network'), isNull);
      expect(InputValidators.checkUrl('http://zenon.network'), 'Invalid URL');
      expect(InputValidators.checkUrl('nope'), 'Invalid URL');
    });

    test('checkHash', () {
      expect(InputValidators.checkHash(emptyHash.toString()), isNull);
      expect(InputValidators.checkHash('nope'), 'Invalid hash');
      expect(InputValidators.checkHash(null), 'Invalid hash');
    });

    test('checkSecret', () async {
      final HtlcInfo htlc = _htlc();
      // Not hex, hex that opens nothing, and nothing at all.
      expect(await InputValidators.checkSecret(htlc, 'zz'), 'Invalid secret');
      expect(await InputValidators.checkSecret(htlc, 'ab'), 'Invalid secret');
      expect(await InputValidators.checkSecret(htlc, null), 'Invalid secret');
    });
  });

  test('a Ledger status reads as it did, in English', () {
    const Map<StatusWord, String> texts = <StatusWord, String>{
      StatusWord.deny: 'Deny',
      StatusWord.wrongP1P2: 'Invalid P1 or P2',
      StatusWord.wrongDataLength: 'Invalid data length',
      StatusWord.inactiveDevice: 'Device is inactive',
      StatusWord.notAllowed: 'Request not allowed',
      StatusWord.insNotSupported:
          'Instruction not supported, please make sure the Zenon app is opened',
      StatusWord.claNotSupported:
          'Class not supported, please make sure the Zenon app is opened',
      StatusWord.appIsNotOpen:
          'App not open, please open the Zenon app on your device',
      StatusWord.wrongResponseLength:
          'Invalid response, please reconnect the device and try again',
      StatusWord.displayBip32PathFail: 'Failed to display BIP32 path',
      StatusWord.displayAddressFail: 'Failed to display address',
      StatusWord.displayAmountFail: 'Failed to display amount',
      StatusWord.wrongTxLength: 'Invalid transaction length',
      StatusWord.txParsingFail: 'Failed to parse transaction',
      StatusWord.txHashFail: 'Failed to hash transaction',
      StatusWord.badState:
          'Bad state, please reconnect the device and try again',
      StatusWord.signatureFail: 'Failed to create signature',
      StatusWord.success: 'Success',
      StatusWord.unknownError:
          'Unknown error, please make sure the device is unlocked',
    };
    expect(texts.keys, unorderedEquals(StatusWord.values));
    for (final MapEntry<StatusWord, String> entry in texts.entries) {
      expect(
        LedgerError.responseError(statusWord: entry.key).toFriendlyString(),
        entry.value,
      );
    }
    expect(
      const LedgerError.connectionError(
        origMessage: 'as the device said it',
      ).toFriendlyString(),
      'as the device said it',
    );
  });

  group('relative times', () {
    test('the plural messages, for 1 and for 5', () {
      final AppLocalizations l10n = currentL10n;
      expect(l10n.timeAgoHours(1), '1 h ago');
      expect(l10n.timeAgoHours(5), '5 h ago');
      expect(l10n.timeAgoMinutes(1), '1 min ago');
      expect(l10n.timeAgoMinutes(5), '5 min ago');
      expect(l10n.timeAgoSeconds(1), '1 s ago');
      expect(l10n.timeAgoSeconds(5), '5 s ago');
      expect(l10n.timeAgoSeconds(0), '0 s ago');
    });

    test('formatDataShort takes the largest whole unit', () {
      int millis(Duration d) => d.inMilliseconds;
      expect(
        FormatUtils.formatDataShort(
          millis(const Duration(hours: 5, minutes: 59)),
        ),
        '5 h ago',
      );
      expect(
        FormatUtils.formatDataShort(millis(const Duration(hours: 1))),
        '1 h ago',
      );
      expect(
        FormatUtils.formatDataShort(
          millis(const Duration(minutes: 5, seconds: 59)),
        ),
        '5 min ago',
      );
      expect(
        FormatUtils.formatDataShort(millis(const Duration(minutes: 1))),
        '1 min ago',
      );
      expect(
        FormatUtils.formatDataShort(millis(const Duration(seconds: 5))),
        '5 s ago',
      );
      expect(FormatUtils.formatDataShort(999), '0 s ago');
    });
  });

  test('formatDuration words a length of time in its two largest units', () {
    final AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));
    String format(Duration d) => FormatUtils.formatDuration(l10n, d);

    expect(
      format(const Duration(days: 214, hours: 3, minutes: 59)),
      '214 d 3 h',
    );
    expect(format(const Duration(days: 2)), '2 d 0 h');
    expect(
      format(const Duration(hours: 9, minutes: 52, seconds: 59)),
      '9 h 52 m',
    );
    expect(format(const Duration(minutes: 14, seconds: 32)), '14 m 32 s');
    expect(format(const Duration(seconds: 32, milliseconds: 999)), '32 s');
    expect(format(Duration.zero), '0 s');
    expect(format(const Duration(seconds: -5)), '0 s');
  });

  group('currentL10n', () {
    test('follows the chosen language', () {
      final LocaleNotifier notifier = LocaleNotifier(AppLanguage.english);
      expect(currentAppLocale, const Locale('en'));
      expect(currentL10n.localeName, 'en');

      // The Spanish file is empty, so its text is still English: the
      // instance's own locale is what tells them apart.
      notifier.changeLanguage(AppLanguage.spanish);
      expect(currentAppLocale, const Locale('es'));
      expect(currentL10n.localeName, 'es');

      notifier.changeLanguage(AppLanguage.arabic);
      expect(currentL10n.localeName, 'ar');
    });

    test('starts in the language the notifier starts in', () {
      LocaleNotifier(AppLanguage.hindi);
      expect(currentL10n.localeName, 'hi');
    });

    test('for System, is the platform locale the app has, else English', () {
      LocaleNotifier(AppLanguage.spanish).changeLanguage(AppLanguage.system);
      expect(
        currentAppLocale,
        resolveAppLocale(
          PlatformDispatcher.instance.locales,
          AppLocalizations.supportedLocales,
        ),
      );
      expect(
        AppLocalizations.supportedLocales,
        contains(currentAppLocale),
      );
    });

    testWidgets('is the locale the app shows, back to System included', (
      WidgetTester tester,
    ) async {
      final LocaleNotifier notifier = LocaleNotifier();
      await tester.pumpWidget(_app(notifier));
      Locale shown() => Localizations.localeOf(
        tester.element(find.byKey(const Key('home'))),
      );
      expect(currentAppLocale, shown());

      // Back to System is the case a record of the resolution callback
      // would miss: Flutter does not call it again.
      for (final AppLanguage language in <AppLanguage>[
        AppLanguage.spanish,
        AppLanguage.system,
        AppLanguage.arabic,
        AppLanguage.chinese,
        AppLanguage.system,
        AppLanguage.english,
      ]) {
        notifier.changeLanguage(language);
        await tester.pumpAndSettle();
        expect(currentAppLocale, shown(), reason: '$language');
        expect(
          currentL10n.localeName,
          shown().languageCode,
          reason: '$language',
        );
      }
    });
  });
}
