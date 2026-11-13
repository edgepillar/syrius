import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/ltr.dart';
import 'package:zenon_syrius_wallet_flutter/seams/seam.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/frosted_route.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/rail.dart';

/// Display facts supplied by an owner, with no wallet or storage handle.
@immutable
class LockWalletDisplayEntry {
  /// Keeps a supplied name, optional address and hardware indicator together.
  const LockWalletDisplayEntry({
    required this.name,
    this.address,
    this.isLedger = false,
  });

  /// A display name, never a wallet path or an invented fallback.
  final String name;

  /// Already available display data; absent during a cold session.
  final String? address;

  /// Draws the hardware glyph without discovering or opening a device.
  final bool isLedger;
}

/// Supplies display-only catalog rows to a presentation fixture.
class LockWalletPickerPreview extends InheritedWidget {
  /// Retains the same lock subtree while showing the fixture menu.
  const LockWalletPickerPreview({
    required this.visible,
    required this.additionalEntries,
    required super.child,
    super.key,
  });

  /// Opens only the drawn menu. Its controls stay behind their seam.
  final bool visible;

  /// The fixture's immutable display facts.
  final List<LockWalletDisplayEntry> additionalEntries;

  @override
  bool updateShouldNotify(LockWalletPickerPreview oldWidget) =>
      visible != oldWidget.visible ||
      !identical(additionalEntries, oldWidget.additionalEntries);
}

/// The lock field and its drawn, disabled wallet menu.
///
/// Production supplies only [current] and leaves this closed. A future catalog
/// owner must establish wallet isolation before removing the seam. Supplied
/// [entries] are display facts only; this widget never discovers a catalog,
/// switches wallets or sends Add wallet through the global reset flow.
class LockWalletPicker extends StatelessWidget {
  /// Takes a fixed snapshot so a caller cannot change rows during a frame.
  LockWalletPicker({
    required this.current,
    Iterable<LockWalletDisplayEntry> entries = const <LockWalletDisplayEntry>[],
    this.expanded = false,
    super.key,
  }) : entries = List<LockWalletDisplayEntry>.unmodifiable(entries);

  /// The actual selected wallet's display data.
  final LockWalletDisplayEntry current;

  /// Externally supplied immutable facts, with no default example catalog.
  ///
  /// A current row is the identical [current] entry, rather than a name or
  /// shortened-address match that could identify a different wallet.
  final List<LockWalletDisplayEntry> entries;

  /// Draws the unavailable menu without enabling any action inside it.
  ///
  /// Pure presentation fixtures can supply synthetic entries here. This flag
  /// is not a route for production to bypass the missing catalog service.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final LockWalletPickerPreview? preview = context
        .dependOnInheritedWidgetOfExactType<LockWalletPickerPreview>();
    final bool showMenu = expanded || preview?.visible == true;
    final List<LockWalletDisplayEntry> rows = preview != null && preview.visible
        ? <LockWalletDisplayEntry>[current, ...preview.additionalEntries]
        : entries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          context.l10n.settingsSectionWallet.toUpperCase(),
          style: tokens.ledgerText,
        ),
        SizedBox(height: tokens.fieldLabelGap),
        _buildField(tokens, showMenu),
        if (showMenu) ...<Widget>[
          SizedBox(height: tokens.walletPickerFieldMenuGap),
          _buildMenu(context, tokens, rows),
        ],
      ],
    );
  }

  Widget _buildField(AppTokens tokens, bool showMenu) => Container(
    key: const ValueKey<String>('lock_wallet_display'),
    height: tokens.fieldHeight,
    padding: tokens.lockFieldPadding,
    decoration: BoxDecoration(
      color: tokens.card2,
      borderRadius: BorderRadius.circular(tokens.cardRadius),
      border: Border.all(color: tokens.faint),
    ),
    child: Row(
      children: <Widget>[
        IconTheme.merge(
          data: IconThemeData(
            size: tokens.lockGlyphSize,
            color: tokens.foreground,
          ),
          child: ShellSymbol(current.isLedger ? 'usb' : 'key'),
        ),
        SizedBox(width: tokens.inlineGap),
        Expanded(
          child: Row(
            children: <Widget>[
              Flexible(
                child: LayoutBuilder(
                  builder:
                      (BuildContext context, BoxConstraints constraints) {
                    final Widget label = Text(
                      current.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.headingText,
                    );
                    final TextPainter metrics = TextPainter(
                      text: TextSpan(
                        text: current.name,
                        style: DefaultTextStyle.of(context).style.merge(
                          tokens.headingText,
                        ),
                      ),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                      maxLines: 1,
                      ellipsis: '\u2026',
                    );
                    try {
                      metrics.layout(maxWidth: constraints.maxWidth);
                      return metrics.didExceedMaxLines
                          ? Tooltip(message: current.name, child: label)
                          : label;
                    } finally {
                      metrics.dispose();
                    }
                  },
                ),
              ),
              if (current.address case final String address) ...<Widget>[
                SizedBox(width: tokens.fieldLabelGap),
                Flexible(
                  child: _LockAddress(
                    address: address,
                    style: tokens.lockAddressText,
                  ),
                ),
              ],
            ],
          ),
        ),
        SeamGate(
          seam: Seam.walletPicker,
          child: IconButton(
            key: const ValueKey<String>('lock_wallet_picker_arrow'),
            onPressed: _refuseWalletPicker,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tightFor(
              width: tokens.lockGlyphSize,
              height: tokens.fieldHeight,
            ),
            icon: RotatedBox(
              quarterTurns: showMenu ? 2 : 0,
              child: ShellSymbol(
                'chev',
                size: tokens.lockGlyphSize,
                color: tokens.faint,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildMenu(
    BuildContext context,
    AppTokens tokens,
    List<LockWalletDisplayEntry> rows,
  ) {
    final BorderRadius radius = BorderRadius.circular(tokens.cardRadius);
    return CustomPaint(
      key: const ValueKey<String>('lock_wallet_picker_menu'),
      foregroundPainter: OuterShadowPainter(
        borderRadius: radius,
        shadows: <BoxShadow>[tokens.menuShadow],
      ),
      child: FrostedSurface(
        sigma: tokens.menuBlur,
        borderRadius: radius,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: tokens.line),
          ),
          child: Padding(
            padding: tokens.walletPickerMenuPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int index = 0; index < rows.length; index++)
                  _buildEntry(tokens, rows[index], index),
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: tokens.walletPickerMenuGap,
                  ),
                  child: Divider(
                    key: const ValueKey<String>('lock_wallet_picker_separator'),
                    height: tokens.glassTopEdge.width,
                    thickness: tokens.glassTopEdge.width,
                    color: tokens.line,
                  ),
                ),
                _buildMenuRow(
                  tokens: tokens,
                  key: const ValueKey<String>('lock_wallet_picker_add'),
                  icon: 'plus',
                  name: context.l10n.lockAddWallet,
                  height: tokens.walletPickerAddRowHeight,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntry(
    AppTokens tokens,
    LockWalletDisplayEntry entry,
    int index,
  ) => _buildMenuRow(
    tokens: tokens,
    key: ValueKey<String>('lock_wallet_picker_entry_$index'),
    icon: entry.isLedger ? 'usb' : 'key',
    name: entry.name,
    height: tokens.walletPickerRowHeight,
    address: entry.address,
    selected: identical(entry, current),
  );

  Widget _buildMenuRow({
    required AppTokens tokens,
    required Key key,
    required String icon,
    required String name,
    required double height,
    String? address,
    bool selected = false,
  }) => SeamGate(
    seam: Seam.walletPicker,
    child: TextButton(
      key: key,
      onPressed: _refuseWalletPicker,
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll<Color>(
          selected ? tokens.foreground : tokens.dim,
        ),
        backgroundColor: WidgetStatePropertyAll<Color>(
          selected ? tokens.card3 : tokens.card3.withValues(alpha: 0),
        ),
        textStyle: WidgetStatePropertyAll<TextStyle>(
          tokens.walletPickerNameText,
        ),
        padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
          tokens.walletPickerRowPadding,
        ),
        minimumSize: WidgetStatePropertyAll<Size>(
          Size(0, height),
        ),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.compactRadius),
          ),
        ),
        alignment: AlignmentDirectional.centerStart,
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        children: <Widget>[
          IconTheme.merge(
            data: IconThemeData(
              size: tokens.lockGlyphSize,
              color: selected ? tokens.foreground : tokens.dim,
            ),
            child: ShellSymbol(icon),
          ),
          SizedBox(width: tokens.inlineGap),
          Expanded(
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (address != null) ...<Widget>[
            SizedBox(width: tokens.inlineGap),
            Flexible(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: _LockAddress(
                  address: address,
                  style: tokens.walletPickerAddressText,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

void _refuseWalletPicker() => throw const SeamNotBuilt(Seam.walletPicker);

class _LockAddress extends StatelessWidget {
  const _LockAddress({required this.address, required this.style});

  final String address;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Ltr(
    child: Tooltip(
      message: address,
      child: Text(
        address.length > 10
            ? '${address.substring(0, 6)}…'
                  '${address.substring(address.length - 4)}'
            : address,
        semanticsLabel: address,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    ),
  );
}
