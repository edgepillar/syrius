import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations_en.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/send/widgets/send_populated.dart';

const String _own = 'z1qqjnwjjpnue8xmmpanz6csze6tcmtzzdtfsww7';
const String _other = 'z1qr4pexnnfaexqqz8nscjjcsajy5hdqfkgadvwx';

void main() {
  group('sentPartyName', () {
    test('a labelled address is named by its label', () {
      expect(
        sentPartyName(_own, <String, String>{_own: 'Address 2'}),
        'Address 2',
      );
    });

    test('an unlabelled address keeps both ends and loses its middle', () {
      expect(sentPartyName(_other, <String, String>{}), 'z1qr4pex…gadvwx');
    });

    test('an empty label is no label', () {
      expect(
        sentPartyName(_other, <String, String>{_other: ''}),
        'z1qr4pex…gadvwx',
      );
    });
  });

  group('sentNotificationTitle', () {
    String title(BigInt amount, {int decimals = 8}) => sentNotificationTitle(
      l10n: AppLocalizationsEn(),
      amount: amount,
      decimals: decimals,
      symbol: 'ZNN',
      sender: _own,
      recipient: _other,
      labels: <String, String>{_own: 'Address 2'},
    );

    test('carries the amount, the symbol, the sender and the recipient', () {
      expect(
        title(BigInt.from(150000000)),
        'Sent 1.5 ZNN from Address 2 to z1qr4pex…gadvwx',
      );
    });

    test('a whole amount shows no decimals', () {
      expect(
        title(BigInt.from(200000000)),
        'Sent 2 ZNN from Address 2 to z1qr4pex…gadvwx',
      );
    });

    test('the smallest unit is shown in full', () {
      expect(
        title(BigInt.one),
        'Sent 0.00000001 ZNN from Address 2 to z1qr4pex…gadvwx',
      );
    });

    test('no part is ever empty', () {
      expect(title(BigInt.from(100000000)), isNot(contains('  ')));
      expect(title(BigInt.from(100000000)), isNot(endsWith('to ')));
    });
  });
}
