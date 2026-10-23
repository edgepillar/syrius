import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/access_wallet_screen.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/entry_action_boundary.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/import_wallet/import_draft.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/import_wallet/import_file_picker.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/import_wallet/import_surface.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/import_wallet/import_wallet_decrypt_screen.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/import_wallet/import_wallet_password_screen.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/onboarding_step_route.dart';
import 'package:zenon_syrius_wallet_flutter/utils/entry_capture_source.dart';
import 'package:zenon_syrius_wallet_flutter/utils/wallet_file.dart';

/// Owns one current mnemonic draft or bounded-probe file selection for import.
class ImportWalletSeedChoiceScreen extends StatefulWidget {
  /// Mounts the genuine input owner only after the welcome action is admitted.
  const ImportWalletSeedChoiceScreen({super.key});

  @override
  State<ImportWalletSeedChoiceScreen> createState() =>
      _ImportWalletSeedChoiceScreenState();
}

class _ImportWalletSeedChoiceScreenState
    extends State<ImportWalletSeedChoiceScreen> {
  final TextEditingController _seed = TextEditingController();
  ImportSeedDraft _draft = ImportSeedDraft('', expectedWords: 12);
  ImportFileSelection? _file;
  bool _fileRefused = false;
  bool _pickerFailed = false;
  Object _source = Object();
  final Completer<void> _controllerDisposed = Completer<void>();
  late final EntryCaptureCompletion _disposal = EntryCaptureCompletion(
    _controllerDisposed.future,
  );
  EntryActionLease? _captureLease;
  bool _pickerRequested = false;
  bool _fileOffered = false;
  bool _probing = false;
  bool _controllerTouched = false;
  bool _disposing = false;
  bool _captureAttached = false;

  @override
  void initState() {
    super.initState();
    _seed.addListener(_observeSeed);
  }

  void _observeSeed() {
    // Keep only history, never the text. Clearing an edited controller cannot
    // turn its original receipt back into an untouched empty input owner.
    if (_seed.text.isNotEmpty) _controllerTouched = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_captureAttached) return;
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route == null) return;
    _captureAttached = true;
    final Object source = _source;
    EntryCaptureRegistry.instance.attachImport(
      owner: this,
      source: source,
      route: route,
      controllerOwner: _seed,
      controllerDisposed: _controllerDisposed.future,
      current: () =>
          !_disposing &&
          mounted &&
          identical(source, _source) &&
          identical(route, ModalRoute.of(context)) &&
          (_captureLease?.isCurrent ?? false),
      empty: () =>
          !_disposing &&
          !_controllerTouched &&
          identical(source, _source) &&
          _seed.text.isEmpty &&
          _draft.words.isEmpty &&
          _draft.expectedWords == 12,
      noOfferedFile: () => !_fileOffered && _file == null,
      // A canceled picker still revokes the untouched proof. Its outcome
      // cannot be inferred from a later empty controller or a visible route.
      noPendingPickerOrProbe: () =>
          !_pickerRequested && !_fileOffered && !_probing,
    );
  }

  bool _probeFile(String path) {
    _fileOffered = true;
    _probing = true;
    try {
      return WalletFile.isKeyStoreFile(path);
    } finally {
      _probing = false;
    }
  }

  void _changed(String value) => setState(() {
    _source = Object();
    _file = null;
    _fileRefused = false;
    _pickerFailed = false;
    _draft = ImportSeedDraft(value, expectedWords: _draft.expectedWords);
  });

  void _wordCount(int count) => setState(() {
    _source = Object();
    _file = null;
    _fileRefused = false;
    _pickerFailed = false;
    _draft = ImportSeedDraft(_seed.text, expectedWords: count);
  });

  @override
  Widget build(BuildContext context) => EntryActionBoundary(
    source: _source,
    builder: (BuildContext context, EntryActionLease lease) {
      _captureLease = lease;
      final Object source = _source;
      final ImportSeedDraft draft = _draft;
      final ImportFileSelection? file = _file;
      return ImportFilePicker(
        lease: lease,
        probe: _probeFile,
        onSelected: (ImportFileSelection? selection) {
          _fileOffered = true;
          if (!mounted || !lease.isCurrent || !identical(source, _source)) {
            return;
          }
          setState(() {
            _source = Object();
            _file = selection;
            _fileRefused = selection == null;
            _pickerFailed = false;
            // A file offer replaces the previous import source, including
            // a refused offer. It can never leave an older file importable.
            _seed.clear();
            _draft = ImportSeedDraft('', expectedWords: _draft.expectedWords);
          });
        },
        onPickerFailed: () {
          if (!mounted || !lease.isCurrent || !identical(source, _source)) {
            return;
          }
          setState(() {
            _source = Object();
            _file = null;
            _fileRefused = false;
            _pickerFailed = true;
          });
        },
        builder:
            (
              BuildContext context,
              VoidCallback browse,
              ImportDropWrapper wrap,
            ) => ImportSurface(
              seedController: _seed,
              draft: draft,
              fileSelected: file != null,
              fileRefused: _fileRefused,
              pickerFailed: _pickerFailed,
              onSeedChanged: (String value) {
                if (lease.isCurrent && identical(source, _source)) {
                  _changed(value);
                }
              },
              onWordCountChanged: (int count) {
                if (lease.isCurrent && identical(source, _source)) {
                  _wordCount(count);
                }
              },
              onBrowse: lease.guard(() {
                _pickerRequested = true;
                browse();
              }),
              wrapDrop: wrap,
              onBack: lease.guard(
                () => Navigator.popUntil(
                  context,
                  ModalRoute.withName(AccessWalletScreen.route),
                ),
              ),
              onContinue: file != null || draft.valid
                  ? lease.guard(() {
                      if (!identical(source, _source)) return;
                      Navigator.of(context).push<void>(
                        OnboardingStepRoute<void>(
                          builder: (_) => file == null
                              ? ImportWalletPasswordScreen(
                                  draft.seed,
                                  progressBarNumLevels: 4,
                                )
                              : ImportWalletDecryptScreen(file.path),
                        ),
                      );
                    })
                  : null,
            ),
      );
    },
  );

  @override
  void dispose() {
    _disposing = true;
    _source = Object();
    unawaited(_disposal.completion);
    try {
      _seed.dispose();
      super.dispose();
      _controllerDisposed.complete();
    } on Object catch (error, stack) {
      _controllerDisposed.completeError(error, stack);
      rethrow;
    }
  }
}
