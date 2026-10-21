import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/refresh_button/view/view.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/constants/constants.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';

/// A widget showing a [title] along with some icon buttons
class CardScaffoldHeader extends StatelessWidget {
  /// Creates a new instance.
  const CardScaffoldHeader({
    required this.onMoreIconPressed,
    required this.onRefreshPressed,
    required this.title,
    super.key,
  });

  /// Title that will appear in the header.
  final String title;

  /// Callback triggered when the more icon is pressed.
  final VoidCallback onMoreIconPressed;

  /// Optional callback that can be trigger from the refresh icon.
  final VoidCallback? onRefreshPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: panelTitleStyle(context),
                  ),
                ),
                kHorizontalGap4,
              ],
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            if (onRefreshPressed != null)
              RefreshButton(
                onPressed: onRefreshPressed!,
              ),
            IconButton(
              mouseCursor: SystemMouseCursors.click,
              tooltip: context.l10n.cardScaffoldAboutTooltip,
              iconSize: 18,
              color: AppColors.faint,
              icon: const Icon(Icons.info_outline),
              onPressed: onMoreIconPressed,
            ),
          ],
        ),
      ],
    );
  }
}
