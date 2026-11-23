import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/create_token_stepper/model/token_create_preflight.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/home/widgets/amount_text.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/zts_utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The four real stages and the captured fee facts beside the live draft.
class TokenCreateRail extends StatelessWidget {
  /// No standard is invented for a token that has not been issued.
  const TokenCreateRail({
    required this.step,
    required this.preflight,
    required this.name,
    required this.symbol,
    required this.onRetry,
    this.busy = false,
    super.key,
  });

  /// One of exactly four visible step marks.
  final int step;

  /// Fresh original account facts, with explicit unknown states.
  final TokenCreatePreflight preflight;

  /// Text still being edited in the retained name field.
  final String name;

  /// Text still being edited in the retained symbol field.
  final String symbol;

  /// Reads again only after an explicit user action.
  final VoidCallback onRetry;

  /// A pending action closes the retry control.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final List<String> labels = <String>[
      context.l10n.tokenCreateNameAndSymbol,
      context.l10n.tokensSupply,
      context.l10n.tokenCreateOptions,
      context.l10n.tokenCreateIssue,
    ];
    final BigInt? balance = preflight.znn;
    final bool current = preflight.isCurrent;
    final String previewName = name.trimLeft();
    final bool needsAttention = !preflight.sufficient;
    final String status = !current
        ? context.l10n.publicationSessionChanged
        : preflight.failed
        ? context.l10n.commonSomethingWentWrong
        : preflight.plasma == null || balance == null
        ? context.l10n.homeAmountUnknown
        : preflight.plasma! < kIssueTokenPlasmaAmountNeeded
        ? context.l10n.sendNotEnough(context.l10n.plasma)
        : context.l10n.sendNotEnough(kZnnCoin.symbol);
    return Container(
      key: const Key('token_create_rail'),
      width: tokens.registrationRailWidth,
      decoration: BoxDecoration(
        border: BorderDirectional(end: BorderSide(color: tokens.line)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.registrationInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: tokens.tokenCreateRailGap,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: tokens.tokenCreateStepInset,
              ),
              child: Column(
                spacing: tokens.registrationActionGap,
                children: <Widget>[
                  for (int i = 0; i < labels.length; i++)
                    _buildStep(tokens, i, labels[i]),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: tokens.line),
            _buildFacts(context, tokens, balance),
            Container(
              padding: EdgeInsets.all(tokens.pageGap),
              decoration: BoxDecoration(
                color: tokens.card2,
                borderRadius: BorderRadius.circular(tokens.cardRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: tokens.inlineGap,
                children: <Widget>[
                  Text(
                    context.l10n.tokenCreatePreview.toUpperCase(),
                    semanticsLabel: context.l10n.tokenCreatePreview,
                    style: tokens.ledgerText,
                  ),
                  Row(
                    children: <Widget>[
                      ExcludeSemantics(
                        child: Container(
                          key: const Key('token_create_preview_badge'),
                          width: tokens.homeTokenBadgeSize,
                          height: tokens.homeTokenBadgeSize,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: tokens.pink,
                          ),
                          child: previewName.isEmpty
                              ? Icon(
                                  Icons.token_outlined,
                                  color: tokens.onZnn,
                                  size: 14,
                                )
                              : Text(
                                  String.fromCharCode(previewName.runes.first)
                                      .toUpperCase(),
                                  style: tokens.homeTokenBadgeText.copyWith(
                                    color: tokens.onZnn,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(width: tokens.inlineGap),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tokens.bodyText,
                            ),
                            Text(
                              symbol,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.ltr,
                              style: tokens.dataText.copyWith(
                                fontSize: 12,
                                color: tokens.dim,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (needsAttention)
              Column(
                spacing: tokens.registrationGap,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        preflight.loading
                            ? Icons.hourglass_empty
                            : Icons.info_outline,
                        size: tokens.tokenCreateStepMarkSize,
                        color: tokens.dim,
                      ),
                      SizedBox(width: tokens.inlineGap),
                      Expanded(
                        child: Text(
                          status,
                          style: tokens.registrationCaptionText,
                        ),
                      ),
                    ],
                  ),
                  if (current)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        key: const Key('token_create_retry'),
                        onPressed: busy || preflight.loading ? null : onRetry,
                        child: Text(
                          preflight.failed
                              ? context.l10n.commonRetry
                              : context.l10n.commonRefresh,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacts(BuildContext context, AppTokens tokens, BigInt? balance) {
    final TextStyle valueStyle = tokens.dataText.copyWith(fontSize: 13);
    final List<(String, Widget)> facts = <(String, Widget)>[
      (
        context.l10n.tokenCreateFee,
        Wrap(
          spacing: tokens.inlineGap,
          children: <Widget>[
            AmountText(
              tokenZtsIssueFeeInZnn,
              decimals: coinDecimals,
              symbol: kZnnCoin.symbol,
              style: valueStyle,
            ),
            Text(
              context.l10n.tokenCreateBurned,
              style: valueStyle.copyWith(color: tokens.dim),
            ),
          ],
        ),
      ),
      (
        context.l10n.tokenCreateHave,
        balance == null
            ? Text('-', style: valueStyle)
            : AmountText(
                balance,
                decimals: coinDecimals,
                symbol: kZnnCoin.symbol,
                style: valueStyle,
              ),
      ),
    ];
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const <int, TableColumnWidth>{
        0: MinColumnWidth(IntrinsicColumnWidth(), FractionColumnWidth(.46)),
        1: FlexColumnWidth(),
      },
      children: <TableRow>[
        for (final (int index, (String label, Widget value)) in facts.indexed)
          TableRow(
            children: <Widget>[
              Padding(
                padding: EdgeInsetsDirectional.only(
                  end: tokens.tokenCreateFactColumnGap,
                  top: index == 0 ? 0 : tokens.tokenCreateFactRowGap,
                ),
                child: Text(
                  label.toUpperCase(),
                  semanticsLabel: label,
                  style: tokens.ledgerText,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  top: index == 0 ? 0 : tokens.tokenCreateFactRowGap,
                ),
                child: value,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStep(AppTokens tokens, int index, String label) {
    final bool active = index == step;
    final bool complete = index < step;
    return Row(
      key: ValueKey<String>('token_create_step_$index'),
      children: <Widget>[
        Container(
          width: tokens.tokenCreateStepMarkSize,
          height: tokens.tokenCreateStepMarkSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: complete ? tokens.znn : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: active || complete ? tokens.znn : tokens.line,
              width: 1.5,
            ),
          ),
          child: Text(
            '${index + 1}',
            style: tokens.dataText.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: complete
                  ? tokens.onZnn
                  : active
                  ? tokens.znnInk
                  : tokens.faint,
            ),
          ),
        ),
        SizedBox(width: tokens.inlineGap),
        Expanded(
          child: Text(
            label,
            style: tokens.compactText.copyWith(
              color: active ? tokens.foreground : tokens.faint,
            ),
          ),
        ),
      ],
    );
  }
}
