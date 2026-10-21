import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/infinite_scroll_table/cells/receive_cell.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

void main() {
  final Hash first = Hash.digest(<int>[1]);
  final Hash second = Hash.digest(<int>[2]);
  late AutoReceiveTxWorker worker;

  setUp(() {
    worker = AutoReceiveTxWorker();
    sl.registerSingleton<AutoReceiveTxWorker>(worker);
  });

  tearDown(() async => sl.reset());

  IconButton button(WidgetTester tester, Hash hash) => tester.widget<IconButton>(
        find.byKey(ValueKey<String>('receive_$hash')),
      );

  testWidgets('the button of a row whose receive is under way is off, '
      'and the other rows keep theirs', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Row(
            children: <Widget>[
              // A cell is its own Expanded.
              ReceiveCell(hash: first),
              ReceiveCell(hash: second),
            ],
          ),
        ),
      ),
    );
    expect(button(tester, first).onPressed, isNotNull);
    expect(button(tester, second).onPressed, isNotNull);

    worker.inFlight.value = <Hash>{first};
    await tester.pump();
    expect(button(tester, first).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(button(tester, second).onPressed, isNotNull);

    worker.inFlight.value = <Hash>{};
    await tester.pump();
    expect(button(tester, first).onPressed, isNotNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  test('a receive that fails before it is published unblocks its row',
      () async {
    // No node: the first request throws.
    zenon = null;
    final List<Set<Hash>> seen = <Set<Hash>>[];
    worker.inFlight.addListener(() => seen.add(worker.inFlight.value));
    await expectLater(
      worker.autoReceiveTransactionHash(first),
      throwsA(anything),
    );
    expect(seen.first, <Hash>{first}, reason: 'blocked while it ran');
    expect(worker.inFlight.value, isEmpty);
    expect(worker.running, isFalse);
  });
}
