import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/htlc_swap.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/p2p_swap.dart';
import 'package:zenon_syrius_wallet_flutter/utils/address_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/detail_row.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The ids and addresses of a finished swap, behind a "Details" toggle.
class HtlcSwapDetailsWidget extends StatefulWidget {
  /// Creates the details of [swap].
  const HtlcSwapDetailsWidget({
    required this.swap,
    super.key,
  });

  /// The swap described.
  final HtlcSwap swap;

  @override
  State<HtlcSwapDetailsWidget> createState() => _HtlcSwapDetailsWidgetState();
}

class _HtlcSwapDetailsWidgetState extends State<HtlcSwapDetailsWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final TextStyle dim = Theme.of(
      context,
    ).textTheme.titleMedium!.copyWith(fontSize: 13);
    return AnimatedSize(
      duration: Durations.short4,
      curve: Easing.standard,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              mouseCursor: SystemMouseCursors.click,
              onTap: () => setState(() {
                _isExpanded = !_isExpanded;
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('Details', style: dim),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: Durations.short4,
                      curve: Easing.standard,
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: AppColors.faint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isExpanded) ...<Widget>[
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 4),
            _buildDetailsList(widget.swap),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsList(HtlcSwap swap) {
    final String yourDepositId = swap.direction == P2pSwapDirection.outgoing
        ? swap.initialHtlcId
        : swap.counterHtlcId!;
    final String? counterpartyDepositId =
        swap.direction == P2pSwapDirection.incoming
        ? swap.initialHtlcId
        : swap.counterHtlcId;
    return Column(
      children: <Widget>[
        DetailRow(
          label: 'Your address',
          value: swap.selfAddress,
          valueToShow: ZenonAddressUtils.getLabel(swap.selfAddress),
        ),
        DetailRow(
          label: 'Counterparty',
          value: swap.counterpartyAddress,
          valueToShow: ZenonAddressUtils.getLabel(swap.counterpartyAddress),
        ),
        DetailRow(
          label: 'Your deposit ID',
          value: yourDepositId,
          valueToShow: Hash.parse(yourDepositId).toShortString(),
        ),
        if (counterpartyDepositId != null)
          DetailRow(
            label: 'Counterparty deposit ID',
            value: counterpartyDepositId,
            valueToShow: Hash.parse(counterpartyDepositId).toShortString(),
          ),
        DetailRow(
          label: 'Hashlock',
          value: swap.hashLock,
          valueToShow: Hash.parse(swap.hashLock).toShortString(),
        ),
        if (swap.preimage != null)
          DetailRow(
            label: 'Secret',
            value: swap.preimage!,
            valueToShow: Hash.parse(swap.preimage!).toShortString(),
          ),
      ],
    );
  }
}
