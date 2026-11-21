import 'dart:io';

import '../app/fixtures/home_goto_contact.dart';
import 'harness.dart' as cli;
import 'readonly_catalog_contact.dart';
import 'readonly_inspection_session.dart';
import 'screen_capture.dart';

/// A distinct output family, separate from the generic page tour.
const String readonlyHomeCatalogDirectory = '.harness/ci-home-catalog';

const List<String> _files = <String>[
  '01-home-rest-dark.png', '01-home-rest-light.png',
];

/// Exports only the original step and a closed original-reply category.
Map<String, Object>? readonlyHomeFailureDiagnostic(
  ScreenCaptureObservation? observation, {
  ScreenCaptureReplyCode? reply,
  CaptureFrameState? frameState,
}) {
  if (observation == null) return null;
  final String? screen = observation.screen;
  final String? theme = observation.theme;
  final int? line = observation.line;
  const Set<String> screens = <String>{
    'home-rest', 'home-open', 'home-hidden', 'home-goto', 'home-bell',
  };
  final bool script = observation.step == ScreenCaptureStep.scriptLine ||
      observation.step == ScreenCaptureStep.afterCaptureLine;
  if ((screen == null) != (theme == null) ||
      screen != null && !screens.contains(screen) ||
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
    'kind': 'readonly_home_capture_failure',
    'last_entered_step': observation.step.name,
    'screen': ?screen, 'theme': ?theme, 'line': ?line,
    'reply': ?reply?.name,
    if (originalFrameState != null) 'frame_state': originalFrameState.toJson(),
  };
}

class _CatalogInstance extends cli.Instance {
  _CatalogInstance(this._session) : super('readonly-home-catalog');

  final ReadonlyInspectionSession _session;

  // Every request retains the original session; no alternate receipt opens.
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

/// Executes the real catalog script through the original bound UI session.
/// Completion retains the runner's original rail/theme/window restoration.
Future<Map<String, Object>> captureReadonlyHomeRest({
  required Directory repository,
  required ReadonlyInspectionSession session,
}) async {
  if (!session.walletBound) {
    throw const ReadonlyInspectionRefused(ReadonlyInspectionReason.binding);
  }
  final ScreenCapture capture = _homeCapture(
    repository: repository, session: session,
  );
  final List<String> captured = await capture.capture(
    'home-rest', directory: readonlyHomeCatalogDirectory,
  );
  if (captured.length != 2 ||
      captured[0] != '$readonlyHomeCatalogDirectory/${_files[0]}' ||
      captured[1] != '$readonlyHomeCatalogDirectory/${_files[1]}') {
    throw const ReadonlyInspectionRefused(ReadonlyInspectionReason.reply);
  }
  return <String, Object>{
    'schema': 1, 'scope': 'readonly_native_home_catalog_capture',
    'screen': 'home-rest', 'number': 1,
    'themes': const <String>['dark', 'light'], 'files': _files,
    'width': 1280, 'height': 780, 'scale': 1, 'capture_returned': true,
  };
}

// Every entry point keeps the bound transport and original UI helpers.
ScreenCapture _homeCapture({
  required Directory repository,
  required ReadonlyInspectionSession session,
  void Function(ScreenCaptureObservation step)? onStep,
  bool withGoToContact = false,
}) {
  final _CatalogInstance instance = _CatalogInstance(session);
  bool contactSaved = false;
  bool isGoToResultAssertion(List<String> words) =>
      withGoToContact && switch (words) {
        ['assert', '--key', 'go_to_results'] => true,
        _ => false,
      };
  return ScreenCapture(
    repository: repository,
    call: (Map<String, Object?> command) => cli.call(instance, command),
    prepareHome: session.prepareScreenHome,
    runLine: (List<String> words) async {
      if (withGoToContact && !contactSaved &&
          words.length == 2 && words[0] == 'key' && words[1] == 'ctrl+k') {
        await prepareReadonlyCatalogContact(
          instance, name: homeGotoContactName,
        );
        contactSaved = true;
      }
      await cli.run(instance, words.first, cli.Args(words.sublist(1)));
      if (isGoToResultAssertion(words)) {
        await cli.call(instance, <String, Object?>{
          'cmd': 'assert', 'key': homeGotoContactKey, 'exact': true,
        });
      }
    },
    assertionFor: (List<String> words) => cli.assertionArgs(cli.Args(
      isGoToResultAssertion(words)
          ? <String>['--key', homeGotoContactKey]
          : words.sublist(1),
    )),
    readRailState: session.railExpanded,
    restoreRailState: session.restoreScreenRail,
    onStep: onStep,
  );
}

/// Captures the two authored Home states in one fresh output directory.
/// Hidden balances are restored only after each durably retained positive shot.
Future<Map<String, Object>> captureReadonlyHomeStates({
  required Directory repository,
  required ReadonlyInspectionSession session,
}) async {
  if (!session.walletBound) {
    throw const ReadonlyInspectionRefused(ReadonlyInspectionReason.binding);
  }
  final ScreenCapture capture = _homeCapture(
    repository: repository, session: session,
  );
  const List<String> files = <String>[
    '01-home-rest-dark.png', '01-home-rest-light.png',
    '03-home-hidden-dark.png', '03-home-hidden-light.png',
  ];
  final List<String> captured = await capture.captureSelection(
    const <String>['home-rest', 'home-hidden'],
    directory: readonlyHomeCatalogDirectory,
  );
  if (captured.length != files.length) {
    throw const ReadonlyInspectionRefused(ReadonlyInspectionReason.reply);
  }
  for (int index = 0; index < files.length; index++) {
    if (captured[index] != '$readonlyHomeCatalogDirectory/${files[index]}') {
      throw const ReadonlyInspectionRefused(ReadonlyInspectionReason.reply);
    }
  }
  return <String, Object>{
    'schema': 2, 'scope': 'readonly_native_home_catalog_capture',
    'screens': const <String>['home-rest', 'home-hidden'],
    'themes': const <String>['dark', 'light'], 'files': files,
    'width': 1280, 'height': 780, 'scale': 1, 'capture_returned': true,
  };
}

/// Captures three authored Home states in one fresh output directory.
/// Tokens and balances restore after each durably retained positive shot.
Future<Map<String, Object>> captureReadonlyHomeOpenStates({
  required Directory repository,
  required ReadonlyInspectionSession session,
}) async {
  if (!session.walletBound) {
    throw const ReadonlyInspectionRefused(ReadonlyInspectionReason.binding);
  }
  final ScreenCapture capture = _homeCapture(
    repository: repository, session: session,
  );
  const List<String> files = <String>[
    '01-home-rest-dark.png', '01-home-rest-light.png',
    '02-home-open-dark.png', '02-home-open-light.png',
    '03-home-hidden-dark.png', '03-home-hidden-light.png',
  ];
  final List<String> captured = await capture.captureSelection(
    const <String>['home-rest', 'home-open', 'home-hidden'],
    directory: readonlyHomeCatalogDirectory,
  );
  if (captured.length != files.length) {
    throw const ReadonlyInspectionRefused(ReadonlyInspectionReason.reply);
  }
  for (int index = 0; index < files.length; index++) {
    if (captured[index] != '$readonlyHomeCatalogDirectory/${files[index]}') {
      throw const ReadonlyInspectionRefused(ReadonlyInspectionReason.reply);
    }
  }
  return <String, Object>{
    'schema': 3, 'scope': 'readonly_native_home_catalog_capture',
    'screens': const <String>['home-rest', 'home-open', 'home-hidden'],
    'themes': const <String>['dark', 'light'], 'files': files,
    'width': 1280, 'height': 780, 'scale': 1, 'capture_returned': true,
  };
}

/// Captures four authored Home states in one fresh output directory.
/// Tokens, balances and the palette restore only after each
/// durably retained positive shot.
Future<Map<String, Object>> captureReadonlyHomeGotoStates({
  required Directory repository,
  required ReadonlyInspectionSession session,
  void Function(ScreenCaptureObservation step)? onStep,
  bool observeRailMotion = false,
}) async {
  if (!session.walletBound) {
    throw const ReadonlyInspectionRefused(ReadonlyInspectionReason.binding);
  }
  final ScreenCapture capture = _homeCapture(
    repository: repository, session: session, onStep: onStep,
    withGoToContact: true,
  );
  const List<String> files = <String>[
    '01-home-rest-dark.png', '01-home-rest-light.png',
    '02-home-open-dark.png', '02-home-open-light.png',
    '03-home-hidden-dark.png', '03-home-hidden-light.png',
    '05-home-goto-dark.png', '05-home-goto-light.png',
  ];
  final List<String> captured = await capture.captureSelection(
    const <String>[
      'home-rest', 'home-open', 'home-hidden', 'home-goto',
    ],
    directory: readonlyHomeCatalogDirectory,
  );
  if (captured.length != files.length) {
    throw const ReadonlyInspectionRefused(ReadonlyInspectionReason.reply);
  }
  for (int index = 0; index < files.length; index++) {
    if (captured[index] != '$readonlyHomeCatalogDirectory/${files[index]}') {
      throw const ReadonlyInspectionRefused(ReadonlyInspectionReason.reply);
    }
  }
  return <String, Object>{
    'schema': 4, 'scope': 'readonly_native_home_catalog_capture',
    'screens': const <String>[
      'home-rest', 'home-open', 'home-hidden', 'home-goto',
    ],
    'themes': const <String>['dark', 'light'], 'files': files,
    'width': 1280, 'height': 780, 'scale': 1, 'capture_returned': true,
    if (observeRailMotion) 'rail_motion': await session.observeRailMotion(),
  };
}

/// Captures the two Bell states through the already bound Home session.
Future<Map<String, Object>> captureReadonlyHomeBell({
  required Directory repository,
  required ReadonlyInspectionSession session,
  void Function(ScreenCaptureObservation step)? onStep,
}) async {
  if (!session.walletBound) {
    throw const ReadonlyInspectionRefused(ReadonlyInspectionReason.binding);
  }
  final ScreenCapture capture = _homeCapture(
    repository: repository, session: session, onStep: onStep,
  );
  const List<String> files = <String>[
    '04-home-bell-dark.png', '04-home-bell-light.png',
  ];
  final List<String> captured = await capture.capture(
    'home-bell', directory: readonlyHomeCatalogDirectory,
  );
  if (captured.length != files.length ||
      captured[0] != '$readonlyHomeCatalogDirectory/${files[0]}' ||
      captured[1] != '$readonlyHomeCatalogDirectory/${files[1]}') {
    throw const ReadonlyInspectionRefused(ReadonlyInspectionReason.reply);
  }
  return <String, Object>{
    'schema': 5, 'scope': 'readonly_native_home_catalog_capture',
    'screens': const <String>['home-bell'],
    'themes': const <String>['dark', 'light'], 'files': files,
    'width': 1280, 'height': 780, 'scale': 1, 'capture_returned': true,
  };
}
