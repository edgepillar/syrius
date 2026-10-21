import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:stacked/stacked.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/home/home.dart'
    show AmountText;
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/screens/project_details_screen.dart';
import 'package:zenon_syrius_wallet_flutter/screens/stepper_screen.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/navigation_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notification_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/pair.dart';
import 'package:zenon_syrius_wallet_flutter/utils/zts_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/accelerator_widgets/accelerator_parts.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/accelerator_widgets/update_phase_stepper.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/accelerator_project_details.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// One project or phase as a row of a list.
///
/// Read at a glance, top to bottom: the name with its status and, for a
/// project, where its latest phase stands; the budget; the ledger line; the
/// description; then the votes, as two meters with their numbers written
/// out, and the vote buttons when the selected address owns a Pillar. A
/// project row opens the project.
class AcceleratorProjectListItem extends StatelessWidget {
  /// Creates the row of [acceleratorProject].
  const AcceleratorProjectListItem({
    required this.acceleratorProject,
    required this.onStepperNotificationSeeMorePressed,
    super.key,
    this.pillarInfo,
    this.project,
  });

  /// The project or phase shown.
  final AcceleratorProject acceleratorProject;

  /// The Pillar the selected address owns; it can vote.
  final PillarInfo? pillarInfo;

  /// For a phase, the project it belongs to.
  final Project? project;

  /// Opens the notifications page from a stepper.
  final VoidCallback onStepperNotificationSeeMorePressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AcceleratorProject item = acceleratorProject;
    final bool isProject = item is Project;
    return InkWell(
      mouseCursor: isProject ? SystemMouseCursors.click : MouseCursor.defer,
      onTap: isProject ? () => _openDetails(context) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildTitleRow(context),
            const SizedBox(height: 6),
            AcceleratorProjectDetails(
              owner: item is Project ? item.owner : null,
              hash: item.id,
              creationTimestamp: item.creationTimestamp,
              acceleratorProjectStatus: item.status,
              isPhase: item is Phase,
            ),
            if (item.description.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                item.description,
                // A project's own page shows its phases in full; in the
                // project list two lines are enough to tell them apart.
                maxLines: isProject ? 2 : null,
                overflow: isProject ? TextOverflow.ellipsis : null,
                style: theme.textTheme.titleMedium!.copyWith(
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildVoteBreakdownViewModel(context),
          ],
        ),
      ),
    );
  }

  /// Whether the row offers the vote buttons to a Pillar.
  bool get _canBeVotedOn {
    final AcceleratorProject item = acceleratorProject;
    return (item is Phase && item.status == AcceleratorProjectStatus.active) ||
        item.status == AcceleratorProjectStatus.voting;
  }

  void _openDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ProjectDetailsScreen(
          pillarInfo: pillarInfo,
          project: acceleratorProject,
          onStepperNotificationSeeMorePressed:
              onStepperNotificationSeeMorePressed,
        ),
      ),
    );
  }

  Widget _buildTitleRow(BuildContext context) {
    final AcceleratorProject item = acceleratorProject;
    final Phase? lastPhase = item is Project && item.phases.isNotEmpty
        ? item.phases.last
        : null;
    final TextStyle amount = monoStyle(
      Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: 13),
    );
    return Row(
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: panelTitleStyle(context),
                ),
              ),
              const SizedBox(width: 10),
              AccStatusChip(item.status),
              if (lastPhase != null) ...<Widget>[
                const SizedBox(width: 6),
                _buildPhaseChip(item as Project, lastPhase),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        Tooltip(
          message: 'Budget',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (item.znnFundsNeeded > BigInt.zero)
                AmountText(
                  item.znnFundsNeeded,
                  decimals: coinDecimals,
                  style: amount,
                  symbol: kZnnCoin.symbol,
                  symbolColor: AppColors.znnColor,
                ),
              if (item.znnFundsNeeded > BigInt.zero &&
                  item.qsrFundsNeeded > BigInt.zero)
                const SizedBox(width: 14),
              if (item.qsrFundsNeeded > BigInt.zero)
                AmountText(
                  item.qsrFundsNeeded,
                  decimals: coinDecimals,
                  style: amount,
                  symbol: kQsrCoin.symbol,
                  symbolColor: AppColors.qsrInk,
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Where a project's latest phase stands: the one fact about its phases
  /// a Pillar or a backer looks for first.
  Widget _buildPhaseChip(Project project, Phase lastPhase) {
    final int n = project.phases.length;
    final (String word, Color color) = switch (lastPhase.status) {
      AcceleratorProjectStatus.voting => ('voting', AppColors.warn),
      AcceleratorProjectStatus.active => ('accepted', AppColors.znnColor),
      AcceleratorProjectStatus.paid => ('paid', AppColors.znnColor),
      AcceleratorProjectStatus.completed => ('completed', AppColors.qsrInk),
      AcceleratorProjectStatus.closed => ('rejected', AppColors.errorColor),
    };
    return AccChip(
      label: 'Phase $n $word',
      icon: Icons.flag_outlined,
      dotColor: color,
    );
  }

  Widget _buildVoteBreakdownViewModel(BuildContext context) {
    return ViewModelBuilder<ProjectVoteBreakdownBloc>.reactive(
      onViewModelReady: (ProjectVoteBreakdownBloc model) {
        // Two requests a row, for every row scrolled past, was most of
        // what the page asked the node. Only a row with vote buttons needs
        // them: the rest show the tally their project came with.
        if (_canBeVotedOn) {
          unawaited(
            model.getVoteBreakdown(pillarInfo?.name, acceleratorProject.id),
          );
        } else {
          model.showKnown(acceleratorProject.voteBreakdown);
        }
        model.stream.listen(
          (Pair<VoteBreakdown, List<PillarVote?>?>? event) {},
          onError: (Object error) async {
            await NotificationUtils.sendNotificationError(
              error,
              'Error while trying to get the vote breakdown',
            );
          },
        );
      },
      builder: (_, ProjectVoteBreakdownBloc model, _) =>
          StreamBuilder<Pair<VoteBreakdown, List<PillarVote?>?>?>(
            stream: model.stream,
            builder:
                (
                  _,
                  AsyncSnapshot<Pair<VoteBreakdown, List<PillarVote?>?>?>
                  snapshot,
                ) {
                  if (snapshot.hasError) {
                    return _buildVotesUnavailable(
                      context,
                      snapshot.error.toString(),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.active &&
                      snapshot.hasData) {
                    return _buildVotingRow(
                      context,
                      snapshot.data!.first,
                      snapshot.data!.second,
                      model,
                    );
                  }
                  return const _ThinLoading();
                },
          ),
      viewModelBuilder: ProjectVoteBreakdownBloc.new,
    );
  }

  Widget _buildVotesUnavailable(BuildContext context, String error) {
    return SizedBox(
      height: 30,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Tooltip(
          message: error,
          child: Text(
            'Votes unavailable',
            style: Theme.of(
              context,
            ).textTheme.titleMedium!.copyWith(fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildVotingRow(
    BuildContext context,
    VoteBreakdown votes,
    List<PillarVote?>? pillarVoteList,
    ProjectVoteBreakdownBloc projectVoteBreakdownViewModel,
  ) {
    final int pillars = kNumOfPillars ?? 0;
    final int quorumNeeded = (pillars * 0.33).ceil();
    final int abstain = math.max(0, votes.total - votes.yes - votes.no);
    final String tally = <String>[
      '${votes.yes} yes',
      '${votes.no} no',
      if (abstain > 0) '$abstain abstain',
    ].join(' · ');
    double share(int part, int whole) => whole <= 0 ? 0 : part / whole;
    return Row(
      children: <Widget>[
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 210),
            child: _Tally(
              label: 'Votes',
              value: tally,
              passed: votes.yes > votes.no,
              tooltip: votes.yes > votes.no
                  ? 'More yes than no'
                  : 'Not enough yes votes',
              meter: AccMeter(
                parts: <(double, Color)>[
                  (share(votes.yes, votes.total), AppColors.znnColor),
                  (share(votes.no, votes.total), AppColors.errorColor),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 28),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 210),
            child: _Tally(
              label: 'Quorum',
              value: '${votes.total} of $quorumNeeded',
              passed: votes.total >= quorumNeeded,
              tooltip: votes.total >= quorumNeeded
                  ? 'Quorum reached'
                  : '${quorumNeeded - votes.total} more votes needed',
              meter: AccMeter(
                parts: <(double, Color)>[
                  (share(votes.total, quorumNeeded), AppColors.qsrColor),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        ..._buildActions(
          context,
          pillarVoteList,
          projectVoteBreakdownViewModel,
        ),
      ],
    );
  }

  List<Widget> _buildActions(
    BuildContext context,
    List<PillarVote?>? pillarVoteList,
    ProjectVoteBreakdownBloc projectVoteBreakdownViewModel,
  ) {
    final AcceleratorProject item = acceleratorProject;
    return <Widget>[
      if (pillarVoteList != null && _canBeVotedOn)
        _buildVoteProjectViewModel(
          context,
          pillarVoteList,
          projectVoteBreakdownViewModel,
        ),
      if (<AcceleratorProjectStatus>[
        AcceleratorProjectStatus.voting,
        AcceleratorProjectStatus.active,
        AcceleratorProjectStatus.paid,
      ].contains(item.status)) ...<Widget>[
        const SizedBox(width: 6),
        IconButton(
          tooltip: item.url,
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          mouseCursor: SystemMouseCursors.click,
          onPressed: () => unawaited(NavigationUtils.openUrl(item.url)),
          icon: const Icon(Icons.open_in_new, color: AppColors.faint),
        ),
      ],
      if (item is Phase &&
          item.status == AcceleratorProjectStatus.voting &&
          project!.owner.toString() == kSelectedAddress)
        IconButton(
          tooltip: 'Update phase',
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          mouseCursor: SystemMouseCursors.click,
          onPressed: () => _openUpdatePhase(context),
          icon: const Icon(Icons.edit_outlined, color: AppColors.faint),
        ),
    ];
  }

  void _openUpdatePhase(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => StepperScreen(
          stepper: UpdatePhaseStepper(
            acceleratorProject as Phase,
            project!,
          ),
          onStepperNotificationSeeMorePressed:
              onStepperNotificationSeeMorePressed,
        ),
      ),
    );
  }

  Widget _buildVotingButtons(
    BuildContext context,
    VoteProjectBloc model,
    List<PillarVote?> pillarVoteList,
  ) {
    Widget pill(String label, AcceleratorProjectVote vote, Color color) {
      final bool chosen = _ifOptionVotedByUser(pillarVoteList, vote);
      return Padding(
        padding: const EdgeInsets.only(left: 6),
        child: OutlinedButton(
          key: Key('acc_vote_${vote.name}'),
          // The vote this Pillar cast is filled in its colour; the others
          // stay quiet, so the row shows the vote without a legend.
          style: chosen
              ? OutlinedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: color == AppColors.znnColor
                      ? kOnZnnColor
                      : Colors.white,
                  side: BorderSide.none,
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : accCompactQuietStyle(context),
          onPressed: () =>
              unawaited(model.voteProject(acceleratorProject.id, vote)),
          child: Text(label),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        pill('Yes', AcceleratorProjectVote.yes, AppColors.znnColor),
        pill('No', AcceleratorProjectVote.no, AppColors.errorColor),
        pill('Abstain', AcceleratorProjectVote.abstain, AppColors.faint),
      ],
    );
  }

  Widget _buildVoteProjectViewModel(
    BuildContext context,
    List<PillarVote?> pillarVoteList,
    ProjectVoteBreakdownBloc projectVoteBreakdownViewModel,
  ) {
    return ViewModelBuilder<VoteProjectBloc>.reactive(
      onViewModelReady: (VoteProjectBloc model) {
        model.stream.listen(
          (AccountBlockTemplate? event) {
            if (event != null) {
              unawaited(
                projectVoteBreakdownViewModel.getVoteBreakdown(
                  pillarInfo?.name,
                  acceleratorProject.id,
                ),
              );
            }
          },
          onError: (Object error) async {
            await NotificationUtils.sendNotificationError(
              error,
              'Error while voting project',
            );
          },
        );
      },
      builder: (_, VoteProjectBloc model, _) =>
          StreamBuilder<AccountBlockTemplate?>(
            stream: model.stream,
            builder: (_, AsyncSnapshot<AccountBlockTemplate?> snapshot) {
              if (snapshot.connectionState == ConnectionState.active &&
                  !snapshot.hasError &&
                  !snapshot.hasData) {
                // A vote is on its way.
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.znnColor,
                    ),
                  ),
                );
              }
              return _buildVotingButtons(context, model, pillarVoteList);
            },
          ),
      viewModelBuilder: VoteProjectBloc.new,
    );
  }

  bool _ifOptionVotedByUser(
    List<PillarVote?> pillarVoteList,
    AcceleratorProjectVote vote,
  ) {
    try {
      final PillarVote? pillarVote = pillarVoteList.firstWhere(
        (PillarVote? pillarVote) => pillarVote?.name == pillarInfo!.name,
      );
      return pillarVote!.vote == vote.index;
    } on Object {
      return false;
    }
  }
}

/// A ledger label and its numbers over a meter.
class _Tally extends StatelessWidget {
  const _Tally({
    required this.label,
    required this.value,
    required this.passed,
    required this.tooltip,
    required this.meter,
  });

  final String label;
  final String value;
  final bool passed;
  final String tooltip;
  final Widget meter;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(label.toUpperCase(), style: ledgerLabelStyle(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: monoStyle(
                    Theme.of(
                      context,
                    ).textTheme.titleMedium!.copyWith(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                passed ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 13,
                color: passed ? AppColors.znnColor : AppColors.faint,
              ),
            ],
          ),
          const SizedBox(height: 6),
          meter,
        ],
      ),
    );
  }
}

/// Votes on their way: a thin line where the meters will be.
class _ThinLoading extends StatelessWidget {
  const _ThinLoading();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 120,
          child: LinearProgressIndicator(
            minHeight: 2,
            color: AppColors.znnColor,
            backgroundColor: Theme.of(context).dividerTheme.color,
          ),
        ),
      ),
    );
  }
}
