part of 'pillars_card.dart';

class _PillarsTable extends StatelessWidget {
  const _PillarsTable({
    required this.visible,
    required this.filtered,
    required this.hasReachedMax,
    required this.loadingMore,
    required this.canDelegate,
    required this.delegatedTo,
    required this.busy,
    required this.delegatingTo,
    required this.onLoadMore,
    required this.onDelegate,
  });

  final List<PillarInfo> visible;
  final bool filtered;
  final bool hasReachedMax;
  final bool loadingMore;
  final bool canDelegate;
  final String? delegatedTo;
  final bool busy;
  final String? delegatingTo;
  final VoidCallback onLoadMore;
  final ValueChanged<PillarInfo> onDelegate;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final Widget? more = hasReachedMax
        ? null
        : Padding(
            padding: tokens.pillarCellPadding,
            child: Align(
              child: OutlinedButton.icon(
                key: const Key('pillars_load_more'),
                onPressed: loadingMore ? null : onLoadMore,
                style: cardSecondaryButtonStyle(context),
                icon: loadingMore
                    ? SizedBox.square(
                        dimension: tokens.settingsIconSize,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.expand_more_rounded,
                        size: tokens.settingsIconSize,
                      ),
                label: Text(context.l10n.pillarsLoadMore),
              ),
            ),
          );
    if (visible.isEmpty) {
      return EmptyNote(
        key: const Key('pillars_no_matches'),
        text: filtered
            ? context.l10n.pillarsNoMatches
            : context.l10n.noItemsFound,
        // A filtered page says nothing about rows not fetched yet.
        action: more,
      );
    }
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: CustomScrollView(
        key: const PageStorageKey<String>('pillars_list'),
        slivers: <Widget>[
          PinnedHeaderSliver(
            child: ColoredBox(
              color: tokens.card,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: tokens.pillarHeadingPadding,
                    child: _PillarColumns(
                      name: _buildHeading(context, context.l10n.name),
                      weight: _buildHeading(context, context.l10n.weight),
                      shares: _buildHeading(
                        context, context.l10n.pillarsShares,
                      ),
                      uptime: _buildHeading(context, context.l10n.uptime),
                      apr: _buildHeading(
                        context, context.l10n.pillarsAprEstimate,
                      ),
                      action: const SizedBox.shrink(),
                    ),
                  ),
                  Divider(height: 1, color: tokens.line),
                ],
              ),
            ),
          ),
          SliverList.separated(
            itemCount: visible.length,
            separatorBuilder: (_, _) => Divider(height: 1, color: tokens.line),
            itemBuilder: (BuildContext context, int index) {
              final PillarInfo item = visible[index];
              return ListEntranceItem(
                key: _pillarKey(item),
                child: RowDetail(
                  id: item.name,
                  keyPrefix: 'pillar_${item.name}',
                  expandedColor: tokens.card2,
                  row: Padding(
                    padding: tokens.pillarCellPadding,
                    child: _PillarColumns(
                      name: _PillarName(item: item),
                      weight: _PillarWeight(item: item),
                      shares: Tooltip(
                        message:
                            '${context.l10n.momentumReward} / '
                            '${context.l10n.delegationReward}',
                        child: _buildData(
                          context,
                          '${item.giveMomentumRewardPercentage}% / '
                          '${item.giveDelegateRewardPercentage}%',
                        ),
                      ),
                      uptime: _buildData(
                        context,
                        pillarUptimeText(
                              produced: item.producedMomentums,
                              expected: item.expectedMomentums,
                            ) ??
                            context.l10n.pillarsUnavailable,
                      ),
                      apr: _buildData(context, context.l10n.pillarsUnavailable),
                      action: RowDetailIgnore(
                        child: _DelegateCell(
                          name: item.name,
                          delegated: delegatedTo == item.name,
                          offered: canDelegate,
                          sending: delegatingTo == item.name,
                          onPressed: busy ? null : () => onDelegate(item),
                        ),
                      ),
                    ),
                  ),
                  detail: (BuildContext context) => _PillarDetail(item: item),
                ),
              );
            },
          ),
          if (more != null) SliverToBoxAdapter(child: more),
        ],
      ),
    );
  }

  Widget _buildHeading(BuildContext context, String text) {
    return Text(
      usesLatinScript(context) ? text.toUpperCase() : text,
      style: ledgerLabelStyle(context),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}

class _PillarColumns extends StatelessWidget {
  const _PillarColumns({
    required this.name,
    required this.weight,
    required this.shares,
    required this.uptime,
    required this.apr,
    required this.action,
  });

  final Widget name;
  final Widget weight;
  final Widget shares;
  final Widget uptime;
  final Widget apr;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    return Row(
      children: <Widget>[
        // Keep the name and final action edges; move numeric roles inward.
        Expanded(flex: 26, child: name),
        SizedBox(width: tokens.pillarColumnGap),
        Expanded(flex: 16, child: _buildEnd(weight)),
        SizedBox(width: tokens.pillarColumnGap),
        Expanded(flex: 16, child: _buildEnd(shares)),
        SizedBox(width: tokens.pillarColumnGap),
        Expanded(flex: 11, child: _buildEnd(uptime)),
        SizedBox(width: tokens.pillarColumnGap),
        Expanded(flex: 14, child: _buildEnd(apr)),
        SizedBox(width: tokens.pillarColumnGap),
        Expanded(flex: 17, child: _buildEnd(action)),
      ],
    );
  }

  Widget _buildEnd(Widget child) =>
      Align(alignment: AlignmentDirectional.centerEnd, child: child);
}

class _PillarName extends StatelessWidget {
  const _PillarName({required this.item});

  final PillarInfo item;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final bool own = item.ownerAddress.toString() == kSelectedAddress;
    return Row(
      children: <Widget>[
        const RowDetailChevron(),
        SizedBox(width: tokens.cardGap),
        Flexible(
          child: Tooltip(
            message: item.name,
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.compactText,
            ),
          ),
        ),
        if (own) ...<Widget>[
          SizedBox(width: tokens.pillarOwnedChipGap),
          Tooltip(
            message: context.l10n.pillarsYours,
            child: Container(
              constraints: BoxConstraints(
                minHeight: tokens.pillarOwnedChipHeight,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: ShapeDecoration(
                color: tokens.znn.withValues(alpha: 0.14),
                shape: const StadiumBorder(),
              ),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  context.l10n.pillarsYours,
                  style: tokens.captionText.copyWith(color: tokens.znnInk),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PillarWeight extends StatelessWidget {
  const _PillarWeight({required this.item});

  final PillarInfo item;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final String exact = splitAmount(item.weight, kZnnCoin.decimals).$1;
    final String compact = compactPillarWeight(
      item.weight,
      decimals: kZnnCoin.decimals,
    );
    return ValueFlash(
      value: item.weight,
      color: tokens.znnInk,
      child: Ltr(
        child: Tooltip(
          message: '$exact ${kZnnCoin.symbol}',
          textStyle: tokens.dataText,
          child: Semantics(
            label: '$exact ${kZnnCoin.symbol}',
            excludeSemantics: true,
            child: _buildData(
              context,
              '$compact ${kZnnCoin.symbol}',
            ),
          ),
        ),
      ),
    );
  }
}

class _PillarDetail extends StatelessWidget {
  const _PillarDetail({required this.item});

  final PillarInfo item;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final EdgeInsetsDirectional gap = EdgeInsetsDirectional.only(
      end: tokens.pillarDetailColumnGap,
    );
    final bool uppercase = usesLatinScript(context);
    final TextStyle labelStyle = ledgerLabelStyle(context);
    Widget label(String text) => Padding(
      padding: gap,
      child: Text(
        uppercase ? text.toUpperCase() : text,
        style: labelStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );

    // Each label column follows its longest label and leaves room for values
    // when a locale or larger text makes that label wider.
    const TableColumnWidth labelWidth = MinColumnWidth(
      IntrinsicColumnWidth(),
      FractionColumnWidth(0.2),
    );
    return Padding(
      key: ValueKey<String>('pillar_${item.name}_detail'),
      padding: tokens.pillarDetailPadding,
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: <int, TableColumnWidth>{
          0: labelWidth,
          // Reserve the inter-group gap before dividing the value columns.
          2: FixedColumnWidth(tokens.pillarDetailColumnGap),
          3: labelWidth,
        },
        children: <TableRow>[
          TableRow(
            children: <Widget>[
              label(context.l10n.pillarOwnerProducer),
              _DetailAddress(address: item.producerAddress),
              const SizedBox.shrink(),
              label(context.l10n.pillarsMomentums),
              _buildData(
                context,
                context.l10n.pillarsMomentumsValue(
                  _groupedInteger(item.producedMomentums),
                  _groupedInteger(item.expectedMomentums),
                ),
              ),
            ],
          ),
          TableRow(
            children: List<Widget>.filled(
              5,
              SizedBox(height: tokens.fieldLabelGap),
            ),
          ),
          TableRow(
            children: <Widget>[
              label(context.l10n.pillarsReward),
              _DetailAddress(address: item.withdrawAddress),
              const SizedBox.shrink(),
              label(context.l10n.pillarsRegistered),
              // PillarInfo has no registration timestamp or block hash.
              _buildData(context, context.l10n.pillarsUnavailable),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailAddress extends StatelessWidget {
  const _DetailAddress({required this.address});

  final Address address;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    return Ltr(
      child: Row(
        children: <Widget>[
          Flexible(
            child: Tooltip(
              message: address.toString(),
              child: _buildData(context, address.toShortString()),
            ),
          ),
          IconButtonTheme(
            data: IconButtonThemeData(
              style: ButtonStyle(
                minimumSize: WidgetStatePropertyAll<Size>(
                  Size(tokens.smallButtonHeight, tokens.pillarDetailCopyHeight),
                ),
                padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
                  EdgeInsets.zero,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            child: CopyToClipboardButton(
              address.toString(),
              iconSize: tokens.inlineGlyphSize,
            ),
          ),
        ],
      ),
    );
  }
}

class _DelegateCell extends StatelessWidget {
  const _DelegateCell({
    required this.name,
    required this.delegated,
    required this.offered,
    required this.sending,
    required this.onPressed,
  });

  final String name;
  final bool delegated;
  final bool offered;
  final bool sending;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (!delegated && !offered) return const SizedBox.shrink();
    final AppTokens tokens = AppTokens.of(context);
    return OutlinedButton(
      key: ValueKey<String>('pillar_${name}_delegate'),
      onPressed: delegated ? null : onPressed,
      style: cardSecondaryButtonStyle(context).copyWith(
        visualDensity: VisualDensity.standard,
        minimumSize: WidgetStatePropertyAll<Size>(
          Size(0, tokens.pillarActionHeight),
        ),
        padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsetsDirectional.symmetric(horizontal: tokens.cardGap),
        ),
        textStyle: WidgetStatePropertyAll<TextStyle>(tokens.compactText),
      ),
      child: sending
          ? SizedBox.square(
              dimension: tokens.settingsIconSize,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              delegated
                  ? context.l10n.pillarsDelegated
                  : context.l10n.nodesDelegate,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }
}

Widget _buildData(BuildContext context, String text) => Text(
  text,
  style: AppTokens.of(context).dataText.copyWith(fontSize: 13),
  textDirection: TextDirection.ltr,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
);

String _groupedInteger(int value) => splitAmount(BigInt.from(value), 0).$1;
