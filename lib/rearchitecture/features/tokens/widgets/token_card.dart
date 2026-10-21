import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/burn_token/view/burn_token_view.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/home/widgets/amount_text.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/mint_token/view/mint_token_view.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/token_favorite/view/token_favorite.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/tokens/widgets/token_row_action.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/transfer_token/view/transfer_token_view.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/motion/motion.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/clipboard_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/navigation_utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The height of a token row.
const double kTokenRowHeight = 60;

/// The width of the supply column of the token list.
const double kTokenSupplyColumnWidth = 120;

/// The width of the owner column of the token list.
const double kTokenOwnerColumnWidth = 110;

/// The width kept for a row's actions: five at most.
const double kTokenActionsColumnWidth = 5 * kTokenRowActionSize;

/// The gap between two columns of the token list.
const double kTokenColumnGap = 12;

/// Below this width a row drops its owner column.
const double kTokenOwnerColumnMinRowWidth = 640;

/// The padding at both ends of a token row, and of the list's header.
const EdgeInsets kTokenRowPadding = EdgeInsets.symmetric(horizontal: 16);

const String _kCopyStandard = 'Copy token standard';
const String _kCopyOwner = 'Copy owner address';
const String _kMaxSupply = 'Max supply';
const String _kDecimals = 'Decimals';
const String _kMintable = 'Mintable';
const String _kBurnable = 'Burnable by any holder';

/// One token of the list: what it is, how much of it exists, who owns it,
/// and what the selected address may do with it.
///
/// It was a flipping card with a pie chart. As a row, twelve tokens fit
/// where two cards did, and mint, burn and transfer open a dialog instead
/// of turning the card over.
class TokenCard extends StatelessWidget {
  /// Creates a [TokenCard].
  const TokenCard({
    required this._token,
    required this._favoritesCallback,
    super.key,
  });

  final Token _token;
  final VoidCallback _favoritesCallback;

  @override
  Widget build(BuildContext context) {
    return _RowSurface(
      onActivate: () => ClipboardUtils.copyToClipboard(
        _token.tokenStandard.toString(),
        context,
      ),
      child: Padding(
        padding: kTokenRowPadding,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide =
                constraints.maxWidth >= kTokenOwnerColumnMinRowWidth;
            return Row(
              children: <Widget>[
                // Without its column the owner moves under the name, so
                // its address can still be copied in a narrow window.
                Expanded(
                  child: _Identity(token: _token, showOwner: !wide),
                ),
                const SizedBox(width: kTokenColumnGap),
                SizedBox(
                  width: kTokenSupplyColumnWidth,
                  child: _Supply(token: _token),
                ),
                if (wide)
                  Padding(
                    padding: const EdgeInsets.only(left: kTokenColumnGap),
                    child: SizedBox(
                      width: kTokenOwnerColumnWidth,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _Owner(owner: _token.owner),
                      ),
                    ),
                  ),
                SizedBox(
                  width: kTokenActionsColumnWidth,
                  child: _Actions(
                    token: _token,
                    favoritesCallback: _favoritesCallback,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A token's colour as text or as a line: the rule is `cardTokenInk`.
Color _tokenInk(BuildContext context, TokenStandard tokenStandard) =>
    cardTokenInk(tokenStandard, context);

/// The row as a surface: tinted under the pointer, so its actions read as
/// belonging to it, and a stop for Tab, ringed while it has the keyboard.
///
/// A row has no action of its own to click, so the pointer keeps its arrow.
/// From the keyboard Enter or Space runs [onActivate]; Tab then goes on
/// through the row's actions.
class _RowSurface extends StatefulWidget {
  const _RowSurface({required this.onActivate, required this.child});

  final VoidCallback onActivate;
  final Widget child;

  @override
  State<_RowSurface> createState() => _RowSurfaceState();
}

class _RowSurfaceState extends State<_RowSurface> {
  bool _hovered = false;
  bool _focused = false;

  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (_) {
        widget.onActivate();
        return null;
      },
    ),
  };

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final Color tint = tokens.hover;
    final bool lit = _hovered || _focused;
    return FocusableActionDetector(
      actions: _actions,
      onShowHoverHighlight: (bool value) => setState(() => _hovered = value),
      onShowFocusHighlight: (bool value) => setState(() => _focused = value),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(
            color: _focused
                ? tokens.focusRing
                : tokens.focusRing.withValues(alpha: 0),
            width: 1.5,
          ),
        ),
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: lit ? tint : tint.withValues(alpha: 0)),
          duration: Durations.short3,
          curve: Easing.standard,
          // A Material rather than a coloured box, so the ink of the row's
          // buttons is painted over the tint and not under it.
          builder: (_, Color? color, Widget? child) =>
              Material(color: color, child: child),
          child: widget.child,
        ),
      ),
    );
  }
}

/// The symbol and name over the token standard.
class _Identity extends StatelessWidget {
  const _Identity({required this.token, required this.showOwner});

  final Token token;

  /// Whether the owner goes on the second line, after the token standard.
  final bool showOwner;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final String standard = token.tokenStandard.toString();
    final bool isOwn = kDefaultAddressList.contains(token.owner.toString());
    final Widget standardText = _CopyText(
      text: standard,
      shown: standard,
      tooltip: _kCopyStandard,
      // The row is the keyboard's way to this copy.
      canRequestFocus: false,
      style: monoStyle(
        cardDimStyle(context).copyWith(fontSize: 12, color: tokens.faint),
      ),
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                token.symbol.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: cardValueStyle(context).copyWith(
                  fontWeight: FontWeight.w600,
                  color: _tokenInk(context, token.tokenStandard),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                token.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: cardDimStyle(context),
              ),
            ),
            if (isOwn)
              _Badge(
                icon: Icons.person_outline,
                color: tokens.znnInk,
                message: context.l10n.ownZtsToken,
              ),
            if (token.isUtility)
              _Badge(
                icon: Icons.settings_outlined,
                color: tokens.faint,
                message: context.l10n.utilityToken,
              ),
          ],
        ),
        const SizedBox(height: 2),
        if (showOwner)
          Row(
            children: <Widget>[
              Flexible(flex: 2, child: standardText),
              const SizedBox(width: kTokenColumnGap),
              Flexible(child: _Owner(owner: token.owner, fontSize: 12)),
            ],
          )
        else
          standardText,
      ],
    );
  }
}

/// A small mark after a token's name, explained by its tooltip.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: message,
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

/// Text that copies [text] when pressed: an identifier too long to retype.
class _CopyText extends StatelessWidget {
  const _CopyText({
    required this.text,
    required this.shown,
    required this.tooltip,
    required this.style,
    this.canRequestFocus = true,
  });

  final String text;
  final String shown;
  final String tooltip;
  final TextStyle style;

  /// False where something else already takes Tab to the same copy.
  final bool canRequestFocus;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        canRequestFocus: canRequestFocus,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(4),
        onTap: () => ClipboardUtils.copyToClipboard(text, context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  shown,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.content_copy,
                size: 12,
                color: AppTokens.of(context).faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How much of the token exists, over a line showing its share of the most
/// there can be.
class _Supply extends StatelessWidget {
  const _Supply({required this.token});

  final Token token;

  @override
  Widget build(BuildContext context) {
    final Color ink = _tokenInk(context, token.tokenStandard);
    final double share = token.maxSupply > BigInt.zero
        ? (token.totalSupply / token.maxSupply).clamp(0, 1).toDouble()
        : 0;
    final String max = cardAmount(
      token.maxSupply,
      token.decimals,
      token.symbol,
    );
    return Tooltip(
      message: <String>[
        '$_kMaxSupply $max',
        '$_kDecimals ${token.decimals}',
        if (token.isMintable) _kMintable,
        if (token.isBurnable) _kBurnable,
      ].join('\n'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // A mint or a burn changes the supply in place; the flash is the
          // sign that it did.
          ValueFlash(
            value: token.totalSupply,
            color: ink,
            child: AmountText(
              token.totalSupply,
              decimals: token.decimals,
              style: cardValueStyle(context).copyWith(fontSize: 13),
            ),
          ),
          const SizedBox(height: 7),
          LinearProgressIndicator(
            value: share,
            minHeight: 3,
            color: ink,
            backgroundColor: cardLineColor(context),
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }
}

/// The owner: the address's label when it is one of this wallet's.
class _Owner extends StatelessWidget {
  const _Owner({required this.owner, this.fontSize = 13});

  final Address owner;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final String address = owner.toString();
    final String? label = kAddressLabelMap[address];
    final TextStyle style = cardDimStyle(context).copyWith(fontSize: fontSize);
    return _CopyText(
      text: address,
      shown: label ?? owner.toShortString(),
      tooltip: _kCopyOwner,
      style: label == null ? monoStyle(style) : style,
    );
  }
}

/// What the selected address may do with the token, quiet until pointed at.
class _Actions extends StatelessWidget {
  const _Actions({required this.token, required this.favoritesCallback});

  final Token token;
  final VoidCallback favoritesCallback;

  @override
  Widget build(BuildContext context) {
    final bool isOwner = kSelectedAddress == token.owner.toString();
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        TokenFavorite(token: token, callback: favoritesCallback),
        if (isOwner && token.isMintable && token.totalSupply < token.maxSupply)
          TokenRowAction(
            key: const Key('token_mint_button'),
            tooltip: context.l10n.mint,
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () =>
                unawaited(MintTokenView.show(context, token: token)),
          ),
        if (token.isBurnable || isOwner)
          TokenRowAction(
            key: const Key('token_burn_button'),
            tooltip: context.l10n.burn,
            icon: const Icon(Icons.local_fire_department_outlined),
            onPressed: () =>
                unawaited(BurnTokenView.show(context, token: token)),
          ),
        if (isOwner)
          TokenRowAction(
            key: const Key('token_transfer_button'),
            tooltip: context.l10n.transferTokenOwnership,
            icon: const Icon(Icons.swap_horiz),
            onPressed: () =>
                unawaited(TransferTokenView.show(context, token: token)),
          ),
        TokenRowAction(
          tooltip: context.l10n.visitDomain(token.domain),
          icon: const Icon(Icons.open_in_new),
          onPressed: () => unawaited(NavigationUtils.openUrl(token.domain)),
        ),
      ],
    );
  }
}

/// The ledger labels over the columns of the token list. Laid out as a
/// [TokenCard] is, so each label sits over its column.
class TokenListHeader extends StatelessWidget {
  /// Creates the header.
  const TokenListHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final TextStyle style = ledgerLabelStyle(context);
    return Padding(
      padding: kTokenRowPadding,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => Row(
          children: <Widget>[
            Expanded(child: Text('TOKEN', style: style)),
            const SizedBox(width: kTokenColumnGap),
            SizedBox(
              width: kTokenSupplyColumnWidth,
              child: Text('SUPPLY', style: style),
            ),
            if (constraints.maxWidth >= kTokenOwnerColumnMinRowWidth)
              Padding(
                padding: const EdgeInsets.only(left: kTokenColumnGap),
                child: SizedBox(
                  width: kTokenOwnerColumnWidth,
                  child: Text('OWNER', style: style),
                ),
              ),
            const SizedBox(width: kTokenActionsColumnWidth),
          ],
        ),
      ),
    );
  }
}
