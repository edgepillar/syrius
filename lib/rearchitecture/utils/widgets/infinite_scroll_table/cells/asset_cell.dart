import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/infinite_scroll_table/infinite_scroll_table.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class AssetCell extends StatelessWidget {
  const AssetCell({required this.block, super.key});

  final AccountBlock block;

  @override
  Widget build(BuildContext context) {
    final String content = block.token?.symbol ?? 'UNK';

    // The one rule for a symbol's colour: a block with no token has the
    // empty standard, whose own colour is black.
    final Color textColor = cardTokenInk(block.tokenStandard, context);

    final String tooltipMessage =
        block.token?.tokenStandard.toString() ??
        context.l10n.assetCellUnknownStandardTooltip;

    return InfiniteScrollTableCell.withText(
      content: content,
      tooltipMessage: tooltipMessage,
      textStyle: TextStyle(color: textColor),
    );
  }
}
