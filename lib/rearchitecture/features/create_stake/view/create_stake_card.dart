import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The least width of the Stake button, as the Send button beside its field.
const double _kButtonMinWidth = 104;

/// A card that lets the user create a stake for the selected address.
class CreateStakeCard extends StatelessWidget {
  /// Creates a stake creation widget.
  const CreateStakeCard({
    required this.onStakeCreated,
    this.framed = true,
    super.key,
  });

  /// Called after a stake transaction was successfully created.
  final VoidCallback onStakeCreated;

  /// Whether the form stands in a titled card that fills its cell. Without
  /// the frame it is a bare surface as tall as the form, laid out along
  /// one line: what opens under the Staking page's strip.
  final bool framed;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SendTransactionBloc>(
      create: (_) => SendTransactionBloc(),
      child: _View(onStakeCreated: onStakeCreated, framed: framed),
    );
  }
}

class _View extends StatelessWidget {
  const _View({required this.onStakeCreated, required this.framed});

  final VoidCallback onStakeCreated;

  final bool framed;

  @override
  Widget build(BuildContext context) {
    // The stake is made from the selected address, which can change while
    // the page is open.
    context.watch<SelectedAddressNotifier>();
    final Widget body = BlocBuilder<MultipleBalanceBloc, MultipleBalanceState>(
      builder: (_, MultipleBalanceState state) {
        final AccountInfo? accountInfo = state.data?[kSelectedAddress];
        return StateSwitcher(
          child: switch (state.status) {
            MultipleBalanceStatus.failure => CardNote.error(
              state.error!,
              key: const ValueKey<String>('failure'),
            ),
            // A refresh keeps the balances it had, so the form stays up,
            // with what was typed in it, while the new ones load.
            _ when accountInfo != null => _Populated(
              key: const ValueKey<String>('form'),
              accountInfo: accountInfo,
              onStakeCreated: onStakeCreated,
              framed: framed,
            ),
            _ => const _Loading(key: ValueKey<String>('loading')),
          },
        );
      },
    );
    if (!framed) return Panel(child: body);
    return Panel(
      title: 'New stake',
      actions: const <Widget>[RefreshButton(onPressed: _fetchBalance)],
      child: body,
    );
  }
}

/// The width of the duration menu where it shares a line with the amount.
const double _kDurationWidth = 200;

void _fetchBalance() {
  sl.get<MultipleBalanceBloc>().add(
    MultipleBalanceFetch(
      addresses: kDefaultAddressList.map((String? e) => e!).toList(),
    ),
  );
}

/// The form while the balance loads: a bar or a block where each of its
/// parts will be, so the form arrives where they stood.
class _Loading extends StatelessWidget {
  const _Loading({super.key});

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: kCardBodyPadding,
      child: RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // The Available line: its label, and the balance at the right.
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Skeleton(width: 72),
                  Skeleton(width: 96),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Skeleton(height: kCardFieldHeight, radius: tokens.cardRadius),
            SizedBox(height: tokens.cardGap),
            Row(
              children: <Widget>[
                Expanded(
                  child: Skeleton(
                    height: kCardFieldHeight,
                    radius: tokens.cardRadius,
                  ),
                ),
                SizedBox(width: tokens.cardGap),
                const Skeleton(
                  width: _kButtonMinWidth,
                  height: kCardFieldHeight,
                  radius: kCardFieldHeight / 2,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Populated extends StatefulWidget {
  const _Populated({
    required this.accountInfo,
    required this.onStakeCreated,
    required this.framed,
    super.key,
  });

  final AccountInfo accountInfo;

  final VoidCallback onStakeCreated;

  final bool framed;

  @override
  State<_Populated> createState() => _PopulatedState();
}

class _PopulatedState extends State<_Populated> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _menuLabelController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();

  final GlobalKey<LoadingButtonState> _stakeButtonKey = GlobalKey();

  final List<Duration> _durations = List<Duration>.generate(
    stakeTimeMaxSec ~/ stakeTimeUnitSec,
    (int index) => Duration(seconds: (index + 1) * stakeTimeUnitSec),
  );

  Duration? _selectedStakeDuration;

  BigInt get _maxZnnAmount =>
      widget.accountInfo.getBalance(kZnnCoin.tokenStandard);

  String get _amount => _amountController.text;

  String? get _amountErrorText => _amount.isNotEmpty
      ? InputValidators.correctValue(
          _amount,
          _maxZnnAmount,
          kZnnCoin.decimals,
          stakeMinZnnAmount,
          canBeEqualToMin: true,
        )
      : null;

  bool get _isInputValid =>
      _selectedStakeDuration != null &&
      _amount.isNotEmpty &&
      _amountErrorText == null;

  @override
  void dispose() {
    _amountController.dispose();
    _menuLabelController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final Widget available = ValueFlash(
      // Another address's balance is not a change of this one.
      key: ValueKey<String?>(kSelectedAddress),
      value: _maxZnnAmount,
      color: tokens.znnInk,
      child: CardAvailable(
        amount: _maxZnnAmount,
        decimals: kZnnCoin.decimals,
        symbol: kZnnCoin.symbol,
        symbolColor: tokens.znnInk,
      ),
    );
    final Widget duration = FocusTraversalOrder(
      order: const NumericFocusOrder(1),
      child: _DurationDropdown(
        controller: _menuLabelController,
        durations: _durations,
        onSelected: _onStakeDurationChanged,
      ),
    );
    final Widget amount = FocusTraversalOrder(
      order: const NumericFocusOrder(2),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _amountController,
        // A refused key, a comma for one, says so under the field, over
        // what the validator says.
        builder: (_, TextEditingValue amount, _) => AmountRefusalScope(
          controller: _amountController,
          builder: (_, String? refusal) => TextField(
            key: const Key('create_stake_amount_field'),
            controller: _amountController,
            focusNode: _amountFocusNode,
            style: monoStyle(cardValueStyle(context)),
            decoration: InputDecoration(
              errorText: refusal ?? _amountErrorText,
              hintText: context.l10n.amount,
              suffixIcon: CardFieldAction(
                label: context.l10n.max,
                onPressed: _maxZnnAmount > BigInt.zero ? _onMaxPressed : null,
              ),
            ),
            inputFormatters: FormatUtils.getAmountTextInputFormatters(
              amount.text,
            ),
            onSubmitted: (_) => _onStakePressed(),
          ),
        ),
      ),
    );
    final Widget submit = FocusTraversalOrder(
      order: const NumericFocusOrder(3),
      child: ListenableBuilder(
        listenable: _amountController,
        builder: (_, _) => KeyedSubtree(
          key: const Key('create_stake_submit_button'),
          child: LoadingButton(
            key: _stakeButtonKey,
            text: context.l10n.stake,
            minimumSize: const Size(_kButtonMinWidth, kCardFieldHeight),
            paddingAroundChild: const EdgeInsets.symmetric(horizontal: 20),
            circularBorderRadius: kCardFieldHeight / 2,
            onPressed: _isInputValid ? _onStakePressed : null,
          ),
        ),
      ),
    );
    return BlocListener<SendTransactionBloc, SendTransactionState>(
      listener: (_, SendTransactionState state) =>
          _onTransactionStateChanged(state),
      // The stake is always made from the selected address, which the
      // shell already names; the old disabled address field is gone.
      child: CardFields(
        // Tab goes through the fields before it reaches the button.
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: widget.framed
              // A scroll view, so an error line under the amount can never
              // push the Stake button off the card.
              ? SingleChildScrollView(
                  padding: kCardBodyPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      available,
                      const SizedBox(height: 12),
                      duration,
                      SizedBox(height: tokens.cardGap),
                      // The amount and the one action of the card share a
                      // line.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(child: amount),
                          SizedBox(width: tokens.cardGap),
                          submit,
                        ],
                      ),
                    ],
                  ),
                )
              // As tall as the form, so the page under it moves down by
              // no more than that: the whole form on one line, under what
              // can be spent. The card's refresh button has no title row
              // to stand in here and ends that first line.
              : Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(child: available),
                          const RefreshButton(onPressed: _fetchBalance),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(width: _kDurationWidth, child: duration),
                          SizedBox(width: tokens.cardGap),
                          Expanded(child: amount),
                          SizedBox(width: tokens.cardGap),
                          submit,
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  void _onStakeDurationChanged(Duration? value) {
    setState(() {
      _selectedStakeDuration = value;
    });
    if (value != null) {
      _amountFocusNode.requestFocus();
    }
  }

  void _onMaxPressed() {
    _amountController.text = _maxZnnAmount.addDecimals(kZnnCoin.decimals);
  }

  void _onStakePressed() {
    if (!_isInputValid) {
      return;
    }

    final AccountBlockTemplate block = zenon!.embedded.stake.stake(
      _selectedStakeDuration!.inSeconds,
      _amount.extractDecimals(kZnnCoin.decimals),
    );

    context.read<SendTransactionBloc>().add(
      SendTransactionInitiateFromBlock(
        block: block,
        fromAddress: kSelectedAddress!,
        reasonForGeneratingPlasma: context.l10n.plasmaPurposeCreateStake,
      ),
    );
  }

  void _onTransactionStateChanged(SendTransactionState state) {
    if (state.status == SendTransactionStatus.loading) {
      _stakeButtonKey.currentState?.animateForward();
    } else if (state.status == SendTransactionStatus.success) {
      _stakeButtonKey.currentState?.animateReverse();
      setState(() {
        _amountController.clear();
        _menuLabelController.clear();
        _selectedStakeDuration = null;
      });
      widget.onStakeCreated();
      _fetchBalance();
    } else if (state.status == SendTransactionStatus.failure) {
      _stakeButtonKey.currentState?.animateReverse();
      unawaited(
        NotificationUtils.sendNotificationError(
          state.error!,
          context.l10n.errorWhileGeneratingStake,
        ),
      );
    }
  }
}

/// How long to stake for: one to twelve months.
class _DurationDropdown extends StatelessWidget {
  const _DurationDropdown({
    required this.controller,
    required this.durations,
    required this.onSelected,
  });

  final TextEditingController controller;
  final List<Duration> durations;
  final ValueChanged<Duration?> onSelected;

  @override
  Widget build(BuildContext context) {
    final Color faint = AppTokens.of(context).faint;
    return DropdownMenu<Duration>(
      controller: controller,
      key: const Key('create_stake_duration_dropdown'),
      hintText: context.l10n.duration,
      dropdownMenuEntries: <DropdownMenuEntry<Duration>>[
        for (final Duration duration in durations)
          DropdownMenuEntry<Duration>(
            value: duration,
            label: stakeDurationText(duration.inSeconds),
          ),
      ],
      onSelected: onSelected,
      selectOnly: true,
      expandedInsets: EdgeInsets.zero,
      // No decoration of its own: it takes the card's, from CardFields, so
      // it matches the amount field under it.
      menuHeight: kDropdownMenuHeight,
      textStyle: cardValueStyle(context),
      trailingIcon: Icon(Icons.keyboard_arrow_down_rounded, color: faint),
      selectedTrailingIcon: Icon(
        Icons.keyboard_arrow_up_rounded,
        color: faint,
      ),
    );
  }
}
