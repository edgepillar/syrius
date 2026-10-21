import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/create_pillar_stepper/widgets/pillar_step_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// Final step: what the pillar will be set to, and the action that submits
/// the update.
class SubmitPillarUpdateStep extends StatefulWidget {
  /// Creates a [SubmitPillarUpdateStep].
  const SubmitPillarUpdateStep({
    required this.delegateRewardPercentage,
    required this.momentumRewardPercentage,
    required this.onBackPressed,
    required this.onUpdateDone,
    required this.pillarNameController,
    required this.pillarProducerController,
    required this.pillarRewardController,
    this.active = true,
    super.key,
  });

  /// Percentage of delegation rewards given to delegators.
  final ValueNotifier<double> delegateRewardPercentage;

  /// Percentage of momentum rewards given to delegators.
  final ValueNotifier<double> momentumRewardPercentage;

  /// Called when the user returns to the previous step.
  final VoidCallback onBackPressed;

  /// Called when the update operation completes successfully.
  final VoidCallback onUpdateDone;

  /// Controller containing the pillar name.
  final TextEditingController pillarNameController;

  /// Controller containing the reward address.
  final TextEditingController pillarRewardController;

  /// Controller containing the producer address.
  final TextEditingController pillarProducerController;

  /// Whether this is the step shown.
  final bool active;

  @override
  State<SubmitPillarUpdateStep> createState() => _SubmitPillarUpdateStepState();
}

class _SubmitPillarUpdateStepState extends State<SubmitPillarUpdateStep> {
  final GlobalKey<LoadingButtonState> _updateButtonKey = GlobalKey();

  // From the press until the bloc is done or has failed.
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<UpdatePillarBloc, UpdatePillarState>(
      listener: (_, UpdatePillarState state) {
        _onUpdatePillarStateChanged(state);
      },
      // The steps before this one write to these; the review follows them.
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          widget.pillarNameController,
          widget.pillarRewardController,
          widget.pillarProducerController,
          widget.momentumRewardPercentage,
          widget.delegateRewardPercentage,
        ]),
        builder: (BuildContext context, _) => TokenStepFrame(
          active: widget.active,
          busy: _isSending,
          onBack: widget.onBackPressed,
          onSubmit: _isSending ? null : _onUpdatePressed,
          body: PillarReview(
            name: widget.pillarNameController.text,
            rewardAddress: widget.pillarRewardController.text,
            producerAddress: widget.pillarProducerController.text,
            momentumPercentage: widget.momentumRewardPercentage.value.toInt(),
            delegatePercentage: widget.delegateRewardPercentage.value.toInt(),
          ),
          primary: LoadingButton(
            onPressed: _isSending ? null : _onUpdatePressed,
            text: context.l10n.update,
            circularBorderRadius: kLoadingButtonMinSize.height / 2,
            key: _updateButtonKey,
          ),
        ),
      ),
    );
  }

  void _onUpdatePillarStateChanged(UpdatePillarState state) {
    if (state is UpdatePillarDone) {
      _updateButtonKey.currentState?.animateReverse();
      setState(() {
        _isSending = false;
      });
      widget.onUpdateDone();
    } else if (state is UpdatePillarFailure) {
      _updateButtonKey.currentState?.animateReverse();
      setState(() {
        _isSending = false;
      });
      unawaited(
        NotificationUtils.sendNotificationError(
          state.exception,
          context.l10n.errorUpdatingPillar,
        ),
      );
    } else if (state is UpdatePillarLoading) {
      _updateButtonKey.currentState?.animateForward();
      setState(() {
        _isSending = true;
      });
    }
  }

  void _onUpdatePressed() {
    if (_isSending) {
      return;
    }
    setState(() {
      _isSending = true;
    });
    context.read<UpdatePillarBloc>().add(
      UpdatePillarRequested(
        pillarName: widget.pillarNameController.text,
        blockProducingAddress: Address.parse(
          widget.pillarProducerController.text,
        ),
        rewardAddress: Address.parse(widget.pillarRewardController.text),
        giveBlockRewardPercentage: widget.momentumRewardPercentage.value
            .toInt(),
        giveDelegateRewardPercentage: widget.delegateRewardPercentage.value
            .toInt(),
      ),
    );
  }
}
