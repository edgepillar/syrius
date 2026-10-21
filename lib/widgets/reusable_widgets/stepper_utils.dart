import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/custom_material_stepper.dart'
    as custom_material_stepper;
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// Builds the steps of the pillar, sentinel, token and accelerator
/// steppers, so they all look alike.
class StepperUtils {
  /// A step titled [stepTitle]. Once it is complete, [stepSubtitle] shows
  /// under the title in [stepSubtitleColor].
  ///
  /// The title carries no style of its own: the stepper sets it, so the
  /// current step reads stronger than the ones still to come.
  static custom_material_stepper.Step getMaterialStep({
    required String stepTitle,
    required Widget stepContent,
    required String stepSubtitle,
    required custom_material_stepper.StepState stepState,
    required BuildContext context,
    bool expanded = false,
    Color stepSubtitleColor = AppColors.znnColor,
    IconData? stepSubtitleIconData,
  }) {
    return custom_material_stepper.Step(
      title: Text(stepTitle),
      subtitle: stepState == custom_material_stepper.StepState.complete
          ? Row(
              children: <Widget>[
                Text(
                  stepSubtitle,
                  style: TextStyle(
                    fontFamily: kSansFontFamily,
                    fontSize: 12,
                    color: stepSubtitleColor,
                  ),
                ),
                if (stepSubtitleIconData != null) ...<Widget>[
                  const SizedBox(width: 4),
                  Icon(
                    stepSubtitleIconData,
                    size: 14,
                    color: stepSubtitleColor,
                  ),
                ],
              ],
            )
          : null,
      content: Container(
        margin: const EdgeInsets.only(left: 37),
        child: Row(
          children: <Widget>[
            Expanded(
              child: stepContent,
            ),
            if (!expanded)
              Expanded(
                child: Container(),
              ),
          ],
        ),
      ),
      state: stepState,
    );
  }

  /// Complete up to and including [completedStepIndex], to come after it.
  static custom_material_stepper.StepState getStepState(
    int currentStepIndex,
    int? completedStepIndex,
  ) {
    return currentStepIndex <= (completedStepIndex ?? -1)
        ? custom_material_stepper.StepState.complete
        : custom_material_stepper.StepState.indexed;
  }

  /// The balance line shown above a step's form.
  static Widget getBalanceWidget(Token token, AccountInfo accountInfo) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 10, bottom: 10),
      child: AvailableBalance(
        token,
        accountInfo,
      ),
    );
  }
}
