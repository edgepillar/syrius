part of 'transfer_page.dart';

Widget _buildTransferAddressChip(
  BuildContext context, {
  required Key key,
  required String label,
  required VoidCallback onPressed,
}) {
  final AppTokens tokens = AppTokens.of(context);
  return TextButton(
    key: key,
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: tokens.dim,
      backgroundColor: tokens.card2,
      minimumSize: Size(0, tokens.compactButtonHeight),
      padding: tokens.transferChipPadding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.transferControlRadius),
        side: BorderSide(color: tokens.line),
      ),
      textStyle: tokens.transferChipText,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        SizedBox(width: tokens.transferRecentGap),
        ShellSymbol('chev', size: tokens.activityIconSize),
      ],
    ),
  );
}

class _TransferReceiver extends StatelessWidget {
  const _TransferReceiver({required this.controller});

  final ReceiveHeaderController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (BuildContext context, Widget? child) {
      final ReceiveHeaderSnapshot? choices = controller.snapshot;
      if (choices == null) return const SizedBox.shrink();
      return MenuAnchor(
        menuChildren: <Widget>[
          for (final MapEntry<String, String> option in choices.labels.entries)
            MenuItemButton(
              onPressed: () => controller.select(choices, option.key),
              child: Text(option.value),
            ),
        ],
        builder: (_, MenuController menu, _) => _buildTransferAddressChip(
          context,
          key: const Key('transfer_receiver'),
          label: choices.labels[choices.selected]!,
          onPressed: () {
            if (!identical(controller.snapshot, choices)) return;
            if (menu.isOpen) {
              menu.close();
            } else {
              menu.open();
            }
          },
        ),
      );
    },
  );
}

class _TransferZapSender extends StatelessWidget {
  const _TransferZapSender();

  @override
  Widget build(BuildContext context) {
    context.watch<SelectedAddressNotifier?>();
    final String? address = kSelectedAddress;
    if (address == null || !kDefaultAddressList.contains(address)) {
      return const SizedBox.shrink();
    }
    final String label =
        kAddressLabelMap[address] ??
        sentPartyName(address, const <String, String>{});
    return SeamGate(
      seam: Seam.zapSend,
      child: _buildTransferAddressChip(
        context,
        key: const Key('transfer_zap_sender'),
        label: label,
        onPressed: () => throw const SeamNotBuilt(Seam.zapSend),
      ),
    );
  }
}

class _TransferSender extends StatelessWidget {
  const _TransferSender();

  @override
  Widget build(BuildContext context) {
    final SendDraftCubit? draft = context.read<SendDraftCubit?>();
    if (draft == null) return const SizedBox.shrink();
    return BlocBuilder<MultipleBalanceBloc, MultipleBalanceState>(
      builder: (_, MultipleBalanceState state) {
        final Map<String, AccountInfo>? balances = state.data;
        final List<String> addresses =
            balances?.keys.where(kDefaultAddressList.contains).toList() ??
            <String>[];
        if (state.status != MultipleBalanceStatus.success ||
            addresses.isEmpty) {
          return const SizedBox.shrink();
        }
        return BlocBuilder<SendDraftCubit, SendDraft>(
          bloc: draft,
          builder: (_, SendDraft value) {
            final String selected = addresses.contains(value.fromAddress)
                ? value.fromAddress!
                : addresses.contains(kSelectedAddress)
                ? kSelectedAddress!
                : addresses.first;
            final ValueListenable<bool> busy = context
                .read<SendTransactionBloc>()
                .busy;
            final AppTokens tokens = AppTokens.of(context);
            String label(String address) =>
                kAddressLabelMap[address] ??
                sentPartyName(address, const <String, String>{});
            return ValueListenableBuilder<bool>(
              valueListenable: busy,
              builder: (_, bool blocked, _) => PopupMenuButton<String>(
                key: const Key('transfer_sender'),
                enabled: !blocked,
                tooltip: context.l10n.send,
                initialValue: selected,
                itemBuilder: (_) => <PopupMenuEntry<String>>[
                  for (final String address in addresses)
                    PopupMenuItem<String>(
                      value: address,
                      child: Text(label(address)),
                    ),
                ],
                onSelected: (String address) {
                  if (!context.mounted || busy.value || draft.isClosed) return;
                  if (!addresses.contains(address) ||
                      !kDefaultAddressList.contains(address)) {
                    return;
                  }
                  final MultipleBalanceState latest = context
                      .read<MultipleBalanceBloc>()
                      .state;
                  if (latest.status != MultipleBalanceStatus.success ||
                      !(latest.data?.containsKey(address) ?? false)) {
                    return;
                  }
                  final SendDraft current = draft.state;
                  draft.save(
                    fromAddress: address,
                    tokenStandard:
                        current.tokenStandard ??
                        kZnnCoin.tokenStandard.toString(),
                    recipient: current.recipient,
                    amount: current.amount,
                  );
                },
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: tokens.compactButtonHeight,
                  ),
                  padding: tokens.transferChipPadding,
                  decoration: BoxDecoration(
                    color: tokens.card2,
                    borderRadius: BorderRadius.circular(
                      tokens.transferControlRadius,
                    ),
                    border: Border.all(color: tokens.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          label(selected),
                          style: tokens.transferChipText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ExcludeSemantics(
                        child: Text(' · ', style: tokens.transferChipText),
                      ),
                      Flexible(
                        child: HiddenAmount(
                          style: tokens.transferChipDataText,
                          child: Text(
                            splitAmount(
                              balances![selected]!
                                  .getBalance(kZnnCoin.tokenStandard),
                              kZnnCoin.decimals,
                            ).$1,
                            style: tokens.transferChipDataText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Text(' ZNN', style: tokens.transferChipDataText),
                      SizedBox(width: tokens.transferRecentGap),
                      ShellSymbol(
                        'chev',
                        size: tokens.activityIconSize,
                        color: tokens.faint,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
