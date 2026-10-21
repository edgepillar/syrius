import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/clipboard_utils.dart';

class CopyToClipboardButton extends StatefulWidget {
  const CopyToClipboardButton(
    this._textToBeCopied, {
    this.iconSize,
    this.tooltip,
    super.key,
  });

  final String _textToBeCopied;
  final double? iconSize;

  /// Said on hover and read by a screen reader, since the button is an icon
  /// alone. Null says "Copy" in the app's language: a default value cannot
  /// read one. A caller that already wraps the button in a [Tooltip] with
  /// the same message gets one tooltip, not two.
  final String? tooltip;

  @override
  State<CopyToClipboardButton> createState() => _CopyToClipboardIcon();
}

class _CopyToClipboardIcon extends State<CopyToClipboardButton> {
  bool _isCopied = false;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final double iconSize = widget.iconSize ?? 24;

    final Widget firstChild = Icon(
      Icons.content_copy,
      color: tokens.faint,
      size: iconSize,
    );

    final Widget secondChild = Icon(
      Icons.check,
      color: tokens.znnInk,
      size: iconSize,
    );

    final String tooltip = widget.tooltip ?? context.l10n.commonCopy;
    final bool wrapped =
        context.findAncestorWidgetOfExactType<Tooltip>()?.message == tooltip;

    return IconButton(
      tooltip: wrapped ? null : tooltip,
      // Only the side is set, so a caller's IconButtonTheme still decides
      // the padding and size the tables lay out around. A border does not
      // take space, so the ring changes nothing else.
      style: ButtonStyle(
        side: WidgetStateProperty.resolveWith<BorderSide?>(
          (Set<WidgetState> states) => states.contains(WidgetState.focused)
              ? BorderSide(color: tokens.focusRing, width: 2)
              : null,
        ),
      ),
      onPressed: () {
        if (!_isCopied) {
          Timer(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _isCopied = false;
              });
            }
          });
          setState(() {
            _isCopied = true;
          });
        }
        ClipboardUtils.copyToClipboard(widget._textToBeCopied, context);
      },
      icon: AnimatedCrossFade(
        duration: const Duration(milliseconds: 100),
        firstChild: firstChild,
        secondChild: secondChild,
        crossFadeState:
            _isCopied ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      ),
    );
  }
}
