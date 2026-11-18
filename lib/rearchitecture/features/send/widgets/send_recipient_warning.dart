part of 'send_populated.dart';

class _SendRecipientWarning extends StatelessWidget {
  const _SendRecipientWarning({
    required this.finding,
    required this.typed,
    required this.name,
    required this.acknowledged,
    required this.onUseKnown,
    required this.onUseTyped,
  });

  final LookAlike finding;
  final String typed;
  final String name;
  final bool acknowledged;
  final VoidCallback? onUseKnown;
  final VoidCallback? onUseTyped;

  Widget _buildAddress(BuildContext context, String address, String key) {
    final AppTokens tokens = AppTokens.of(context);
    return Tooltip(
      message: address,
      child: SelectableText.rich(
        TextSpan(
          style: tokens.dataText.copyWith(
            fontSize: tokens.transferAddressComparisonTextSize,
            color: tokens.dim,
          ),
          children: <InlineSpan>[
            for (int index = 0; index < address.length; index++)
              TextSpan(
                text: address[index],
                style: finding.differing.contains(index)
                    ? TextStyle(
                        color: key == 'send_typed_address'
                            ? tokens.warn
                            : tokens.foreground,
                      )
                    : null,
              ),
          ],
        ),
        key: Key(key),
        textDirection: TextDirection.ltr,
        textAlign: ltrTextAlign(context),
      ),
    );
  }

  TableRow _buildComparisonRow(
    BuildContext context, {
    required String label,
    required String address,
    required String addressKey,
    required double maxLabelWidth,
    double bottomGap = 0,
  }) {
    final AppTokens tokens = AppTokens.of(context);
    return TableRow(
      children: <Widget>[
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxLabelWidth),
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              end: tokens.transferAddressComparisonGap,
              bottom: bottomGap,
            ),
            child: Text(
              label,
              style: tokens.transferCaptionText.copyWith(
                fontSize: tokens.transferAddressComparisonTextSize,
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: bottomGap),
          child: _buildAddress(context, address, addressKey),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final ButtonStyle compact = ButtonStyle(
      minimumSize: WidgetStatePropertyAll<Size>(
        Size(0, tokens.compactButtonHeight),
      ),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
        tokens.compactButtonPadding,
      ),
      textStyle: WidgetStatePropertyAll<TextStyle>(
        tokens.compactText.copyWith(fontWeight: FontWeight.w500),
      ),
    );
    return Container(
      key: const Key('send_recipient_warning'),
      padding: tokens.transferWarningPadding,
      decoration: BoxDecoration(
        color: tokens.transferWarningTint,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              buildShellSymbol(
                context,
                'warn',
                size: tokens.smallActionGlyphSize,
                color: tokens.warn,
              ),
              SizedBox(width: tokens.inlineGap),
              Expanded(
                child: Text(
                  context.l10n.sendLooksLike(name),
                  style: tokens.headingText,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.inlineGap),
          Text(
            context.l10n.sendLookAlikeDetail,
            style: tokens.transferCaptionText,
          ),
          SizedBox(height: tokens.inlineGap),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double maxLabelWidth = constraints.maxWidth / 3;
              return Table(
                columnWidths: const <int, TableColumnWidth>{
                  0: IntrinsicColumnWidth(),
                },
                children: <TableRow>[
                  _buildComparisonRow(
                    context,
                    label: context.l10n.sendKnownAddress,
                    address: finding.address,
                    addressKey: 'send_known_address',
                    maxLabelWidth: maxLabelWidth,
                    bottomGap: tokens.fieldLabelGap,
                  ),
                  _buildComparisonRow(
                    context,
                    label: context.l10n.sendTypedAddress,
                    address: typed,
                    addressKey: 'send_typed_address',
                    maxLabelWidth: maxLabelWidth,
                  ),
                ],
              );
            },
          ),
          SizedBox(height: tokens.inlineGap),
          Wrap(
            spacing: tokens.inlineGap,
            runSpacing: tokens.fieldLabelGap,
            children: <Widget>[
              OutlinedButton(
                key: const Key('send_use_known'),
                onPressed: onUseKnown,
                style: secondaryButtonStyle(context).merge(compact),
                child: Text(context.l10n.sendUseKnown(name)),
              ),
              TextButton(
                key: const Key('send_use_typed'),
                onPressed: onUseTyped,
                style: quietButtonStyle(context).merge(compact),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (acknowledged) ...<Widget>[
                      Icon(Icons.check, size: tokens.heroCopyIconSize),
                      SizedBox(width: tokens.fieldLabelGap),
                    ],
                    Flexible(child: Text(context.l10n.sendUseTypedAnyway)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
