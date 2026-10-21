import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/refresh_button/view/refresh_button.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/screens/stepper_screen.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/accelerator_widgets/accelerator_parts.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/accelerator_widgets/accelerator_project_list.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/accelerator_widgets/phase_creation_stepper.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// A project's phases, newest first, as the list that fills its page.
///
/// The owner creates the next phase from the panel's title row. This
/// replaces the separate create-phase card: the button sits with the list
/// it adds to.
class PhaseList extends StatelessWidget {
  /// Creates the phases of [project].
  const PhaseList(
    this.pillarInfo,
    this.project,
    this.onRefreshButtonPressed, {
    required this.onStepperNotificationSeeMorePressed,
    super.key,
  });

  /// The Pillar the selected address owns; it can vote on phases.
  final PillarInfo? pillarInfo;

  /// The project whose phases are listed.
  final Project project;

  /// Reloads the project.
  final VoidCallback onRefreshButtonPressed;

  /// Opens the notifications page from a stepper.
  final VoidCallback onStepperNotificationSeeMorePressed;

  @override
  Widget build(BuildContext context) {
    final bool isOwner = project.owner.toString() == kSelectedAddress;
    return Panel(
      title: 'Phases',
      actions: <Widget>[
        RefreshButton(onPressed: onRefreshButtonPressed),
        if (isOwner) ...<Widget>[
          const SizedBox(width: 6),
          Tooltip(
            message: _canCreatePhase()
                ? ''
                : 'Possible once the project is accepted and its last phase '
                      'is paid',
            child: OutlinedButton.icon(
              key: const Key('acc_create_phase'),
              style: accCompactPrimaryStyle(),
              onPressed: _canCreatePhase()
                  ? () => _openPhaseCreation(context)
                  : null,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Create phase'),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ],
      child: project.phases.isEmpty
          ? Center(
              child: Text(
                'None yet',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium!.copyWith(fontSize: 14),
              ),
            )
          : AcceleratorProjectList(
              pillarInfo,
              project.phases.reversed.toList(),
              projects: project,
              onStepperNotificationSeeMorePressed:
                  onStepperNotificationSeeMorePressed,
            ),
    );
  }

  void _openPhaseCreation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => StepperScreen(
          stepper: PhaseCreationStepper(project),
          onStepperNotificationSeeMorePressed:
              onStepperNotificationSeeMorePressed,
        ),
      ),
    );
  }

  bool _canCreatePhase() =>
      project.status == AcceleratorProjectStatus.active &&
      (project.phases.isEmpty ||
          project.phases.last.status == AcceleratorProjectStatus.paid);
}
