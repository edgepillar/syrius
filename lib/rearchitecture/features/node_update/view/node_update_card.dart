import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zenon_syrius_wallet_flutter/embedded_node/node_library.dart';
import 'package:zenon_syrius_wallet_flutter/embedded_node/node_updater.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/node_update/cubit/node_update_cubit.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/ltr.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/motion/skeleton.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/motion/state_switcher.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/copy_to_clipboard_button.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';

part '../widgets/node_update_dialogs.dart';
part '../widgets/node_update_rows.dart';
part '../widgets/node_update_text.dart';

/// Lets the person pick a library on disk. Completes with its path, or with
/// null when they backed out.
typedef NodeLibraryFilePicker = Future<String?> Function();

/// The Embedded node panel of Settings: which libznn is loaded, what the
/// source repository has published, and installing another build or going
/// back to an earlier one.
///
/// The library runs in the process that holds the wallet's keys. Opening the
/// panel therefore reads the disk and nothing else: no request leaves the
/// wallet until Check is pressed, nothing is downloaded until Download is,
/// and nothing is installed until the person has confirmed a dialog that
/// lists the repository, the tag, the asset, the whole sha256 and what each
/// check found. What is installed takes effect at the next start.
///
/// As tall as its rows, so it goes in a scrolling column.
class NodeUpdateCard extends StatelessWidget {
  /// Creates the panel over this install's libraries, GitHub and the saved
  /// repository. Tests pass their own.
  const NodeUpdateCard({
    this._library,
    this._updaterFor,
    this._repository,
    this._saveRepository,
    this._pickFile,
    super.key,
  });

  final NodeLibrary? _library;
  final NodeUpdaterFactory? _updaterFor;
  final String? _repository;
  final Future<void> Function(String repository)? _saveRepository;
  final NodeLibraryFilePicker? _pickFile;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NodeUpdateCubit>(
      create: (_) {
        final NodeLibrary library = _library ?? NodeLibrary.forThisInstall();
        final NodeUpdateCubit cubit = NodeUpdateCubit(
          library: library,
          updaterFor:
              _updaterFor ??
              (NodeUpdateSource source) =>
                  NodeUpdater(library: library, source: source),
          repository: _repository ?? _savedRepository(),
          saveRepository: _saveRepository ?? _keepRepository,
        );
        // The disk only: what is loaded, installed and staged. Nothing is
        // asked of the network until Check is pressed.
        unawaited(cubit.load());
        return cubit;
      },
      child: _View(pickFile: _pickFile ?? _pickLibraryFile),
    );
  }

  /// The repository kept in the wallet's preferences, beside the chain
  /// identifier. Null when none was ever saved.
  static String? _savedRepository() {
    final Object? saved = sharedPrefsService?.get(kNodeUpdateRepositoryKey);
    return saved is String ? saved : null;
  }

  static Future<void> _keepRepository(String repository) =>
      sharedPrefsService!.put(kNodeUpdateRepositoryKey, repository);

  /// The file dialog the wallet uses elsewhere, opened on Downloads and
  /// showing this platform's library and the archives a release ships.
  static Future<String?> _pickLibraryFile() async {
    final Directory? downloads = await getDownloadsDirectory();
    final XFile? picked = await openFile(
      initialDirectory: downloads?.path,
      acceptedTypeGroups: <XTypeGroup>[
        XTypeGroup(
          label: 'libznn',
          extensions: <String>[
            NodeLibrary.extension.substring(1),
            'zip',
            'gz',
            'tgz',
          ],
        ),
      ],
    );
    return picked?.path;
  }
}

class _View extends StatelessWidget {
  const _View({required this._pickFile});

  final NodeLibraryFilePicker _pickFile;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return BlocListener<NodeUpdateCubit, NodeUpdatePanelState>(
      listenWhen: (NodeUpdatePanelState before, NodeUpdatePanelState now) =>
          before.step.runtimeType != now.step.runtimeType,
      listener: (BuildContext context, NodeUpdatePanelState state) =>
          unawaited(_onStep(context, state.step)),
      child: Panel(
        title: l10n.nodeUpdatePanelTitle,
        shrinkWrap: true,
        // One group, so Tab walks the panel's controls before it leaves.
        child: FocusTraversalGroup(
          child:
              BlocSelector<
                NodeUpdateCubit,
                NodeUpdatePanelState,
                NodeUpdateLoad
              >(
                selector: (NodeUpdatePanelState state) => state.load,
                builder: (BuildContext context, NodeUpdateLoad load) =>
                    AnimatedSize(
                      duration: Durations.medium1,
                      curve: Easing.standard,
                      alignment: AlignmentDirectional.topStart,
                      child: StateSwitcher(
                        alignment: AlignmentDirectional.topStart,
                        child: switch (load) {
                          NodeUpdateLoad.loading => const Padding(
                            key: ValueKey<String>('node_update_loading'),
                            padding: EdgeInsetsDirectional.all(16),
                            child: SkeletonRows(rows: 4),
                          ),
                          NodeUpdateLoad.failed => QuietNote(
                            l10n.nodeUpdateStatusError,
                            key: const ValueKey<String>('node_update_failed'),
                          ),
                          NodeUpdateLoad.ready => _Body(
                            key: const ValueKey<String>('node_update_ready'),
                            pickFile: _pickFile,
                          ),
                        },
                      ),
                    ),
              ),
        ),
      ),
    );
  }

  /// Puts the question a step asks, and gives the cubit the answer. Closing
  /// a dialog any other way than by its action is a no.
  Future<void> _onStep(BuildContext context, NodeUpdateStep step) async {
    final NodeUpdateCubit cubit = context.read<NodeUpdateCubit>();
    if (step is NodeUpdateConfirmAsk) {
      if (await _showInstallDialog(context, step.library) ?? false) {
        await cubit.confirmInstall();
      } else {
        cubit.cancelInstall();
      }
    } else if (step is NodeUpdateUnverifiedAsk) {
      if (await _showUnverifiedDialog(context, step.release) ?? false) {
        await cubit.downloadUnverified();
      } else {
        cubit.cancelInstall();
      }
    }
  }
}
