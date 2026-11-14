import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/disclosure.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notifiers/balance_visibility.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';

typedef _Levels = InfiniteListState<PlasmaInfoWrapper>;

class _Stats extends MockBloc<InfiniteListEvent, _Levels>
    implements PlasmaStatsBloc {}

void main() {
  for (final bool dark in <bool>[false, true]) {
    for (final double height in <double>[360, 674]) {
      testWidgets(
        'other addresses stays at the foot in '
        '${dark ? 'dark' : 'light'} at $height',
        (WidgetTester tester) async {
          final String? previousAddress = kSelectedAddress;
          kSelectedAddress = null;
          final SelectedAddressNotifier selection = SelectedAddressNotifier();
          final _Stats stats = _Stats();
          whenListen(
            stats,
            const Stream<_Levels>.empty(),
            initialState: const _Levels(
              status: InfiniteListStatus.success,
              data: <PlasmaInfoWrapper>[],
              hasReachedMax: true,
            ),
          );
          when(() => stats.hasCurrentRead).thenReturn(true);
          when(() => stats.currentReadings).thenReturn(
            const <PlasmaInfoWrapper>[],
          );
          when(() => stats.currentReading(any())).thenReturn(null);
          BalanceVisibility.debugReset();
          tester.view.physicalSize = const Size(1280, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(() async {
            try {
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump();
            } finally {
              selection.dispose();
              kSelectedAddress = previousAddress;
              BalanceVisibility.debugReset();
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            }
          });

          await tester.pumpWidget(
            ChangeNotifierProvider<SelectedAddressNotifier>.value(
              value: selection,
              child: BlocProvider<PlasmaStatsBloc>.value(
                value: stats,
                child: MaterialApp(
                  theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
                  locale: const Locale('en'),
                  localizationsDelegates: appLocalizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Scaffold(
                    body: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        key: const Key('plasma_layout_slot'),
                        width: 340,
                        height: height,
                        child: const PlasmaStatsCard(
                          version: PlasmaStatsWidgetVersion.plasmaTab,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          final Rect card = tester.getRect(
            find.byKey(const Key('plasma_layout_slot')),
          );
          final Finder toggle = find.byKey(
            const ValueKey<String>('plasma_other_addresses_toggle'),
          );
          final Finder mark = find.byKey(const Key('plasma_page_mark'));
          final State<PlasmaGlow> glow = tester.state<State<PlasmaGlow>>(mark);
          final Finder disclosure = find.byKey(
            const Key('plasma_other_addresses'),
          );
          final Element originalDisclosure = tester.element(disclosure);
          expect(tester.getBottomRight(toggle).dy, card.bottom);
          final double restingTop = tester.getTopLeft(toggle).dy;

          await tester.tap(toggle);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 60));
          final double openingTop = tester.getTopLeft(toggle).dy;
          expect(openingTop, lessThan(restingTop));
          await tester.pump(const Duration(milliseconds: 240));
          final double openTop = tester.getTopLeft(toggle).dy;
          expect(openTop, lessThan(openingTop));
          expect(openTop, greaterThan(card.top + card.height * .35));
          expect(openTop, lessThan(card.top + card.height * .65));
          expect(tester.state<State<PlasmaGlow>>(mark), same(glow));
          expect(tester.element(disclosure), same(originalDisclosure));
          expect(tester.takeException(), isNull);

          await tester.tap(toggle);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 60));
          final double closingTop = tester.getTopLeft(toggle).dy;
          expect(closingTop, greaterThan(openTop));
          expect(closingTop, lessThan(restingTop));
          await tester.pump(const Duration(milliseconds: 240));
          expect(tester.getBottomRight(toggle).dy, card.bottom);
          expect(tester.state<State<PlasmaGlow>>(mark), same(glow));
          expect(tester.element(disclosure), same(originalDisclosure));
          expect(tester.widget<Disclosure>(disclosure).keepAlive, isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
