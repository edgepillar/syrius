import 'dart:io';

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
  earn(5, 'earn_catalog', <String>['staking-empty', 'pillar-mine'],
    <String>[
      '15-staking-empty-dark.png', '15-staking-empty-light.png',
      '17-pillar-mine-dark.png', '17-pillar-mine-light.png',
    ],
  ),
  sentinelFixture(8, 'sentinel_fixture_catalog', <String>['sentinels'],
    <String>['18-sentinels-dark.png', '18-sentinels-light.png'],
  );

  const ReadonlyDetailsSelection(
    this.schema, this.stage, this.screens, this.files,
  );

  final int schema;
  final String stage;
  final List<String> screens;
  final List<String> files;

  bool get catalogOnly =>
      this == sendConfirmation || this == earn || this == sentinelFixture;
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

/// Exports the original step and an optional closed original-reply category.
Map<String, Object>? readonlyDetailsFailureDiagnostic(
  ScreenCaptureObservation? observation, {
  ScreenCaptureReplyCode? reply,
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
  return <String, Object>{
    'schema': reply == null ? 1 : 2,
    'kind': 'readonly_details_capture_failure',
    'last_entered_step': observation.step.name,
    'screen': ?screen, 'theme': ?theme, 'line': ?line,
    'reply': ?reply?.name,
  };
}

/// Runs the selected details scripts through the same bound UI owner.
/// Each positive shot returns to Home before the next preparation can run.
Future<Map<String, Object>> captureReadonlyDetailsDefaults({
  required Directory repository,
  required ReadonlyInspectionSession session,
  void Function(ScreenCaptureObservation step)? onStep,
  ReadonlyDetailsSelection selection = ReadonlyDetailsSelection.details,
  String? labRecipient,
}) async {
  final bool sendConfirmation =
      selection == ReadonlyDetailsSelection.sendConfirmation;
  if (!session.walletBound ||
      sendConfirmation && (labRecipient == null || labRecipient.isEmpty) ||
      !sendConfirmation && labRecipient != null) {
    throw const ReadonlyInspectionRefused(ReadonlyInspectionReason.binding);
  }
  final _DetailsInstance instance = _DetailsInstance(session);
  final ScreenCapture capture = ScreenCapture(
    repository: repository,
    call: (Map<String, Object?> command) => cli.call(instance, command),
    prepareHome: session.prepareScreenHome,
    runLine: (List<String> words) async {
      if (sendConfirmation && words.length >= 3 && words.first == 'type' &&
          words[1] == '--key' && words[2] == 'send_recipient_field') {
        final String? value = switch (words) {
          [_, _, _] => '',
          [_, _, _, '@lab-index-0'] => labRecipient,
          _ => throw const ReadonlyInspectionRefused(
            ReadonlyInspectionReason.command,
          ),
        };
        // The ordinary report includes the field value before and after input.
        final Map<String, dynamic> typed = await cli.call(
          instance, <String, Object?>{
            'cmd': 'type', 'key': 'send_recipient_field', 'exact': true,
            'value': value,
          },
        );
        if (typed['value'] != value) {
          throw const ReadonlyInspectionRefused(
            ReadonlyInspectionReason.reply,
          );
        }
        return;
      }
      await cli.run(instance, words.first, cli.Args(words.sublist(1)));
    },
    assertionFor: (List<String> words) =>
        selection == ReadonlyDetailsSelection.sentinelFixture
            ? const <String, Object>{
                'key': 'nodes_sentinel_read_scope', 'exact': true,
              }
            : cli.assertionArgs(cli.Args(words.sublist(1))),
    readRailState: session.railExpanded,
    restoreRailState: session.restoreScreenRail,
    onStep: onStep,
    readonlySendConfirmation: sendConfirmation,
    readonlyEarn: selection == ReadonlyDetailsSelection.earn,
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
