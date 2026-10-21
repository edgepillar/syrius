import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:stacked/stacked.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/dashboard/balance_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/p2p_swap/htlc_swap/initial_htlc_for_swap_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/p2p_swap/htlc_swap/join_htlc_swap_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/htlc_swap.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/p2p_swap.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/clipboard_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/date_time_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/extensions.dart';
import 'package:zenon_syrius_wallet_flutter/utils/input_validators.dart';
import 'package:zenon_syrius_wallet_flutter/utils/toast_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/zts_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/htlc_card.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/bullet_point_card.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/instruction_button.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/error_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/exchange_rate_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/important_text_container.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_fields/input_fields.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/loading_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/base_modal.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// Joins a swap the counterparty started: find their deposit by its id,
/// then deposit the other side.
class JoinNativeSwapModal extends StatefulWidget {
  /// Creates the dialog. [onJoinedSwap] gets the id of the joined swap.
  const JoinNativeSwapModal({
    required this.onJoinedSwap,
    super.key,
  });

  /// Called with the swap's id once this wallet has joined it.
  final Function(String) onJoinedSwap;

  @override
  State<JoinNativeSwapModal> createState() => _JoinNativeSwapModalState();
}

class _JoinNativeSwapModalState extends State<JoinNativeSwapModal> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _depositIdController = TextEditingController();

  late String _selfAddress;

  HtlcInfo? _initialHltc;
  Future<Token?>? _tokenToReceive;
  String? _initialHtlcError;
  int? _safeExpirationTime;
  StreamSubscription<void>? _safeExpirationSubscription;

  Token _selectedToken = kZnnCoin;
  bool _isAmountValid = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    unawaited(sl.get<BalanceBloc>().getBalanceForAllAddresses());
    _safeExpirationSubscription =
        Stream<void>.periodic(const Duration(seconds: 5)).listen((_) {
          if (_initialHltc != null) {
            _safeExpirationTime = _calculateSafeExpirationTime(
              _initialHltc!.expirationTime,
            );
            setState(() {});
          }
        });
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    _depositIdController.dispose();
    unawaited(_safeExpirationSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseModal(
      title: 'Join swap',
      child: _initialHltc == null
          ? _buildSearchView()
          : FutureBuilder<Token?>(
              future: _tokenToReceive,
              builder: (_, AsyncSnapshot<Token?> snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: RepaintBoundary(
                      child: SyriusErrorWidget(snapshot.error!),
                    ),
                  );
                } else if (snapshot.hasData) {
                  return _buildContent(snapshot.data!);
                }
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: SyriusLoadingWidget(size: 18, strokeWidth: 1.5),
                );
              },
            ),
    );
  }

  Widget _buildSearchView() {
    return Column(
      children: <Widget>[
        const SizedBox(height: 20),
        Form(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: InputField(
            onChanged: (String value) {
              setState(() {});
            },
            validator: InputValidators.checkHash,
            controller: _depositIdController,
            suffixIcon: RawMaterialButton(
              shape: const CircleBorder(),
              onPressed: () => ClipboardUtils.pasteToClipboard(
                callback: (String value) {
                  _depositIdController.text = value;
                  setState(() {});
                },
              ),
              child: const Icon(
                Icons.content_paste,
                color: AppColors.faint,
                size: 15,
              ),
            ),
            suffixIconConstraints: const BoxConstraints(
              maxWidth: 45,
              maxHeight: 20,
            ),
            hintText: 'Deposit ID from your counterparty',
            contentLeftPadding: 10,
          ),
        ),
        const SizedBox(height: 20),
        if (_initialHtlcError != null) ...<Widget>[
          ImportantTextContainer(
            text: _initialHtlcError!,
            showBorder: true,
          ),
          const SizedBox(height: 20),
        ],
        _buildInitialHtlcViewModel(),
      ],
    );
  }

  ViewModelBuilder<InitialHtlcForSwapBloc> _buildInitialHtlcViewModel() {
    return ViewModelBuilder<InitialHtlcForSwapBloc>.reactive(
      onViewModelReady: (InitialHtlcForSwapBloc model) {
        model.stream.listen(
          (HtlcInfo? event) async {
            if (event is HtlcInfo) {
              _initialHltc = event;
              // Fetched once: the dialog rebuilds every few seconds, and a
              // future made in build would fetch the token every time.
              _tokenToReceive = zenon!.embedded.token.getByZts(
                event.tokenStandard,
              );
              _isLoading = false;
              _addressController.text = event.hashLocked.toString();
              _selfAddress = event.hashLocked.toString();
              _safeExpirationTime = _calculateSafeExpirationTime(
                event.expirationTime,
              );
              _initialHtlcError = null;
              setState(() {});
            }
          },
          onError: (Object error) {
            setState(() {
              _initialHtlcError = error.toString();
              _isLoading = false;
            });
          },
        );
      },
      builder: (_, InitialHtlcForSwapBloc model, _) =>
          _buildContinueButton(model),
      viewModelBuilder: InitialHtlcForSwapBloc.new,
    );
  }

  Widget _buildContinueButton(InitialHtlcForSwapBloc model) {
    return InstructionButton(
      text: 'Continue',
      loadingText: 'Searching',
      instructionText: 'Enter the deposit ID',
      isEnabled: _isHashValid(),
      isLoading: _isLoading,
      onPressed: () => _onContinueButtonPressed(model),
    );
  }

  Future<void> _onContinueButtonPressed(InitialHtlcForSwapBloc model) async {
    setState(() {
      _isLoading = true;
      _initialHtlcError = null;
    });
    unawaited(model.getInitialHtlc(Hash.parse(_depositIdController.text)));
  }

  Widget _buildContent(Token tokenToReceive) {
    final ThemeData theme = Theme.of(context);
    final TextStyle strong = theme.textTheme.bodyLarge!.copyWith(fontSize: 14);
    final int minutesLeft =
        (((_initialHltc!.expirationTime -
                        kMinSafeTimeToFindPreimage.inSeconds -
                        kCounterHtlcDuration.inSeconds) -
                    DateTimeUtils.unixTimeNow) /
                60)
            .ceil();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 20),
        LabeledInputContainer(
          labelText: 'Your address',
          helpText: 'The swapped funds arrive at this address',
          inputWidget: DisabledAddressField(
            _addressController,
            contentLeftPadding: 10,
          ),
        ),
        const SizedBox(height: 16),
        LabeledInputContainer(
          labelText: 'You send',
          inputWidget: Flexible(
            child: StreamBuilder<Map<String, AccountInfo>?>(
              stream: sl.get<BalanceBloc>().stream,
              builder: (_, AsyncSnapshot<Map<String, AccountInfo>?> snapshot) {
                if (snapshot.hasError) {
                  return RepaintBoundary(
                    child: SyriusErrorWidget(snapshot.error!),
                  );
                }
                if (snapshot.connectionState == ConnectionState.active &&
                    snapshot.hasData) {
                  return AmountInputField(
                    controller: _amountController,
                    accountInfo: snapshot.data![_selfAddress]!,
                    valuePadding: 10,
                    textColor: theme.colorScheme.inverseSurface,
                    initialToken: _selectedToken,
                    hintText: '0.0',
                    onChanged: (Token token, bool isValid) {
                      setState(() {
                        _selectedToken = token;
                        _isAmountValid = isValid;
                      });
                    },
                  );
                }
                return const SyriusLoadingWidget(size: 18, strokeWidth: 1.5);
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Icon(Icons.arrow_downward, color: AppColors.faint, size: 18),
        const SizedBox(height: 10),
        HtlcCard.fromHtlcInfo(
          title: 'You receive',
          htlc: _initialHltc!,
          token: tokenToReceive,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Rate',
                style: theme.textTheme.titleMedium!.copyWith(fontSize: 13),
              ),
              _buildExchangeRate(tokenToReceive),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_safeExpirationTime != null) ...<Widget>[
          BulletPointCard(
            bulletPoints: <RichText>[
              RichText(
                text: BulletPointCard.textSpan(
                  'Join within ',
                  children: <TextSpan>[
                    TextSpan(text: '$minutesLeft minutes', style: strong),
                    BulletPointCard.textSpan('.'),
                  ],
                ),
              ),
              RichText(
                text: BulletPointCard.textSpan(
                  'The counterparty then has ',
                  children: <TextSpan>[
                    TextSpan(
                      text: 'about ${kCounterHtlcDuration.inHours} hour',
                      style: strong,
                    ),
                    BulletPointCard.textSpan(' to complete the swap.'),
                  ],
                ),
              ),
              RichText(
                text: BulletPointCard.textSpan(
                  'If they do not, you can reclaim your funds.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!isTrustedToken(tokenToReceive.tokenStandard.toString()))
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: ImportantTextContainer(
                text:
                    'This token is not in your favorites. Check its token '
                    'standard: ${tokenToReceive.tokenStandard}',
                isSelectable: true,
              ),
            ),
          _buildJoinSwapViewModel(tokenToReceive),
        ] else
          const ImportantTextContainer(
            text: 'Too close to expiry to join safely.',
            showBorder: true,
          ),
      ],
    );
  }

  ViewModelBuilder<JoinHtlcSwapBloc> _buildJoinSwapViewModel(
    Token tokenToReceive,
  ) {
    return ViewModelBuilder<JoinHtlcSwapBloc>.reactive(
      onViewModelReady: (JoinHtlcSwapBloc model) {
        model.stream.listen(
          (HtlcSwap? event) async {
            if (event is HtlcSwap) {
              widget.onJoinedSwap.call(event.id);
            }
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
            });
            ToastUtils.showToast(context, error.toString());
          },
        );
      },
      builder: (_, JoinHtlcSwapBloc model, _) =>
          _buildJoinSwapButton(model, tokenToReceive),
      viewModelBuilder: JoinHtlcSwapBloc.new,
    );
  }

  Widget _buildJoinSwapButton(JoinHtlcSwapBloc model, Token tokenToReceive) {
    return InstructionButton(
      text: 'Join swap',
      instructionText: 'Enter an amount',
      loadingText: 'Sending',
      isEnabled: _isInputValid(),
      isLoading: _isLoading,
      onPressed: () => _onJoinButtonPressed(model, tokenToReceive),
    );
  }

  Future<void> _onJoinButtonPressed(
    JoinHtlcSwapBloc model,
    Token tokenToReceive,
  ) async {
    setState(() {
      _isLoading = true;
    });
    unawaited(
      model.joinHtlcSwap(
        initialHtlc: _initialHltc!,
        fromToken: _selectedToken,
        toToken: tokenToReceive,
        fromAmount: _amountController.text.extractDecimals(
          _selectedToken.decimals,
        ),
        swapType: P2pSwapType.native,
        fromChain: P2pSwapChain.nom,
        toChain: P2pSwapChain.nom,
        counterHtlcExpirationTime: _safeExpirationTime!,
      ),
    );
  }

  int? _calculateSafeExpirationTime(int initialHtlcExpiration) {
    final Duration minNeededRemainingTime =
        kMinSafeTimeToFindPreimage + kCounterHtlcDuration;
    final int now = DateTimeUtils.unixTimeNow;
    final Duration remaining = Duration(seconds: initialHtlcExpiration - now);
    return remaining >= minNeededRemainingTime
        ? now + kCounterHtlcDuration.inSeconds
        : null;
  }

  Widget _buildExchangeRate(Token tokenToReceive) {
    return ExchangeRateWidget(
      fromAmount: _amountController.text.extractDecimals(
        _selectedToken.decimals,
      ),
      fromDecimals: _selectedToken.decimals,
      fromSymbol: _selectedToken.symbol,
      toAmount: _initialHltc!.amount,
      toDecimals: tokenToReceive.decimals,
      toSymbol: tokenToReceive.symbol,
    );
  }

  bool _isInputValid() => _isAmountValid;

  bool _isHashValid() =>
      InputValidators.checkHash(_depositIdController.text) == null;
}
