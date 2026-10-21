import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/refresh_button/view/refresh_button.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/accelerator_widgets/accelerator_parts.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/accelerator_widgets/accelerator_project_list_item.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/error_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_fields/input_field.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The filters of the project list. [ProjectListBloc] reads them.
enum AccProjectsFilterTag {
  /// Projects the selected address owns.
  myProjects,

  /// Accepted projects.
  onlyAccepted,

  /// Projects the selected address's Pillar has not voted on.
  needsVoting,

  /// Projects the selected address's Pillar has voted on.
  alreadyVoted,
}

/// Every Accelerator project, as the list that fills the Accelerator page:
/// a search field and filters over the list [ProjectListBloc] holds. Rows
/// are built as they scroll into view, so the list needs no paging.
class AccProjectList extends StatefulWidget {
  /// Creates the list. With [pillarInfo] it offers the voting filters.
  const AccProjectList({
    required this.onStepperNotificationSeeMorePressed,
    required this.pillarInfo,
    super.key,
  });

  /// Opens the notifications page from a stepper.
  final VoidCallback onStepperNotificationSeeMorePressed;

  /// The Pillar the selected address owns, if any.
  final PillarInfo? pillarInfo;

  @override
  State<AccProjectList> createState() => _AccProjectListState();
}

class _AccProjectListState extends State<AccProjectList> {
  final ScrollController _scrollController = ScrollController();
  late ProjectListBloc _bloc;

  final TextEditingController _searchKeyWordController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _bloc = ProjectListBloc(
      pillarInfo: widget.pillarInfo,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Projects',
      actions: <Widget>[
        IconButton(
          key: const Key('acc_sort'),
          tooltip: 'Sort by last update',
          iconSize: 18,
          color: AppColors.faint,
          mouseCursor: SystemMouseCursors.click,
          onPressed: _bloc.sortByLastUpdate,
          icon: const Icon(Icons.swap_vert),
        ),
        RefreshButton(
          onPressed: () {
            // Clearing the field in code does not call its onChanged.
            _searchKeyWordController.clear();
            _bloc
              ..search('')
              ..refreshResults();
            // The fund's balance in the row above can only have moved with
            // the projects, so one refresh renews both.
            unawaited(
              sl.get<AcceleratorBalanceBloc>().getAcceleratorBalance(),
            );
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: <Widget>[
                SizedBox(width: 280, child: _buildSearchInputField()),
                const SizedBox(width: 14),
                Expanded(child: _buildProjectsFilterTags()),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<ProjectListState>(
              stream: _bloc.stream,
              initialData: _bloc.state,
              builder: (_, AsyncSnapshot<ProjectListState> snapshot) =>
                  _buildList(snapshot.data!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(ProjectListState state) {
    final List<Project>? projects = state.projects;
    if (projects == null) {
      if (state.error != null) {
        return RepaintBoundary(child: SyriusErrorWidget(state.error!));
      }
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppColors.znnColor,
            ),
          ),
        ),
      );
    }
    if (projects.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: Text(
            'None yet',
            style: Theme.of(
              context,
            ).textTheme.titleMedium!.copyWith(fontSize: 14),
          ),
        ),
      );
    }
    return Scrollbar(
      controller: _scrollController,
      child: ListView.separated(
        controller: _scrollController,
        itemCount: projects.length,
        separatorBuilder: (_, _) => const Divider(thickness: 0.75),
        itemBuilder: (_, int index) => AcceleratorProjectListItem(
          key: ValueKey<String>(projects[index].id.toString()),
          pillarInfo: widget.pillarInfo,
          acceleratorProject: projects[index],
          onStepperNotificationSeeMorePressed:
              widget.onStepperNotificationSeeMorePressed,
        ),
      ),
    );
  }

  Widget _buildSearchInputField() {
    return InputField(
      controller: _searchKeyWordController,
      hintText: 'Search projects',
      inputtedTextStyle: Theme.of(
        context,
      ).textTheme.bodyLarge!.copyWith(fontSize: 14),
      suffixIcon: const Icon(
        Icons.search,
        size: 18,
        color: AppColors.faint,
      ),
      // Each keystroke: the search is over the list in memory.
      onChanged: _bloc.search,
    );
  }

  Widget _buildProjectsFilterTags() {
    final List<Widget> children = <Widget>[];
    for (final AccProjectsFilterTag tag in AccProjectsFilterTag.values) {
      if (widget.pillarInfo == null &&
          <AccProjectsFilterTag>[
            AccProjectsFilterTag.needsVoting,
            AccProjectsFilterTag.alreadyVoted,
          ].contains(tag)) {
        continue;
      }
      if (children.isNotEmpty) children.add(const SizedBox(width: 6));
      children.add(_buildProjectsFilterTag(tag));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: children),
    );
  }

  Widget _buildProjectsFilterTag(AccProjectsFilterTag filterTag) {
    final bool selected = _bloc.selectedProjectsFilterTag.contains(filterTag);
    return AccChip(
      key: Key('acc_filter_${filterTag.name}'),
      label: FormatUtils.extractNameFromEnum<AccProjectsFilterTag>(filterTag),
      icon: selected ? Icons.check_rounded : null,
      selected: selected,
      onPressed: () {
        setState(() => _bloc.toggleFilter(filterTag));
      },
    );
  }

  @override
  void dispose() {
    _bloc.dispose();
    _searchKeyWordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
