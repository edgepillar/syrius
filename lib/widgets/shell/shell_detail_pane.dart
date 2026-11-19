import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/page_dismiss.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/rail.dart'
    show ShellSymbol;

/// A detail surface that keeps the current shell rail and status visible.
class ShellDetailPane extends StatelessWidget {
  /// Supplies the original route's title, return controls and content.
  const ShellDetailPane({
    required this.keyPrefix,
    required this.breadcrumb,
    required this.title,
    required this.onClose,
    required this.child,
    super.key,
  });

  /// Identifies the surface and its two controls within the destination.
  final String keyPrefix;

  /// The name of the destination beneath this pane.
  final String breadcrumb;

  /// The heading of the presented pane.
  final String title;

  /// Returns to the route beneath the original pane.
  final VoidCallback onClose;

  /// The content under the original route owner.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    return PageDismissAction(
      open: true,
      onDismiss: onClose,
      child: Material(
        key: ValueKey<String>('${keyPrefix}_pane'),
        color: tokens.card,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: tokens.panelHeaderHeight),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
                child: Row(
                  children: <Widget>[
                    TextButton.icon(
                      key: ValueKey<String>('${keyPrefix}_breadcrumb'),
                      style: quietButtonStyle(context).copyWith(
                        minimumSize: WidgetStatePropertyAll<Size>(
                          Size(0, tokens.smallButtonHeight),
                        ),
                        padding: const WidgetStatePropertyAll<EdgeInsets>(
                          EdgeInsets.symmetric(horizontal: 10),
                        ),
                        textStyle: WidgetStatePropertyAll<TextStyle>(
                          tokens.compactText.copyWith(fontSize: 12),
                        ),
                      ),
                      onPressed: onClose,
                      icon: Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.chevron_right
                            : Icons.chevron_left,
                        size: 16,
                      ),
                      label: Text(breadcrumb),
                    ),
                    SizedBox(width: tokens.inlineGap),
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          title,
                          key: ValueKey<String>('${keyPrefix}_title'),
                          style: tokens.headingText,
                        ),
                      ),
                    ),
                    IconButton(
                      key: ValueKey<String>('${keyPrefix}_close'),
                      tooltip: context.l10n.commonClose,
                      color: tokens.faint,
                      style: IconButton.styleFrom(
                        minimumSize: Size.square(tokens.panelHeaderHeight),
                        padding: EdgeInsets.zero,
                        alignment: AlignmentDirectional.centerEnd,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.standard,
                      ),
                      onPressed: onClose,
                      icon: ShellSymbol(
                        'x',
                        size: tokens.smallActionGlyphSize,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: tokens.line),
            Expanded(
              child: ClipRect(child: FocusTraversalGroup(child: child)),
            ),
          ],
        ),
      ),
    );
  }
}
