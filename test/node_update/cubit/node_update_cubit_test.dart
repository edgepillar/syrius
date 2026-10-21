// The Embedded node panel's cubit, over a fake loader and a fake updater:
// what each button asks for, and what is never asked without one.

import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/embedded_node/node_archive.dart';
import 'package:zenon_syrius_wallet_flutter/embedded_node/node_library.dart';
import 'package:zenon_syrius_wallet_flutter/embedded_node/node_updater.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/node_update/cubit/node_update_cubit.dart';

import '../support.dart';

TypeMatcher<NodeUpdatePanelState> _step<T extends NodeUpdateStep>([
  Object? Function(T step)? read,
  Object? expected,
]) => isA<NodeUpdatePanelState>().having(
  (NodeUpdatePanelState state) => state.step,
  'step',
  read == null ? isA<T>() : isA<T>().having(read, 'value', expected),
);

TypeMatcher<NodeUpdatePanelState> _check<T extends NodeUpdateCheck>([
  Object? Function(T check)? read,
  Object? expected,
]) => isA<NodeUpdatePanelState>().having(
  (NodeUpdatePanelState state) => state.check,
  'check',
  read == null ? isA<T>() : isA<T>().having(read, 'value', expected),
);

Matcher _downloading(int received, int total) => _step<NodeUpdateDownloading>(
  (NodeUpdateDownloading step) => <int>[step.received, step.total],
  <int>[received, total],
);

void main() {
  late FakeNodeLibrary library;
  late FakeNodeUpdater updater;

  /// The updaters asked for, by repository. One for the default repository
  /// is ready; whether it was asked for is in [asked].
  late Map<String, FakeNodeUpdater> updaters;
  late List<String> asked;
  late List<String> saved;

  NodeUpdateCubit build({String? repository}) => NodeUpdateCubit(
    library: library,
    repository: repository,
    updaterFor: (NodeUpdateSource source) {
      asked.add(source.repository);
      return updaters.putIfAbsent(
        source.repository,
        () => FakeNodeUpdater(library, source),
      );
    },
    saveRepository: (String repository) async => saved.add(repository),
  );

  /// Loads, checks and downloads: where every install from a release starts.
  Future<void> toDownload(NodeUpdateCubit cubit) async {
    await cubit.load();
    await cubit.check();
    await cubit.download();
  }

  setUp(() {
    library = FakeNodeLibrary();
    updater = FakeNodeUpdater(library)..latest = releaseOf();
    updaters = <String, FakeNodeUpdater>{kRepo: updater};
    asked = <String>[];
    saved = <String>[];
  });

  group('opening the panel', () {
    blocTest<NodeUpdateCubit, NodeUpdatePanelState>(
      'reads the disk and asks the network nothing',
      build: build,
      act: (NodeUpdateCubit cubit) => cubit.load(),
      expect: () => <Matcher>[
        isA<NodeUpdatePanelState>()
            .having(
              (NodeUpdatePanelState state) => state.load,
              'load',
              NodeUpdateLoad.ready,
            )
            .having(
              (NodeUpdatePanelState state) => state.library,
              'library',
              same(library.current),
            ),
      ],
      verify: (NodeUpdateCubit cubit) {
        expect(asked, isEmpty, reason: 'no updater was even made');
        expect(updater.calls, isEmpty);
        expect(cubit.state.check, isA<NodeUpdateCheckIdle>());
        expect(cubit.state.repository, kRepo);
      },
    );

    blocTest<NodeUpdateCubit, NodeUpdatePanelState>(
      'a folder that cannot be read is a failed panel',
      build: () {
        library.statusFailure = const FileSystemException('denied');
        return build();
      },
      act: (NodeUpdateCubit cubit) => cubit.load(),
      expect: () => <Matcher>[
        isA<NodeUpdatePanelState>().having(
          (NodeUpdatePanelState state) => state.load,
          'load',
          NodeUpdateLoad.failed,
        ),
      ],
    );

    test('a saved repository that is not owner/name is the default', () async {
      final NodeUpdateCubit cubit = build(repository: '../../etc');
      expect(cubit.state.repository, kRepo);
      await cubit.close();
    });
  });

  group('check', () {
    blocTest<NodeUpdateCubit, NodeUpdatePanelState>(
      'asks for the latest release once and compares it',
      build: build,
      act: (NodeUpdateCubit cubit) async {
        await cubit.load();
        await cubit.check();
      },
      skip: 1,
      expect: () => <Matcher>[
        _check<NodeUpdateCheckRunning>(),
        // The bundled library has no tag to compare a release with.
        _check<NodeUpdateCheckDone>(
          (NodeUpdateCheckDone check) => <Object?>[
            check.release,
            check.comparison,
            check.downloadable,
          ],
          <Object?>[same(updater.latest), NodeUpdateState.unknown, true],
        ),
      ],
      verify: (_) {
        expect(updater.calls, <String>['latestRelease $kRepo']);
      },
    );

    blocTest<NodeUpdateCubit, NodeUpdatePanelState>(
      'an installed release of another tag is an update available',
      build: () {
        library.current = statusOf(
          installed: manifestOf(tag: 'v0.0.8', sha256: kOldSha),
        );
        return build();
      },
      act: (NodeUpdateCubit cubit) async {
        await cubit.load();
        await cubit.check();
      },
      skip: 2,
      expect: () => <Matcher>[
        _check<NodeUpdateCheckDone>(
          (NodeUpdateCheckDone check) => check.comparison,
          NodeUpdateState.updateAvailable,
        ),
      ],
    );

    blocTest<NodeUpdateCubit, NodeUpdatePanelState>(
      'the installed release is up to date and is not offered again',
      build: () {
        library.current = statusOf(installed: manifestOf());
        return build();
      },
      act: toDownload,
      skip: 2,
      expect: () => <Matcher>[
        _check<NodeUpdateCheckDone>(
          (NodeUpdateCheckDone check) => <Object?>[
            check.comparison,
            check.downloadable,
          ],
          <Object?>[NodeUpdateState.upToDate, false],
        ),
      ],
      verify: (_) {
        expect(updater.calls, <String>['latestRelease $kRepo']);
      },
    );

    blocTest<NodeUpdateCubit, NodeUpdatePanelState>(
      'a repository with no release answers with none',
      build: () {
        updater.latest = null;
        return build();
      },
      act: toDownload,
      skip: 2,
      expect: () => <Matcher>[
        _check<NodeUpdateCheckDone>(
          (NodeUpdateCheckDone check) => <Object?>[
            check.release,
            check.downloadable,
          ],
          <Object?>[null, false],
        ),
      ],
    );

    blocTest<NodeUpdateCubit, NodeUpdatePanelState>(
      'a release with no library for this platform cannot be downloaded',
      build: () {
        updater.latest = releaseOf(withAsset: false);
        return build();
      },
      act: toDownload,
      skip: 2,
      expect: () => <Matcher>[
        _check<NodeUpdateCheckDone>(
          (NodeUpdateCheckDone check) => check.downloadable,
          false,
        ),
      ],
      verify: (_) {
        expect(updater.calls, <String>['latestRelease $kRepo']);
      },
    );

    for (final NodeUpdateException error in <NodeUpdateException>[
      NodeUpdateRateLimited(resetAt: DateTime.utc(2026, 10, 13, 12)),
      const NodeUpdateNetworkError('no route'),
      const NodeUpdateHttpError(404),
      const NodeUpdateMalformedResponse('not JSON'),
      NodeUpdateForbiddenUrl(Uri.parse('https://example.com/x')),
    ]) {
      blocTest<NodeUpdateCubit, NodeUpdatePanelState>(
        '${error.runtimeType} is that failure, and Check can be pressed again',
        build: () {
          updater.latest = error;
          return build();
        },
        act: (NodeUpdateCubit cubit) async {
          await cubit.load();
          await cubit.check();
        },
        skip: 2,
        expect: () => <Matcher>[
          _check<NodeUpdateCheckFailed>(
            (NodeUpdateCheckFailed check) => check.error,
            same(error),
          ),
        ],
        verify: (NodeUpdateCubit cubit) => expect(cubit.state.idle, isTrue),
      );
    }
  });

  group('download', () {
    blocTest<NodeUpdateCubit, NodeUpdatePanelState>(
      'does nothing before a release has been checked',
      build: build,
      act: (NodeUpdateCubit cubit) async {
        await cubit.load();
        await cubit.download();
      },
      skip: 1,
      expect: () => <Matcher>[],
      verify: (_) => expect(updater.calls, isEmpty),
    );

    blocTest<NodeUpdateCubit, NodeUpdatePanelState>(
      'reports progress, then waits for the answer with nothing installed',
      build: () {
        updater.downloads.add(downloadedOf());
        return build();
      },
      act: (NodeUpdateCubit cubit) async {
        await toDownload(cubit);
        // Asserted here: closing the cubit, which the harness does next,
        // deletes a library nobody answered for.
        expect(updater.calls, <String>[
          'latestRelease $kRepo',
          'download $kTag allowUnverified=false',
        ]);
        expect(cubit.state.idle, isFalse);
        // Its hash is known now, and it is not the bundled library's.
        expect(
          (cubit.state.check as NodeUpdateCheckDone).comparison,
          NodeUpdateState.updateAvailable,
        );
      },
      skip: 3,
      expect: () => <Matcher>[
        _downloading(0, 100),
        _downloading(50, 100),
        _downloading(100, 100),
        _step<NodeUpdateConfirmAsk>(
          (NodeUpdateConfirmAsk step) => step.library.sha256,
          kNewSha,
        ),
      ],
    );

    blocTest<NodeUpdateCubit, NodeUpdatePanelState>(
      'Cancel stops it and leaves nothing to confirm',
      build: () {
        updater
          ..hold = Completer<void>()
          ..downloads.add(downloadedOf());
        return build();
      },
      act: (NodeUpdateCubit cubit) async {
        await cubit.load();
        await cubit.check();
        final Future<void> download = cubit.download();
        await pumpEventQueue();
        cubit.cancelDownload();
        await download;
      },
      skip: 3,
      expect: () => <Matcher>[
        _downloading(0, 100),
        _downloading(50, 100),
        _downloading(100, 100),
        _step<NodeUpdateStepIdle>(),
      ],
      verify: (_) {
        expect(updater.downloads, hasLength(1), reason: 'never handed out');
        expect(
          updater.calls.where((String c) => c.startsWith('stage')),
          isEmpty,
        );
      },
    );

    for (final NodeUpdateException error in <NodeUpdateException>[
      NodeUpdateRateLimited(resetAt: DateTime.utc(2026, 10, 13, 12)),
      const NodeUpdateNetworkError('reset by peer'),
      const NodeUpdateHttpError(500),
      const NodeUpdateTooLarge(NodeUpdater.defaultMaxBytes),
      const NodeUpdateSizeMismatch(expected: 100, actual: 60),
      const NodeUpdateDigestMismatch(
        check: NodeDigestSource.checksumFile,
        expected: kNewSha,
        actual: kOldSha,
      ),
      const NodeUpdateChecksumConflict(
        checksumFile: kNewSha,
        apiDigest: kOldSha,
      ),
      const NodeUpdateMalformedChecksums('a line is not a checksum'),
      NodeUpdateArchiveError(NodeArchiveProblem.memberMissing, 'no libznn'),
      const NodeUpdateNoAsset(kTag),
      const NodeUpdateFileError('disk full'),
    ]) {
      blocTest<NodeUpdateCubit, NodeUpdatePanelState>(
        '${error.runtimeType} is that failure, with nothing to confirm',
        build: () {
          updater.downloads.add(error);
          return build();
        },
        act: toDownload,
        skip: 6,
        expect: () => <Matcher>[
          _step<NodeUpdateStepFailed>(
            (NodeUpdateStepFailed step) => step.error,
            same(error),
          ),
        ],
        verify: (NodeUpdateCubit cubit) {
          expect(cubit.state.idle, isTrue);
          expect(
            updater.calls.where((String c) => c.startsWith('stage')),
            isEmpty,
          );
        },
      );
    }
  });

  group('a verified download', () {
    blocTest<NodeUpdateCubit, NodeUpdatePanelState>(
      'is staged only by the confirmation',
      build: () {
        updater.downloads.add(downloadedOf());
        return build();
      },
      act: (NodeUpdateCubit cubit) async {
        await toDownload(cubit);
        expect(updater.calls, isNot(contains('stage $kNewSha')));
        await cubit.confirmInstall();
      },
      skip: 7,
      expect: () => <Matcher>[
        _step<NodeUpdateStaging>(),
        _step<NodeUpdateStepIdle>()
            .having(
              (NodeUpdatePanelState state) => state.library?.staged?.sha256,
              'staged',
              kNewSha,
            )
            .having(
              (NodeUpdatePanelState state) =>
                  (state.check as NodeUpdateCheckDone).comparison,
              'comparison',
              NodeUpdateState.staged,
            ),
      ],
      verify: (_) {
        expect(updater.calls, <String>[
          'latestRelease $kRepo',
          'download $kTag allowUnverified=false',
          'stage $kNewSha',
        ]);
      },
    );

    blocTest<NodeUpdateCubit, NodeUpdatePanelState>(
      'is deleted by Cancel, and nothing is staged',
      build: () {
        updater.downloads.add(downloadedOf());
        return build();
      },
      act: (NodeUpdateCubit cubit) async {
        await toDownload(cubit);
        cubit.cancelInstall();
        // The answer has been given; a late yes installs nothing.
        await cubit.confirmInstall();
      },
      skip: 7,
      expect: () => <Matcher>[_step<NodeUpdateStepIdle>()],
      verify: (NodeUpdateCubit cubit) {
        expect(updater.calls.last, 'discard $kNewSha');
        expect(updater.calls, isNot(contains('stage $kNewSha')));
        expect(cubit.state.library?.staged, isNull);
      },
    );

    blocTest<NodeUpdateCubit, NodeUpdatePanelState>(
      'that cannot be staged is a failure',
      build: () {
        updater
          ..downloads.add(downloadedOf())
          ..stageFailure = const NodeUpdateFileError('changed on disk');
        return build();
      },
      act: (NodeUpdateCubit cubit) async {
        await toDownload(cubit);
        await cubit.confirmInstall();
      },
      skip: 8,
      expect: () => <Matcher>[
        _step<NodeUpdateStepFailed>(
          (NodeUpdateStepFailed step) => step.error,
          same(updater.stageFailure),
        ),
      ],
      verify: (NodeUpdateCubit cubit) {
        expect(cubit.state.library?.staged, isNull);
      },
    );

    test('a confirmation nobody was asked for installs nothing', () async {
      final NodeUpdateCubit cubit = build();
      await cubit.load();
      await cubit.confirmInstall();
      expect(asked, isEmpty);
      expect(cubit.state.step, isA<NodeUpdateStepIdle>());
      await cubit.close();
    });
  });

  group('a release that publishes no hash', () {
    const NodeUpdateUnverified refusal = NodeUpdateUnverified(
      checksumFile: NodeChecksumFileCheck.absentFromRelease,
    );
    final DownloadedNodeLibrary unverified = downloadedOf(
      checksumFile: NodeChecksumFileCheck.absentFromRelease,
    );

    blocTest<NodeUpdateCubit, NodeUpdatePanelState>(
      'is refused first, and asks',
      build: () {
        updater.downloads.addAll(<Object>[refusal, unverified]);
        return build();
      },
      act: toDownload,
      skip: 6,
      expect: () => <Matcher>[
        _step<NodeUpdateUnverifiedAsk>(
          (NodeUpdateUnverifiedAsk step) => <Object?>[
            step.release,
            step.checksumFile,
          ],
          <Object?>[
            same(updater.latest),
            NodeChecksumFileCheck.absentFromRelease,
          ],
        ),
      ],
      verify: (_) {
        expect(updater.calls, <String>[
          'latestRelease $kRepo',
          'download $kTag allowUnverified=false',
        ]);
      },
    );

    blocTest<NodeUpdateCubit, NodeUpdatePanelState>(
      'is downloaded unverified after a yes, and still has to be confirmed',
      build: () {
        updater.downloads.addAll(<Object>[refusal, unverified]);
        return build();
      },
      act: (NodeUpdateCubit cubit) async {
        await toDownload(cubit);
        await cubit.downloadUnverified();
        expect(cubit.state.step, isA<NodeUpdateConfirmAsk>());
        expect(updater.calls, isNot(contains('stage $kNewSha')));
        await cubit.confirmInstall();
      },
      skip: 7,
      expect: () => <Matcher>[
        _downloading(0, 100),
        _downloading(50, 100),
        _downloading(100, 100),
        _step<NodeUpdateConfirmAsk>(
          (NodeUpdateConfirmAsk step) => step.library.verified,
          false,
        ),
        _step<NodeUpdateStaging>(),
        _step<NodeUpdateStepIdle>(),
      ],
      verify: (_) {
        expect(updater.calls, <String>[
          'latestRelease $kRepo',
          'download $kTag allowUnverified=false',
          'download $kTag allowUnverified=true',
          'stage $kNewSha',
        ]);
      },
    );

    blocTest<NodeUpdateCubit, NodeUpdatePanelState>(
      'is left alone after a no',
      build: () {
        updater.downloads.addAll(<Object>[refusal, unverified]);
        return build();
      },
      act: (NodeUpdateCubit cubit) async {
        await toDownload(cubit);
        cubit.cancelInstall();
        // No question is open any more, so this is nobody's yes.
        await cubit.downloadUnverified();
      },
      skip: 7,
      expect: () => <Matcher>[_step<NodeUpdateStepIdle>()],
      verify: (_) {
        expect(
          updater.calls,
          isNot(contains('download $kTag allowUnverified=true')),
        );
      },
    );

    test('is never downloaded unverified without the question', () async {
      updater.downloads.add(unverified);
      final NodeUpdateCubit cubit = build();
      await cubit.load();
      await cubit.check();
      await cubit.downloadUnverified();
      expect(updater.calls, <String>['latestRelease $kRepo']);
      expect(cubit.state.step, isA<NodeUpdateStepIdle>());
      await cubit.close();
    });
  });

  group('a file', () {
    blocTest<NodeUpdateCubit, NodeUpdatePanelState>(
      'is read, then waits for the answer',
      build: () {
        updater.picked = pickedOf();
        return build();
      },
      act: (NodeUpdateCubit cubit) async {
        await cubit.load();
        await cubit.installFromFile(File('C:/Downloads/libznn.dll'));
        expect(updater.calls, <String>['fromFile libznn.dll']);
      },
      skip: 1,
      expect: () => <Matcher>[
        _step<NodeUpdateReadingFile>(
          (NodeUpdateReadingFile step) => step.name,
          'libznn.dll',
        ),
        _step<NodeUpdateConfirmAsk>(
          (NodeUpdateConfirmAsk step) => <Object?>[
            step.library.isFromFile,
            step.library.checksumFile,
            step.library.apiDigest,
          ],
          <Object?>[true, null, null],
        ),
      ],
    );

    for (final NodeUpdateException error in <NodeUpdateException>[
      const NodeUpdateUnsupportedFile('notes.txt'),
      const NodeUpdateTooLarge(NodeUpdater.defaultMaxBytes),
      NodeUpdateArchiveError(NodeArchiveProblem.corrupt, 'not a zip'),
      const NodeUpdateFileError('gone'),
    ]) {
      blocTest<NodeUpdateCubit, NodeUpdatePanelState>(
        'that is refused with ${error.runtimeType} is that failure',
        build: () {
          updater.picked = error;
          return build();
        },
        act: (NodeUpdateCubit cubit) async {
          await cubit.load();
          await cubit.installFromFile(File('notes.txt'));
        },
        skip: 2,
        expect: () => <Matcher>[
          _step<NodeUpdateStepFailed>(
            (NodeUpdateStepFailed step) => step.error,
            same(error),
          ),
        ],
      );
    }
  });

  group('roll back', () {
    blocTest<NodeUpdateCubit, NodeUpdatePanelState>(
      'Use bundled node removes the override for the next start',
      build: () {
        library
          ..current = statusOf(
            loadedOverride: manifestOf(),
            installed: manifestOf(),
          )
          // The override keeps running until the wallet restarts.
          ..afterRollback = statusOf(loadedOverride: manifestOf());
        return build();
      },
      act: (NodeUpdateCubit cubit) async {
        await cubit.load();
        await cubit.useBundled();
      },
      skip: 1,
      expect: () => <Matcher>[
        _step<NodeUpdateStepIdle>()
            .having(
              (NodeUpdatePanelState state) => state.library?.installed,
              'installed',
              isNull,
            )
            .having(
              (NodeUpdatePanelState state) => state.library?.next?.kind,
              'next',
              NodeLibraryKind.bundled,
            ),
      ],
      verify: (_) {
        expect(library.calls, <String>['rollback']);
        expect(asked, isEmpty, reason: 'a roll back needs no network');
      },
    );

    blocTest<NodeUpdateCubit, NodeUpdatePanelState>(
      'Use previous swaps the earlier override back in',
      build: () {
        library
          ..current = statusOf(
            installed: manifestOf(),
            previous: manifestOf(tag: 'v0.0.8', sha256: kOldSha),
          )
          ..afterRollback = statusOf(
            installed: manifestOf(tag: 'v0.0.8', sha256: kOldSha),
            previous: manifestOf(),
          );
        return build();
      },
      act: (NodeUpdateCubit cubit) async {
        await cubit.load();
        await cubit.usePrevious();
      },
      skip: 1,
      expect: () => <Matcher>[
        _step<NodeUpdateStepIdle>().having(
          (NodeUpdatePanelState state) => state.library?.installed?.tag,
          'installed',
          'v0.0.8',
        ),
      ],
      verify: (_) => expect(library.calls, <String>['restorePrevious']),
    );

    blocTest<NodeUpdateCubit, NodeUpdatePanelState>(
      'Use previous with nothing to put back is a failure',
      build: () {
        library.restores = false;
        return build();
      },
      act: (NodeUpdateCubit cubit) async {
        await cubit.load();
        await cubit.usePrevious();
      },
      skip: 1,
      expect: () => <Matcher>[
        _step<NodeUpdateStepFailed>(
          (NodeUpdateStepFailed step) => step.error,
          isA<NodeUpdateFileError>(),
        ),
      ],
    );
  });

  group('the source repository', () {
    blocTest<NodeUpdateCubit, NodeUpdatePanelState>(
      'is saved, forgets the last check and is read by the next one',
      build: build,
      act: (NodeUpdateCubit cubit) async {
        await cubit.load();
        await cubit.check();
        expect(await cubit.setRepository(' someone/go-zenon '), isTrue);
        await cubit.check();
      },
      skip: 3,
      expect: () => <Matcher>[
        _check<NodeUpdateCheckIdle>().having(
          (NodeUpdatePanelState state) => state.repository,
          'repository',
          'someone/go-zenon',
        ),
        _check<NodeUpdateCheckRunning>(),
        _check<NodeUpdateCheckDone>(),
      ],
      verify: (_) {
        expect(saved, <String>['someone/go-zenon']);
        expect(asked, <String>[kRepo, 'someone/go-zenon']);
        expect(updater.closed, isTrue);
        expect(updaters['someone/go-zenon']!.calls, <String>[
          'latestRelease someone/go-zenon',
        ]);
      },
    );

    test('that is not owner/name is refused and not saved', () async {
      final NodeUpdateCubit cubit = build();
      await cubit.load();
      for (final String bad in <String>[
        '',
        'go-zenon',
        'a/b/c',
        '../go-zenon',
        'https://github.com/zenon-network/go-zenon',
      ]) {
        expect(await cubit.setRepository(bad), isFalse, reason: bad);
      }
      expect(saved, isEmpty);
      expect(cubit.state.repository, kRepo);
      await cubit.close();
    });

    test('cannot change under a library waiting for its answer', () async {
      updater.downloads.add(downloadedOf());
      final NodeUpdateCubit cubit = build();
      await toDownload(cubit);
      expect(await cubit.setRepository('someone/go-zenon'), isFalse);
      expect(cubit.state.repository, kRepo);
      expect(saved, isEmpty);
      await cubit.close();
    });
  });

  group('closing the panel', () {
    test('deletes a library still waiting for its answer', () async {
      updater.downloads.add(downloadedOf());
      final NodeUpdateCubit cubit = build();
      await toDownload(cubit);
      await cubit.close();
      expect(updater.calls.last, 'discard $kNewSha');
      expect(updater.closed, isTrue);
      // The dialog may still be open; its answer goes nowhere.
      await cubit.confirmInstall();
      expect(updater.calls, isNot(contains('stage $kNewSha')));
    });

    test('stops a download, and nothing of it is kept', () async {
      updater
        ..hold = Completer<void>()
        ..downloads.add(downloadedOf());
      final NodeUpdateCubit cubit = build();
      await cubit.load();
      await cubit.check();
      final Future<void> download = cubit.download();
      await pumpEventQueue();
      await cubit.close();
      await download;
      expect(updater.downloads, hasLength(1));
      expect(updater.calls.where((String c) => c.startsWith('stage')), isEmpty);
    });
  });
}
