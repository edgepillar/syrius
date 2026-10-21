import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/svg.dart';
import 'package:stacked/stacked.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/p2p_swap/htlc_swap/complete_htlc_swap_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/p2p_swap/htlc_swap/htlc_swap_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/p2p_swap/htlc_swap/reclaim_htlc_swap_funds_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/htlc_swap.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/p2p_swap.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/home/home.dart'
    show AmountText;
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/htlc_card.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/htlc_swap_details_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/instruction_button.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/error_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/exchange_rate_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/important_text_container.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/loading_info_text.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/loading_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/base_modal.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// One swap, from its first deposit to its end: what each side puts in,
/// and the one thing this wallet can do next.
class NativeP2pSwapModal extends StatefulWidget {
  /// Creates the dialog of the swap with [swapId].
  const NativeP2pSwapModal({
    required this.swapId,
    this.onSwapStarted,
    super.key,
  });

  /// The swap shown.
  final String swapId;

  /// Called with the swap's id once it has started.
  final Function(String)? onSwapStarted;

  @override
  State<NativeP2pSwapModal> createState() => _NativeP2pSwapModalState();
}

class _NativeP2pSwapModalState extends State<NativeP2pSwapModal> {
  late final HtlcSwapBloc _htlcSwapBloc;

  String _swapCompletedText = 'Swap completed';

  bool _isSendingTransaction = false;
  bool _shouldShowIncorrectAmountInstructions = false;

  @override
  void initState() {
    super.initState();
    _htlcSwapBloc = HtlcSwapBloc(widget.swapId);
    _htlcSwapBloc.getDataPeriodically();
  }

  @override
  void dispose() {
    _htlcSwapBloc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HtlcSwap>(
      stream: _htlcSwapBloc.stream,
      builder: (_, AsyncSnapshot<HtlcSwap> snapshot) {
        if (snapshot.hasData) {
          return BaseModal(
            title: _getTitle(snapshot.data!),
            child: _buildContent(snapshot.data!),
          );
        } else if (snapshot.hasError) {
          return BaseModal(
            title: '',
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: RepaintBoundary(
                child: SyriusErrorWidget(snapshot.error!),
              ),
            ),
          );
        }
        return const SyriusLoadingWidget(size: 18, strokeWidth: 1.5);
      },
    );
  }

  String _getTitle(HtlcSwap swap) {
    return swap.state == P2pSwapState.active ? 'Active swap' : '';
  }

  TextStyle get _dim =>
      Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 13);

  TextStyle get _body =>
      Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 14);

  Widget _buildContent(HtlcSwap swap) {
    switch (swap.state) {
      case P2pSwapState.pending:
        return _buildPendingView();
      case P2pSwapState.active:
        return _buildActiveView(swap);
      case P2pSwapState.completed:
        return _buildCompletedView(swap);
      case P2pSwapState.reclaimable:
      case P2pSwapState.unsuccessful:
        return _buildUnsuccessfulView(swap);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPendingView() {
    return SizedBox(
      height: 180,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text('Starting swap', style: _body.copyWith(fontSize: 15)),
          const SizedBox(height: 20),
          const SyriusLoadingWidget(size: 18, strokeWidth: 1.5),
        ],
      ),
    );
  }

  Widget _buildActiveView(HtlcSwap swap) {
    return Column(
      children: <Widget>[
        const SizedBox(height: 20),
        HtlcCard.sending(swap: swap),
        const SizedBox(height: 10),
        const Icon(Icons.arrow_downward, color: AppColors.faint, size: 18),
        const SizedBox(height: 10),
        HtlcCard.receiving(swap: swap),
        const SizedBox(height: 20),
        _buildBottomSection(swap),
      ],
    );
  }

  /// The inner surface of a result: the card colour on the dialog's raised
  /// tone, at the card radius.
  Widget _buildSummary(List<Widget> rows) {
    return Material(
      color: Theme.of(context).colorScheme.primary,
      borderRadius: BorderRadius.circular(kCardRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(children: rows),
      ),
    );
  }

  /// A label and its value at the two ends of a line.
  ///
  /// An amount is a single text and fades if it outgrows the line. The rate
  /// is a row of its own that would stretch across the space it is given,
  /// so with [shrinkValue] it is laid out at its own width instead.
  Widget _buildSummaryRow(
    String label,
    Widget value, {
    bool shrinkValue = false,
  }) {
    return SizedBox(
      height: 32,
      child: Row(
        children: <Widget>[
          Text(label, style: _dim),
          const SizedBox(width: 12),
          if (shrinkValue) ...<Widget>[
            const Spacer(),
            value,
          ] else
            Expanded(
              child: Align(alignment: Alignment.centerRight, child: value),
            ),
        ],
      ),
    );
  }

  Widget _buildAmount(BigInt amount, int decimals, String symbol) {
    return AmountText(amount, decimals: decimals, style: _body, symbol: symbol);
  }

  Widget _buildCompletedView(HtlcSwap swap) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const SizedBox(height: 10),
        SizedBox(
          width: 64,
          height: 64,
          child: SvgPicture.asset(
            'assets/svg/ic_completed_symbol.svg',
            colorFilter: const ColorFilter.mode(
              AppColors.znnColor,
              BlendMode.srcIn,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _swapCompletedText,
          textAlign: TextAlign.center,
          style: _body.copyWith(fontSize: 15),
        ),
        const SizedBox(height: 20),
        _buildSummary(<Widget>[
          _buildSummaryRow(
            'Sent',
            _buildAmount(swap.fromAmount, swap.fromDecimals, swap.fromSymbol),
          ),
          _buildSummaryRow(
            'Received',
            _buildAmount(swap.toAmount!, swap.toDecimals!, swap.toSymbol!),
          ),
          _buildSummaryRow(
            'Rate',
            _buildExchangeRate(swap),
            shrinkValue: true,
          ),
        ]),
        const SizedBox(height: 16),
        HtlcSwapDetailsWidget(swap: swap),
      ],
    );
  }

  Widget _buildUnsuccessfulView(HtlcSwap swap) {
    final int? expiration = swap.direction == P2pSwapDirection.outgoing
        ? swap.initialHtlcExpirationTime
        : swap.counterHtlcExpirationTime;
    final Duration remainingDuration = Duration(
      seconds: (expiration ?? 0) - DateTimeUtils.unixTimeNow,
    );
    final bool isReclaimable =
        remainingDuration.inSeconds <= 0 &&
        swap.state == P2pSwapState.reclaimable;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const SizedBox(height: 10),
        SizedBox(
          width: 64,
          height: 64,
          child: SvgPicture.asset(
            'assets/svg/ic_unsuccessful_symbol.svg',
            colorFilter: const ColorFilter.mode(
              AppColors.errorColor,
              BlendMode.srcIn,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          isReclaimable || swap.state == P2pSwapState.unsuccessful
              ? 'Swap unsuccessful'
              : 'Swap unsuccessful. Reclaim your deposit once it expires.',
          style: _body.copyWith(fontSize: 15),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _buildSummary(<Widget>[
          if (remainingDuration.inSeconds > 0)
            TweenAnimationBuilder<Duration>(
              duration: remainingDuration,
              tween: Tween<Duration>(
                begin: remainingDuration,
                end: Duration.zero,
              ),
              onEnd: () => setState(() {}),
              builder: (_, Duration d, _) {
                return Visibility(
                  visible: d.inSeconds > 0,
                  child: _buildSummaryRow(
                    'Deposit expires in',
                    Text(
                      d.toString().split('.').first,
                      style: monoStyle(_body),
                    ),
                  ),
                );
              },
            ),
          _buildSummaryRow(
            swap.state == P2pSwapState.reclaimable ? 'Deposited' : 'Reclaimed',
            _buildAmount(swap.fromAmount, swap.fromDecimals, swap.fromSymbol),
          ),
        ]),
        if (isReclaimable)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: _buildReclaimButton(swap),
          ),
        const SizedBox(height: 16),
        HtlcSwapDetailsWidget(swap: swap),
      ],
    );
  }

  Widget _buildBottomSection(HtlcSwap swap) {
    if (swap.counterHtlcId == null) {
      return Column(
        children: <Widget>[
          Text(
            'Send the deposit ID to your counterparty so they can join.',
            textAlign: TextAlign.center,
            style: _dim.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('p2p_copy_deposit_id'),
              onPressed: () =>
                  ClipboardUtils.copyToClipboard(swap.initialHtlcId, context),
              icon: const Icon(Icons.copy_outlined, size: 18),
              label: const Text('Copy deposit ID'),
            ),
          ),
        ],
      );
    }
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _buildSummaryRow(
            'Rate',
            _buildExchangeRate(swap),
            shrinkValue: true,
          ),
        ),
        const SizedBox(height: 16),
        if (swap.direction == P2pSwapDirection.outgoing) ...<Widget>[
          if (!isTrustedToken(swap.toTokenStandard ?? ''))
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: ImportantTextContainer(
                text:
                    'This token is not in your favorites. Check its token '
                    'standard: ${swap.toTokenStandard ?? ''}',
                isSelectable: true,
              ),
            ),
          _buildExpirationWarningForOutgoingSwap(swap),
          _buildSwapButton(swap),
          const SizedBox(height: 16),
          _buildIncorrectAmountButton(swap),
        ],
        if (swap.direction == P2pSwapDirection.incoming)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LoadingInfoText(
              text: 'Waiting for the counterparty. Keep Syrius open.',
              tooltipText: 'The wallet does not auto-lock during a swap',
            ),
          ),
      ],
    );
  }

  Widget _buildExpirationWarningForOutgoingSwap(HtlcSwap swap) {
    const Duration warningThreshold = Duration(minutes: 10);
    final Duration timeToCompleteSwap =
        Duration(
          seconds: swap.counterHtlcExpirationTime! - DateTimeUtils.unixTimeNow,
        ) -
        kMinSafeTimeToCompleteSwap;
    return TweenAnimationBuilder<Duration>(
      duration: timeToCompleteSwap,
      tween: Tween<Duration>(begin: timeToCompleteSwap, end: Duration.zero),
      onEnd: () => setState(() {}),
      builder: (_, Duration d, _) {
        return Visibility(
          visible: timeToCompleteSwap <= warningThreshold,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: ImportantTextContainer(
              text: context.l10n.p2pSwapExpiresIn(
                FormatUtils.formatDuration(context.l10n, d),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSwapButton(HtlcSwap swap) {
    return ViewModelBuilder<CompleteHtlcSwapBloc>.reactive(
      onViewModelReady: (CompleteHtlcSwapBloc model) {
        model.stream.listen(
          (HtlcSwap? event) async {
            if (event is HtlcSwap) {
              setState(() {
                _swapCompletedText = 'Swap completed. Funds arrive shortly.';
              });
            }
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _isSendingTransaction = false;
            });
            ToastUtils.showToast(context, error.toString());
          },
        );
      },
      builder: (_, CompleteHtlcSwapBloc model, _) => InstructionButton(
        text: 'Swap',
        isEnabled: true,
        isLoading: _isSendingTransaction,
        loadingText: 'Swapping',
        onPressed: () {
          setState(() {
            _isSendingTransaction = true;
          });
          unawaited(model.completeHtlcSwap(swap: swap));
        },
      ),
      viewModelBuilder: CompleteHtlcSwapBloc.new,
    );
  }

  Widget _buildIncorrectAmountButton(HtlcSwap swap) {
    return SizedBox(
      width: double.infinity,
      child: AnimatedCrossFade(
        duration: Durations.short4,
        firstCurve: Easing.standard,
        secondCurve: Easing.standard,
        sizeCurve: Easing.standard,
        firstChild: Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            mouseCursor: SystemMouseCursors.click,
            onTap: () => setState(() {
              _shouldShowIncorrectAmountInstructions = true;
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text('Wrong token or amount?', style: _dim),
            ),
          ),
        ),
        secondChild: _buildIncorrectAmountInstructions(
          swap.initialHtlcExpirationTime,
        ),
        crossFadeState: _shouldShowIncorrectAmountInstructions
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
      ),
    );
  }

  Widget _buildIncorrectAmountInstructions(int expirationTime) {
    final String expires = FormatUtils.formatDeadline(expirationTime * 1000);
    return Text(
      'Do not swap. Your deposit expires at $expires; reclaim it then.',
      textAlign: TextAlign.center,
      style: _dim,
    );
  }

  Widget _buildReclaimButton(HtlcSwap swap) {
    return ViewModelBuilder<ReclaimHtlcSwapFundsBloc>.reactive(
      onViewModelReady: (ReclaimHtlcSwapFundsBloc model) {
        model.stream.listen(
          null,
          onError: (Object error) {
            setState(() {
              _isSendingTransaction = false;
            });
          },
        );
      },
      builder: (_, ReclaimHtlcSwapFundsBloc model, _) => InstructionButton(
        text: 'Reclaim funds',
        isEnabled: true,
        isLoading: _isSendingTransaction,
        loadingText: 'Reclaiming',
        onPressed: () {
          setState(() {
            _isSendingTransaction = true;
          });
          unawaited(
            model.reclaimFunds(
              htlcId: swap.direction == P2pSwapDirection.outgoing
                  ? Hash.parse(swap.initialHtlcId)
                  : Hash.parse(swap.counterHtlcId!),
              selfAddress: Address.parse(swap.selfAddress),
            ),
          );
        },
      ),
      viewModelBuilder: ReclaimHtlcSwapFundsBloc.new,
    );
  }

  Widget _buildExchangeRate(HtlcSwap swap) {
    return ExchangeRateWidget(
      fromAmount: swap.fromAmount,
      fromDecimals: swap.fromDecimals,
      fromSymbol: swap.fromSymbol,
      toAmount: swap.toAmount!,
      toDecimals: swap.toDecimals!,
      toSymbol: swap.toSymbol!,
    );
  }
}
