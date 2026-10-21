import 'package:desktop_drop/desktop_drop.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';

/// What the zone is showing, which decides how the line is drawn.
enum _Showing { hint, path, refusal }

class SelectFileWidget extends StatefulWidget {
  final void Function(String) onPathFoundCallback;
  final String? fileExtension;

  /// Decides from the file itself whether it is accepted. When set, it
  /// replaces the [fileExtension] gate, so any file can be offered.
  final bool Function(String path)? validator;

  /// What the zone says when the [validator] refuses a file. Null says
  /// "This file cannot be used" in the app's language: a default value
  /// cannot read one.
  final String? invalidFileMessage;

  /// Called when the [validator] refuses a file. The zone then shows the
  /// refusal, so a caller still holding an earlier path must drop it: it
  /// would otherwise act on a file the screen no longer names.
  final VoidCallback? onFileRefusedCallback;
  final TextStyle? textStyle;

  const SelectFileWidget({
    required this.onPathFoundCallback,
    this.fileExtension,
    this.validator,
    this.invalidFileMessage,
    this.onFileRefusedCallback,
    this.textStyle,
    Key? key,
  }) : super(key: key);

  @override
  SelectFileWidgetState createState() => SelectFileWidgetState();
}

class SelectFileWidgetState extends State<SelectFileWidget> {
  bool _browseButtonHover = false;
  bool _dragging = false;
  bool _focused = false;

  /// The path or the refusal. Null while the hint shows, which is read in
  /// `build` so that it follows the app's language.
  String? _messageToUser;
  _Showing _showing = _Showing.hint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color line = _dragging || _browseButtonHover || _focused
        ? AppColors.znnColor
        : _showing == _Showing.refusal
        ? AppColors.errorColor
        : AppColors.faint;
    return DropTarget(
      onDragDone: (DropDoneDetails detail) {
        setState(() {
          _dragging = false;
        });
        _onFileOffered(detail.files.first.path);
      },
      onDragEntered: (DropEventDetails detail) {
        setState(() {
          _dragging = true;
        });
      },
      onDragExited: (DropEventDetails detail) {
        setState(() {
          _dragging = false;
        });
      },
      child: GestureDetector(
        onTap: _browse,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          // Enter or Space on the focused zone opens the file dialog, as a
          // click does.
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (ActivateIntent intent) => _browse(),
            ),
          },
          onShowFocusHighlight: (bool x) => setState(() => _focused = x),
          onShowHoverHighlight: (bool x) {
            if (x) {
              setState(() {
                _browseButtonHover = true;
              });
            } else {
              setState(() {
                _browseButtonHover = false;
              });
            }
          },
          child: DottedBorder(
            options: RoundedRectDottedBorderOptions(
              color: line,
              strokeWidth: 1.2,
              dashPattern: const <double>[6, 4],
              radius: const Radius.circular(kCardRadius),
              padding: EdgeInsets.zero,
            ),
            child: AnimatedContainer(
              duration: Durations.short3,
              height: 76,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _dragging
                    ? AppColors.znnColor.withValues(alpha: 0.12)
                    : theme.colorScheme.primary,
                borderRadius: const BorderRadius.all(
                  Radius.circular(kCardRadius),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    _showing == _Showing.path
                        ? Icons.insert_drive_file_outlined
                        : Icons.upload_file_outlined,
                    size: 18,
                    color: _showing == _Showing.path
                        ? AppColors.znnColor
                        : AppColors.faint,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      _messageToUser ?? context.l10n.selectFileHint,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: widget.textStyle ?? _lineStyle(context),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _browse() async {
    // Read before the first await, while the context is known to be live.
    final String typeLabel = context.l10n.selectFileTypeLabel;
    final String initialDirectory =
        (await getApplicationDocumentsDirectory()).path;
    final XFile? selectedFile = await openFile(
      acceptedTypeGroups: <XTypeGroup>[
        XTypeGroup(
          label: typeLabel,
          extensions: widget.validator == null && widget.fileExtension != null
              ? <String>[
                  widget.fileExtension!,
                ]
              : null,
        ),
      ],
      initialDirectory: initialDirectory,
    );
    if (selectedFile != null && mounted) {
      _onFileOffered(selectedFile.path, picked: true);
    }
  }

  /// The hint is dim, a refusal takes the error colour, and a path is data,
  /// so it is mono.
  TextStyle _lineStyle(BuildContext context) {
    switch (_showing) {
      case _Showing.hint:
        return TextStyle(fontSize: 13, color: dimColorOf(context));
      case _Showing.refusal:
        return const TextStyle(fontSize: 13, color: AppColors.errorColor);
      case _Showing.path:
        return monoStyle(
          TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        );
    }
  }

  /// A file that was dropped is checked against the extension; one [picked]
  /// in the file dialog was already filtered by it there, and is taken as it
  /// is. A [SelectFileWidget.validator] decides for both.
  void _onFileOffered(String path, {bool picked = false}) {
    final bool accepted = widget.validator != null
        ? widget.validator!(path)
        : picked || path.contains(widget.fileExtension ?? '');
    if (accepted) {
      setState(() {
        widget.onPathFoundCallback(path);
        _messageToUser = path;
        _showing = _Showing.path;
      });
    } else if (widget.validator != null) {
      setState(() {
        widget.onFileRefusedCallback?.call();
        _messageToUser =
            widget.invalidFileMessage ?? context.l10n.selectFileInvalidError;
        _showing = _Showing.refusal;
      });
    }
  }

  void resetMessageToUser() => setState(() {
    _messageToUser = null;
    _showing = _Showing.hint;
  });
}
