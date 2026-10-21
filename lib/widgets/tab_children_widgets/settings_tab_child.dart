import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/node_update/node_update.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/help_widgets/about_section.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

/// The parts of Settings, in the order of the list at the left.
enum _Section {
  addresses('Addresses', Icons.account_balance_wallet_outlined),
  node('Node', Icons.dns_outlined),
  security('Security', Icons.shield_outlined),
  display('Display', Icons.palette_outlined),
  wallet('Wallet', Icons.tune),
  about('About', Icons.info_outline);

  const _Section(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Settings: a short list of sections at the left and the chosen one at the
/// right.
///
/// It was nine expandable cards on one grid, each setting one click deep
/// inside its card. Now a section shows all of its settings at once, and
/// the About section holds what the Help page had.
class SettingsTabChild extends StatefulWidget {
  const SettingsTabChild(
    this._onChangeAutoLockTime, {
    required this.onStepperNotificationSeeMorePressed,
    required this.onNodeChangedCallback,
    super.key,
  });
  final VoidCallback _onChangeAutoLockTime;
  final VoidCallback onStepperNotificationSeeMorePressed;
  final VoidCallback onNodeChangedCallback;

  @override
  State<SettingsTabChild> createState() => _SettingsTabChildState();
}

class _SettingsTabChildState extends State<SettingsTabChild> {
  // The shell builds a page only while it is shown, so the section picked
  // last is kept here for the next visit.
  static _Section _lastSection = _Section.addresses;

  _Section _section = _lastSection;

  final AccountChainStatsBloc _accountChainStatsBloc = AccountChainStatsBloc();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          width: 184,
          child: Panel(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final _Section section in _Section.values)
                  _SectionItem(
                    section: section,
                    selected: section == _section,
                    onTap: () => setState(() {
                      _section = section;
                      _lastSection = section;
                    }),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: kPanelGap),
        Expanded(
          child: AnimatedSwitcher(
            duration: Durations.medium1,
            reverseDuration: Durations.short2,
            switchInCurve: Easing.emphasizedDecelerate,
            switchOutCurve: Easing.emphasizedAccelerate,
            layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
              fit: StackFit.expand,
              children: <Widget>[...previous, if (current != null) current],
            ),
            transitionBuilder: (Widget child, Animation<double> animation) =>
                FadeTransition(opacity: animation, child: child),
            child: KeyedSubtree(
              key: ValueKey<_Section>(_section),
              child: _buildSection(_section),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(_Section section) {
    switch (section) {
      case _Section.addresses:
        return PageGrid(
          rows: <PageRow>[
            PageRow.fill(<PageCell>[
              PageCell(
                Addresses(accountChainStatsBloc: _accountChainStatsBloc),
                flex: 3,
              ),
              PageCell(
                AccountChainStatsWidget(
                  accountChainStatsBloc: _accountChainStatsBloc,
                ),
                flex: 2,
              ),
            ]),
          ],
        );
      case _Section.node:
        // The grid keeps the height it had as its least, and the Embedded
        // node panel, as tall as its rows, goes under it; the section
        // scrolls as one, as Security does.
        return SettingsSection(
          children: <Widget>[
            SizedBox(
              height: 420,
              child: PageGrid(
                rows: <PageRow>[
                  PageRow.fill(<PageCell>[
                    PageCell(
                      NodeManagement(
                        onNodeChangedCallback: widget.onNodeChangedCallback,
                      ),
                      flex: 3,
                    ),
                    const PageCell(_NetworkColumn(), flex: 2),
                  ], height: 420),
                ],
              ),
            ),
            const NodeUpdateCard(),
          ],
        );
      case _Section.security:
        return SecurityWidget(
          widget._onChangeAutoLockTime,
          onStepperNotificationSeeMorePressed:
              widget.onStepperNotificationSeeMorePressed,
        );
      case _Section.display:
        return const DisplayWidget();
      case _Section.wallet:
        return const SettingsSection(
          children: <Widget>[
            SettingsColumns(
              children: <Widget>[WalletOptions(), _BackupColumn()],
            ),
          ],
        );
      case _Section.about:
        return const AboutSection();
    }
  }

  @override
  void dispose() {
    _accountChainStatsBloc.dispose();
    super.dispose();
  }
}

/// The node's view of the network over the peers it has.
class _NetworkColumn extends StatelessWidget {
  const _NetworkColumn();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(height: 168, child: GeneralWidget()),
        SizedBox(height: kPanelGap),
        Expanded(child: PeersWidget()),
      ],
    );
  }
}

/// Backing up over the two ways to start again, each panel as tall as its
/// rows. They used to halve a fixed 366, which came to less than two rows
/// each, so the last row of both ended on the panel's edge.
class _BackupColumn extends StatelessWidget {
  const _BackupColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const BackupWidget(),
        SizedBox(height: AppTokens.of(context).panelGap),
        const WalletReset(),
      ],
    );
  }
}

/// A row of the section list, styled as the rail is: the chosen one on a
/// lighter surface with a green icon.
class _SectionItem extends StatelessWidget {
  const _SectionItem({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final _Section section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color dim = theme.textTheme.titleMedium!.color!;
    final Color fill = theme.colorScheme.primaryContainer;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: AnimatedContainer(
        duration: Durations.short3,
        curve: Easing.standard,
        decoration: BoxDecoration(
          color: selected ? fill : fill.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(kCardRadius),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            // The harness finds a section by this key or by its label.
            key: ValueKey<String>('settings_${section.name}'),
            borderRadius: BorderRadius.circular(kCardRadius),
            onTap: selected ? null : onTap,
            child: SizedBox(
              height: 38,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: <Widget>[
                    Icon(
                      section.icon,
                      size: 18,
                      color: selected ? AppColors.znnColor : dim,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        section.label,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge!.copyWith(
                          fontWeight: selected ? FontWeight.w500 : null,
                          color: selected ? null : dim,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
