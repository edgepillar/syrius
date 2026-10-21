import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/custom_material_stepper.dart'
    as custom_material_stepper;
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

enum _Step {
  pillarDetails,
  pillarMomentumReward,
  pillarUpdate,
}

/// A stepper that aids the user in the process of updating pillar details
class UpdatePillarStepperView extends StatefulWidget {
  /// {@macro default_constructor}
  const UpdatePillarStepperView({required this._pillarInfo, super.key});

  final PillarInfo _pillarInfo;

  @override
  State<UpdatePillarStepperView> createState() =>
      _UpdatePillarStepperViewState();
}

class _UpdatePillarStepperViewState extends State<UpdatePillarStepperView> {
  final TextEditingController _pillarNameController = TextEditingController();
  final TextEditingController _pillarRewardController = TextEditingController();
  final TextEditingController _pillarProducerController =
      TextEditingController();

  // When value is null, it means the stepper has completed.
  final ValueNotifier<_Step?> _currentStep = .new(
    .pillarDetails,
  );

  late final ValueNotifier<double> _momentumRewardPercentageGiven;
  late final ValueNotifier<double> _delegateRewardPercentageGiven;

  @override
  void initState() {
    super.initState();
    _pillarNameController.text = widget._pillarInfo.name;
    _pillarRewardController.text = widget._pillarInfo.withdrawAddress
        .toString();
    _pillarProducerController.text = widget._pillarInfo.producerAddress
        .toString();
    _momentumRewardPercentageGiven = ValueNotifier<double>(
      widget._pillarInfo.giveMomentumRewardPercentage.toDouble(),
    );
    _delegateRewardPercentageGiven = ValueNotifier<double>(
      widget._pillarInfo.giveDelegateRewardPercentage.toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The steps are told how tall the card is: the list they sit in would
    // give a step any height, and its actions would end below the window.
    return LayoutBuilder(
      builder: (_, BoxConstraints constraints) => TokenStepViewport(
        height: constraints.maxHeight,
        child: ValueListenableBuilder<_Step?>(
          valueListenable: _currentStep,
          builder: (_, _Step? currentStep, _) {
            final bool hasPillarBeenUpdated = currentStep == null;

            return Stack(
              children: <Widget>[
                ListView(
                  children: <Widget>[
                    _getMaterialStepper(currentStep: currentStep),
                  ],
                ),
                if (hasPillarBeenUpdated)
                  PillarUpdatedSuccess(
                    onViewPillarsPressed: _onViewPillarsPressed,
                  ),
                if (hasPillarBeenUpdated) const PillarUpdatedSuccessAnimation(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _getMaterialStepper({required _Step? currentStep}) {
    final int lastStepIndex = _Step.values.last.index;
    // The one accent of the stepper: its marks, the lines between them and
    // what a finished step says under its title.
    final Color accent = AppTokens.of(context).znnInk;

    custom_material_stepper.StepState getStepState(
      _Step step,
      _Step? currentStep,
    ) {
      return step.index < (currentStep?.index ?? lastStepIndex + 1)
          ? custom_material_stepper.StepState.complete
          : custom_material_stepper.StepState.indexed;
    }

    return custom_material_stepper.Stepper(
      activeColor: accent,
      currentStep: currentStep?.index ?? lastStepIndex,
      onStepTapped: (int index) {},
      steps: <custom_material_stepper.Step>[
        StepperUtils.getMaterialStep(
          stepTitle: context.l10n.pillarDetails,
          stepContent: PillarUpdateDetailsStep(
            active: currentStep == _Step.pillarDetails,
            onCancelPressed: _onCancelPressed,
            onNextPressed: _navigateToNextStep,
            pillarNameController: _pillarNameController,
            pillarProducerController: _pillarProducerController,
            pillarRewardController: _pillarRewardController,
          ),
          stepSubtitle: _pillarNameController.text,
          stepState: getStepState(
            _Step.pillarDetails,
            currentStep,
          ),
          context: context,
          stepSubtitleColor: accent,
        ),
        StepperUtils.getMaterialStep(
          stepTitle: context.l10n.updatePillarRewardsTitle,
          stepContent: PillarUpdateRewardsStep(
            active: currentStep == _Step.pillarMomentumReward,
            delegateRewardPercentage: _delegateRewardPercentageGiven,
            momentumRewardPercentage: _momentumRewardPercentageGiven,
            onBackPressed: _navigateToPreviousStep,
            onNextPressed: _navigateToNextStep,
          ),
          // Whole numbers: the sliders move in steps of one, and "50.0"
          // reads 50.
          stepSubtitle:
              '${context.l10n.momentumPercentageGiven(
                _momentumRewardPercentageGiven.value.toInt(),
              )}'
              '\n'
              '${context.l10n.delegationPercentageGiven(
                _delegateRewardPercentageGiven.value.toInt(),
              )}',
          stepState: getStepState(
            _Step.pillarMomentumReward,
            currentStep,
          ),
          context: context,
          stepSubtitleColor: accent,
        ),
        StepperUtils.getMaterialStep(
          stepTitle: context.l10n.pillarUpdate,
          stepContent: SubmitPillarUpdateStep(
            active: currentStep == _Step.pillarUpdate,
            delegateRewardPercentage: _delegateRewardPercentageGiven,
            momentumRewardPercentage: _momentumRewardPercentageGiven,
            onBackPressed: _navigateToPreviousStep,
            onUpdateDone: _onUpdateDone,
            pillarNameController: _pillarNameController,
            pillarProducerController: _pillarProducerController,
            pillarRewardController: _pillarRewardController,
          ),
          stepSubtitle: context.l10n.pillarUpdated,
          stepState: getStepState(
            _Step.pillarUpdate,
            currentStep,
          ),
          context: context,
          stepSubtitleColor: accent,
        ),
      ],
    );
  }

  void _onCancelPressed() {
    Navigator.pop(context);
  }

  void _onViewPillarsPressed() {
    Navigator.pop(context);
  }

  void _onUpdateDone() {
    // All steps have been completed.
    _currentStep.value = null;
  }

  void _navigateToNextStep() {
    final int currentStepIndex = _currentStep.value!.index;

    _currentStep.value = _Step.values[currentStepIndex + 1];
  }

  void _navigateToPreviousStep() {
    final _Step? currentStep = _currentStep.value;

    if (currentStep == null || currentStep.index == 0) {
      return;
    }

    _currentStep.value = _Step.values[currentStep.index - 1];
  }

  @override
  void dispose() {
    _pillarNameController.dispose();
    _pillarRewardController.dispose();
    _pillarProducerController.dispose();
    _momentumRewardPercentageGiven.dispose();
    _delegateRewardPercentageGiven.dispose();
    _currentStep.dispose();
    super.dispose();
  }
}
