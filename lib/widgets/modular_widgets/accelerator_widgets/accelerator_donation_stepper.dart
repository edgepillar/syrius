import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:stacked/stacked.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/motion/motion.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/custom_material_stepper.dart'
    as custom_material_stepper;
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The steps of a donation to the Accelerator.
enum AcceleratorDonationStep {
  /// The address that donates, and what it holds.
  donationAddress,

  /// How much ZNN and QSR.
  donationDetails,

  /// Sending it.
  submitDonation,
}

/// Donates ZNN, QSR or both from the selected address to the Accelerator.
class AcceleratorDonationStepper extends StatefulWidget {
  /// Creates the stepper.
  const AcceleratorDonationStepper({super.key});

  @override
  State<AcceleratorDonationStepper> createState() =>
      _AcceleratorDonationStepperState();
}

class _AcceleratorDonationStepperState
    extends State<AcceleratorDonationStepper> {
  AcceleratorDonationStep? _lastCompletedStep;
  AcceleratorDonationStep _currentStep = AcceleratorDonationStep.values.first;

  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _znnAmountController = TextEditingController();
  final TextEditingController _qsrAmountController = TextEditingController();

  final GlobalKey<FormState> _znnAmountKey = GlobalKey();
  final GlobalKey<FormState> _qsrAmountKey = GlobalKey();
  final GlobalKey<LoadingButtonState> _submitButtonKey = GlobalKey();

  BigInt _znnAmount = BigInt.zero;
  BigInt _qsrAmount = BigInt.zero;

  @override
  void initState() {
    super.initState();
    _addressController.text = kSelectedAddress!;
    unawaited(sl.get<BalanceBloc>().getBalanceForAllAddresses());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, AccountInfo>?>(
      stream: sl.get<BalanceBloc>().stream,
      builder: (_, AsyncSnapshot<Map<String, AccountInfo>?> snapshot) {
        final Widget state;
        if (snapshot.hasError) {
          state = SyriusErrorWidget(
            snapshot.error!,
            key: const ValueKey<String>('error'),
          );
        } else if (snapshot.connectionState == ConnectionState.active &&
            snapshot.hasData) {
          state = KeyedSubtree(
            key: const ValueKey<String>('steps'),
            child: _buildBody(
              context,
              snapshot.data![_addressController.text]!,
            ),
          );
        } else {
          state = const AccStepperLoading(key: ValueKey<String>('loading'));
        }
        return StateSwitcher(child: state);
      },
    );
  }

  Widget _buildBody(BuildContext context, AccountInfo accountInfo) {
    return AccStepperFrame(
      isDone: _lastCompletedStep == AcceleratorDonationStep.values.last,
      againLabel: 'Donate again',
      onAgain: () {
        setState(() {
          _currentStep = AcceleratorDonationStep.values.first;
          _lastCompletedStep = null;
        });
      },
      doneLabel: 'View projects',
      onDone: () {
        Navigator.pop(context);
      },
      stepper: custom_material_stepper.Stepper(
        currentStep: _currentStep.index,
        onStepTapped: (int index) {},
        steps: <custom_material_stepper.Step>[
          StepperUtils.getMaterialStep(
            stepTitle: 'Address',
            stepContent: _buildAddressStep(accountInfo),
            stepSubtitle: _addressController.text,
            stepState: StepperUtils.getStepState(
              AcceleratorDonationStep.donationAddress.index,
              _lastCompletedStep?.index,
            ),
            context: context,
          ),
          StepperUtils.getMaterialStep(
            stepTitle: 'Amount',
            stepContent: _buildAmountStep(accountInfo),
            stepSubtitle: _donationSummary(),
            stepState: StepperUtils.getStepState(
              AcceleratorDonationStep.donationDetails.index,
              _lastCompletedStep?.index,
            ),
            context: context,
          ),
          StepperUtils.getMaterialStep(
            stepTitle: 'Donate',
            stepContent: _buildSubmitStep(),
            stepSubtitle: 'Sent',
            stepState: StepperUtils.getStepState(
              AcceleratorDonationStep.submitDonation.index,
              _lastCompletedStep?.index,
            ),
            context: context,
          ),
        ],
      ),
    );
  }

  /// What was typed, as "10 ZNN · 5 QSR"; either part may be missing.
  String _donationSummary() {
    final String znnPrefix = _znnAmountController.text.isNotEmpty
        ? '${_znnAmountController.text} ${kZnnCoin.symbol}'
        : '';
    final String qsrSuffix = _qsrAmountController.text.isNotEmpty
        ? '${_qsrAmountController.text} ${kQsrCoin.symbol}'
        : '';
    final String splitter = znnPrefix.isNotEmpty && qsrSuffix.isNotEmpty
        ? ' · '
        : '';

    return znnPrefix + splitter + qsrSuffix;
  }

  Widget _buildAddressStep(AccountInfo accountInfo) {
    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AccField(
            label: 'From',
            child: DisabledAddressField(_addressController),
          ),
          Row(
            children: <Widget>[
              AccBalanceLine(kZnnCoin, accountInfo),
              const SizedBox(width: 20),
              AccBalanceLine(kQsrCoin, accountInfo),
            ],
          ),
          const SizedBox(height: kAccFieldGap),
          const DottedBorderInfoWidget(
            text: 'Donations go to the Accelerator fund',
          ),
          AccStepActions(
            primary: StepperButton(
              onPressed:
                  accountInfo.znn()! > BigInt.zero ||
                      accountInfo.qsr()! > BigInt.zero
                  ? () {
                      setState(() {
                        _lastCompletedStep =
                            AcceleratorDonationStep.donationAddress;
                        _currentStep = AcceleratorDonationStep.donationDetails;
                      });
                    }
                  : null,
              text: 'Continue',
            ),
            secondaryLabel: 'Cancel',
            onSecondary: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAmountStep(AccountInfo accountInfo) {
    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AccField(
            label: 'ZNN amount',
            child: Form(
              key: _znnAmountKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: InputField(
                hintText: '0.0',
                inputtedTextStyle: accFieldTextStyle(context, mono: true),
                controller: _znnAmountController,
                suffixIcon: AmountSuffixWidgets(
                  kZnnCoin,
                  onMaxPressed: () {
                    final BigInt maxZnn = accountInfo.getBalance(
                      kZnnCoin.tokenStandard,
                    );
                    if (_znnAmountController.text.isEmpty ||
                        _znnAmountController.text.extractDecimals(
                              coinDecimals,
                            ) <
                            maxZnn) {
                      setState(() {
                        _znnAmountController.text = maxZnn.addDecimals(
                          coinDecimals,
                        );
                      });
                    }
                  },
                ),
                validator: (String? value) => InputValidators.correctValue(
                  value,
                  accountInfo.znn()!,
                  coinDecimals,
                  BigInt.zero,
                  canBeEqualToMin: true,
                  canBeBlank: true,
                ),
                onChanged: (String value) {
                  setState(() {});
                },
                inputFormatters: FormatUtils.getAmountTextInputFormatters(
                  _znnAmountController.text,
                ),
              ),
            ),
          ),
          AccBalanceLine(kZnnCoin, accountInfo),
          const SizedBox(height: kAccFieldGap),
          AccField(
            label: 'QSR amount',
            child: Form(
              key: _qsrAmountKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: InputField(
                hintText: '0.0',
                inputtedTextStyle: accFieldTextStyle(context, mono: true),
                controller: _qsrAmountController,
                suffixIcon: AmountSuffixWidgets(
                  kQsrCoin,
                  onMaxPressed: () {
                    final BigInt maxQsr = accountInfo.getBalance(
                      kQsrCoin.tokenStandard,
                    );
                    if (_qsrAmountController.text.isEmpty ||
                        _qsrAmountController.text.extractDecimals(
                              coinDecimals,
                            ) <
                            maxQsr) {
                      setState(() {
                        _qsrAmountController.text = maxQsr.addDecimals(
                          coinDecimals,
                        );
                      });
                    }
                  },
                ),
                validator: (String? value) => InputValidators.correctValue(
                  value,
                  accountInfo.qsr()!,
                  coinDecimals,
                  BigInt.zero,
                  canBeEqualToMin: true,
                  canBeBlank: true,
                ),
                onChanged: (String value) {
                  setState(() {});
                },
                inputFormatters: FormatUtils.getAmountTextInputFormatters(
                  _qsrAmountController.text,
                ),
              ),
            ),
          ),
          AccBalanceLine(kQsrCoin, accountInfo),
          AccStepActions(
            primary: StepperButton(
              text: 'Continue',
              onPressed: _ifInputValid(accountInfo)
                  ? () {
                      setState(() {
                        _lastCompletedStep =
                            AcceleratorDonationStep.donationDetails;
                        _currentStep = AcceleratorDonationStep.submitDonation;
                      });
                    }
                  : null,
            ),
            secondaryLabel: 'Cancel',
            onSecondary: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  bool _ifInputValid(AccountInfo accountInfo) {
    try {
      _znnAmount = _znnAmountController.text.isNotEmpty
          ? _znnAmountController.text.extractDecimals(coinDecimals)
          : BigInt.zero;
      _qsrAmount = _qsrAmountController.text.isNotEmpty
          ? _qsrAmountController.text.extractDecimals(coinDecimals)
          : BigInt.zero;
    } on Object catch (_) {}

    return InputValidators.correctValue(
                  _znnAmountController.text,
                  accountInfo.znn()!,
                  coinDecimals,
                  BigInt.zero,
                  canBeEqualToMin: true,
                  canBeBlank: true,
                ) ==
                null &&
            InputValidators.correctValue(
                  _qsrAmountController.text,
                  accountInfo.qsr()!,
                  coinDecimals,
                  BigInt.zero,
                  canBeEqualToMin: true,
                  canBeBlank: true,
                ) ==
                null &&
            (_znnAmountController.text.isNotEmpty &&
                _qsrAmountController.text.isNotEmpty &&
                _znnAmount > BigInt.zero &&
                _znnAmount <= accountInfo.znn()! &&
                _qsrAmount > BigInt.zero &&
                _qsrAmount <= accountInfo.qsr()!) ||
        (_znnAmountController.text.isNotEmpty &&
            _qsrAmountController.text.isEmpty &&
            _znnAmount > BigInt.zero &&
            _znnAmount <= accountInfo.znn()!) ||
        (_znnAmountController.text.isEmpty &&
            !_qsrAmountController.text.isNotEmpty &&
            _qsrAmount > BigInt.zero &&
            _qsrAmount <= accountInfo.qsr()!);
  }

  Widget _buildSubmitStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DottedBorderInfoWidget(
          text: 'Sends ${_donationSummary()} to the Accelerator fund',
        ),
        AccStepActions(
          primary: _buildSubmitDonationViewModel(),
          secondaryLabel: 'Back',
          onSecondary: () {
            setState(() {
              _currentStep = AcceleratorDonationStep.donationDetails;
              _lastCompletedStep = AcceleratorDonationStep.donationAddress;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSubmitDonationButton(SubmitDonationBloc model) {
    return LoadingButton(
      onPressed: () {
        _submitButtonKey.currentState?.animateForward();
        unawaited(model.submitDonation(_znnAmount, _qsrAmount));
      },
      text: 'Donate',
      circularBorderRadius: kLoadingButtonMinSize.height / 2,
      key: _submitButtonKey,
    );
  }

  Widget _buildSubmitDonationViewModel() {
    return ViewModelBuilder<SubmitDonationBloc>.reactive(
      onViewModelReady: (SubmitDonationBloc model) {
        model.stream.listen(
          (AccountBlockTemplate? event) {
            if (event != null) {
              _submitButtonKey.currentState?.animateReverse();
              setState(() {
                _lastCompletedStep = AcceleratorDonationStep.values.last;
              });
            }
          },
          onError: (Object error) async {
            _submitButtonKey.currentState?.animateReverse();
            await NotificationUtils.sendNotificationError(
              error,
              'Error while submitting donation',
            );
          },
        );
      },
      builder: (_, SubmitDonationBloc model, _) =>
          _buildSubmitDonationButton(model),
      viewModelBuilder: SubmitDonationBloc.new,
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    _znnAmountController.dispose();
    _qsrAmountController.dispose();
    super.dispose();
  }
}
