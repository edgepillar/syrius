import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/accelerator_widgets/accelerator_parts.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/accelerator_widgets/accelerator_project_list_item.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_fields/input_field.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The filters of a list of projects held in memory.
enum AcceleratorProjectsFilterTag {
  /// Projects the selected address owns.
  myProjects,

  /// Accepted projects.
  onlyAccepted,

  /// Projects being voted on.
  votingOpened,
}

/// A list of projects or phases already loaded, with a search field: on a
/// project's page, its phases.
class AcceleratorProjectList extends StatefulWidget {
  /// Creates the list of [acceleratorProjects], which must not be empty.
  const AcceleratorProjectList(
    this.pillarInfo,
    this.acceleratorProjects, {
    required this.onStepperNotificationSeeMorePressed,
    this.projects,
    super.key,
  });

  /// The Pillar the selected address owns, if any.
  final PillarInfo? pillarInfo;

  /// The items listed.
  final List<AcceleratorProject> acceleratorProjects;

  /// For a list of phases, the project they belong to.
  final Project? projects;

  /// Opens the notifications page from a stepper.
  final VoidCallback onStepperNotificationSeeMorePressed;

  @override
  State<AcceleratorProjectList> createState() => _AcceleratorProjectListState();
}

class _AcceleratorProjectListState extends State<AcceleratorProjectList> {
  final TextEditingController _searchKeyWordController =
      TextEditingController();

  final List<AcceleratorProjectsFilterTag> _selectedProjectsFilterTag =
      <AcceleratorProjectsFilterTag>[];

  final ScrollController _scrollController = ScrollController();

  String _searchKeyWord = '';

  @override
  Widget build(BuildContext context) {
    final bool areProjects = widget.acceleratorProjects.first is Project;
    final List<AcceleratorProject> shown = _filterBaseProjects(
      widget.acceleratorProjects,
    ).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: <Widget>[
              SizedBox(width: 280, child: _buildSearchInputField()),
              if (areProjects) ...<Widget>[
                const SizedBox(width: 14),
                Expanded(child: _buildProjectsFilterTags()),
              ],
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Text(
                    'None yet',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium!.copyWith(fontSize: 14),
                  ),
                )
              : Scrollbar(
                  controller: _scrollController,
                  child: ListView.separated(
                    controller: _scrollController,
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const Divider(thickness: 0.75),
                    itemBuilder: (BuildContext context, int index) =>
                        AcceleratorProjectListItem(
                          key: ValueKey<String>(shown[index].id.toString()),
                          pillarInfo: widget.pillarInfo,
                          acceleratorProject: shown[index],
                          project: widget.projects,
                          onStepperNotificationSeeMorePressed:
                              widget.onStepperNotificationSeeMorePressed,
                        ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSearchInputField() {
    return InputField(
      controller: _searchKeyWordController,
      hintText: 'Search',
      inputtedTextStyle: Theme.of(
        context,
      ).textTheme.bodyLarge!.copyWith(fontSize: 14),
      suffixIcon: const Icon(
        Icons.search,
        size: 18,
        color: AppColors.faint,
      ),
      onChanged: (String value) {
        setState(() {
          _searchKeyWord = value;
        });
      },
    );
  }

  Set<AcceleratorProject> _filterBaseProjects(
    List<AcceleratorProject> acceleratorProjects,
  ) {
    Set<AcceleratorProject> filteredBaseProjects =
        _filterBaseProjectsBySearchKeyWord(acceleratorProjects);
    if (widget.acceleratorProjects.first is Project &&
        _selectedProjectsFilterTag.isNotEmpty) {
      filteredBaseProjects = _filterProjectsByFilterTags(
        filteredBaseProjects
            .map((AcceleratorProject e) => e as Project)
            .toList(),
      );
    }
    return filteredBaseProjects;
  }

  Set<AcceleratorProject> _filterBaseProjectsBySearchKeyWord(
    List<AcceleratorProject> acceleratorProjects,
  ) {
    final String keyWord = _searchKeyWord.toLowerCase();
    final Set<AcceleratorProject> filteredBaseProjects = <AcceleratorProject>{
      ...acceleratorProjects.where(
        (AcceleratorProject element) =>
            element.id.toString().toLowerCase().contains(keyWord),
      ),
      if (acceleratorProjects.first is Project)
        ...acceleratorProjects.where(
          (AcceleratorProject element) => (element as Project).owner
              .toString()
              .toLowerCase()
              .contains(keyWord),
        ),
      ...acceleratorProjects.where(
        (AcceleratorProject element) =>
            element.name.toLowerCase().contains(keyWord),
      ),
      ...acceleratorProjects.where(
        (AcceleratorProject element) =>
            element.description.toLowerCase().contains(keyWord),
      ),
      ...acceleratorProjects.where(
        (AcceleratorProject element) =>
            element.url.toLowerCase().contains(keyWord),
      ),
    };
    return filteredBaseProjects;
  }

  Widget _buildProjectsFilterTags() {
    final List<Widget> children = <Widget>[];
    for (final AcceleratorProjectsFilterTag tag
        in AcceleratorProjectsFilterTag.values) {
      if (tag == AcceleratorProjectsFilterTag.votingOpened &&
          widget.pillarInfo == null) {
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

  Widget _buildProjectsFilterTag(AcceleratorProjectsFilterTag filterTag) {
    final bool selected = _selectedProjectsFilterTag.contains(filterTag);
    return AccChip(
      label: FormatUtils.extractNameFromEnum<AcceleratorProjectsFilterTag>(
        filterTag,
      ),
      icon: selected ? Icons.check_rounded : null,
      selected: selected,
      onPressed: () {
        setState(() {
          if (selected) {
            _selectedProjectsFilterTag.remove(filterTag);
          } else {
            _selectedProjectsFilterTag.add(filterTag);
          }
        });
      },
    );
  }

  Set<AcceleratorProject> _filterProjectsByFilterTags(List<Project> projects) {
    Iterable<Project> filteredBaseProjects = const Iterable<Project>.empty();
    if (_selectedProjectsFilterTag.contains(
      AcceleratorProjectsFilterTag.myProjects,
    )) {
      filteredBaseProjects = projects.where(
        (Project project) => project.owner.toString() == kSelectedAddress,
      );
    }
    if (_selectedProjectsFilterTag.contains(
      AcceleratorProjectsFilterTag.onlyAccepted,
    )) {
      if (filteredBaseProjects.isNotEmpty) {
        filteredBaseProjects = filteredBaseProjects.where(
          (Project project) =>
              project.status == AcceleratorProjectStatus.active,
        );
      } else {
        filteredBaseProjects = projects.where(
          (Project project) =>
              project.status == AcceleratorProjectStatus.active,
        );
      }
    }
    if (_selectedProjectsFilterTag.contains(
      AcceleratorProjectsFilterTag.votingOpened,
    )) {
      if (filteredBaseProjects.isNotEmpty) {
        filteredBaseProjects = filteredBaseProjects.where(
          (Project project) =>
              project.status == AcceleratorProjectStatus.voting,
        );
      } else {
        filteredBaseProjects = projects.where(
          (Project project) =>
              project.status == AcceleratorProjectStatus.voting,
        );
      }
    }
    return filteredBaseProjects.toSet();
  }

  @override
  void dispose() {
    _searchKeyWordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
