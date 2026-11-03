part of 'home_hero.dart';

class _HomeHeroAddress extends StatelessWidget {
  const _HomeHeroAddress({required this.address, this.eye});

  final String address;
  final Widget? eye;

  @override
  Widget build(BuildContext context) {
    final TextStyle label = ledgerLabelStyle(context);
    final AppTokens tokens = AppTokens.of(context);
    final String name = kAddressLabelMap[address] ?? context.l10n.address;
    final String short = address.length > 12
        ? '${address.substring(0, 6)}…${address.substring(address.length - 4)}'
        : address;
    return Wrap(
      spacing: tokens.inlineGap,
      runSpacing: tokens.heroAddressRunGap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(name.toUpperCase(), style: label),
        Tooltip(
          message: address,
          child: Ltr(
            child: Text(
              short,
              style: label.copyWith(letterSpacing: 0, color: tokens.dim),
            ),
          ),
        ),
        SizedBox.square(
          dimension: tokens.heroAddressIconSize,
          child: IconButton(
            key: const Key('home_copy_address'),
            tooltip: context.l10n.homeCopyAddress,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            iconSize: tokens.heroCopyIconSize,
            onPressed: () => ClipboardUtils.copyToClipboard(address, context),
            icon: _HomeHeroSymbol(
              'copy', size: tokens.heroCopyIconSize, color: tokens.faint,
            ),
          ),
        ),
        if (kDefaultAddressList.whereType<String>().length > 1)
          SizedBox.square(
            dimension: tokens.heroAddressIconSize,
            child: PopupMenuButton<String>(
              key: const Key('home_switch_address'),
              tooltip: context.l10n.homeSwitchAddress,
              padding: EdgeInsets.zero,
              iconSize: tokens.heroAddressIconSize,
              icon: _HomeHeroSymbol(
                'chev', size: tokens.heroAddressIconSize, color: tokens.faint,
              ),
              onSelected: (String selected) =>
                  selectWalletAddress(context, selected),
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                for (final String selected
                    in kDefaultAddressList.whereType<String>())
                  PopupMenuItem<String>(
                    value: selected,
                    child: Text(
                      kAddressLabelMap[selected] ?? selected,
                      textDirection: ltrUnlessRtl(
                        kAddressLabelMap[selected] ?? selected,
                      ),
                      style: monoStyle(
                        TextStyle(
                          color: selected == address ? tokens.znnInk : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (eye case final Widget control) control,
      ],
    );
  }
}

class _HomeHeroActions extends StatelessWidget {
  const _HomeHeroActions({required this.onOpenTransfer});

  final ValueChanged<TransferMode> onOpenTransfer;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    return Wrap(
      spacing: tokens.heroActionGap,
      runSpacing: tokens.heroActionGap,
      children: <Widget>[
        PrimaryPill(
          key: const Key('home_send'),
          onPressed: () => onOpenTransfer(TransferMode.send),
          icon: _HomeHeroSymbol('up', size: tokens.heroIconSize),
          style: OutlinedButton.styleFrom(
            padding: tokens.heroActionPadding,
          ),
          child: Text(context.l10n.send),
        ),
        _HomeHeroSecondaryPill(
          key: const Key('home_receive'),
          symbol: 'down',
          label: context.l10n.receive,
          onPressed: () => onOpenTransfer(TransferMode.receive),
        ),
        SeamGate(
          seam: Seam.zapSend,
          child: _HomeHeroSecondaryPill(
            key: const Key('home_zap'),
            symbol: 'zap',
            label: context.l10n.transferZap,
            onPressed: () {
              runUnlessSeamed(
                seam: Seam.zapSend,
                action: () => onOpenTransfer(TransferMode.zap),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HomeHeroSecondaryPill extends StatelessWidget {
  const _HomeHeroSecondaryPill({
    required this.symbol,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String symbol;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: _HomeHeroSymbol(symbol, size: tokens.heroIconSize),
      label: Text(label),
      style:
          OutlinedButton.styleFrom(
            visualDensity: VisualDensity.standard,
            minimumSize: Size(0, tokens.buttonHeight),
            padding: tokens.heroActionPadding,
            foregroundColor: tokens.foreground,
            iconColor: tokens.foreground,
            backgroundColor: tokens.card2,
            side: BorderSide(color: tokens.line),
            shape: const StadiumBorder(),
            textStyle: tokens.buttonText,
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith(
              (Set<WidgetState> states) =>
                  states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused) ||
                      states.contains(WidgetState.pressed)
                  ? tokens.hover
                  : null,
            ),
          ),
    );
  }
}

// Resolve color inside the button so its foreground state owns the symbol.
class _HomeHeroSymbol extends StatelessWidget {
  const _HomeHeroSymbol(this.symbol, {required this.size, this.color});

  final String symbol;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => buildShellSymbol(
    context,
    symbol,
    color: color ?? IconTheme.of(context).color,
    size: size,
  );
}
