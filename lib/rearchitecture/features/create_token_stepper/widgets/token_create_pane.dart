import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/page_dismiss.dart';

/// The shell-contained header and surface for the existing token form.
class TokenCreatePane extends StatelessWidget {
  /// The route owner supplies dismissal and the already-owned form.
  const TokenCreatePane({
    required this.onClose,
    required this.child,
    super.key,
  });

  /// Returns to the ledger beneath the original pane route.
  final VoidCallback onClose;

  /// The original form and receipt under one registration owner.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    return PageDismissAction(
      open: true,
      onDismiss: onClose,
      child: Material(
        key: const Key('token_create_pane'),
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
                      key: const Key('token_create_breadcrumb'),
                      style: quietButtonStyle(context).copyWith(
                        minimumSize: WidgetStatePropertyAll<Size>(
                          Size(0, tokens.smallButtonHeight),
                        ),
                        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
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
                      label: Text(context.l10n.tokens),
                    ),
                    SizedBox(width: tokens.inlineGap),
                    Expanded(
                      child: Text(
                        context.l10n.createTokenOpenLabel,
                        style: tokens.headingText,
                      ),
                    ),
                    IconButton(
                      key: const Key('token_create_close'),
                      tooltip: context.l10n.commonClose,
                      iconSize: 16,
                      color: tokens.faint,
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: tokens.line),
            Expanded(child: FocusTraversalGroup(child: child)),
          ],
        ),
      ),
    );
  }
}
