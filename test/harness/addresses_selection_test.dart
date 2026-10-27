import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/send/cubit/send_draft_cubit.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/addresses_settings_presenter.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/addresses_settings_view.dart';

import '../settings_addresses_redesign/support.dart';
import '../welcome/support.dart';

void main() {
  for (final bool revoked in <bool>[false, true]) {
    testWidgets('the original address choice retains its owner $revoked', (
      WidgetTester tester,
    ) async {
      prepareWelcomeViewport(tester);
      final AddressesFixture source = AddressesFixture();
      final AddressesSettingsPresenter presenter = AddressesSettingsPresenter(
        binding: source.bind(),
      );
      final SendDraftCubit draft = SendDraftCubit();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await presenter.close();
        await draft.close();
      });
      await tester.pumpWidget(welcomeHost(Scaffold(
        body: Center(child: SizedBox(width: 1000, height: 650,
          child: AddressesSettingsView(presenter: presenter, draft: draft,
            isCurrent: source.captureView()),
        )),
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final Finder choice = find.byKey(ValueKey<String>(
        'addresses_select_${source.members[1]}',
      ));
      final IconButton original = tester.widget<IconButton>(choice);
      expect(original.onPressed, isNotNull);
      expect(tester.widget<IconButton>(find.byKey(ValueKey<String>(
        'addresses_select_${source.members[0]}',
      ))).onPressed, isNull);
      if (revoked) {
        source.leaveAndReturn();
        original.onPressed!();
      } else {
        await tester.tap(choice);
      }
      await tester.pump();
      expect(source.selections,
        revoked ? isEmpty : <String>[source.members[1]]);
      expect(tester.takeException(), isNull);
    });
  }
}
