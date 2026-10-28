import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/window_chrome.dart';

/// The production Windows client frame. Its body is the supplied Navigator,
/// including that Navigator's routes, modal barriers and overlay ownership.
/// Other platforms retain their native caption and the original child layout.
class AppWindowFrame extends StatefulWidget {
  /// Keep the supplied Navigator subtree as the unchanged body child.
  const AppWindowFrame({required this.child, super.key});

  /// The original application Navigator and its route/modal subtree.
  final Widget child;

  @override
  State<AppWindowFrame> createState() => AppWindowFrameState();
}

/// Owns one production caption controller for this frame's entire lifetime.
class AppWindowFrameState extends State<AppWindowFrame> {
  late final AppWindowController? _window;

  /// Read-only original-owner observation, independent of painted frame timing.
  AppWindowStatus? get windowStatus => _window?.status;

  @override
  void initState() {
    super.initState();
    _window = usesAppWindowFrame ? AppWindowController.native() : null;
    _window?.addListener(_changed);
  }

  void _changed() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppWindowController? window = _window;
    if (window == null) {
      return widget.child;
    }
    final AppTokens tokens = AppTokens.of(context);
    final AppLocalizations text = AppLocalizations.of(context)!;
    final Widget caption = Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        key: const ValueKey<String>('window-caption'),
        color: tokens.windowCaptionBackground,
        child: SizedBox(
          height: tokens.windowCaptionHeight,
          child: Padding(
            padding: tokens.windowCaptionPadding,
            child: FocusTraversalGroup(
              policy: WidgetOrderTraversalPolicy(),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: GestureDetector(
                      key: const ValueKey<String>('window-drag-region'),
                      behavior: HitTestBehavior.opaque,
                      onPanStart: window.canMinimize
                          ? (_) => unawaited(window.startDragging())
                          : null,
                      onSecondaryTapDown: window.canMinimize
                          ? (_) => unawaited(window.showMenu())
                          : null,
                      onDoubleTap: window.canToggleMaximize
                          ? () => unawaited(window.toggleMaximize())
                          : null,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'SYRIUS',
                          style: tokens.windowTitleText,
                        ),
                      ),
                    ),
                  ),
                  _CaptionButton(
                    key: const ValueKey<String>('window-minimize'),
                    label: text.windowMinimize,
                    icon: Icons.remove,
                    glyph: '\u2014',
                    onPressed: window.canMinimize
                        ? () => unawaited(window.minimize())
                        : null,
                  ),
                  _CaptionButton(
                    key: const ValueKey<String>('window-maximize'),
                    label: window.maximized == true
                        ? text.windowRestore
                        : text.windowMaximize,
                    icon: window.maximized == true
                        ? Icons.filter_none
                        : Icons.crop_square,
                    glyph: window.maximized == true ? null : '\u25a1',
                    onPressed: window.canToggleMaximize
                        ? () => unawaited(window.toggleMaximize())
                        : null,
                  ),
                  _CaptionButton(
                    key: const ValueKey<String>('window-close'),
                    label: text.commonClose,
                    icon: Icons.close,
                    glyph: '\u2715',
                    isClose: true,
                    onPressed: window.canClose
                        ? () => unawaited(window.close())
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // Keep body lookups in the original Navigator and View ancestry.
    // Only the caption uses the full-client tooltip Overlay.
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Column(
          children: <Widget>[
            SizedBox(height: tokens.windowCaptionHeight),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) =>
                    MediaQuery(
                      key: const ValueKey<String>('window-body'),
                      data: MediaQuery.of(
                        context,
                      ).copyWith(size: constraints.biggest),
                      child: widget.child,
                    ),
              ),
            ),
          ],
        ),
        Positioned.fill(
          child: Overlay.wrap(
            child: Align(alignment: Alignment.topCenter, child: caption),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _window
      ?..removeListener(_changed)
      ..dispose();
    super.dispose();
  }
}

class _CaptionButton extends StatelessWidget {
  const _CaptionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
    this.isClose = false,
    this.glyph,
  });

  final String label;
  final IconData icon;
  final String? glyph;
  final VoidCallback? onPressed;
  final bool isClose;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final Size size = Size(
      tokens.windowControlWidth,
      tokens.windowCaptionHeight,
    );
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      icon: glyph == null
          ? Icon(icon, size: tokens.windowControlIconSize)
          : ExcludeSemantics(
              child: Builder(
                builder: (BuildContext context) => Text(
                  glyph!,
                  style: tokens.windowTitleText.copyWith(
                    fontSize: tokens.windowControlIconSize,
                    letterSpacing: 0,
                    color: IconTheme.of(context).color,
                  ),
                ),
              ),
            ),
      style: ButtonStyle(
        fixedSize: WidgetStatePropertyAll<Size>(size),
        minimumSize: WidgetStatePropertyAll<Size>(size),
        maximumSize: WidgetStatePropertyAll<Size>(size),
        padding: const WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.zero),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        shape: const WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(),
        ),
        foregroundColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.disabled)) {
              return tokens.dim;
            }
            return isClose && states.contains(WidgetState.hovered)
                ? tokens.error
                : tokens.faint;
          },
        ),
        overlayColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) =>
              isClose ? tokens.windowCloseHover : tokens.hover,
        ),
        side: WidgetStateProperty.resolveWith<BorderSide>(
          (Set<WidgetState> states) => states.contains(WidgetState.focused)
              ? BorderSide(color: tokens.focusRing, width: tokens.focusWidth)
              : BorderSide.none,
        ),
      ),
    );
  }
}
