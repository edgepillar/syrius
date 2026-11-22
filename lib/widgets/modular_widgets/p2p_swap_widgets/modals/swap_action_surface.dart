import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/home/widgets/amount_text.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/dollar_text.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/ltr.dart';
import 'package:zenon_syrius_wallet_flutter/services/price_feed.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/zts_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/modals/swap_action_data.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/primary_pill.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/frosted_route.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/rail.dart'
    show ShellSymbol;
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// Fixtures inject finite art and never subscribe to a network price source.
typedef SwapDollarBuilder = Widget Function(BuildContext, BigInt, Token);

/// Approximate public dollar text; price facts never authorize signing.
Widget swapLiveDollars(BuildContext context, BigInt amount, Token token) =>
    DollarText(
      amount: amount,
      decimals: token.decimals,
      coin: PricedCoin.ofTokenStandard(token.tokenStandard.toString()),
      approx: true,
    );

/// The default label for a member's position in the captured wallet.
String? swapMemberLabel(
  BuildContext context,
  Iterable<String> members,
  String? address,
) {
  if (address == null) return null;
  for (final (int index, String member) in members.indexed) {
    if (member == address) return context.l10n.addressDefaultLabel(index + 1);
  }
  return null;
}

/// A transfer-shaped glass dialog. It owns no action, source or wallet.
class SwapDialogSurface extends StatelessWidget {
  /// Lays out a glass dialog around externally owned content and callbacks.
  const SwapDialogSurface({
    required this.title,
    required this.child,
    required this.onClose,
    required this.marker,
    this.primary,
    this.footer,
    this.headerAction,
    this.notice,
    super.key,
  });

  /// Localized title for the captured flow.
  final String title;

  /// Form or review content, with its own source guards.
  final Widget child;

  /// Current-generation close callback, absent while publication is pending.
  final VoidCallback? onClose;

  /// Stable screen marker used by the harness and finite widget fixtures.
  final Key marker;

  /// Optional single primary action rendered below the content.
  final Widget? primary;

  /// Compact transfer actions outside the scrollable form.
  final Widget? footer;

  /// A quiet action beside the title's close button.
  final Widget? headerAction;

  /// Fixed localized action or source notice, without raw diagnostics.
  final Widget? notice;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final BorderRadius radius = BorderRadius.circular(
      footer == null ? tokens.transferCardRadius : tokens.dialogRadius,
    );
    final Border outline = Border.all(color: tokens.line);
    final BoxShadow shadow = tokens.dialogShadow;
    final double extent =
        (5 * shadow.blurSigma + shadow.spreadRadius).ceilToDouble();
    final EdgeInsets shadowInsets = EdgeInsets.symmetric(
      horizontal: extent + shadow.offset.dx.abs(),
      vertical: extent + shadow.offset.dy.abs(),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: tokens.swapActionWidth,
        maxHeight: MediaQuery.sizeOf(context).height - tokens.pageGap * 2,
      ),
      child: SizedBox(
        width: tokens.swapActionWidth,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            FrostedSurface(
              borderRadius: radius,
              child: Material(
                type: MaterialType.transparency,
                child: DecoratedBox(
                  key: marker,
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: outline,
                  ),
                  child: Padding(
                    padding: footer == null
                        ? EdgeInsets.zero
                        : outline.dimensions,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border(top: tokens.glassTopEdge),
                          ),
                          child: Padding(
                            padding: tokens.swapActionHeaderPadding,
                            child: LayoutBuilder(
                              builder: (_, BoxConstraints constraints) => Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(title, style: tokens.headingText),
                                  ),
                                  if (headerAction != null)
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: constraints.maxWidth / 2,
                                      ),
                                      child: headerAction,
                                    ),
                                  IconButton(
                                    key: const Key('swap_action_close'),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    constraints: BoxConstraints.tightFor(
                                      width: tokens.smallButtonHeight,
                                      height: tokens.smallButtonHeight,
                                    ),
                                    iconSize: tokens.smallActionGlyphSize,
                                    tooltip: context.l10n.commonClose,
                                    onPressed: onClose,
                                    icon: ShellSymbol(
                                      'x',
                                      size: tokens.smallActionGlyphSize,
                                      color: tokens.faint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Divider(height: 1, color: tokens.line),
                        Flexible(
                          child: SingleChildScrollView(
                            key: const Key('swap_action_scroll'),
                            padding: footer == null
                                ? tokens.swapActionBodyPadding
                                : tokens.dialogBodyPadding,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                child,
                                if (notice != null) ...<Widget>[
                                  SizedBox(height: tokens.swapActionGap),
                                  notice!,
                                ],
                                if (primary != null) ...<Widget>[
                                  SizedBox(height: tokens.transferFormGap),
                                  primary!,
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (footer != null)
                          Padding(
                            padding: tokens.dialogFooterPadding,
                            child: footer,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Reserve paint bounds for the blur outside the card, and paint
            // after the glass has sampled its backdrop.
            Positioned(
              left: -shadowInsets.left,
              top: -shadowInsets.top,
              right: -shadowInsets.right,
              bottom: -shadowInsets.bottom,
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: OuterShadowPainter(
                      borderRadius: radius,
                      shadows: <BoxShadow>[shadow],
                      surfaceInsets: shadowInsets,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The single transfer-shaped action control; admission belongs to its caller.
class SwapPrimaryAction extends StatelessWidget {
  /// Displays the current next step or action with an optional busy indicator.
  const SwapPrimaryAction({
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.compact = false,
    super.key,
  });

  /// Localized missing-input or explicit-action label.
  final String label;

  /// Captured guarded callback, or null when action admission is unavailable.
  final VoidCallback? onPressed;

  /// Whether an original admitted action is still pending.
  final bool busy;

  /// The original Start and Join footer uses an ordinary action pill.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    return PrimaryPill(
      onPressed: onPressed,
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll<Size>(
          compact
              ? Size(0, tokens.buttonHeight)
              : Size(double.infinity, tokens.swapActionPrimaryHeight),
        ),
        animationDuration: tokens.swapActionStateDuration,
        textStyle: WidgetStatePropertyAll<TextStyle>(
          compact ? tokens.buttonText : tokens.swapActionPrimaryText,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (busy) ...<Widget>[
            SizedBox(
              width: tokens.swapActionTokenIconSize,
              height: tokens.swapActionTokenIconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: tokens.primaryButtonForeground,
              ),
            ),
            SizedBox(width: tokens.inlineGap),
          ],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

/// Public identifiers retain complete hover text and a stable data direction.
class SwapIdentifier extends StatelessWidget {
  /// Shows a shortened public value with its complete value on hover.
  const SwapIdentifier(this.value, {super.key});

  /// Full public address or hash; unlock material must never enter this widget.
  final String value;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: value,
    child: Text(
      value.length <= 18
          ? value
          : '${value.substring(0, 8)}…${value.substring(value.length - 6)}',
      style: AppTokens.of(context).dataText,
      textDirection: TextDirection.ltr,
      textAlign: ltrTextAlign(context),
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
    ),
  );
}

/// Route-owned menus never revive a departed lease when choosing an item.
class SwapChoice extends StatelessWidget {
  /// Rechecks admission before selecting captured public data.
  const SwapChoice({
    required this.label,
    required this.value,
    required this.choices,
    required this.onSelected,
    this.canInteract,
    super.key,
  });

  /// Localized description of the choice control.
  final String label;

  /// Exact currently selected key from [choices].
  final String value;

  /// Captured public labels keyed by exact addresses or token standards.
  final Map<String, Widget> choices;

  /// Current-generation selection callback, absent when editing is blocked.
  final ValueChanged<String>? onSelected;

  /// Final ownership check before a retained menu callback can edit the form.
  final bool Function()? canInteract;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    return MenuAnchor(
      menuChildren: <Widget>[
        for (final MapEntry<String, Widget> item in choices.entries)
          MenuItemButton(
            onPressed: onSelected == null
                ? null
                : () {
                    if (canInteract?.call() ?? true) onSelected!(item.key);
                  },
            child: item.value,
          ),
      ],
      builder: (_, MenuController menu, Widget? child) => OutlinedButton(
        key: key,
        style: OutlinedButton.styleFrom(
          animationDuration: tokens.swapActionStateDuration,
          backgroundColor: tokens.card2,
          disabledBackgroundColor: tokens.card2,
          foregroundColor: tokens.foreground,
          disabledForegroundColor: tokens.dim,
          side: BorderSide(color: tokens.faint),
          visualDensity: VisualDensity.standard,
          minimumSize: Size(0, tokens.swapActionTokenHeight),
          padding: tokens.transferChipPadding,
          shape: const StadiumBorder(),
        ),
        onPressed: onSelected == null
            ? null
            : () {
                if (!(canInteract?.call() ?? true)) return;
                menu.isOpen ? menu.close() : menu.open();
              },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child:
                  choices[value] ??
                  Text(label, overflow: TextOverflow.ellipsis),
            ),
            SizedBox(width: tokens.transferRecentGap),
            ShellSymbol(
              'chev',
              size: tokens.inlineGlyphSize,
              color: onSelected == null ? tokens.faint : tokens.foreground,
            ),
          ],
        ),
      ),
    );
  }
}

/// Exact amounts and dollar estimates share the two panes of Start and Join.
class SwapAmountPane extends StatelessWidget {
  /// Displays exact entered or proven amounts without inventing unavailable
  /// balances or using approximate dollar values as transaction authority.
  const SwapAmountPane({
    required this.label,
    required this.token,
    required this.visible,
    this.controller,
    this.amount,
    this.balance,
    this.party,
    this.choices = const <Token>[],
    this.onChanged,
    this.onToken,
    this.onMax,
    this.dollars = swapLiveDollars,
    this.hideBalances = false,
    this.canInteract,
    super.key,
  });

  /// Localized sending or receiving leg label.
  final String label;

  /// Captured token metadata for exact amount parsing and display.
  final Token token;

  /// Whether this pane's values may currently be revealed.
  final bool visible;

  /// Optional caller-owned exact decimal input; null selects computed display.
  final TextEditingController? controller;

  /// Exact computed base-unit amount when no controller is supplied.
  final BigInt? amount;

  /// Positive complete-account balance, or null when unavailable.
  final BigInt? balance;

  /// Public sender or recipient shown below the amount.
  final Widget? party;

  /// Captured token choices from a complete original account read.
  final List<Token> choices;

  /// Exact-generation amount editing callback.
  final ValueChanged<String>? onChanged;

  /// Exact-generation token-standard selection callback.
  final ValueChanged<String>? onToken;

  /// Uses the captured exact balance for the explicit Max action.
  final VoidCallback? onMax;

  /// Approximate dollar-line renderer, with finite offline injection support.
  final SwapDollarBuilder dollars;

  /// Shared privacy state for hiding amounts, balances and estimates.
  final bool hideBalances;

  /// Ownership check for retained token and amount callbacks.
  final bool Function()? canInteract;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final BigInt? current = controller == null
        ? amount
        : swapAmount(controller!.text, token.decimals);
    final Widget amountField = controller == null
        ? current == null || hideBalances
              ? Text(
                  current == null ? context.l10n.swapListUnknown : '••••',
                  style: tokens.swapActionAmountText.copyWith(
                    color: tokens.dim,
                  ),
                )
              : AmountText(
                  current,
                  decimals: token.decimals,
                  style: tokens.swapActionAmountText,
                )
        : TextField(
            key: const Key('swap_amount_input'),
            controller: controller,
            enabled: onChanged != null,
            onChanged: onChanged,
            style: tokens.swapActionAmountText,
            textDirection: TextDirection.ltr,
            textAlign: ltrTextAlign(context),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            maxLength: 1024,
            decoration: const InputDecoration(
              hintText: '0',
              counterText: '',
              isDense: true,
              isCollapsed: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          );
    final Widget? available = balance == null
        ? null
        : hideBalances
        ? const Text('••••')
        : AmountText(
            balance!,
            decimals: token.decimals,
            style: tokens.ledgerText,
            symbol: token.symbol,
          );
    final Widget figure = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        amountField,
        // A hidden pane never mounts the original price subscription.
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: tokens.swapActionDollarHeight),
          child: visible &&
                  TickerMode.valuesOf(context).enabled &&
                  current != null &&
                  current > BigInt.zero
              ? hideBalances
                  ? Text('••••', style: tokens.captionText)
                  : dollars(context, current, token)
              : const SizedBox.shrink(),
        ),
      ],
    );
    final Widget tokenChoice = choices.isEmpty
        ? _SwapTokenLabel(token)
        : SwapChoice(
            label: token.symbol,
            value: token.tokenStandard.toString(),
            choices: <String, Widget>{
              for (final Token item in choices)
                item.tokenStandard.toString(): _SwapTokenLabel(item),
            },
            onSelected: onToken,
            canInteract: canInteract,
          );
    return Container(
      padding: tokens.swapActionRowPadding,
      decoration: BoxDecoration(
        color: tokens.card2,
        border: Border.all(color: tokens.line),
        borderRadius: BorderRadius.circular(tokens.dialogRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: tokens.inlineGap,
            runSpacing: tokens.transferRecentGap,
            children: <Widget>[
              Text(label.toUpperCase(), style: tokens.ledgerText),
              if (party != null || available != null)
                DefaultTextStyle.merge(
                  style: tokens.ledgerText,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: tokens.transferRecentGap,
                    children: <Widget>[
                      ?party,
                      if (party != null && available != null)
                        const ExcludeSemantics(child: Text('·')),
                      ?available,
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: tokens.transferRecentGap),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget? max = onMax == null
                  ? null
                  : TextButton(
                      key: const Key('swap_amount_max'),
                      onPressed: onMax,
                      style: quietButtonStyle(context),
                      child: Text(context.l10n.max),
                    );
              if (constraints.maxWidth < tokens.transferTokenWidth * 2 ||
                  MediaQuery.textScalerOf(
                        context,
                      ).scale(tokens.swapActionAmountText.fontSize!) >
                      tokens.swapActionAmountText.fontSize! * 1.4) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    figure,
                    SizedBox(height: tokens.transferRecentGap),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: tokens.transferRecentGap,
                      runSpacing: tokens.transferRecentGap,
                      children: <Widget>[?max, tokenChoice],
                    ),
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  Expanded(child: figure),
                  SizedBox(width: tokens.swapActionGap),
                  if (max != null) ...<Widget>[
                    max,
                    SizedBox(width: tokens.transferRecentGap),
                  ],
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth / 2,
                    ),
                    child: tokenChoice,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SwapTokenLabel extends StatelessWidget {
  const _SwapTokenLabel(this.token);
  final Token token;
  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final bool znn = token.tokenStandard == kZnnCoin.tokenStandard;
    final bool qsr = token.tokenStandard == kQsrCoin.tokenStandard;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ExcludeSemantics(
          child: Container(
            width: tokens.swapActionTokenIconSize,
            height: tokens.swapActionTokenIconSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: znn
                  ? tokens.znn
                  : qsr
                  ? tokens.qsr
                  : tokens.faint,
              shape: BoxShape.circle,
            ),
            child: Text(
              token.symbol.isEmpty ? '?' : token.symbol.substring(0, 1),
              style: tokens.swapActionCoinText.copyWith(
                color: znn ? tokens.onZnn : tokens.swapActionCoinForeground,
              ),
            ),
          ),
        ),
        SizedBox(width: tokens.transferRecentGap),
        Flexible(
          child: Text(
            token.symbol,
            style: tokens.bodyText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Stacks the sending and receiving panes around the shared transfer mark.
class SwapTransferPanes extends StatelessWidget {
  /// Preserves the supplied panes and their externally owned input state.
  const SwapTransferPanes({
    required this.send,
    required this.receive,
    super.key,
  });

  /// Sending amount pane for the captured draft.
  final Widget send;

  /// Receiving amount pane for the same captured draft.
  final Widget receive;
  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    // The centered badge has one form gap on either side of its midpoint.
    final double gap = 2 * tokens.swapActionGap;
    final double diameter = tokens.swapActionArrowSize;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        send,
        SizedBox(height: gap),
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            receive,
            Positioned(
              top: -(gap + diameter) / 2,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    key: const Key('swap_action_direction'),
                    width: diameter,
                    height: diameter,
                    decoration: BoxDecoration(
                      color: tokens.card3,
                      shape: BoxShape.circle,
                      border: Border.all(color: tokens.line),
                    ),
                    alignment: Alignment.center,
                    child: ShellSymbol(
                      'swap',
                      size: tokens.smallActionGlyphSize,
                      color: tokens.foreground,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A receiving leg whose amount has not been positively established.
class SwapUnknownPane extends StatelessWidget {
  /// Keeps unavailable facts visibly unknown rather than rendering zero.
  const SwapUnknownPane({required this.label, super.key});

  /// Localized leg label displayed above the unknown value.
  final String label;
  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    return Container(
      width: double.infinity,
      padding: tokens.swapActionRowPadding,
      decoration: BoxDecoration(
        color: tokens.card2,
        border: Border.all(color: tokens.line),
        borderRadius: BorderRadius.circular(tokens.dialogRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label.toUpperCase(), style: tokens.ledgerText),
          SizedBox(height: tokens.transferRecentGap),
          Text(
            context.l10n.swapListUnknown,
            style: tokens.swapActionAmountText.copyWith(color: tokens.dim),
          ),
          SizedBox(height: tokens.swapActionDollarHeight),
        ],
      ),
    );
  }
}

/// The common Start/Join form is a pure projection of its captured draft.
class SwapTransferSurface extends StatelessWidget {
  /// Composes a captured Start or Join draft without owning financial effects.
  const SwapTransferSurface({
    required this.title,
    required this.marker,
    required this.send,
    required this.receive,
    required this.counterparty,
    required this.rate,
    required this.timing,
    required this.primary,
    required this.detailsSummary,
    required this.details,
    required this.onToggleDetails,
    required this.onClose,
    this.notice,
    super.key,
  });

  /// Localized flow title.
  final String title;

  /// Stable screen marker for this flow.
  final Key marker;

  /// Sending pane built from the original draft and complete account facts.
  final Widget send;

  /// Receiving pane built from entered or independently proven facts.
  final Widget receive;

  /// Captured counterparty address control or public identifier.
  final Widget counterparty;

  /// Display-only rate derived from the two exact amounts.
  final Widget rate;

  /// Localized timing fact for the original flow.
  final String timing;

  /// Single externally guarded explicit primary action.
  final Widget primary;

  /// The persistent disclosure of what this original action does.
  final String detailsSummary;

  /// Original-flow public details revealed by the header action.
  final Widget details;

  /// Checks whether the original route still owns disclosure.
  final bool Function()? onToggleDetails;

  /// Exact-generation close callback, absent while busy.
  final VoidCallback? onClose;

  /// Fixed localized notice, without raw backend diagnostics.
  final Widget? notice;

  @override
  Widget build(BuildContext context) => SwapActionDetails._inTransfer(
    summary: detailsSummary,
    onToggle: onToggleDetails,
    child: details,
    layout: (Widget help, Widget disclosure) =>
        _buildDialog(context, help, disclosure),
  );

  Widget _buildDialog(
    BuildContext context,
    Widget help,
    Widget disclosure,
  ) {
    final AppTokens tokens = AppTokens.of(context);
    return SwapDialogSurface(
      title: title,
      marker: marker,
      onClose: onClose,
      notice: notice,
      headerAction: help,
      footer: OverflowBar(
        alignment: MainAxisAlignment.end,
        overflowAlignment: OverflowBarAlignment.end,
        spacing: tokens.inlineGap,
        overflowSpacing: tokens.inlineGap,
        children: <Widget>[
          OutlinedButton(
            key: const Key('swap_action_cancel'),
            style: secondaryButtonStyle(context).copyWith(
              backgroundColor: WidgetStatePropertyAll<Color>(tokens.card2),
            ),
            onPressed: onClose,
            child: Text(context.l10n.cancel),
          ),
          primary,
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SwapTransferPanes(send: send, receive: receive),
          SizedBox(height: tokens.swapActionGap),
          Text(
            context.l10n.swapListCounterparty.toUpperCase(),
            style: tokens.ledgerText,
          ),
          SizedBox(height: tokens.transferRecentGap),
          counterparty,
          SizedBox(height: tokens.swapActionGap),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: tokens.swapActionGap,
            runSpacing: tokens.transferRecentGap,
            children: <Widget>[
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: tokens.inlineGap,
                runSpacing: tokens.transferRecentGap,
                children: <Widget>[
                  Text(
                    context.l10n.swapListRate,
                    style: tokens.transferCaptionText,
                  ),
                  rate,
                ],
              ),
              Text(timing, style: tokens.transferCaptionText),
            ],
          ),
          SizedBox(height: tokens.swapActionGap),
          SwapNotice._experimental(context.l10n.swapActionExperimental),
          SizedBox(height: tokens.transferRecentGap),
          Text(detailsSummary, style: tokens.captionText),
          disclosure,
        ],
      ),
    );
  }
}

/// Shared exact address or deposit identifier input with caller-owned guards.
class SwapTextEntry extends StatelessWidget {
  /// Displays external draft text without owning clipboard or signing effects.
  const SwapTextEntry({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.onPaste,
    this.onPickContact,
    this.fieldCaption,
    this.onSubmitted,
    this.fieldKey,
    super.key,
  });

  /// Caller-owned draft text, retained across this input's rebuilds.
  final TextEditingController controller;

  /// Localized field description.
  final String label;

  /// Guarded current-generation draft-edit callback.
  final ValueChanged<String>? onChanged;

  /// Explicit finite clipboard read owned by the captured modal.
  final VoidCallback? onPaste;

  /// Opens the original address book for a counterparty draft.
  final VoidCallback? onPickContact;

  /// A persistent label above the counterparty address field.
  final String? fieldCaption;

  /// Guarded exact input submission callback, when applicable.
  final ValueChanged<String>? onSubmitted;

  /// Stable input key for focus and finite widget fixtures.
  final Key? fieldKey;
  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final String? caption = fieldCaption;
    final OutlineInputBorder outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(
        caption == null ? tokens.transferControlRadius : tokens.cardRadius,
      ),
    );
    final Widget input = TextField(
      key: fieldKey,
      controller: controller,
      enabled: onChanged != null,
      textDirection: TextDirection.ltr,
      textAlign: ltrTextAlign(context),
      style: tokens.dataText,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      maxLength: 256,
      decoration: InputDecoration(
        hintText: label,
        counterText: '',
        contentPadding: tokens.transferFieldPadding,
        border: outline,
        enabledBorder: caption == null
            ? null
            : outline.copyWith(borderSide: BorderSide(color: tokens.faint)),
        fillColor: caption == null ? null : tokens.card2,
        filled: caption == null ? null : true,
        isDense: caption == null ? null : true,
        suffixIconConstraints: caption == null
            ? null
            : BoxConstraints(minHeight: tokens.fieldHeight),
        suffixIcon: _trailingAction(context, tokens),
      ),
    );
    if (caption == null) return input;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: tokens.transferRecentGap,
      children: <Widget>[
        ExcludeSemantics(
          child: Text(caption.toUpperCase(), style: tokens.ledgerText),
        ),
        Semantics(label: caption, child: input),
      ],
    );
  }

  Widget? _trailingAction(BuildContext context, AppTokens tokens) {
    if (fieldCaption != null) {
      return IconButton(
        key: const Key('swap_counterparty_contacts'),
        style: IconButton.styleFrom(
          minimumSize: Size(40, tokens.fieldHeight),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.standard,
        ),
        tooltip: context.l10n.sendAddressBook,
        onPressed: onPickContact,
        icon: ShellSymbol(
          'book',
          size: tokens.smallActionGlyphSize,
          color: tokens.faint,
        ),
      );
    }
    if (onPaste == null) return null;
    return IconButton(
      tooltip: context.l10n.swapActionPaste,
      onPressed: onPaste,
      icon: const Icon(Icons.content_paste),
    );
  }
}

/// A fixed localized source or action state with an accompanying status icon.
class SwapNotice extends StatelessWidget {
  /// Shows supplied interface text without exposing backend error objects.
  const SwapNotice(
    this.text, {
    this.error = false,
    this.waiting = false,
    super.key,
  }) : _warning = false;

  const SwapNotice._experimental(this.text)
    : error = false,
      waiting = false,
      _warning = true;

  final bool _warning;

  /// Short localized fact or remedy.
  final String text;

  /// Whether the state is a known refusal or unavailable source.
  final bool error;

  /// Whether publication or chain confirmation remains pending or uncertain.
  final bool waiting;
  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_warning)
          ShellSymbol(
            'warn',
            size: tokens.smallActionGlyphSize,
            color: tokens.warn,
          )
        else
          Icon(
            error
                ? Icons.error_outline
                : waiting
                ? Icons.schedule
                : Icons.info_outline,
            size: tokens.swapActionTokenIconSize,
            color: error
                ? tokens.error
                : waiting
                ? tokens.qsr
                : tokens.dim,
          ),
        SizedBox(width: tokens.inlineGap),
        Expanded(
          child: Text(
            text,
            style: tokens.transferCaptionText.copyWith(
              color: error ? tokens.error : tokens.dim,
            ),
          ),
        ),
      ],
    );
  }
}

typedef _SwapDetailsLayout = Widget Function(Widget help, Widget disclosure);

/// Details are absent from input and semantics while closed or reversing.
class SwapActionDetails extends StatefulWidget {
  /// Owns disclosure animation; onToggle guards its state changes.
  const SwapActionDetails({
    required this.summary,
    required this.child,
    this.onToggle,
    super.key,
  }) : _layout = null;

  const SwapActionDetails._inTransfer({
    required this.summary,
    required this.child,
    required this.onToggle,
    required _SwapDetailsLayout this._layout,
  });

  /// Single public fact visible while the details are collapsed.
  final String summary;

  /// Public details excluded from interaction and semantics while closed.
  final Widget child;

  /// Original-view guard that must admit every disclosure state change.
  final bool Function()? onToggle;

  final _SwapDetailsLayout? _layout;

  @override
  State<SwapActionDetails> createState() => _SwapActionDetailsState();
}

class _SwapActionDetailsState extends State<SwapActionDetails>
    with TickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  late final AnimationController _chevron = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  bool _open = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppTokens tokens = AppTokens.of(context);
    _reveal.duration = tokens.swapActionDetailsDuration;
    _chevron.duration = tokens.swapActionChevronDuration;
  }

  @override
  void dispose() {
    _reveal.dispose();
    _chevron.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!mounted || widget.onToggle?.call() != true) return;
    setState(() => _open = !_open);
    unawaited(_open ? _reveal.forward() : _reveal.reverse());
    if (widget._layout == null) {
      unawaited(_open ? _chevron.forward() : _chevron.reverse());
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final VoidCallback? toggle = widget.onToggle == null ? null : _toggle;
    final Widget disclosure = _buildDisclosure(tokens);
    final _SwapDetailsLayout? layout = widget._layout;
    if (layout != null) {
      return layout(
        Semantics(
          expanded: _open,
          child: TextButton(
            key: const Key('swap_action_details_toggle'),
            style: quietButtonStyle(context).copyWith(
              minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 30)),
              padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
                EdgeInsets.symmetric(horizontal: 6),
              ),
              textStyle: WidgetStatePropertyAll<TextStyle>(
                tokens.compactText.copyWith(fontWeight: FontWeight.w400),
              ),
            ),
            onPressed: toggle,
            child: Text(
              context.l10n.swapActionHowItWorks,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        disclosure,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OutlinedButton(
          key: const Key('swap_action_details_toggle'),
          style: quietButtonStyle(
            context,
          ).copyWith(animationDuration: tokens.swapActionStateDuration),
          onPressed: toggle,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      context.l10n.swapListDetails,
                      style: tokens.transferCaptionText,
                    ),
                    Text(
                      widget.summary,
                      style: tokens.captionText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.inlineGap),
              RotationTransition(
                turns: _chevron.drive(
                  Tween<double>(
                    begin: 0,
                    end: Directionality.of(context) == TextDirection.rtl
                        ? -.5
                        : .5,
                  ),
                ),
                child: Icon(
                  Icons.expand_more,
                  size: tokens.swapActionTokenIconSize,
                ),
              ),
            ],
          ),
        ),
        disclosure,
      ],
    );
  }

  Widget _buildDisclosure(AppTokens tokens) => AnimatedBuilder(
    animation: _reveal,
    builder: (_, Widget? child) {
      if (_reveal.isDismissed) return const SizedBox.shrink();
      final Animation<double> curve = _reveal.drive(
        CurveTween(curve: tokens.spring),
      );
      return ExcludeSemantics(
        excluding: !_open,
        child: IgnorePointer(
          ignoring: !_open,
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            descendantsAreFocusable: _open,
            descendantsAreTraversable: _open,
            child: SizeTransition(
              sizeFactor: curve,
              alignment: AlignmentDirectional.topStart,
              child: FadeTransition(
                opacity: curve,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    -tokens.swapActionDetailsRise * (1 - curve.value),
                  ),
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      top: tokens.swapActionGap,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    child: widget.child,
  );
}

/// One public review fact whose value retains its own data style.
class SwapFactRow extends StatelessWidget {
  /// Aligns a localized label with a public exact value widget.
  const SwapFactRow({required this.label, required this.value, super.key});

  /// Localized public-fact label.
  final String label;

  /// Public amount, identifier or timing value from the captured flow.
  final Widget value;
  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: tokens.transferRecentGap),
      child: Wrap(
        spacing: tokens.inlineGap,
        runSpacing: tokens.transferRecentGap,
        alignment: WrapAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: tokens.transferCaptionText),
          value,
        ],
      ),
    );
  }
}

/// A display rate derived from two entered or proven integer amounts.
class SwapRate extends StatelessWidget {
  /// Computes display text from the two supplied exact base-unit amounts.
  const SwapRate({
    required this.fromAmount,
    required this.fromToken,
    required this.toAmount,
    required this.toToken,
    super.key,
  });

  /// Exact sending amount, absent when the draft is incomplete.
  final BigInt? fromAmount;

  /// Captured sending precision and symbol.
  final Token fromToken;

  /// Exact entered or proven receiving amount, absent when unavailable.
  final BigInt? toAmount;

  /// Captured receiving precision and symbol.
  final Token toToken;
  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final BigInt? from = fromAmount;
    final BigInt? to = toAmount;
    String value = context.l10n.swapListUnknown;
    if (from != null && to != null && from > BigInt.zero && to > BigInt.zero) {
      final BigInt fixed =
          to *
          BigInt.from(10).pow(fromToken.decimals + 8) ~/
          (from * BigInt.from(10).pow(toToken.decimals));
      value =
          '1 ${fromToken.symbol} = ${swapAmountInput(fixed, 8)} '
          '${toToken.symbol}';
    }
    return Text(
      value,
      textDirection: TextDirection.ltr,
      textAlign: ltrTextAlign(context),
      style: tokens.dataText,
    );
  }
}
