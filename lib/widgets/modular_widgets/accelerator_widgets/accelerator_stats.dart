import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/home/home.dart'
    show splitAmount;
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/screens/stepper_screen.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/accelerator_widgets/accelerator_donation_stepper.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/accelerator_widgets/project_creation_stepper.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The top row of the Accelerator page: what the fund holds, what a vote
/// needs, and the two ways to put something in.
///
/// Creating a project is the page's one primary action; a donation is the
/// quieter button beside it. This row replaces three cards: the donation
/// card, the fund's pie chart and the create-project card.
class AcceleratorStats extends StatefulWidget {
  /// Creates the row.
  const AcceleratorStats({
    required this.onStepperNotificationSeeMorePressed,
    this.pillarInfo,
    super.key,
  });

  /// Opens the notifications page from a stepper.
  final VoidCallback onStepperNotificationSeeMorePressed;

  /// The Pillar the selected address owns, if any.
  final PillarInfo? pillarInfo;

  @override
  State<AcceleratorStats> createState() => _AcceleratorStatsState();
}

class _AcceleratorStatsState extends State<AcceleratorStats> {
  @override
  void initState() {
    super.initState();
    unawaited(sl.get<AcceleratorBalanceBloc>().getAcceleratorBalance());
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: <Widget>[
          Expanded(child: _buildFigures()),
          const SizedBox(width: 16),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildFigures() {
    final int? pillars = kNumOfPillars;
    return StreamBuilder<AccountInfo?>(
      stream: sl.get<AcceleratorBalanceBloc>().stream,
      builder: (_, AsyncSnapshot<AccountInfo?> snapshot) {
        final AccountInfo? fund = snapshot.data;
        String amount(BigInt? raw) =>
            raw == null ? '-' : splitAmount(raw, coinDecimals).$1;
        final Widget figures = Row(
          children: <Widget>[
            Flexible(
              child: Figure(
                key: const Key('acc_figure_znn'),
                label: 'ZNN available',
                value: amount(fund?.znn()),
              ),
            ),
            const SizedBox(width: 40),
            Flexible(
              child: Figure(
                key: const Key('acc_figure_qsr'),
                label: 'QSR available',
                value: amount(fund?.qsr()),
              ),
            ),
            if (pillars != null && pillars > 0) ...<Widget>[
              const SizedBox(width: 40),
              Flexible(
                child: Figure(
                  label: 'Quorum',
                  value: '${(pillars * 0.33).ceil()} of $pillars',
                ),
              ),
            ],
            if (widget.pillarInfo != null) ...<Widget>[
              const SizedBox(width: 40),
              Flexible(
                child: Figure(
                  label: 'Votes as',
                  value: widget.pillarInfo!.name,
                  valueStyle: panelTitleStyle(context).copyWith(fontSize: 18),
                ),
              ),
            ],
          ],
        );
        return snapshot.hasError
            ? Tooltip(message: snapshot.error.toString(), child: figures)
            : figures;
      },
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        OutlinedButton.icon(
          key: const Key('acc_donate'),
          style: secondaryButtonStyle(context),
          onPressed: () => _openStepper(const AcceleratorDonationStepper()),
          icon: const Icon(Icons.volunteer_activism_outlined, size: 18),
          label: const Text('Donate'),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          key: const Key('acc_create_project'),
          onPressed: () => _openStepper(const ProjectCreationStepper()),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Create project'),
        ),
      ],
    );
  }

  void _openStepper(Widget stepper) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => StepperScreen(
          stepper: stepper,
          onStepperNotificationSeeMorePressed:
              widget.onStepperNotificationSeeMorePressed,
        ),
      ),
    );
  }
}
