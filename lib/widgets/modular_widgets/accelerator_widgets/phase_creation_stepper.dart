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

/// The steps of creating a phase of an Accelerator project.
enum PhaseCreationStep {
  /// The phase's name, description, link and budget.
  phaseDetails,

  /// Sending it.
  submitPhase,
}

/// Creates the next phase of [project], which the selected address owns.
class PhaseCreationStepper extends StatefulWidget {
  /// Creates the stepper for [project].
  const PhaseCreationStepper(this.project, {super.key});

  /// The project the phase is added to.
  final Project project;

  @override
  State<PhaseCreationStepper> createState() => _PhaseCreationStepperState();
}

class _PhaseCreationStepperState extends State<PhaseCreationStepper> {
  PhaseCreationStep? _lastCompletedStep;
  PhaseCreationStep _currentStep = PhaseCreationStep.values.first;

  final TextEditingController _addressController = TextEditingController();
  TextEditingController _phaseNameController = TextEditingController();
  TextEditingController _phaseDescriptionController = TextEditingController();
  TextEditingController _phaseUrlController = TextEditingController();
  TextEditingController _phaseZnnAmountController = TextEditingController();
  TextEditingController _phaseQsrAmountController = TextEditingController();

  GlobalKey<FormState> _phaseNameKey = GlobalKey();
  GlobalKey<FormState> _phaseDescriptionKey = GlobalKey();
  GlobalKey<FormState> _phaseUrlKey = GlobalKey();
  GlobalKey<FormState> _phaseZnnAmountKey = GlobalKey();
  GlobalKey<FormState> _phaseQsrAmountKey = GlobalKey();

  final GlobalKey<LoadingButtonState> _submitButtonKey = GlobalKey();

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
            child: _buildBody(context),
          );
        } else {
          state = const AccStepperLoading(key: ValueKey<String>('loading'));
        }
        return StateSwitcher(child: state);
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    return AccStepperFrame(
      isDone: _lastCompletedStep == PhaseCreationStep.values.last,
      againLabel: 'Create another',
      onAgain: () {
        _clearInput();
        setState(() {
          _currentStep = PhaseCreationStep.values.first;
          _lastCompletedStep = null;
        });
      },
      doneLabel: 'View phases',
      onDone: () {
        Navigator.pop(context);
      },
      stepper: custom_material_stepper.Stepper(
        currentStep: _currentStep.index,
        onStepTapped: (int index) {},
        steps: <custom_material_stepper.Step>[
          StepperUtils.getMaterialStep(
            stepTitle: 'Details',
            stepContent: _buildDetailsStep(),
            stepSubtitle:
                '${_phaseNameController.text} · '
                '${_phaseZnnAmountController.text} ${kZnnCoin.symbol} · '
                '${_phaseQsrAmountController.text} ${kQsrCoin.symbol}',
            stepState: StepperUtils.getStepState(
              PhaseCreationStep.phaseDetails.index,
              _lastCompletedStep?.index,
            ),
            context: context,
          ),
          StepperUtils.getMaterialStep(
            stepTitle: 'Submit',
            stepContent: _buildSubmitStep(),
            stepSubtitle: 'ID ${widget.project.id.toShortString()}',
            stepState: StepperUtils.getStepState(
              PhaseCreationStep.submitPhase.index,
              _lastCompletedStep?.index,
            ),
            context: context,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    final TextStyle text = accFieldTextStyle(context);
    final TextStyle amount = accFieldTextStyle(context, mono: true);
    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AccIdLine(
            label: 'Project',
            name: widget.project.name,
            id: widget.project.id,
          ),
          AccField(
            label: 'Name',
            child: Form(
              key: _phaseNameKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: InputField(
                controller: _phaseNameController,
                inputtedTextStyle: text,
                onChanged: (String value) {
                  setState(() {});
                },
                validator: Validations.projectName,
              ),
            ),
          ),
          const SizedBox(height: kAccFieldGap),
          AccField(
            label: 'Description',
            child: Form(
              key: _phaseDescriptionKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: InputField(
                controller: _phaseDescriptionController,
                inputtedTextStyle: text,
                onChanged: (String value) {
                  setState(() {});
                },
                validator: Validations.projectDescription,
              ),
            ),
          ),
          const SizedBox(height: kAccFieldGap),
          AccField(
            label: 'URL',
            help: 'Proof of progress, such as a pull request',
            child: Form(
              key: _phaseUrlKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: InputField(
                controller: _phaseUrlController,
                hintText: 'https://',
                inputtedTextStyle: text,
                onChanged: (String value) {
                  setState(() {});
                },
                validator: InputValidators.checkUrl,
              ),
            ),
          ),
          const SizedBox(height: kAccFieldGap),
          AccField(
            label: 'ZNN budget',
            child: Form(
              key: _phaseZnnAmountKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: InputField(
                controller: _phaseZnnAmountController,
                hintText: '0.0',
                inputtedTextStyle: amount,
                suffixIcon: AmountSuffixWidgets(
                  kZnnCoin,
                  onMaxPressed: () {
                    setState(() {
                      _phaseZnnAmountController.text = widget.project
                          .getRemainingZnnFunds()
                          .addDecimals(coinDecimals);
                    });
                  },
                ),
                inputFormatters: FormatUtils.getAmountTextInputFormatters(
                  _phaseZnnAmountController.text,
                ),
                validator: (String? value) => InputValidators.correctValue(
                  value,
                  widget.project.getRemainingZnnFunds(),
                  coinDecimals,
                  BigInt.zero,
                  canBeEqualToMin: true,
                ),
                onChanged: (String value) {
                  setState(() {});
                },
              ),
            ),
          ),
          AccHintLine(
            '${accAmount(
              widget.project.getRemainingZnnFunds(),
              coinDecimals,
              kZnnCoin.symbol,
            )} left in the project',
          ),
          const SizedBox(height: kAccFieldGap),
          AccField(
            label: 'QSR budget',
            child: Form(
              key: _phaseQsrAmountKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: InputField(
                controller: _phaseQsrAmountController,
                hintText: '0.0',
                inputtedTextStyle: amount,
                suffixIcon: AmountSuffixWidgets(
                  kQsrCoin,
                  onMaxPressed: () {
                    setState(() {
                      _phaseQsrAmountController.text = widget.project
                          .getRemainingQsrFunds()
                          .addDecimals(coinDecimals);
                    });
                  },
                ),
                inputFormatters: FormatUtils.getAmountTextInputFormatters(
                  _phaseQsrAmountController.text,
                ),
                validator: (String? value) => InputValidators.correctValue(
                  value,
                  widget.project.getRemainingQsrFunds(),
                  coinDecimals,
                  BigInt.zero,
                  canBeEqualToMin: true,
                ),
                onChanged: (String value) {
                  setState(() {});
                },
              ),
            ),
          ),
          AccHintLine(
            '${accAmount(
              widget.project.getRemainingQsrFunds(),
              coinDecimals,
              kQsrCoin.symbol,
            )} left in the project',
          ),
          AccStepActions(
            primary: StepperButton(
              text: 'Continue',
              onPressed: _areInputDetailsValid()
                  ? () {
                      setState(() {
                        _lastCompletedStep = PhaseCreationStep.phaseDetails;
                        _currentStep = PhaseCreationStep.submitPhase;
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

  Widget _buildSubmitStep() {
    final BigInt remainingZnnBudget =
        widget.project.getRemainingZnnFunds() -
        (_phaseZnnAmountController.text.isNotEmpty
            ? _phaseZnnAmountController.text.extractDecimals(coinDecimals)
            : BigInt.zero);

    final BigInt remainingQsrBudget =
        widget.project.getRemainingQsrFunds() -
        (_phaseQsrAmountController.text.isNotEmpty
            ? _phaseQsrAmountController.text.extractDecimals(coinDecimals)
            : BigInt.zero);

    final String znnLeft = accAmount(
      remainingZnnBudget,
      coinDecimals,
      kZnnCoin.symbol,
    );
    final String qsrLeft = accAmount(
      remainingQsrBudget,
      coinDecimals,
      kQsrCoin.symbol,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DottedBorderInfoWidget(
          text: 'Leaves $znnLeft and $qsrLeft for later phases',
        ),
        AccStepActions(
          primary: _buildCreatePhaseViewModel(),
          secondaryLabel: 'Back',
          onSecondary: () {
            setState(() {
              _currentStep = PhaseCreationStep.phaseDetails;
              _lastCompletedStep = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton(CreatePhaseBloc model) {
    return LoadingButton(
      onPressed: () {
        _submitButtonKey.currentState?.animateForward();
        unawaited(
          model.createPhase(
            widget.project.id,
            _phaseNameController.text,
            _phaseDescriptionController.text,
            _phaseUrlController.text,
            _phaseZnnAmountController.text.extractDecimals(
              coinDecimals,
            ),
            _phaseQsrAmountController.text.extractDecimals(
              coinDecimals,
            ),
          ),
        );
      },
      text: 'Submit',
      circularBorderRadius: kLoadingButtonMinSize.height / 2,
      key: _submitButtonKey,
    );
  }

  Widget _buildCreatePhaseViewModel() {
    return ViewModelBuilder<CreatePhaseBloc>.reactive(
      onViewModelReady: (CreatePhaseBloc model) {
        model.stream.listen(
          (AccountBlockTemplate? event) {
            if (event != null) {
              _submitButtonKey.currentState?.animateReverse();
              setState(() {
                _lastCompletedStep = PhaseCreationStep.values.last;
              });
            }
          },
          onError: (Object error) async {
            _submitButtonKey.currentState?.animateReverse();
            await NotificationUtils.sendNotificationError(
              error,
              'Error while creating phase',
            );
          },
        );
      },
      builder: (_, CreatePhaseBloc model, _) => _buildSubmitButton(model),
      viewModelBuilder: CreatePhaseBloc.new,
    );
  }

  bool _areInputDetailsValid() =>
      Validations.projectName(
            _phaseNameController.text,
          ) ==
          null &&
      Validations.projectDescription(
            _phaseDescriptionController.text,
          ) ==
          null &&
      InputValidators.checkUrl(
            _phaseUrlController.text,
          ) ==
          null &&
      InputValidators.correctValue(
            _phaseZnnAmountController.text,
            widget.project.getRemainingZnnFunds(),
            coinDecimals,
            BigInt.zero,
            canBeEqualToMin: true,
          ) ==
          null &&
      InputValidators.correctValue(
            _phaseQsrAmountController.text,
            widget.project.getRemainingQsrFunds(),
            coinDecimals,
            BigInt.zero,
            canBeEqualToMin: true,
          ) ==
          null;

  @override
  void dispose() {
    _addressController.dispose();
    _phaseNameController.dispose();
    _phaseDescriptionController.dispose();
    _phaseUrlController.dispose();
    _phaseZnnAmountController.dispose();
    _phaseQsrAmountController.dispose();
    super.dispose();
  }

  void _clearInput() {
    _phaseNameController = TextEditingController();
    _phaseDescriptionController = TextEditingController();
    _phaseUrlController = TextEditingController();
    _phaseZnnAmountController = TextEditingController();
    _phaseQsrAmountController = TextEditingController();
    _phaseNameKey = GlobalKey();
    _phaseDescriptionKey = GlobalKey();
    _phaseUrlKey = GlobalKey();
    _phaseZnnAmountKey = GlobalKey();
    _phaseQsrAmountKey = GlobalKey();
  }
}
