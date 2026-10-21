import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/ltr.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The least width of the Fuse button, as the Send button beside its field.
const double _kButtonMinWidth = 104;

/// The width of the meter that previews the plasma a fusion gives.
const double _kPreviewMeterWidth = 120;

/// The form that fuses QSR from the selected address into plasma for a
/// beneficiary.
class FusePlasmaCard extends StatelessWidget {
  /// Creates a [FusePlasmaCard].
  const FusePlasmaCard({required this.onPlasmaFused, super.key});

  /// Called after a fuse transaction was successfully created: the place to
  /// reload what shows the fusion, the plasma levels and the fusions.
  final VoidCallback onPlasmaFused;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FusePlasmaBloc>(
      create: (_) => FusePlasmaBloc(
        accountBlockUtils: AccountBlockUtils(),
        zenon: zenon!,
        zenonAddressUtils: ZenonAddressUtils(),
      ),
      child: _View(onPlasmaFused: onPlasmaFused),
    );
  }
}

class _View extends StatelessWidget {
  const _View({required this.onPlasmaFused});

  final VoidCallback onPlasmaFused;

  @override
  Widget build(BuildContext context) {
    // The form spends from the selected address, which can change while the
    // page is open.
    context.watch<SelectedAddressNotifier>();
    return Panel(
      title: context.l10n.fuse,
      actions: const <Widget>[RefreshButton(onPressed: _fetchBalance)],
      child: BlocBuilder<MultipleBalanceBloc, MultipleBalanceState>(
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
                onPlasmaFused: onPlasmaFused,
              ),
              _ => const _Loading(key: ValueKey<String>('loading')),
            },
          );
        },
      ),
    );
  }
}

/// The form while the balance loads: a bar or a block where each of its
/// parts will be, so the form arrives where they stood.
class _Loading extends StatelessWidget {
  const _Loading({super.key});

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final Widget field = Skeleton(
      height: kCardFieldHeight,
      radius: tokens.cardRadius,
    );
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
            // The beneficiary.
            field,
            SizedBox(height: tokens.cardGap),
            // The amount, and the Fuse button beside it.
            Row(
              children: <Widget>[
                Expanded(child: field),
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

void _fetchBalance() {
  sl.get<MultipleBalanceBloc>().add(
    MultipleBalanceFetch(
      addresses: kDefaultAddressList.map((String? e) => e!).toList(),
    ),
  );
}

class _Populated extends StatefulWidget {
  const _Populated({
    required this.accountInfo,
    required this.onPlasmaFused,
    super.key,
  });

  final AccountInfo accountInfo;
  final VoidCallback onPlasmaFused;

  @override
  State<_Populated> createState() => _PopulatedState();
}

class _PopulatedState extends State<_Populated> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _beneficiaryController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();
  final GlobalKey<LoadingButtonState> _fuseButtonKey = GlobalKey();

  late final Listenable _inputs = Listenable.merge(<Listenable>[
    _amountController,
    _beneficiaryController,
  ]);

  BigInt get _maxQsrAmount =>
      widget.accountInfo.getBalance(kQsrCoin.tokenStandard);

  String get _amount => _amountController.text;

  String get _beneficiary => _beneficiaryController.text;

  String? get _amountError => _amount.isEmpty
      ? null
      : InputValidators.correctValue(
          _amount,
          _maxQsrAmount,
          kQsrCoin.decimals,
          fuseMinQsrAmount,
          canBeEqualToMin: true,
        );

  String? get _beneficiaryError =>
      _beneficiary.isEmpty ? null : InputValidators.checkAddress(_beneficiary);

  bool get _isInputValid =>
      _amount.isNotEmpty &&
      _amountError == null &&
      _beneficiary.isNotEmpty &&
      _beneficiaryError == null;

  /// The plasma the typed amount would add; nothing while it is not a number.
  int get _plasmaToAdd {
    if (_amount.isEmpty) return 0;
    try {
      return plasmaForQsr(
        _amount.extractDecimals(kQsrCoin.decimals),
        kQsrCoin.decimals,
      );
    } on FormatException {
      return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _beneficiaryController
      ..text = context.read<PlasmaBeneficiaryAddressCubit>().state ?? ''
      ..addListener(_onBeneficiaryTyped);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _beneficiaryController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    return MultiBlocListener(
      listeners: <BlocListener<dynamic, dynamic>>[
        BlocListener<FusePlasmaBloc, FusePlasmaState>(
          listener: (_, FusePlasmaState state) => _onFuseStateChanged(state),
        ),
        BlocListener<PlasmaBeneficiaryAddressCubit, String?>(
          listener: (_, String? address) => _onBeneficiaryPicked(address),
        ),
      ],
      child: CardFields(
        // Tab goes through the fields before it reaches the button.
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          // A scroll view, so an error line under a field can never push
          // the Fuse button off the card.
          child: SingleChildScrollView(
            padding: kCardBodyPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ValueFlash(
                  // Another address's balance is not a change of this one.
                  key: ValueKey<String?>(kSelectedAddress),
                  value: _maxQsrAmount,
                  color: tokens.qsrInk,
                  child: CardAvailable(
                    amount: _maxQsrAmount,
                    decimals: kQsrCoin.decimals,
                    symbol: kQsrCoin.symbol,
                    symbolColor: tokens.qsrInk,
                  ),
                ),
                const SizedBox(height: 12),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _beneficiaryController,
                    builder: (_, _, _) => TextField(
                      key: const Key('fuse_plasma_beneficiary_address_field'),
                      controller: _beneficiaryController,
                      style: monoStyle(cardValueStyle(context)),
                      // An address is typed and read left to right in every
                      // language, from the app's start. The hint, the suffix
                      // and the error line keep the app's direction.
                      textDirection: TextDirection.ltr,
                      textAlign: ltrTextAlign(context, TextAlign.start),
                      decoration: InputDecoration(
                        errorText: _beneficiaryError,
                        hintText: context.l10n.beneficiaryAddress,
                        suffixIcon: FieldSuffixButtons(
                          controller: _beneficiaryController,
                        ),
                      ),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp('[0-9a-z]')),
                      ],
                      onSubmitted: (_) => _amountFocusNode.requestFocus(),
                    ),
                  ),
                ),
                SizedBox(height: tokens.cardGap),
                // The amount and the one action of the card share a line.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: FocusTraversalOrder(
                        order: const NumericFocusOrder(2),
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _amountController,
                          // QSR is fused whole. A refused key, a point or a
                          // comma for one, says so under the field, over
                          // what the validator says.
                          builder: (_, TextEditingValue value, _) =>
                              AmountRefusalScope(
                                controller: _amountController,
                                builder: (_, String? refusal) => TextField(
                                  key: const Key('fuse_plasma_amount_field'),
                                  controller: _amountController,
                                  focusNode: _amountFocusNode,
                                  enabled: _maxQsrAmount > BigInt.zero,
                                  style: monoStyle(cardValueStyle(context)),
                                  // An amount, like the address above.
                                  textDirection: TextDirection.ltr,
                                  textAlign: ltrTextAlign(
                                    context,
                                    TextAlign.start,
                                  ),
                                  decoration: InputDecoration(
                                    errorText: refusal ?? _amountError,
                                    hintText: context.l10n.amount,
                                    suffixIcon: CardFieldAction(
                                      label: context.l10n.max,
                                      onPressed: _maxQsrAmount > BigInt.zero
                                          ? _onMaxPressed
                                          : null,
                                    ),
                                  ),
                                  inputFormatters:
                                      FormatUtils.getPlasmaAmountTextInputFormatters(
                                        value.text,
                                      ),
                                  onSubmitted: (_) {
                                    if (_isInputValid) {
                                      _onFusePressed();
                                    }
                                  },
                                ),
                              ),
                        ),
                      ),
                    ),
                    SizedBox(width: tokens.cardGap),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(3),
                      child: ListenableBuilder(
                        listenable: _inputs,
                        builder: (_, _) => KeyedSubtree(
                          key: const Key('fuse_plasma_submit_button'),
                          child: LoadingButton(
                            key: _fuseButtonKey,
                            text: context.l10n.fuse,
                            minimumSize: const Size(
                              _kButtonMinWidth,
                              kCardFieldHeight,
                            ),
                            paddingAroundChild: const EdgeInsets.symmetric(
                              horizontal: 20,
                            ),
                            circularBorderRadius: kCardFieldHeight / 2,
                            onPressed: _isInputValid ? _onFusePressed : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: _inputs,
                  builder: (_, _) => _After(
                    visible: _isInputValid,
                    beneficiary: _beneficiary,
                    plasmaToAdd: _plasmaToAdd,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onFusePressed() {
    final FusePlasmaBloc bloc = context.read<FusePlasmaBloc>();
    // Enter in the amount field reaches here too, and the busy button does
    // not stop it: a second Enter would send a second fusion.
    if (!_isInputValid || bloc.state is FusePlasmaLoading) {
      return;
    }
    bloc.add(
      FusePlasmaRequested(
        beneficiaryAddress: _beneficiary,
        amount: _amount.extractDecimals(kQsrCoin.decimals),
      ),
    );
  }

  void _onMaxPressed() {
    if (_amount.isEmpty ||
        _amount.extractDecimals(kQsrCoin.decimals) != _maxQsrAmount) {
      _amountController.text = _maxQsrAmount.addDecimals(kQsrCoin.decimals);
    }
  }

  /// Keeps the address marked in the Plasma card in step with the field: a
  /// typed address that is not the marked one unmarks it.
  void _onBeneficiaryTyped() {
    final PlasmaBeneficiaryAddressCubit cubit = context
        .read<PlasmaBeneficiaryAddressCubit>();
    final String? typed = _beneficiary.isEmpty ? null : _beneficiary;
    if (cubit.state != typed) {
      cubit.changeAddress(typed);
    }
  }

  /// An address picked elsewhere (a row of the Plasma card, a new selected
  /// address) fills the field.
  void _onBeneficiaryPicked(String? address) {
    if (address == null || address == _beneficiary) {
      return;
    }
    _beneficiaryController.text = address;
  }

  void _onFuseStateChanged(FusePlasmaState state) {
    if (state is FusePlasmaLoading) {
      _fuseButtonKey.currentState?.animateForward();
    } else if (state is FusePlasmaDone) {
      _fuseButtonKey.currentState?.animateReverse();
      // The beneficiary stays: the next fusion is most often for the same
      // address, and its row stays marked.
      _amountController.clear();
      _fetchBalance();
      // The plasma levels and the fusions show the fusion only once the
      // contract has received it; the page reloads them until they do.
      widget.onPlasmaFused();
    } else if (state is FusePlasmaFailure) {
      _fuseButtonKey.currentState?.animateReverse();
      unawaited(
        NotificationUtils.sendNotificationError(
          state.exception,
          context.l10n.errorGeneratingPlasma,
        ),
      );
    }
  }
}

/// The level the beneficiary reaches once the fusion is in: what it has now,
/// where the wallet knows it, plus what the amount adds. Shown only for an
/// input that can be fused.
class _After extends StatelessWidget {
  const _After({
    required this.visible,
    required this.beneficiary,
    required this.plasmaToAdd,
  });

  final bool visible;
  final String beneficiary;
  final int plasmaToAdd;

  @override
  Widget build(BuildContext context) {
    // Known only for the wallet's own addresses; another address starts
    // from nothing here.
    final int current = context.select<PlasmaStatsBloc, int>((
      PlasmaStatsBloc bloc,
    ) {
      for (final PlasmaInfoWrapper w
          in bloc.state.data ?? const <PlasmaInfoWrapper>[]) {
        if (w.address == beneficiary) {
          return w.plasmaInfo.currentPlasma;
        }
      }
      return 0;
    });
    final int after = current + plasmaToAdd;
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: Durations.short4,
      curve: Easing.standard,
      child: CardRow(
        label: 'After fusing',
        value: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: _kPreviewMeterWidth,
              child: PlasmaLevelMeter(plasma: after),
            ),
            SizedBox(width: AppTokens.of(context).cardGap),
            PlasmaLevelLabel(plasma: after),
          ],
        ),
      ),
    );
  }
}
