import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:stacked/stacked.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// One Accelerator project: its head on top, its phases filling the rest.
///
/// The same page rules as a rail page: a fixed row for what the project is
/// and how much it has been paid, a filling row for the list.
class ProjectDetailsScreen extends StatefulWidget {
  /// Creates the page of [project].
  const ProjectDetailsScreen({
    required this.project,
    required this.pillarInfo,
    required this.onStepperNotificationSeeMorePressed,
    super.key,
  });

  /// Opens the notifications page from a stepper.
  final VoidCallback onStepperNotificationSeeMorePressed;

  /// The project, as the list had it; the page reloads it.
  final AcceleratorProject project;

  /// The Pillar the selected address owns, if any.
  final PillarInfo? pillarInfo;

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildTopBar(),
              NotificationWidget(
                onSeeMorePressed: widget.onStepperNotificationSeeMorePressed,
              ),
              const SizedBox(height: 10),
              Expanded(child: _buildStreamBuilder()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SizedBox(
      height: 48,
      child: Row(
        children: <Widget>[
          IconButton(
            key: const Key('project_details_back'),
            tooltip: 'Back',
            mouseCursor: SystemMouseCursors.click,
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.project.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayout(
    Project project,
    RefreshProjectBloc refreshProjectViewModel,
  ) {
    return PageGrid(
      rows: <PageRow>[
        PageRow.fixed(172, <PageCell>[PageCell(ProjectsStats(project))]),
        PageRow.fill(<PageCell>[
          PageCell(
            PhaseList(
              widget.pillarInfo,
              project,
              () => refreshProjectViewModel.refreshProject(project.id),
              onStepperNotificationSeeMorePressed:
                  widget.onStepperNotificationSeeMorePressed,
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildStreamBuilder() {
    return ViewModelBuilder<RefreshProjectBloc>.reactive(
      onViewModelReady: (RefreshProjectBloc model) {
        unawaited(model.refreshProject(widget.project.id));
      },
      builder: (_, RefreshProjectBloc model, _) => StreamBuilder<Project?>(
        stream: model.stream,
        builder: (_, AsyncSnapshot<Project?> snapshot) {
          if (snapshot.hasError) {
            return RepaintBoundary(child: SyriusErrorWidget(snapshot.error!));
          }
          if (snapshot.connectionState == ConnectionState.active &&
              snapshot.hasData) {
            return _buildLayout(snapshot.data!, model);
          }
          return const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.znnColor,
              ),
            ),
          );
        },
      ),
      viewModelBuilder: RefreshProjectBloc.new,
    );
  }
}
