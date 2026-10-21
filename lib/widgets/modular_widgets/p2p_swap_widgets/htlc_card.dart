import 'package:material_ui/material_ui.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/htlc_swap.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/p2p_swap.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/home/home.dart'
    show AmountText;
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/address_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/color_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/date_time_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/detail_row.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/loading_info_text.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// One leg of a swap inside a swap dialog: the amount under a ledger label,
/// and the deposit's details behind a chevron.
class HtlcCard extends StatefulWidget {
  /// Creates a leg from its parts.
  const HtlcCard({
    required this.title,
    required this.sender,
    required this.htlcId,
    required this.hashLock,
    required this.expirationTime,
    required this.recipient,
    required this.amount,
    required this.tokenStandard,
    required this.tokenDecimals,
    required this.tokenSymbol,
    super.key,
  });

  /// The leg this wallet deposits.
  factory HtlcCard.sending({
    required HtlcSwap swap,
  }) => HtlcCard(
    title: 'You send',
    sender: swap.selfAddress,
    htlcId: swap.direction == P2pSwapDirection.outgoing
        ? swap.initialHtlcId
        : swap.counterHtlcId,
    hashLock: swap.hashLock,
    expirationTime: swap.direction == P2pSwapDirection.outgoing
        ? swap.initialHtlcExpirationTime
        : swap.counterHtlcExpirationTime,
    recipient: swap.counterpartyAddress,
    amount: swap.fromAmount,
    tokenStandard: swap.fromTokenStandard,
    tokenDecimals: swap.fromDecimals,
    tokenSymbol: swap.fromSymbol,
  );

  /// The leg the counterparty deposits. Without a deposit id yet, the card
  /// says it is waiting.
  factory HtlcCard.receiving({
    required HtlcSwap swap,
  }) => HtlcCard(
    title: 'You receive',
    sender: swap.counterpartyAddress,
    htlcId: swap.direction == P2pSwapDirection.outgoing
        ? swap.counterHtlcId
        : swap.initialHtlcId,
    hashLock: swap.hashLock,
    expirationTime: swap.direction == P2pSwapDirection.outgoing
        ? swap.counterHtlcExpirationTime
        : swap.initialHtlcExpirationTime,
    recipient: swap.selfAddress,
    amount: swap.toAmount,
    tokenStandard: swap.toTokenStandard,
    tokenDecimals: swap.toDecimals,
    tokenSymbol: swap.toSymbol,
  );

  /// A leg read from the chain, before this wallet has joined.
  factory HtlcCard.fromHtlcInfo({
    required String title,
    required HtlcInfo htlc,
    required Token token,
  }) => HtlcCard(
    title: title,
    sender: htlc.timeLocked.toString(),
    htlcId: htlc.id.toString(),
    hashLock: FormatUtils.encodeHexString(htlc.hashLock),
    expirationTime: htlc.expirationTime,
    recipient: htlc.hashLocked.toString(),
    amount: htlc.amount,
    tokenStandard: token.tokenStandard.toString(),
    tokenDecimals: token.decimals,
    tokenSymbol: token.symbol,
  );

  /// The ledger label over the amount.
  final String title;

  /// Who deposits.
  final String sender;

  /// The deposit's id; null until the deposit exists.
  final String? htlcId;

  /// The hashlock both legs share.
  final String? hashLock;

  /// When the deposit expires, in Unix seconds.
  final int? expirationTime;

  /// Who can unlock the deposit.
  final String? recipient;

  /// The amount in the smallest unit.
  final BigInt? amount;

  /// The token's standard.
  final String? tokenStandard;

  /// The token's decimals.
  final int? tokenDecimals;

  /// The token's symbol.
  final String? tokenSymbol;

  @override
  State<HtlcCard> createState() => _HtlcCardState();
}

class _HtlcCardState extends State<HtlcCard> {
  bool _areDetailsExpanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: Durations.short4,
      curve: Easing.standard,
      alignment: Alignment.topCenter,
      child: Material(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(kCardRadius),
        clipBehavior: Clip.antiAlias,
        child: widget.htlcId == null ? _buildWaitingBody() : _buildBody(),
      ),
    );
  }

  Widget _buildWaitingBody() {
    return const SizedBox(
      height: 76,
      child: LoadingInfoText(text: 'Waiting for the counterparty'),
    );
  }

  Widget _buildBody() {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(widget.title.toUpperCase(), style: ledgerLabelStyle(context)),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Expanded(
                child: Row(
                  children: <Widget>[
                    Flexible(
                      child: AmountText(
                        widget.amount!,
                        decimals: widget.tokenDecimals!,
                        style: theme.textTheme.bodyLarge!.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                        symbol: widget.tokenSymbol,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 6,
                      width: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ColorUtils.getTokenColor(
                          TokenStandard.parse(widget.tokenStandard!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Details',
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() {
                  _areDetailsExpanded = !_areDetailsExpanded;
                }),
                icon: AnimatedRotation(
                  turns: _areDetailsExpanded ? 0.5 : 0,
                  duration: Durations.short4,
                  curve: Easing.standard,
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.faint,
                  ),
                ),
              ),
            ],
          ),
          if (_areDetailsExpanded) ...<Widget>[
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Divider(),
            ),
            const SizedBox(height: 4),
            _buildDetailsList(),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsList() {
    final Hash htlcId = Hash.parse(widget.htlcId!);
    final Hash hashLock = Hash.parse(widget.hashLock!);
    return Column(
      children: <Widget>[
        _buildExpirationRow(widget.expirationTime!),
        DetailRow(
          label: 'Deposit ID',
          value: htlcId.toString(),
          valueToShow: htlcId.toShortString(),
        ),
        DetailRow(
          label: 'Token standard',
          value: widget.tokenStandard!,
          prefixWidget: _buildTokenStandardMark(widget.tokenStandard ?? ''),
        ),
        DetailRow(
          label: 'Sender',
          value: widget.sender,
          valueToShow: ZenonAddressUtils.getLabel(widget.sender),
        ),
        DetailRow(
          label: 'Recipient',
          value: widget.recipient!,
          valueToShow: ZenonAddressUtils.getLabel(widget.recipient!),
        ),
        DetailRow(
          label: 'Hashlock',
          value: hashLock.toString(),
          valueToShow: hashLock.toShortString(),
        ),
      ],
    );
  }

  Widget _buildTokenStandardMark(String tokenStandard) {
    String message = 'Not in your favorites';
    IconData icon = Icons.help;
    Color iconColor = AppColors.errorColor;
    if (<String>[znnTokenStandard, qsrTokenStandard].contains(tokenStandard)) {
      message = 'Verified';
      icon = Icons.check_circle_outline;
      iconColor = AppColors.znnColor;
    } else if (Hive.box(kFavoriteTokensBox).values.contains(tokenStandard)) {
      message = 'In your favorites';
      icon = Icons.star;
      iconColor = AppColors.znnColor;
    }
    return Tooltip(
      message: message,
      child: Icon(icon, color: iconColor, size: 14),
    );
  }

  Widget _buildExpirationRow(int expirationTime) {
    final Duration duration = Duration(
      seconds: expirationTime - DateTimeUtils.unixTimeNow,
    );
    if (duration.isNegative) {
      return const DetailRow(
        label: 'Expires in',
        value: 'Expired',
        canBeCopied: false,
      );
    }
    return TweenAnimationBuilder<Duration>(
      duration: duration,
      tween: Tween<Duration>(begin: duration, end: Duration.zero),
      builder: (_, Duration d, _) {
        return DetailRow(
          label: 'Expires in',
          value: d.toString().split('.').first,
          canBeCopied: false,
        );
      },
    );
  }
}
