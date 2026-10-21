import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/tabs.dart';

/// The space between two rail items, half above each and half below.
const double _kRailItemGap = 2;

/// The rail's width open: an icon and a label for each page.
const double _kRailWidth = 200;

/// The rail's width collapsed: the icons alone, with as much room on each
/// side of one as it has above and below at the tallest row.
const double _kRailCollapsedWidth = 56;

const double _kRailIconSize = 18;

/// The space before an icon in the open rail, and between it and its label.
const double _kRailIconInset = 12;

/// The same space collapsed, which is what centres the icon in the strip.
const double _kRailIconInsetCollapsed =
    (_kRailCollapsedWidth - _kRailIconSize) / 2;

/// What is left of an item in the open rail after the icon: the room its
/// label is laid out in, at every width of the rail.
const double _kRailLabelBox = _kRailWidth - _kRailIconInset - _kRailIconSize;

/// The labels are gone before the rail is much narrower than they are, and
/// come back once it is nearly wide enough for them: they fade over the wide
/// 60% of the travel, so the edge of the rail is not seen cutting through a
/// word at full strength.
const Interval _kRailLabelFade = Interval(0.4, 1);

/// A length between its value in the collapsed rail and in the open one.
/// [expansion] is 0 collapsed and 1 open.
double _railLerp(double collapsed, double open, double expansion) =>
    collapsed + (open - collapsed) * expansion;

/// Puts a rail tooltip beside its item, towards the page, [gap] off the
/// rail. Material puts a tooltip under its target, which in a column of
/// icons is on top of the next one.
TooltipPositionDelegate _railTooltipBeside(
  TextDirection direction,
  double gap,
) => (TooltipPositionContext context) {
  final double reach = context.targetSize.width / 2 + gap;
  final double top = context.target.dy - context.tooltipSize.height / 2;
  final double lowest = math.max(
    0,
    context.overlaySize.height - context.tooltipSize.height,
  );
  return Offset(
    direction == TextDirection.ltr
        ? context.target.dx + reach
        : context.target.dx - reach - context.tooltipSize.width,
    top.clamp(0.0, lowest),
  );
};

/// The selected rail item's tint: the theme's hover tint, twice as strong on
/// the light ground, where near white the eye needs about twice the alpha
/// for the step the dark ground shows at once. An item under the pointer
/// gets half of it, so hover stays lighter than selected in both themes.
///
/// The rail's own colour, not a scheme role: it used the scheme's primary,
/// which is the card colour (the status strip's fill) and drew the selected
/// item in the light theme as a mid-grey slab.
Color _railPillColor(BuildContext context) {
  final Color hover = AppTokens.of(context).hover;
  final double strength = Theme.of(context).brightness == Brightness.light
      ? 2
      : 1;
  return hover.withValues(alpha: hover.a * strength);
}

/// One destination of the rail: a page, its name and its icon.
class RailEntry {
  /// Creates an entry for [tab].
  const RailEntry(this.tab, this.label, this.icon);

  /// The page the entry opens.
  final Tabs tab;

  /// The entry's name.
  final String label;

  /// The entry's icon.
  final IconData icon;
}

/// The rail's pages, in the order of their number shortcuts.
const List<RailEntry> kRailPages = <RailEntry>[
  RailEntry(Tabs.dashboard, 'Home', Icons.home_outlined),
  RailEntry(Tabs.transfer, 'Transfer', Icons.send_outlined),
  RailEntry(Tabs.pillars, 'Pillars', Icons.layers_outlined),
  RailEntry(Tabs.sentinels, 'Sentinels', Icons.shield_outlined),
  RailEntry(Tabs.staking, 'Staking', Icons.savings_outlined),
  RailEntry(Tabs.plasma, 'Plasma', Icons.bolt_outlined),
  RailEntry(Tabs.tokens, 'Tokens', Icons.toll_outlined),
  RailEntry(Tabs.p2pSwap, 'P2P Swap', Icons.swap_horiz),
  RailEntry(Tabs.accelerator, 'Accelerator', Icons.rocket_launch_outlined),
];

/// The wallet's own entries, at the foot of the rail.
///
/// Help has none: what it held is Settings > About.
List<RailEntry> railWalletEntries({required bool onLock}) => <RailEntry>[
  // Shown when the page exists: kTabs decides, the rail follows.
  if (kTabs.contains(Tabs.walletConnect))
    const RailEntry(Tabs.walletConnect, 'Connected sites', Icons.link),
  const RailEntry(
    Tabs.notifications,
    'Notifications',
    Icons.notifications_outlined,
  ),
  const RailEntry(Tabs.settings, 'Settings', Icons.settings_outlined),
  RailEntry(
    Tabs.lock,
    onLock ? 'Locked' : 'Lock',
    onLock ? Icons.lock_outline : Icons.lock_open_outlined,
  ),
];

/// What a profile that has never opened or collapsed the rail gets.
///
/// Collapsed: the labels cost every page 144 px for as long as they show,
/// and the pages are few enough to know by their icons within a day. The
/// names are one press away, and under the pointer as tooltips.
const bool _kRailCollapsedDefault = true;

/// Whether the rail is collapsed to its icons: the stored choice, and the
/// one place that reads and writes it.
///
/// A notifier and not a field of the rail, because two things change it
/// (the rail's own toggle and the shell's shortcut) and the shell's is not
/// inside the rail.
///
/// Public, with [ShellRail], so that `test/shell` can reach the rail: the
/// shell round it cannot be pumped without a wallet and a node.
class RailCollapse extends ValueNotifier<bool> {
  /// Starts from what is stored, or from the default when nothing is.
  RailCollapse() : super(_stored());

  static bool _stored() {
    final Object? stored = sharedPrefsService!.get(
      kRailCollapsedKey,
      defaultValue: _kRailCollapsedDefault,
    );
    // Anything but a bool is a damaged entry, and reads as never chosen.
    return stored is bool ? stored : _kRailCollapsedDefault;
  }

  /// Opens the rail if it is collapsed and collapses it if it is open, and
  /// stores which for the next start.
  void toggle() {
    value = !value;
    unawaited(sharedPrefsService!.put(kRailCollapsedKey, value));
  }
}

/// The rail at the width it has now: [_kRailCollapsedWidth] collapsed,
/// [_kRailWidth] open, and each width between while it moves from one to
/// the other. The page beside it has whatever is left.
///
/// One controller gives the width, the labels' fade and the icons' place,
/// so the three cannot come apart. That is why it is a controller and not
/// an AnimatedContainer: the items need the value the width was made from.
///
/// The motion always runs. The controller keeps its duration whatever the
/// system says about reduced motion ([AnimationBehavior.preserve]; the
/// default shortens it to a twentieth), and nothing here asks MediaQuery.
///
/// Public, with [RailCollapse], for `test/shell`.
class ShellRail extends StatefulWidget {
  /// Creates the rail. [collapse] is the shell's, so its shortcut and the
  /// rail's toggle change the same thing.
  const ShellRail({
    required this.collapse,
    required this.selected,
    required this.locked,
    required this.onSelected,
    super.key,
  });

  /// Whether the rail is collapsed. The rail follows it and toggles it.
  final RailCollapse collapse;

  /// The page shown.
  final Tabs selected;

  /// Whether the wallet is locked: the rail, toggle included, then takes no
  /// pointer and no focus.
  final bool locked;

  /// Called with the page of the item pressed.
  final ValueChanged<Tabs> onSelected;

  @override
  State<ShellRail> createState() => _ShellRailState();
}

class _ShellRailState extends State<ShellRail>
    with SingleTickerProviderStateMixin {
  // Starts where the stored choice is, so the first frame is already at its
  // width: nothing opens or closes as the wallet starts.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Durations.short4,
    value: widget.collapse.value ? 0 : 1,
    animationBehavior: AnimationBehavior.preserve,
  );

  late final CurvedAnimation _expansion = CurvedAnimation(
    parent: _controller,
    curve: Easing.standard,
  );

  @override
  void initState() {
    super.initState();
    widget.collapse.addListener(_follow);
  }

  @override
  void didUpdateWidget(ShellRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collapse != widget.collapse) {
      oldWidget.collapse.removeListener(_follow);
      widget.collapse.addListener(_follow);
      _follow();
    }
  }

  @override
  void dispose() {
    widget.collapse.removeListener(_follow);
    _expansion.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _follow() {
    // The toggle is renamed at once; the width catches up.
    setState(() {});
    unawaited(
      widget.collapse.value ? _controller.reverse() : _controller.forward(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _expansion,
      builder: (BuildContext context, Widget? child) {
        final double expansion = _expansion.value.clamp(0.0, 1.0);
        return SizedBox(
          width: _railLerp(_kRailCollapsedWidth, _kRailWidth, expansion),
          child: _Rail(
            selected: widget.selected,
            locked: widget.locked,
            onSelected: widget.onSelected,
            collapsed: widget.collapse.value,
            expansion: expansion,
            onToggle: widget.collapse.toggle,
          ),
        );
      },
    );
  }
}

/// The side rail: the toggle that opens and collapses it, the pages under
/// that, the wallet's own entries at the bottom, and one pill that glides to
/// whichever is selected.
///
/// It fills the width it is given and does not choose it: [ShellRail] does,
/// and tells the rail how far open that width is.
class _Rail extends StatefulWidget {
  const _Rail({
    required this.selected,
    required this.locked,
    required this.onSelected,
    required this.collapsed,
    required this.expansion,
    required this.onToggle,
  });

  final Tabs selected;
  final bool locked;
  final ValueChanged<Tabs> onSelected;

  /// Where the rail is going: collapsed, or open. It names the toggle.
  final bool collapsed;

  /// Where the rail is now: 0 collapsed, 1 open, between while it moves.
  final double expansion;

  final VoidCallback onToggle;

  @override
  State<_Rail> createState() => _RailState();
}

class _RailState extends State<_Rail> {
  double? _lastHeight;

  @override
  Widget build(BuildContext context) {
    final List<RailEntry> wallet = railWalletEntries(
      onLock: widget.selected == Tabs.lock,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double height = constraints.maxHeight;
        // Every item must fit the shortest window (1200x600) without
        // losing Lock off the bottom: rows shrink from 40 to 30 first.
        // The toggle is a row like the others, above the pages.
        final int count = 1 + kRailPages.length + wallet.length;
        final double itemHeight = ((height - 24) / count - _kRailItemGap).clamp(
          30.0,
          40.0,
        );
        final double slot = itemHeight + _kRailItemGap;

        // Where the pill sits: counted from the top for the pages, under the
        // toggle's row, and from the bottom for the wallet's entries, as
        // the Spacer between them lays them out.
        final int pageAt = kRailPages.indexWhere(
          (RailEntry e) => e.tab == widget.selected,
        );
        final int walletAt = wallet.indexWhere(
          (RailEntry e) => e.tab == widget.selected,
        );
        final double? pillTop = pageAt >= 0
            ? (1 + pageAt) * slot
            : walletAt >= 0
            ? height - (wallet.length - walletAt) * slot
            : null;

        // The pill glides when the selection changes. When the window is
        // resized the items move at once, and so must the pill.
        final bool resized = _lastHeight != null && _lastHeight != height;
        _lastHeight = height;

        final Color pill = _railPillColor(context);
        // Locked, the rail takes no pointer and no keyboard focus: the only
        // way past the lock screen is the password. IgnorePointer alone
        // would leave Tab and Enter able to reach an item.
        return ExcludeFocus(
          excluding: widget.locked,
          child: IgnorePointer(
            ignoring: widget.locked,
            child: AnimatedOpacity(
              opacity: widget.locked ? 0.4 : 1,
              duration: Durations.short4,
              child: Stack(
                children: <Widget>[
                  if (pillTop != null)
                    AnimatedPositioned(
                      key: const Key('rail_pill'),
                      duration: resized ? Duration.zero : Durations.medium1,
                      curve: Easing.emphasizedDecelerate,
                      left: 0,
                      right: 0,
                      top: pillTop + _kRailItemGap / 2,
                      height: itemHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: pill,
                          borderRadius: BorderRadius.circular(kCardRadius),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _RailToggle(
                          collapsed: widget.collapsed,
                          expansion: widget.expansion,
                          height: itemHeight,
                          onTap: widget.onToggle,
                        ),
                        for (final RailEntry entry in kRailPages)
                          _buildItem(entry, itemHeight),
                        const Spacer(),
                        for (final RailEntry entry in wallet)
                          _buildItem(entry, itemHeight),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItem(RailEntry entry, double height) {
    return _RailButton(
      // The harness finds rail items by this key (`--tab <name>`).
      hitKey: ValueKey<String>('nav_${entry.tab.name}'),
      icon: entry.icon,
      name: entry.label,
      height: height,
      expansion: widget.expansion,
      selected: entry.tab == widget.selected,
      onTap: () => widget.onSelected(entry.tab),
    );
  }
}

/// The button that opens and collapses the rail, in the first row.
///
/// One chevron for both: it points away from the rail's edge to open it and
/// turns half a circle with the rail to point back. The icon mirrors itself
/// right to left, where the rail is on the other side, and the turn is the
/// same there.
class _RailToggle extends StatelessWidget {
  const _RailToggle({
    required this.collapsed,
    required this.expansion,
    required this.height,
    required this.onTap,
  });

  final bool collapsed;
  final double expansion;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _RailButton(
      // The harness opens and collapses the rail by this key.
      hitKey: const ValueKey<String>('rail_toggle'),
      icon: Icons.chevron_right,
      iconAngle: math.pi * expansion,
      name: collapsed ? context.l10n.railExpand : context.l10n.railCollapse,
      labelled: false,
      height: height,
      expansion: expansion,
      onTap: onTap,
    );
  }
}

/// One row of the rail: an icon, and its name beside it while the rail is
/// open. A page's item and the toggle are both one, so the hover, the focus
/// ring and the tooltip are made once.
///
/// The selected item is marked by the rail's pill, behind it; the row
/// itself only changes its ink, on selection and under the mouse.
class _RailButton extends StatefulWidget {
  const _RailButton({
    required this.hitKey,
    required this.icon,
    required this.name,
    required this.height,
    required this.expansion,
    required this.onTap,
    this.labelled = true,
    this.selected = false,
    this.iconAngle = 0,
  });

  /// On the row's own box: the harness and the tests find a row by it and
  /// press its middle.
  final Key hitKey;
  final IconData icon;

  /// What the row is called: its label, and its tooltip when it shows none.
  final String name;
  final double height;

  /// How far open the rail is: 0 collapsed, 1 open.
  final double expansion;
  final VoidCallback onTap;

  /// Whether the name shows beside the icon while the rail is open.
  final bool labelled;
  final bool selected;

  /// How far the icon is turned, in radians.
  final double iconAngle;

  @override
  State<_RailButton> createState() => _RailButtonState();
}

class _RailButtonState extends State<_RailButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppTokens tokens = AppTokens.of(context);
    final Color dim = theme.textTheme.titleMedium!.color!;
    final Color fg = theme.textTheme.bodyLarge!.color!;
    final Color pill = _railPillColor(context);
    final bool selected = widget.selected;
    final bool lit = selected || _hovered;
    // The label is in the tree from the moment the rail starts to open
    // until it has closed, and not while it rests collapsed.
    final bool showsLabel = widget.labelled && widget.expansion > 0;
    // The tooltip names the row only while no label does. It is switched
    // off, not taken out: taking it out would rebuild the row under it and
    // drop its hover and its focus each time the rail moved.
    return TooltipVisibility(
      visible: !showsLabel,
      child: Tooltip(
        message: widget.name,
        positionDelegate: _railTooltipBeside(
          Directionality.of(context),
          tokens.cardGap,
        ),
        // The icon carries the name for a screen reader instead, and only
        // while there is no label, so the name is never read twice.
        excludeFromSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: _kRailItemGap / 2),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(tokens.cardRadius),
              // Half the pill: enough to say "this one", less than
              // "selected".
              hoverColor: selected
                  ? Colors.transparent
                  : pill.withValues(alpha: pill.a / 2),
              // Focus is the ring below, not a fill: the theme's focus
              // fill is a 12% grey, heavier than the pill it would sit on.
              focusColor: Colors.transparent,
              onHover: (bool value) => setState(() => _hovered = value),
              onFocusChange: (bool value) => setState(() => _focused = value),
              onTap: widget.onTap,
              child: DecoratedBox(
                // The key is on this box and not on the one inside it: a
                // decoration is hit anywhere in its bounds, and the middle
                // of a row that shows an icon alone is otherwise empty.
                key: widget.hitKey,
                // Drawn inside the row's own box, so focus moves nothing.
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  border: _focused
                      ? Border.all(color: tokens.focusRing, width: 2)
                      : null,
                  borderRadius: BorderRadius.circular(tokens.cardRadius),
                ),
                child: SizedBox(
                  height: widget.height,
                  child: Padding(
                    // Only the start is padded. The icon is centred in the
                    // collapsed rail by this inset and not by an alignment,
                    // so it slides the 7 px to its open place with the
                    // width instead of jumping there.
                    padding: EdgeInsetsDirectional.only(
                      start: _railLerp(
                        _kRailIconInsetCollapsed,
                        _kRailIconInset,
                        widget.expansion,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        TweenAnimationBuilder<Color?>(
                          tween: ColorTween(
                            end: selected
                                ? tokens.znnInk
                                : lit
                                ? fg
                                : dim,
                          ),
                          duration: Durations.short3,
                          builder:
                              (
                                BuildContext context,
                                Color? color,
                                Widget? child,
                              ) => Transform.rotate(
                                angle: widget.iconAngle,
                                child: Icon(
                                  widget.icon,
                                  size: _kRailIconSize,
                                  color: color,
                                  semanticLabel: showsLabel
                                      ? null
                                      : widget.name,
                                ),
                              ),
                        ),
                        if (showsLabel)
                          Expanded(
                            child: _RailLabel(
                              text: widget.name,
                              expansion: widget.expansion,
                              style: theme.textTheme.bodyLarge!.copyWith(
                                fontSize: 14,
                                fontWeight: selected
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                                color: lit ? fg : dim,
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
        ),
      ),
    );
  }
}

/// A rail item's label, laid out in the room it has in the open rail
/// whatever the rail's width is at this moment, and cut off at the rail's
/// edge.
///
/// So while the rail opens or closes the label keeps its one line and its
/// own ellipsis, and fades. Laid out in the room actually left, it would be
/// cut to a new ellipsis on every frame, and wrap if it were allowed to.
class _RailLabel extends StatelessWidget {
  const _RailLabel({
    required this.text,
    required this.style,
    required this.expansion,
  });

  final String text;
  final TextStyle style;
  final double expansion;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: OverflowBox(
        alignment: AlignmentDirectional.centerStart,
        minWidth: _kRailLabelBox,
        maxWidth: _kRailLabelBox,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: _kRailIconInset,
            end: _kRailIconInset,
          ),
          child: Opacity(
            opacity: _kRailLabelFade.transform(expansion),
            child: AnimatedDefaultTextStyle(
              duration: Durations.short3,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
              child: Text(text),
            ),
          ),
        ),
      ),
    );
  }
}
