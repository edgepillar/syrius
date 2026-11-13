import 'dart:io';

import '../app/fixtures/send_warning_draft.dart';
import '../app/readonly_native_commands.dart'
    show readonlyHomeZapPreviewCommand, readonlySendWarningSyncCommand;
import 'harness.dart' as cli;
import 'readonly_inspection_session.dart';
import 'screen_capture.dart';

/// Literal details defaults, separate from Home, Settings and generic
/// captures.
const String readonlyDetailsCatalogDirectory = '.harness/ci-details-catalog';

/// Fixed, independently readable selections within the Details bundle.
enum ReadonlyDetailsSelection {
  details(1, 'details_catalog', <String>[
    'receive-qr', 'zap-form', 'plasma-fuse', 'set-licences', 'set-originals',
  ], <String>[
    '10-receive-qr-dark.png',
    '10-receive-qr-light.png',
    '11-zap-form-dark.png',
    '11-zap-form-light.png',
    '22-plasma-fuse-dark.png',
    '22-plasma-fuse-light.png',
    '37-set-licences-dark.png',
    '37-set-licences-light.png',
    '38-set-originals-dark.png',
    '38-set-originals-light.png',
  ]),
  tokenDraft(2, 'token_draft_catalog', <String>['token-new'], <String>[
    '25-token-new-dark.png', '25-token-new-light.png',
  ]),
  sendConfirmation(3, 'send_confirm_catalog', <String>['send-confirm'],
    <String>['12-send-confirm-dark.png', '12-send-confirm-light.png'],
  ),
  homeZapPreview(12, 'home_zap_preview_catalog', <String>['home-zap'],
    <String>['06-home-zap-dark.png', '06-home-zap-light.png'],
  ),
  sendWarning(11, 'send_warn_catalog', <String>['send-warn'],
    <String>['08-send-warn-dark.png', '08-send-warn-light.png'],
  ),
  earn(5, 'earn_catalog', <String>['staking-empty', 'pillar-mine'],
    <String>[
      '15-staking-empty-dark.png', '15-staking-empty-light.png',
      '17-pillar-mine-dark.png', '17-pillar-mine-light.png',
    ],
  ),
  sentinelFixture(8, 'sentinel_fixture_catalog', <String>['sentinels'],
    <String>['18-sentinels-dark.png', '18-sentinels-light.png'],
  ),
  swapStart(9, 'swap_start_catalog', <String>['swap-start'],
    <String>['27-swap-start-dark.png', '27-swap-start-light.png'],
  ),
  walletReady(10, 'wallet_ready_catalog', <String>['wallet-ready'],
    <String>['47-wallet-ready-dark.png', '47-wallet-ready-light.png'],
  );

  const ReadonlyDetailsSelection(
    this.schema, this.stage, this.screens, this.files,
  );

  final int schema;
  final String stage;
  final List<String> screens;
  final List<String> files;

  bool get catalogOnly =>
      this == sendConfirmation || this == earn || this == sentinelFixture ||
      this == swapStart || this == walletReady || this == sendWarning ||
      this == homeZapPreview;

  bool get requiresLabRecipient =>
      this == sendConfirmation || this == swapStart;
}

class _DetailsInstance extends cli.Instance {
  _DetailsInstance(this._session) : super('readonly-details-catalog');

  final ReadonlyInspectionSession _session;

  @override
  Map<String, dynamic> read() =>
      throw const ReadonlyInspectionRefused(ReadonlyInspectionReason.process);

  @override
  Future<Map<String, dynamic>> send(
    Map<String, Object?> command, {
    Duration timeout = const Duration(seconds: 30),
  }) => _session.send(command, timeout > const Duration(seconds: 30)
      ? const Duration(seconds: 30) : timeout);
}

Future<void> _typeDraft(cli.Instance instance, String key, String value) async {
  final Map<String, dynamic> typed = await cli.call(instance, <String, Object?>{
    'cmd': 'type', 'key': key, 'exact': true, 'value': value,
  });
  if (typed['value'] != value) {
    throw const ReadonlyInspectionRefused(ReadonlyInspectionReason.reply);
  }
}

Future<void> _prepareWarningContact(cli.Instance instance) async {
  await cli.goto(instance, 'settings');
  await cli.call(instance, <String, Object?>{
    'cmd': 'tap', 'key': 'settings_addresses', 'exact': true,
  });
  await cli.waitForTarget(instance, cli.Args(<String>[
    '--key', 'addresses_add_contact', '--kind', 'button',
    '--exact', '--ready', '--timeout', '20',
  ]));
  await cli.call(instance, <String, Object?>{
    'cmd': 'tap', 'key': 'addresses_add_contact', 'exact': true,
  });
  await cli.call(instance, <String, Object?>{'cmd': 'scroll', 'dy': 440});
  await cli.waitForTarget(instance, cli.Args(<String>[
    '--key', 'addresses_contact_name', '--kind', 'field',
    '--exact', '--ready', '--timeout', '10',
  ]));
  await _typeDraft(instance, 'addresses_contact_name', 'Alice');
  await _typeDraft(
    instance, 'addresses_contact_address', sendWarningKnownAddress,
  );
  await cli.call(instance, <String, Object?>{
    'cmd': 'tap', 'key': 'addresses_save_contact', 'exact': true,
  });
  await cli.waitForTarget(instance, cli.Args(<String>[
    '--key', 'addresses_edit_contact_$sendWarningKnownAddress',
    '--kind', 'button',
    '--exact', '--ready', '--timeout', '10',
  ]));
  await cli.goto(instance, 'dashboard');
}

/// Exports the original step and an optional closed original-reply category.
Map<String, Object>? readonlyDetailsFailureDiagnostic(
  ScreenCaptureObservation? observation, {
  ScreenCaptureReplyCode? reply,
  CaptureFrameState? frameState,
  ReadonlyDetailsSelection selection = ReadonlyDetailsSelection.details,
}) {
  if (observation == null) return null;
  final String? screen = observation.screen;
  final String? theme = observation.theme;
  final int? line = observation.line;
  final bool script = observation.step == ScreenCaptureStep.scriptLine ||
      observation.step == ScreenCaptureStep.afterCaptureLine;
  if ((screen == null) != (theme == null) ||
      screen != null && !selection.screens.contains(screen) ||
      theme != null && theme != 'dark' && theme != 'light' ||
      script && (screen == null || line == null) ||
      line != null && (!script || line < 1 || line > 65535)) {
    return null;
  }
  final CaptureFrameState? originalFrameState =
      const <ScreenCaptureReplyCode>{
        ScreenCaptureReplyCode.frameBusy,
        ScreenCaptureReplyCode.frameDeadlineExceeded,
        ScreenCaptureReplyCode.frameOriginalFailed,
        ScreenCaptureReplyCode.frameAdmissionFailed,
      }.contains(reply) ? frameState : null;
  return <String, Object>{
    'schema': originalFrameState != null ? 3 : reply == null ? 1 : 2,
    'kind': 'readonly_details_capture_failure',
    'last_entered_step': observation.step.name,
    'screen': ?screen, 'theme': ?theme, 'line': ?line,
    'reply': ?reply?.name,
    if (originalFrameState != null) 'frame_state': originalFrameState.toJson(),
  };
}

Map<String, Object?> _sendSyncReceipt(Object? value) {
  const ReadonlyInspectionRefused refused =
      ReadonlyInspectionRefused(ReadonlyInspectionReason.reply);
  if (value is! Map<String, dynamic> || value.length != 3 ||
      !const <String>{
        'alreadyReady', 'refreshReturned', 'refreshTimedOut',
        'refreshRefused', 'formMissing', 'cubitMissing',
      }.contains(value['outcome']) ||
      !value.containsKey('before') || !value.containsKey('after')) {
    throw refused;
  }
  Map<String, Object?>? sample(Object? row) {
    if (row == null) return null;
    if (row is! Map<String, dynamic> || row.length != 3 ||
        !const <String>{'initial', 'loading', 'success', 'failure'}
            .contains(row['status']) ||
        row['timer_active'] is! bool || !row.containsKey('sync')) {
      throw refused;
    }
    final Object? sync = row['sync'];
    if (sync != null &&
        (sync is! Map<String, dynamic> || sync.length != 3 ||
          sync['state'] is! int ||
          !const <int>{0, 1, 2, 3}.contains(sync['state']) ||
          const <String>['current_height', 'target_height'].any((String key) {
            final Object? height = sync[key];
            return height is! int || height < 0 || height > 9007199254740991;
          }))) {
      throw refused;
    }
    return <String, Object?>{
      'status': row['status'], 'timer_active': row['timer_active'],
      'sync': sync,
    };
  }

  return <String, Object?>{
    'outcome': value['outcome'],
    'before': sample(value['before']),
    'after': sample(value['after']),
  };
}

/// Runs the selected details scripts through their original UI owner.
/// Wallet Ready is captured before that owner opens the dashboard.
Future<Map<String, Object>> captureReadonlyDetailsDefaults({
  required Directory repository,
  required ReadonlyInspectionSession session,
  void Function(ScreenCaptureObservation step)? onStep,
  ReadonlyDetailsSelection selection = ReadonlyDetailsSelection.details,
  String? labRecipient,
  Future<void> Function()? requireReady,
  Future<void> Function(String event)? sendWarningWindow,
  Future<void> Function(Map<String, Object?> sample)? sendWarningSync,
}) async {
  final bool sendConfirmation =
      selection == ReadonlyDetailsSelection.sendConfirmation;
  final bool sendWarning = selection == ReadonlyDetailsSelection.sendWarning;
  final bool zapPreview =
      selection == ReadonlyDetailsSelection.homeZapPreview;
  final bool swapStart = selection == ReadonlyDetailsSelection.swapStart;
  final bool walletReady = selection == ReadonlyDetailsSelection.walletReady;
  final bool ownerAdmitted = walletReady
      ? !session.walletBound && requireReady != null
      : session.walletBound && requireReady == null;
  if (!ownerAdmitted ||
      sendWarning != (sendWarningWindow != null) ||
      sendWarning != (sendWarningSync != null) ||
      selection.requiresLabRecipient != (labRecipient != null) ||
      labRecipient?.isEmpty == true) {
    throw const ReadonlyInspectionRefused(ReadonlyInspectionReason.binding);
  }
  final _DetailsInstance instance = _DetailsInstance(session);
  bool warningContactSaved = false;
  bool warningWindowOpened = false;
  bool swapWarningAcknowledged = false;
  final ScreenCapture capture = ScreenCapture(
    repository: repository,
    call: (Map<String, Object?> command) async {
      if (sendWarning && command['cmd'] == 'shot') {
        final String event = switch (command['theme']) {
          'dark' => 'DARK',
          'light' => 'LIGHT',
          _ => throw const ReadonlyInspectionRefused(
            ReadonlyInspectionReason.command,
          ),
        };
        await sendWarningWindow!(event);
      }
      return cli.call(instance, command);
    },
    prepareHome: sendWarning ? () async {
      await session.prepareScreenHome();
      if (!warningContactSaved) {
        await _prepareWarningContact(instance);
        warningContactSaved = true;
      }
    } : requireReady ?? session.prepareScreenHome,
    runLine: (List<String> words) async {
      if (zapPreview) {
        switch (words) {
          case ['preview', 'zap-message']:
            final Map<String, dynamic> opened = await cli.call(
              instance, <String, Object?>{'cmd': readonlyHomeZapPreviewCommand},
            );
            if (opened['fixture'] != 'home-zap-preview') {
              throw const ReadonlyInspectionRefused(
                ReadonlyInspectionReason.reply,
              );
            }
          case ['wait', '--key', final String key] when
              key == 'zap_received_nice' || key == 'home_hero':
            await cli.waitForTarget(instance, cli.Args(<String>[
              '--key', key, '--exact', '--ready', '--timeout', '10',
            ]));
          case ['assert', '--key', 'zap_received_card']:
            await cli.call(instance, <String, Object?>{
              'cmd': 'assert', 'key': 'zap_received_card', 'exact': true,
            });
          case ['tap', '--key', 'zap_received_nice']:
            await cli.call(instance, <String, Object?>{
              'cmd': 'tap', 'key': 'zap_received_nice', 'exact': true,
            });
          default:
            throw const ReadonlyInspectionRefused(
              ReadonlyInspectionReason.command,
            );
        }
        return;
      }
      if (sendWarning) {
        switch (words) {
          case ['goto', final String page] when page == 'transfer' ||
              page == 'dashboard':
            await cli.goto(instance, page);
          case ['tap', '--key', 'transfer_mode_send']:
            await cli.call(instance, <String, Object?>{
              'cmd': 'tap', 'key': 'transfer_mode_send', 'exact': true,
            });
          case ['type', '--key', 'send_recipient_field', '@warning-recipient']:
            await _typeDraft(
              instance, 'send_recipient_field', sendWarningTypedAddress,
            );
          case ['type', '--key', 'send_amount_field', '12.5']:
            await _typeDraft(instance, 'send_amount_field', sendWarningAmount);
          case ['type', '--key', final String key] when
              key == 'send_recipient_field' || key == 'send_amount_field':
            await _typeDraft(instance, key, '');
          case ['wait', '--key', 'send_node_behind']:
            if (!warningWindowOpened) {
              await sendWarningWindow!('BEGIN');
              warningWindowOpened = true;
              final Map<String, dynamic> reply = await cli.call(
                instance,
                <String, Object?>{'cmd': readonlySendWarningSyncCommand},
              );
              await sendWarningSync!(_sendSyncReceipt(reply['sendSync']));
            }
            // The original widget must still become visibly ready.
            await cli.waitForTarget(instance, cli.Args(<String>[
              '--key', 'send_node_behind', '--exact', '--ready',
              '--timeout', '15',
            ]));
          case ['wait', '--key', final String key] when
              key == 'send_form_ready' || key == 'home_hero':
            await cli.waitForTarget(instance, cli.Args(<String>[
              '--key', key, '--exact', '--ready', '--timeout', '15',
            ]));
          case ['assert', '--key', 'send_submit_button']:
            await cli.call(instance, <String, Object?>{
              'cmd': 'assert', 'key': 'send_submit_button', 'exact': true,
            });
          default:
            throw const ReadonlyInspectionRefused(
              ReadonlyInspectionReason.command,
            );
        }
        return;
      }
      if (walletReady) {
        if (words.length != 3 || words[0] != 'assert' ||
            words[1] != '--key' || !const <String>{
              'wallet_ready_screen_marker', 'wallet_ready_card',
              'wallet_ready_address', 'wallet_ready_open',
            }.contains(words[2])) {
          throw const ReadonlyInspectionRefused(
            ReadonlyInspectionReason.command,
          );
        }
        // An assertion reply can contain the disposable wallet's address.
        await cli.call(instance, <String, Object?>{
          'cmd': 'assert', 'key': words[2], 'exact': true,
        });
        return;
      }
      final String? field = words.length >= 3 && words.first == 'type' &&
          words[1] == '--key' ? words[2] : null;
      final bool recipient = selection.requiresLabRecipient &&
          field == (swapStart
              ? 'swap_counterparty_input' : 'send_recipient_field');
      final bool swapAmount = swapStart && field == 'swap_amount_input';
      if (recipient || swapAmount) {
        final String value = switch (words) {
          [_, _, _] when sendConfirmation => '',
          [_, _, _, '@lab-index-0'] when recipient => labRecipient!,
          _ when swapAmount => words.last,
          _ => throw const ReadonlyInspectionRefused(
            ReadonlyInspectionReason.command,
          ),
        };
        final Map<String, Object?> selector = cli.assertionArgs(
          cli.Args(words.sublist(1, words.length == 3 ? 3 : words.length - 1)),
        );
        // The ordinary report includes the field value before and after input.
        final Map<String, dynamic> typed = await cli.call(
          instance, <String, Object?>{
            'cmd': 'type', ...selector, 'value': value,
          },
        );
        if (typed['value'] != value) {
          throw const ReadonlyInspectionRefused(
            ReadonlyInspectionReason.reply,
          );
        }
        return;
      }
      if (swapStart && words.first == 'assert') {
        final Map<String, Object?> selector =
            cli.assertionArgs(cli.Args(words.sublist(1)));
        final Map<String, dynamic> checked = await cli.call(
          instance, <String, Object?>{'cmd': 'assert', ...selector},
        );
        final Object? target = checked['target'];
        if (selector['key'] == 'swap_counterparty_input' &&
            (target is! Map<String, dynamic> ||
                target['value'] != labRecipient)) {
          throw const ReadonlyInspectionRefused(
            ReadonlyInspectionReason.reply,
          );
        }
        return;
      }
      await cli.run(instance, words.first, cli.Args(words.sublist(1)));
      if (swapStart && !swapWarningAcknowledged && words.join(' ') ==
          'tap --key p2p_start_swap --kind button --exact') {
        await cli.waitForTarget(instance, cli.Args(<String>[
          '--key', 'p2p_warning_continue', '--kind', 'button', '--ready',
          '--exact', '--timeout', '10',
        ]));
        await cli.call(instance, <String, Object?>{
          'cmd': 'tap', 'key': 'p2p_warning_continue', 'exact': true,
        });
        swapWarningAcknowledged = true;
      }
    },
    assertionFor: (List<String> words) =>
        selection == ReadonlyDetailsSelection.sentinelFixture
            ? const <String, Object>{
                'key': 'nodes_sentinel_read_scope', 'exact': true,
              }
            : cli.assertionArgs(cli.Args(words.sublist(1))),
    readRailState: walletReady ? null : session.railExpanded,
    restoreRailState: walletReady ? null : session.restoreScreenRail,
    onStep: onStep,
    readonlySendConfirmation: sendConfirmation,
    readonlySendWarning: sendWarning,
    readonlyHomeZapPreview: zapPreview,
    readonlySwapStart: swapStart,
    readonlyEarn: selection == ReadonlyDetailsSelection.earn,
    readonlyWalletReady: walletReady,
  );
  final List<String> captured = await capture.captureSelection(
    selection.screens, directory: readonlyDetailsCatalogDirectory,
  );
  final List<String> files = selection.files;
  if (captured.length != files.length) {
    throw const ReadonlyInspectionRefused(ReadonlyInspectionReason.reply);
  }
  for (int index = 0; index < files.length; index++) {
    final String expected =
        '$readonlyDetailsCatalogDirectory/${files[index]}';
    if (captured[index] != expected) {
      throw const ReadonlyInspectionRefused(ReadonlyInspectionReason.reply);
    }
  }
  return <String, Object>{
    'schema': selection.schema,
    'scope': 'readonly_native_details_catalog_capture',
    'screens': selection.screens, 'themes': const <String>['dark', 'light'],
    'files': files, 'width': 1280, 'height': 780, 'scale': 1,
    'capture_returned': true,
  };
}
