import 'dart:async';

import 'package:hive_ce/hive_ce.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart'
    show panelTitleStyle;
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart'
    show kSharedPrefsBox;
import 'package:zenon_syrius_wallet_flutter/widgets/shell/page_dismiss.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/rail.dart'
    show ShellSymbol;

/// How long the body takes to open or close.
const Duration _kRevealDuration = Duration(milliseconds: 240);

/// How long the chevron takes to turn. Shorter than the body, so it has
/// arrived before the height has.
const Duration _kTurnDuration = Duration(milliseconds: 220);

/// How far above its place the body starts, to slide down into it.
const double _kSlide = 8;

/// The least height of the header row.
const double _kHeaderHeight = 44;

const EdgeInsetsDirectional _kHeaderPadding = EdgeInsetsDirectional.fromSTEB(
  16,
  0,
  12,
  0,
);

/// The mockup's spring: fast out, long settle, and never past either end,
/// so a height that follows it is never negative.
const Cubic _kSpring = Cubic(0.2, 0.8, 0.2, 1);

/// What a disclosure's state is filed under in the shared preferences:
/// this, then its [Disclosure.storeKey].
///
/// A prefix of its own, and the value is "open" where a panel stores
/// "collapsed": a disclosure is closed until someone opens it, so an entry
/// here always records a choice against that default or back to it.
const String _kDisclosureOpenKeyPrefix = 'disclosure_open_';

/// The shared preferences, or null while their box is not open: before the
/// wallet has opened it, and in a test that pumps a disclosure on its own.
Box<dynamic>? _disclosurePreferences() =>
    Hive.isBoxOpen(kSharedPrefsBox) ? Hive.box<dynamic>(kSharedPrefsBox) : null;

/// Whether the disclosure filed under [storeKey] was left open. Null when
/// nothing says so: it was never toggled, there is no box, or the entry is
/// damaged.
bool? _storedOpen(String storeKey) {
  final Object? stored = _disclosurePreferences()?.get(
    '$_kDisclosureOpenKeyPrefix$storeKey',
  );
  return stored is bool ? stored : null;
}

/// Stores the choice for the next start. Without a box it lives only as
/// long as the disclosure's own state does.
void _storeOpen(String storeKey, {required bool open}) {
  final Box<dynamic>? preferences = _disclosurePreferences();
  if (preferences == null) return;
  unawaited(preferences.put('$_kDisclosureOpenKeyPrefix$storeKey', open));
}

/// Opens and closes a [Disclosure] from somewhere else on the page: the
/// strip's "Stake" button for the form under the strip.
///
/// It also says where the disclosure is, and tells its listeners when that
/// changes, whoever changed it. The one change it does not announce is the
/// disclosure taking its starting state as it is first built: that happens
/// during a build, when no listener may be told to rebuild.
class DisclosureController extends ChangeNotifier {
  /// Creates a controller. [open] is honoured by a disclosure that has no
  /// stored choice of its own.
  DisclosureController({this._open = false});

  bool _open;

  /// Whether the disclosure is open, or on its way to being.
  bool get isOpen => _open;

  /// Opens the disclosure.
  void open() => _set(true);

  /// Closes the disclosure.
  void close() => _set(false);

  /// Opens a closed disclosure and closes an open one.
  void toggle() => _set(!_open);

  void _set(bool value) {
    if (_open == value) return;
    _open = value;
    notifyListeners();
  }

  /// Takes the disclosure's state without telling anyone; see the class.
  // ignore: use_setters_to_change_properties
  void _adopt(bool value) => _open = value;
}

/// A section that opens in place, under a header that is its button.
///
/// Where a collapsible `Panel` is a whole card and drops its body when
/// closed, this is only the header and the body, to be put inside whatever
/// surface the page has, and with [keepAlive] the body stays mounted while
/// closed, so a half-typed form is still there when it is opened again.
///
/// It needs a bounded width, and is as tall as what it shows.
class Disclosure extends StatefulWidget {
  /// Creates a disclosure under a header.
  const Disclosure({
    required String this.title,
    required this.child,
    this.count,
    this.summary,
    this.summaryColumnPercent,
    this.storeKey,
    this.initiallyOpen = false,
    this.keepAlive = false,
    this.onChanged,
    this.controller,
    this.keyPrefix,
    this.headerPadding = _kHeaderPadding,
    this.headerMinHeight = _kHeaderHeight,
    this.showDividerWhenOpen = false,
    this.titleStyle,
    this.isolateChevronPaint = true,
    super.key,
  }) : assert(
         summaryColumnPercent == null ||
             (summaryColumnPercent > 0 && summaryColumnPercent < 100),
         'The summary column must start inside the header.',
       );

  /// Creates a body with no header, opened and closed only by [controller]:
  /// the form under a strip whose own button is the toggle.
  const Disclosure.bare({
    required DisclosureController this.controller,
    required this.child,
    this.storeKey,
    this.initiallyOpen = false,
    this.keepAlive = false,
    this.onChanged,
    this.headerMinHeight = _kHeaderHeight,
    super.key,
  }) : title = null,
       count = null,
       summary = null,
       summaryColumnPercent = null,
       keyPrefix = null,
       titleStyle = null,
       showDividerWhenOpen = false,
       isolateChevronPaint = false,
       headerPadding = _kHeaderPadding;

  /// The heading. Null only for [Disclosure.bare], which has no header.
  final String? title;

  /// How many things the body holds, shown small beside the title.
  final int? count;

  /// What the body would say, in a few words, dim at the end of the header
  /// before the chevron.
  final String? summary;

  /// When set, the summary starts at this percentage of the header before
  /// the chevron. Rows in a table can share the same aligned column.
  final int? summaryColumnPercent;

  /// The body.
  final Widget child;

  /// What the open or closed state is stored under, so that it outlives a
  /// restart. Null means it is not stored.
  ///
  /// A fixed identifier of the place, such as `settings.security.sign`.
  /// Never the title: that is translated, and a state keyed on it is lost
  /// when the language changes.
  final String? storeKey;

  /// Whether it is open the first time it is shown. Once the reader has
  /// opened or closed a stored one, what they chose wins over this.
  final bool initiallyOpen;

  /// Whether the body stays mounted while closed: laid out but not painted,
  /// and out of focus traversal and of the semantics tree. A form keeps
  /// what was typed and a list its scroll position.
  ///
  /// False by default, because a mounted body still runs: its streams and
  /// requests go on behind a closed header.
  final bool keepAlive;

  /// Called with the new state whenever it changes, by the header or by
  /// the [controller].
  final ValueChanged<bool>? onChanged;

  /// Opens and closes it from elsewhere. The header works with or without.
  final DisclosureController? controller;

  /// Gives the header `ValueKey('<keyPrefix>_toggle')`, for the UI harness.
  final String? keyPrefix;

  /// The header can grow for text; other disclosures keep the default.
  final double headerMinHeight;

  /// Insets for the title and chevron inside the header hit target.
  final EdgeInsetsGeometry headerPadding;

  /// Paints a rule inside the lower edge of an open heading.
  final bool showDividerWhenOpen;

  /// Optional title style for disclosures embedded in a form.
  final TextStyle? titleStyle;

  /// Gives the chevron a layer when its parent row has no paint boundary.
  final bool isolateChevronPaint;

  @override
  State<Disclosure> createState() => _DisclosureState();
}

class _DisclosureState extends State<Disclosure> with TickerProviderStateMixin {
  late bool _open;
  bool _hasMotion = false;

  // Both start where the disclosure is, so nothing opens as a page is
  // shown. The motion always runs: the controllers keep their duration
  // whatever the system says about reduced motion
  // ([AnimationBehavior.preserve]; the default shortens it to a twentieth),
  // and nothing here asks MediaQuery.
  late final AnimationController _body;
  late final AnimationController _turn;
  late final CurvedAnimation _reveal;
  late final CurvedAnimation _turned;

  /// The stored choice; until there is one, a controller already told to
  /// open, or [Disclosure.initiallyOpen].
  bool _startsOpen() {
    final String? storeKey = widget.storeKey;
    final bool? stored = storeKey == null ? null : _storedOpen(storeKey);
    return stored ??
        ((widget.controller?.isOpen ?? false) || widget.initiallyOpen);
  }

  @override
  void initState() {
    super.initState();
    _open = _startsOpen();
    if (_open) _createMotion(initialValue: 1);
    widget.controller
      ?.._adopt(_open)
      ..addListener(_onController);
  }

  // Closed rows render at rest without allocating two tickers per row.
  void _createMotion({required double initialValue}) {
    _body = AnimationController(
      vsync: this,
      duration: _kRevealDuration,
      value: initialValue,
      animationBehavior: AnimationBehavior.preserve,
    )..addStatusListener(_onBodyStatus);
    _turn = AnimationController(
      vsync: this,
      duration: _kTurnDuration,
      value: initialValue,
      animationBehavior: AnimationBehavior.preserve,
    );
    _reveal = CurvedAnimation(parent: _body, curve: _kSpring);
    _turned = CurvedAnimation(parent: _turn, curve: _kSpring);
    _hasMotion = true;
  }

  @override
  void didUpdateWidget(Disclosure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onController);
      widget.controller
        ?.._adopt(_open)
        ..addListener(_onController);
    }
    // Another key is another section's state, to be read as on a first
    // show.
    if (oldWidget.storeKey != widget.storeKey) {
      _open = _startsOpen();
      widget.controller?._adopt(_open);
      _follow();
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onController);
    if (_hasMotion) {
      _reveal.dispose();
      _turned.dispose();
      _body.dispose();
      _turn.dispose();
    }
    super.dispose();
  }

  void _onController() => _setOpen(widget.controller!.isOpen);

  /// The two ends take a build that no change of the widget asks for:
  /// closed, the body leaves the tree or goes offstage; open, the clip
  /// comes off.
  void _onBodyStatus(AnimationStatus status) {
    if (!mounted || status.isAnimating) return;
    setState(() {});
  }

  void _setOpen(bool open) {
    if (open == _open) return;
    setState(() => _open = open);
    // Tells the controller's other listeners; this state's own hears it
    // too and finds nothing to do.
    widget.controller?._set(open);
    final String? storeKey = widget.storeKey;
    if (storeKey != null) _storeOpen(storeKey, open: open);
    widget.onChanged?.call(open);
    _follow();
  }

  /// Sends both animations to where [_open] says they belong.
  void _follow() {
    if (_open) {
      if (!_hasMotion) _createMotion(initialValue: 0);
      _body.forward();
      _turn.forward();
    } else if (_hasMotion) {
      _body.reverse();
      _turn.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool closed = !_open && (!_hasMotion || _body.isDismissed);
    final String? title = widget.title;

    Widget? body;
    if (!closed || widget.keepAlive) {
      // A closing form is already closed to input and screen readers, even
      // while its last frame is visible. Keep the wrappers stable so a
      // keepAlive form retains its state when it opens again.
      body = IgnorePointer(
        ignoring: !_open,
        child: ExcludeSemantics(
          excluding: !_open,
          child: Focus(
            canRequestFocus: false,
            // Retained EditableText nodes can latch an inherited traversal
            // barrier. Focusability alone closes the form without that latch.
            descendantsAreFocusable: _open,
            child: DisclosureReveal._(
              _hasMotion ? _reveal : kAlwaysDismissedAnimation,
              child: widget.child,
            ),
          ),
        ),
      );
      if (widget.keepAlive) {
        // The same wrappers open and closed, so the body's state is never
        // rebuilt. Offstage takes it out of paint, hit testing and
        // semantics; it does not stop its tickers, hence TickerMode.
        body = Offstage(
          offstage: closed,
          child: TickerMode(enabled: !closed, child: body),
        );
      }
    }

    return PageDismissAction(
      open: _open,
      onDismiss: () => _setOpen(false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (title != null)
            _DisclosureHeader(
              toggleKey: widget.keyPrefix == null
                  ? null
                  : ValueKey<String>('${widget.keyPrefix}_toggle'),
              title: title,
              titleStyle: widget.titleStyle,
              minHeight: widget.headerMinHeight,
              padding: widget.headerPadding,
              count: widget.count,
              summary: widget.summary,
              summaryColumnPercent: widget.summaryColumnPercent,
              turned: _hasMotion ? _turned : kAlwaysDismissedAnimation,
              isolateChevronPaint: widget.isolateChevronPaint,
              showDivider: _open && widget.showDividerWhenOpen,
              open: _open,
              onToggle: () => _setOpen(!_open),
            ),
          ?body,
        ],
      ),
    );
  }
}

/// The moving body of a [Disclosure].
///
/// The body is laid out at its full height throughout and uncovered from
/// the top while it slides down into place. Squeezed into the height reached
/// so far, a form would overflow on every frame of the way.
class DisclosureReveal extends StatelessWidget {
  const DisclosureReveal._(this._reveal, {required this.child});

  final Animation<double> _reveal;

  /// The body laid out at its full size.
  final Widget child;

  /// Whether the revealed body has reached its fully open position.
  bool get isSettled => _reveal.isCompleted;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _reveal,
      // Align gives its child loose constraints. Keep the full body width.
      child: SizedBox(
        width: double.infinity,
        child: RepaintBoundary(child: child),
      ),
      builder: (BuildContext context, Widget? child) {
        final double t = _reveal.value;
        // Fully open, focus rings and glows can extend past the body box.
        return ClipRect(
          clipBehavior: isSettled ? Clip.none : Clip.hardEdge,
          child: Align(
            alignment: AlignmentDirectional.topStart,
            heightFactor: t,
            child: Transform.translate(
              offset: Offset(0, -_kSlide * (1 - t)),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// The header: title, count, and at the end the summary and the chevron.
/// The whole row is the button.
class _DisclosureHeader extends StatefulWidget {
  const _DisclosureHeader({
    required this.toggleKey,
    required this.title,
    required this.titleStyle,
    required this.minHeight,
    required this.padding,
    required this.count,
    required this.summary,
    required this.summaryColumnPercent,
    required this.turned,
    required this.isolateChevronPaint,
    required this.showDivider,
    required this.open,
    required this.onToggle,
  });

  final Key? toggleKey;
  final double minHeight;
  final EdgeInsetsGeometry padding;
  final String title;
  final TextStyle? titleStyle;
  final int? count;
  final String? summary;
  final int? summaryColumnPercent;

  /// 0 closed, 1 open: what the chevron turns with.
  final Animation<double> turned;

  final bool isolateChevronPaint;
  final bool showDivider;

  /// Where the disclosure is going, for a screen reader.
  final bool open;

  final VoidCallback onToggle;

  @override
  State<_DisclosureHeader> createState() => _DisclosureHeaderState();
}

class _DisclosureHeaderState extends State<_DisclosureHeader> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppTokens tokens = AppTokens.of(context);
    final int? count = widget.count;
    final String? summary = widget.summary;
    final int? summaryColumnPercent = widget.summaryColumnPercent;

    final Widget heading = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: widget.titleStyle ?? panelTitleStyle(context),
          ),
        ),
        if (count != null) ...<Widget>[
          SizedBox(width: tokens.cardGap),
          Text(
            '$count',
            style: monoStyle(
              theme.textTheme.titleSmall,
            ).copyWith(fontSize: 11, color: tokens.faint),
          ),
        ],
      ],
    );

    final Widget? summaryText = summary == null
        ? null
        : Padding(
            padding: EdgeInsetsDirectional.only(start: tokens.cardGap),
            child: Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // Match the secondary text used beside the header chevron.
              style: theme.textTheme.titleMedium!.copyWith(fontSize: 12.5),
            ),
          );

    // The ink needs a Material to draw on, and the disclosure does not know
    // whether the surface it was put in is one.
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        button: true,
        expanded: widget.open,
        child: InkWell(
          key: widget.toggleKey,
          // Said outright: left to itself the ink keeps the arrow on a
          // desktop, and the row would not look pressable.
          mouseCursor: SystemMouseCursors.click,
          hoverColor: tokens.hover,
          // The reveal and chevron already animate the press.
          splashFactory: NoSplash.splashFactory,
          // Focus is the ring below, not a fill: the theme's focus fill is
          // heavier than the hover it would sit beside.
          focusColor: Colors.transparent,
          onFocusChange: (bool value) => setState(() => _focused = value),
          onTap: widget.onToggle,
          child: DecoratedBox(
            // Drawn inside the row's own box, so focus moves nothing.
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: _focused
                  ? Border.all(color: tokens.focusRing, width: 2)
                  : widget.showDivider
                  ? Border(bottom: BorderSide(color: tokens.line))
                  : null,
              borderRadius: _focused
                  ? BorderRadius.circular(tokens.cardRadius)
                  : null,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: widget.minHeight),
              child: Padding(
                padding: widget.padding,
                child: Row(
                  children: <Widget>[
                    // The two share this row, half each at most, and what
                    // they leave goes between them. Flexed side by side in
                    // the outer row, the slack of a short title would land
                    // after the chevron and push it off the end.
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          if (summaryColumnPercent == null ||
                              summaryText == null) ...<Widget>[
                            Flexible(child: heading),
                            if (summaryText != null)
                              Flexible(child: summaryText),
                          ] else ...<Widget>[
                            Expanded(
                              flex: summaryColumnPercent,
                              child: heading,
                            ),
                            Expanded(
                              flex: 100 - summaryColumnPercent,
                              child: summaryText,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _DisclosureChevron(
                      turned: widget.turned,
                      isolatePaint: widget.isolateChevronPaint,
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

/// The chevron at the end of the header: sideways while closed, pointing
/// the way the text runs on, and turned a quarter to point down as the
/// body opens.
///
/// Right to left it starts from the other side, as the row does, and both
/// arrive at the same place.
class _DisclosureChevron extends StatelessWidget {
  const _DisclosureChevron({required this.turned, required this.isolatePaint});

  /// 0 closed, 1 open.
  final Animation<double> turned;
  final bool isolatePaint;

  @override
  Widget build(BuildContext context) {
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final Widget chevron = RotationTransition(
      turns: Tween<double>(begin: rtl ? 0.25 : -0.25, end: 0).animate(turned),
      child: ShellSymbol(
        'chev',
        size: AppTokens.disclosureChevronSize,
        color: AppTokens.of(context).faint,
      ),
    );
    // Isolate a standalone header's turning glyph from its surrounding paint.
    return isolatePaint ? RepaintBoundary(child: chevron) : chevron;
  }
}
