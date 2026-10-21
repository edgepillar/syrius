import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/p2p_swap.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/home/home.dart'
    show AmountText;
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/color_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/loading_widget.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The shares of the swap table's columns: status, sent, received,
/// counterparty, started. The header and every row read this one list, so
/// they cannot drift apart.
const List<int> kP2pSwapColumnFlex = <int>[3, 4, 4, 4, 3];

/// The width kept at the end of a swap row for its one action.
const double kP2pSwapActionWidth = 104;

/// The side padding of the swap table's header and rows.
const double kP2pSwapRowPadding = 16;

/// One swap as a table row. The row opens the swap; its last cell holds the
/// one thing left to do with it, if anything.
class P2pSwapsListItem extends StatelessWidget {
  /// Creates the row of [swap].
  const P2pSwapsListItem({
    required this.swap,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  /// The swap shown.
  final P2pSwap swap;

  /// Opens the swap with the given id.
  final void Function(String) onTap;

  /// Asks to delete the swap.
  final void Function(P2pSwap) onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle text = theme.textTheme.bodyMedium!.copyWith(fontSize: 13);
    final TextStyle dim = theme.textTheme.titleMedium!.copyWith(fontSize: 13);
    // The counterparty's amount is known once they have joined; a swap that
    // failed never delivers it, so it is not shown there.
    final bool showsReceived =
        swap.state == P2pSwapState.active ||
        swap.state == P2pSwapState.completed;
    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      onTap: () => onTap(swap.id),
      child: SizedBox(
        height: 46,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: kP2pSwapRowPadding),
          child: Row(
            children: <Widget>[
              Expanded(
                flex: kP2pSwapColumnFlex[0],
                child: _buildStatus(text),
              ),
              Expanded(
                flex: kP2pSwapColumnFlex[1],
                child: _buildAmount(
                  text,
                  swap.fromAmount,
                  swap.fromDecimals,
                  swap.fromTokenStandard,
                  swap.fromSymbol,
                ),
              ),
              Expanded(
                flex: kP2pSwapColumnFlex[2],
                child: showsReceived
                    ? _buildAmount(
                        text,
                        swap.toAmount,
                        swap.toDecimals,
                        swap.toTokenStandard,
                        swap.toSymbol,
                      )
                    : Text('-', style: dim),
              ),
              Expanded(
                flex: kP2pSwapColumnFlex[3],
                child: _buildCounterparty(dim),
              ),
              Expanded(
                flex: kP2pSwapColumnFlex[4],
                child: Text(
                  _formatTime(swap.startTime * 1000),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dim,
                ),
              ),
              SizedBox(
                width: kP2pSwapActionWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _buildAction(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatus(TextStyle text) {
    const double size = 16;
    final (Widget mark, String label) = switch (swap.state) {
      P2pSwapState.pending => (
        const SyriusLoadingWidget(size: 12, strokeWidth: 1.5, padding: 2),
        'Starting',
      ),
      P2pSwapState.active => (
        const SyriusLoadingWidget(size: 12, strokeWidth: 1.5, padding: 2),
        'Active',
      ),
      P2pSwapState.completed => (
        const Icon(
          Icons.check_circle_outline,
          color: AppColors.znnColor,
          size: size,
        ),
        'Completed',
      ),
      P2pSwapState.reclaimable => (
        const Icon(Icons.replay, color: AppColors.warn, size: size),
        'Reclaimable',
      ),
      _ => (
        const Icon(
          Icons.cancel_outlined,
          color: AppColors.errorColor,
          size: size,
        ),
        'Unsuccessful',
      ),
    };
    return Row(
      children: <Widget>[
        mark,
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text,
          ),
        ),
      ],
    );
  }

  Widget _buildAmount(
    TextStyle text,
    BigInt? amount,
    int? decimals,
    String? tokenStandard,
    String? symbol,
  ) {
    if (amount == null ||
        decimals == null ||
        tokenStandard == null ||
        symbol == null) {
      return Text('-', style: text);
    }
    return Row(
      children: <Widget>[
        Flexible(
          child: AmountText(
            amount,
            decimals: decimals,
            style: text,
            symbol: symbol,
          ),
        ),
        const SizedBox(width: 6),
        // The symbol is free text; the dot is derived from the token
        // standard, so two tokens that share a symbol still look different.
        Container(
          height: 6,
          width: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ColorUtils.getTokenColor(
              TokenStandard.parse(tokenStandard),
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildCounterparty(TextStyle dim) {
    final String address = swap.counterpartyAddress;
    final String short = address.length <= 12
        ? address
        : '${address.substring(0, 6)}…'
              '${address.substring(address.length - 4)}';
    return Align(
      alignment: Alignment.centerLeft,
      child: Tooltip(
        message: address,
        child: Text(
          short,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: monoStyle(dim),
        ),
      ),
    );
  }

  Widget _buildAction() {
    switch (swap.state) {
      case P2pSwapState.completed:
      case P2pSwapState.unsuccessful:
        return IconButton(
          tooltip: 'Delete',
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          mouseCursor: SystemMouseCursors.click,
          onPressed: () => onDelete(swap),
          icon: const Icon(Icons.delete_outline, color: AppColors.faint),
        );
      case P2pSwapState.reclaimable:
        return TextButton(
          style: TextButton.styleFrom(foregroundColor: kOnZnnColor),
          onPressed: () => onTap(swap.id),
          child: const Text('Reclaim'),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _formatTime(int transactionMillis) {
    final int currentMillis = DateTime.now().millisecondsSinceEpoch;
    if (currentMillis - transactionMillis <=
        const Duration(days: 1).inMilliseconds) {
      return FormatUtils.formatDataShort(currentMillis - transactionMillis);
    }
    return FormatUtils.formatDateTime(transactionMillis);
  }
}
