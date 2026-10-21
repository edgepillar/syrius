import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/notifications_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/hive/hive_registrar.g.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/services/shared_prefs_service.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notifiers/locale_notifier.dart';
import 'package:zenon_syrius_wallet_flutter/utils/plasma_purpose.dart';

/// How every title began when the notifications bloc still glued it.
const String _opening = 'Plasma will be generated in order to ';

/// The fragment each caller passed before the sentence was moved whole into
/// `app_en.arb`, written out here so that a change of a single character in
/// the English fails.
const Map<PlasmaPurpose, String> _fragments = <PlasmaPurpose, String>{
  PlasmaPurpose.receiveTransaction: 'receive transaction',
  PlasmaPurpose.sendTransaction: 'send transaction',
  PlasmaPurpose.executeTransfer: 'Execute transfer',
  PlasmaPurpose.createStake: 'create stake',
  PlasmaPurpose.cancelStake: 'cancel stake',
  PlasmaPurpose.collectStakingRewards: 'Collect staking rewards',
  PlasmaPurpose.collectPillarRewards: 'Collect Pillar rewards',
  PlasmaPurpose.collectSentinelRewards: 'Collect Sentinel rewards',
  PlasmaPurpose.delegateToPillar: 'delegate to Pillar',
  PlasmaPurpose.undelegate: 'undelegate',
  PlasmaPurpose.fuseQsrForPlasma: 'fuse QSR for Plasma',
  PlasmaPurpose.cancelPlasma: 'cancel Plasma',
  PlasmaPurpose.registerPillar: 'register Pillar',
  PlasmaPurpose.updatePillar: 'update pillar',
  PlasmaPurpose.disassemblePillar: 'disassemble Pillar',
  // "from", as the wallet always showed it.
  PlasmaPurpose.depositQsrForPillarSlot: 'deposit QSR from Pillar Slot',
  PlasmaPurpose.withdrawQsrFromPillarSlot: 'withdraw QSR from Pillar Slot',
  PlasmaPurpose.registerSentinel: 'register Sentinel',
  PlasmaPurpose.disassembleSentinel: 'disassemble Sentinel',
  PlasmaPurpose.depositQsrForSentinelSlot: 'deposit QSR for Sentinel Slot',
  PlasmaPurpose.withdrawQsrFromSentinelSlot: 'withdraw QSR from Sentinel Slot',
  PlasmaPurpose.issueToken: 'issue token',
  PlasmaPurpose.mintToken: 'mint token',
  PlasmaPurpose.burnToken: 'burn token',
  PlasmaPurpose.transferToken: 'transfer token',
  // "creating", as the wallet always showed it.
  PlasmaPurpose.createProject: 'creating project',
  PlasmaPurpose.createPhase: 'create phase',
  PlasmaPurpose.updatePhase: 'update phase',
  PlasmaPurpose.voteForProject: 'vote for project',
  PlasmaPurpose.donateToAccelerator: 'donate for accelerator',
  PlasmaPurpose.startSwap: 'start swap',
  PlasmaPurpose.joinSwap: 'join swap',
  PlasmaPurpose.completeSwap: 'complete swap',
  PlasmaPurpose.reclaimSwapFunds: 'reclaim swap funds',
};

void main() {
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

  setUp(() {
    // The language is the one of the notifier made last.
    LocaleNotifier(AppLanguage.english);
  });

  group('PlasmaPurpose, in English', () {
    test('every purpose has the sentence the wallet showed', () {
      expect(_fragments.keys.toSet(), PlasmaPurpose.values.toSet());
      for (final PlasmaPurpose purpose in PlasmaPurpose.values) {
        final String message = purpose.messageIn(en);
        expect(message, isNotEmpty, reason: purpose.name);
        expect(message, startsWith(_opening), reason: purpose.name);
        expect(message, '$_opening${_fragments[purpose]}');
      }
    });

    test('no sentence starts or ends with a space', () {
      for (final PlasmaPurpose purpose in PlasmaPurpose.values) {
        final String message = purpose.messageIn(en);
        expect(message.trim(), message, reason: purpose.name);
      }
    });

    test('message is the sentence in the language being shown', () {
      for (final PlasmaPurpose purpose in PlasmaPurpose.values) {
        expect(purpose.message, purpose.messageIn(en), reason: purpose.name);
      }
    });

    test('a send for a page names the page', () {
      expect(
        plasmaPurposeSendForDapp('https://example.com', en),
        '${_opening}Send for https://example.com',
      );
      expect(
        plasmaPurposeSendForDapp('https://example.com'),
        '${_opening}Send for https://example.com',
      );
    });
  });

  test('every purpose has a sentence in every language', () {
    for (final Locale locale in AppLocalizations.supportedLocales) {
      final AppLocalizations l10n = lookupAppLocalizations(locale);
      for (final PlasmaPurpose purpose in PlasmaPurpose.values) {
        expect(
          purpose.messageIn(l10n).trim(),
          isNotEmpty,
          reason: '${purpose.name} in $locale',
        );
      }
    }
  });

  group('NotificationsBloc', () {
    late Directory dir;
    late NotificationsBloc bloc;

    // The bloc writes each notification to its box and reads one preference,
    // so both get a folder of their own, never the wallet's.
    setUpAll(() async {
      dir = Directory.systemTemp.createTempSync('syrius_plasma_purpose_');
      Hive
        ..init(dir.path)
        ..registerAdapters();
      sharedPrefsService = await SharedPrefsService.getInstance();
    });

    tearDownAll(() async {
      sharedPrefsService = null;
      await Hive.close();
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });

    setUp(() {
      bloc = NotificationsBloc();
    });

    tearDown(() {
      bloc.dispose();
    });

    test('the Plasma notification carries the whole sentence', () async {
      final Future<WalletNotification?> emitted = bloc.stream.first;

      await bloc.sendPlasmaNotification(
        PlasmaPurpose.fuseQsrForPlasma.message,
      );

      final WalletNotification? notification = await emitted;
      expect(
        notification?.title,
        'Plasma will be generated in order to fuse QSR for Plasma',
      );
      expect(
        notification?.details,
        'Plasma will be generated for this account-block',
      );
      expect(notification?.type, NotificationType.generatingPlasma);

      // What is kept is that same finished text.
      final Object? stored = Hive.box<dynamic>(kNotificationsBox).values.last;
      expect(
        (stored as WalletNotification?)?.title,
        'Plasma will be generated in order to fuse QSR for Plasma',
      );
    });

    test('the title is the message as given, with nothing put before it',
        () async {
      final Future<WalletNotification?> emitted = bloc.stream.first;

      await bloc.sendPlasmaNotification(
        plasmaPurposeSendForDapp('https://example.com'),
      );

      expect(
        (await emitted)?.title,
        'Plasma will be generated in order to Send for https://example.com',
      );
    });

    test('an error notification gives the title, then the error', () async {
      final Future<WalletNotification?> emitted = bloc.stream.first;

      await bloc.addErrorNotification(
        Exception('boom'),
        'Error while sending transaction',
      );

      final WalletNotification? notification = await emitted;
      expect(notification?.title, 'Error while sending transaction');
      expect(
        notification?.details,
        'Error while sending transaction: Exception: boom',
      );
      expect(notification?.type, NotificationType.error);
    });
  });

  test('notificationErrorWithDetails, in English', () {
    expect(
      en.notificationErrorWithDetails('Title', 'the error'),
      'Title: the error',
    );
    expect(en.notificationErrorWithDetails('Title', 42), 'Title: 42');
    expect(en.notificationEmptyTitle, 'Empty title');
    expect(en.notificationNoDetails, 'No details available');
  });
}
