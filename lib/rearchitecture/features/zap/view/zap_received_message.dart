part of 'zap_form.dart';

/// The received-message presentation, for the existing frosted dialog route.
///
/// This view does not admit a receipt or start a receive, reply or celebration.
/// Callers still need the missing receive service and its durable ownership
/// checks. The ordinary Activity Message control remains behind its seam.
class ZapReceivedMessage extends StatelessWidget {
  /// Draws caller-supplied facts without fetching or publishing anything.
  ZapReceivedMessage({
    required String sender,
    required BigInt znn,
    required BigInt qsr,
    required String message,
    required VoidCallback onClose,
    BalanceVisibility? visibility,
    super.key,
  }) : _sender = sender,
       _znn = znn,
       _qsr = qsr,
       _message = _plainReceivedMessage(message),
       _onClose = onClose,
       _visibility = visibility {
    if (sender.isEmpty ||
        sender.length > 128 ||
        !RegExp(r'^[\x21-\x7e]+$').hasMatch(sender) ||
        znn.isNegative ||
        qsr.isNegative) {
      throw ArgumentError('Invalid received Zap presentation.');
    }
  }

  final String _sender;
  final BigInt _znn;
  final BigInt _qsr;
  final String _message;
  final VoidCallback _onClose;
  final BalanceVisibility? _visibility;

  void _refuseReply() {
    runUnlessSeamed(
      seam: Seam.zapSend,
      action: () => throw const SeamNotBuilt(Seam.zapSend),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final BorderRadius radius = BorderRadius.circular(tokens.dialogRadius);
    return RiseIn(
      duration: const Duration(milliseconds: 240),
      child: Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.all(tokens.zapReceivedViewportInset),
        child: Container(
          key: const Key('zap_received_card'),
          width: tokens.zapReceivedWidth,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: tokens.line),
            boxShadow: <BoxShadow>[tokens.dialogShadow],
          ),
          child: FrostedSurface(
            borderRadius: radius,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: Border(top: tokens.glassTopEdge),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _buildHeader(context),
                  Flexible(
                    child: SingleChildScrollView(child: _buildBody(context)),
                  ),
                  _buildFooter(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    return Container(
      key: const Key('zap_received_header'),
      padding: tokens.zapReceivedHeaderPadding,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Row(
        children: <Widget>[
          buildShellSymbol(
            context,
            'zap',
            size: tokens.zapGlyphSize,
            color: tokens.pinkInk,
          ),
          SizedBox(width: tokens.zapReceivedTitleGap),
          Expanded(
            child: Text(context.l10n.transferZap, style: tokens.headingText),
          ),
          IconButton(
            key: const Key('zap_received_close'),
            tooltip: context.l10n.commonClose,
            onPressed: _onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 20, height: 20),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.standard,
            ),
            icon: buildShellSymbol(
              context,
              'x',
              size: tokens.zapSmallGlyphSize,
              color: tokens.faint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    return Padding(
      key: const Key('zap_received_body'),
      padding: tokens.zapReceivedBodyPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: <int, TableColumnWidth>{
              0: const IntrinsicColumnWidth(),
              1: FixedColumnWidth(tokens.zapReceivedColumnGap),
              2: const FlexColumnWidth(),
            },
            children: <TableRow>[
              TableRow(
                children: <Widget>[
                  Text(
                    context.l10n.from.toUpperCase(),
                    style: tokens.ledgerText,
                  ),
                  const SizedBox.shrink(),
                  _ReceivedZapSender(_sender),
                ],
              ),
              TableRow(
                children: List<Widget>.generate(
                  3,
                  (_) => SizedBox(height: tokens.zapReceivedFactGap),
                ),
              ),
              TableRow(
                children: <Widget>[
                  Text(
                    context.l10n.amount.toUpperCase(),
                    style: tokens.ledgerText,
                  ),
                  const SizedBox.shrink(),
                  _buildAmounts(context),
                ],
              ),
            ],
          ),
          SizedBox(height: tokens.zapReceivedSectionGap),
          Container(
            key: const Key('zap_received_message_area'),
            constraints: BoxConstraints(minHeight: tokens.zapMessageMinHeight),
            padding: tokens.zapMessagePadding,
            decoration: BoxDecoration(
              color: tokens.card2,
              border: Border.all(color: tokens.line),
              borderRadius: BorderRadius.circular(tokens.compactRadius),
            ),
            child: Text(
              _message,
              key: const Key('zap_received_message'),
              style: tokens.zapReceivedMessageText,
            ),
          ),
          SizedBox(height: tokens.zapReceivedSectionGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: buildShellSymbol(
                  context,
                  'info',
                  size: tokens.zapSmallGlyphSize,
                  color: tokens.dim,
                ),
              ),
              SizedBox(width: tokens.inlineGap),
              Expanded(
                child: Text(
                  context.l10n.zapSenderAttribution,
                  key: const Key('zap_received_attribution'),
                  style: tokens.zapReceivedAttributionText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmounts(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    return Ltr(
      child: Wrap(
        key: const Key('zap_received_amounts'),
        spacing: tokens.inlineGap,
        runSpacing: tokens.zapReceivedFactGap,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          _buildCoin(context, _znn, 'ZNN'),
          Text('+', style: tokens.zapReceivedDataText),
          _buildCoin(context, _qsr, 'QSR'),
        ],
      ),
    );
  }

  Widget _buildCoin(BuildContext context, BigInt raw, String symbol) {
    final AppTokens tokens = AppTokens.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          HiddenAmount(
            visibility: _visibility,
            style: tokens.zapReceivedDataText,
            child: AmountText(
              raw,
              decimals: ZapDraft.decimals,
              style: tokens.zapReceivedDataText,
            ),
          ),
          Text(' $symbol', style: tokens.zapReceivedDataText),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final ButtonStyle style = OutlinedButton.styleFrom(
      minimumSize: Size(0, tokens.buttonHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: tokens.buttonText,
    );
    return Padding(
      key: const Key('zap_received_footer'),
      padding: tokens.zapReceivedFooterPadding,
      child: OverflowBar(
        alignment: MainAxisAlignment.end,
        overflowAlignment: OverflowBarAlignment.end,
        spacing: tokens.inlineGap,
        overflowSpacing: tokens.inlineGap,
        children: <Widget>[
          SeamGate(
            seam: Seam.zapSend,
            child: OutlinedButton(
              key: const Key('zap_received_reply'),
              onPressed: _refuseReply,
              style: style.copyWith(
                backgroundColor: WidgetStatePropertyAll<Color>(tokens.card2),
                foregroundColor: WidgetStatePropertyAll<Color>(
                  tokens.foreground,
                ),
                side: WidgetStatePropertyAll<BorderSide>(
                  BorderSide(color: tokens.line),
                ),
              ),
              child: Text(context.l10n.zapReceivedBack),
            ),
          ),
          PrimaryPill(
            key: const Key('zap_received_nice'),
            onPressed: _onClose,
            style: style,
            child: Text(context.l10n.zapReceivedNice),
          ),
        ],
      ),
    );
  }
}

String _plainReceivedMessage(String message) {
  if (message.length > ZapDraft.messageLimit * 2 ||
      utf8.encode(message).length > ZapDraft.messageLimit) {
    throw ArgumentError('Received Zap message exceeds the byte limit.');
  }
  return message
      .replaceAll(RegExp(r'[\r\n\t\u2028\u2029]'), ' ')
      .replaceAll(
        RegExp(
          r'[\x00-\x1f\x7f-\x9f\u061c\u200b-\u200f'
          r'\u202a-\u202e\u2060-\u206f\ufeff]',
        ),
        '',
      );
}

class _ReceivedZapSender extends StatelessWidget {
  const _ReceivedZapSender(this._sender);

  final String _sender;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final TextStyle style = tokens.zapReceivedDataText.copyWith(
      color: tokens.dim,
    );
    return Tooltip(
      message: _sender,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final TextPainter painter = TextPainter(
            text: TextSpan(text: _sender, style: style),
            textDirection: TextDirection.ltr,
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final bool fits = painter.width <= constraints.maxWidth;
          painter.dispose();
          final String label = fits || _sender.length <= 16
              ? _sender
              : '${_sender.substring(0, 8)}…'
                    '${_sender.substring(_sender.length - 6)}';
          return Text(
            label,
            key: const Key('zap_received_sender'),
            semanticsLabel: _sender,
            style: style,
            textDirection: TextDirection.ltr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        },
      ),
    );
  }
}
