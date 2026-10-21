import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';

/// The frame of a modal: a title, an optional line under it, a close button
/// and the modal's own content.
class BaseModal extends StatelessWidget {
  /// Creates a modal titled [title] around [child].
  const BaseModal({
    required this.title,
    required this.child,
    super.key,
    this.subtitle = '',
  });

  /// The heading.
  final String title;

  /// A short line under the heading; nothing when empty.
  final String subtitle;

  /// The modal's content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: SingleChildScrollView(
        child: Material(
          color: theme.colorScheme.primaryContainer,
          child: AnimatedSize(
            duration: Durations.short3,
            curve: Easing.standard,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 570,
              child: Padding(
                padding: kDialogPadding,
                // Centred, not stretched: the modals' own content was laid
                // out for a column that leaves its width alone.
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(title, style: panelTitleStyle(context)),
                              if (subtitle.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: dimColorOf(context),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          tooltip: context.l10n.commonClose,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 28,
                            height: 28,
                          ),
                          iconSize: 18,
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.clear, color: AppColors.faint),
                        ),
                      ],
                    ),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
