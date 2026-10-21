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

/// The steps of updating a phase that is being voted on.
enum UpdatePhaseStep {
  /// The phase's name, description, link and budget.
  phaseDetails,

  /// Sending it.
  updatePhase,
}

/// Updates [phase] of [project]. An update resets the phase's votes.
class UpdatePhaseStepper extends StatefulWidget {
  /// Creates the stepper for [phase] of [project].
  const UpdatePhaseStepper(
    this.phase,
    this.project, {
    super.key,
  });

  /// The phase to update.
  final Phase phase;

  /// The project it belongs to.
  final Project project;

  @override
  State<UpdatePhaseStepper> createState() => _UpdatePhaseStepperState();
}

class _UpdatePhaseStepperState extends State<UpdatePhaseStepper> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phaseNameController = TextEditingController();
  final TextEditingController _phaseDescriptionController =
      TextEditingController();
  final TextEditingController _phaseUrlController = TextEditingController();
  final TextEditingController _phaseZnnAmountController =
      TextEditingController();
  final TextEditingController _phaseQsrAmountController =
      TextEditingController();

  final GlobalKey<FormState> _phaseNameKey = GlobalKey();
  final GlobalKey<FormState> _phaseDescriptionKey = GlobalKey();
  final GlobalKey<FormState> _phaseUrlKey = GlobalKey();
  final GlobalKey<FormState> _phaseZnnAmountKey = GlobalKey();
  final GlobalKey<FormState> _phaseQsrAmountKey = GlobalKey();

  UpdatePhaseStep? _lastCompletedStep;

  UpdatePhaseStep _currentStep = UpdatePhaseStep.values.first;

  @override
  void initState() {
    super.initState();
    _addressController.text = kSelectedAddress!;
    _phaseNameController.text = widget.phase.name;
    _phaseDescriptionController.text = widget.phase.description;
    _phaseUrlController.text = widget.phase.url;
    _phaseZnnAmountController.text = widget.phase.znnFundsNeeded.addDecimals(
      coinDecimals,
    );
    _phaseQsrAmountController.text = widget.phase.qsrFundsNeeded.addDecimals(
      coinDecimals,
    );
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
      isDone: _lastCompletedStep == UpdatePhaseStep.updatePhase,
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
            stepState: _getStepState(UpdatePhaseStep.phaseDetails),
            context: context,
          ),
          StepperUtils.getMaterialStep(
            stepTitle: 'Update',
            stepContent: _buildUpdateStep(),
            stepSubtitle: 'ID ${widget.phase.id.toShortString()}',
            stepState: _getStepState(UpdatePhaseStep.updatePhase),
            context: context,
          ),
        ],
      ),
    );
  }

  custom_material_stepper.StepState _getStepState(UpdatePhaseStep step) {
    final int stepIndex = step.index;
    return stepIndex <= (_lastCompletedStep?.index ?? -1)
        ? custom_material_stepper.StepState.complete
        : custom_material_stepper.StepState.indexed;
  }

  Widget _buildDetailsStep() {
    final TextStyle text = accFieldTextStyle(context);
    final TextStyle amount = accFieldTextStyle(context, mono: true);
    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AccIdLine(
            label: 'Phase',
            name: widget.phase.name,
            id: widget.phase.id,
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
                  kZnnCoin.decimals,
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
                  kQsrCoin.decimals,
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
                        _lastCompletedStep = UpdatePhaseStep.phaseDetails;
                        _currentStep = UpdatePhaseStep.updatePhase;
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

  Widget _buildUpdateStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const DottedBorderInfoWidget(
          text: 'Updating resets the votes on this phase',
          borderColor: AppColors.warn,
        ),
        AccStepActions(
          primary: _buildUpdatePhaseViewModel(),
          secondaryLabel: 'Back',
          onSecondary: () {
            setState(() {
              _currentStep = UpdatePhaseStep.phaseDetails;
              _lastCompletedStep = null;
            });
          },
        ),
      ],
    );
  }

  StepperButton _buildUpdatePhaseButton(UpdatePhaseBloc model) {
    return StepperButton(
      onPressed: () {
        model.updatePhase(
          widget.project.id,
          _phaseNameController.text,
          _phaseDescriptionController.text,
          _phaseUrlController.text,
          _phaseZnnAmountController.text.extractDecimals(coinDecimals),
          _phaseQsrAmountController.text.extractDecimals(coinDecimals),
        );
      },
      text: 'Update',
    );
  }

  bool _areInputDetailsValid() =>
      Validations.projectName(_phaseNameController.text) == null &&
      Validations.projectDescription(_phaseDescriptionController.text) ==
          null &&
      InputValidators.checkUrl(_phaseUrlController.text) == null &&
      InputValidators.correctValue(
            _phaseZnnAmountController.text,
            widget.project.getRemainingZnnFunds(),
            kZnnCoin.decimals,
            BigInt.zero,
            canBeEqualToMin: true,
          ) ==
          null &&
      InputValidators.correctValue(
            _phaseQsrAmountController.text,
            widget.project.getRemainingQsrFunds(),
            kQsrCoin.decimals,
            BigInt.zero,
            canBeEqualToMin: true,
          ) ==
          null;

  Widget _buildUpdatePhaseViewModel() {
    return ViewModelBuilder<UpdatePhaseBloc>.reactive(
      onViewModelReady: (UpdatePhaseBloc model) {
        model.stream.listen(
          (AccountBlockTemplate? event) {
            if (event != null) {
              setState(() {
                _lastCompletedStep = UpdatePhaseStep.updatePhase;
              });
            }
          },
          onError: (Object error) async {
            await NotificationUtils.sendNotificationError(
              error,
              'Error while updating phase',
            );
          },
        );
      },
      builder: (_, UpdatePhaseBloc model, _) =>
          StreamBuilder<AccountBlockTemplate?>(
            stream: model.stream,
            builder: (_, AsyncSnapshot<AccountBlockTemplate?> snapshot) {
              if (snapshot.hasError) {
                return _buildUpdatePhaseButton(model);
              }
              if (snapshot.connectionState == ConnectionState.active) {
                if (snapshot.hasData) {
                  return _buildUpdatePhaseButton(model);
                }
                // The update is on its way: the ring stands where the
                // button was, at the button's size, so the row keeps still.
                return SizedBox.fromSize(
                  size: kLoadingButtonMinSize,
                  child: const Center(
                    child: SyriusLoadingWidget(size: 18, strokeWidth: 1.5),
                  ),
                );
              }
              return _buildUpdatePhaseButton(model);
            },
          ),
      viewModelBuilder: UpdatePhaseBloc.new,
    );
  }

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
}
