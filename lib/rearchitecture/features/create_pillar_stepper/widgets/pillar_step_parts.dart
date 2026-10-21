import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/ltr.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

// What the create-pillar and the update-pillar steppers share: the review
// shown above the action that sends.

/// The width of the labels of the review, so the values start on one edge.
/// The longest, "Pillar producer address", fits in capitals.
const double _kReviewLabelWidth = 176;

/// What a Pillar is about to be registered or updated with: its name, both
/// addresses and both percentages, then whatever [costs] the send has.
///
/// A name is kept for good and an address typed wrong produces no momentums,
/// so each is read once more beside the action that sends it.
class PillarReview extends StatelessWidget {
  /// Creates the review.
  const PillarReview({
    required this.name,
    required this.rewardAddress,
    required this.producerAddress,
    required this.momentumPercentage,
    required this.delegatePercentage,
    this.costs = const <Widget>[],
    super.key,
  });

  /// The Pillar's name.
  final String name;

  /// The address that collects the rewards.
  final String rewardAddress;

  /// The address that produces momentums.
  final String producerAddress;

  /// The percentage of momentum rewards given to delegators.
  final int momentumPercentage;

  /// The percentage of delegation rewards given to delegators.
  final int delegatePercentage;

  /// Further lines, [PillarReviewRow]s: what the send locks or burns.
  final List<Widget> costs;

  @override
  Widget build(BuildContext context) {
    final TextStyle text = accFieldTextStyle(context);
    final TextStyle mono = accFieldTextStyle(context, mono: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PillarReviewRow(
          label: context.l10n.pillarName,
          value: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text,
          ),
        ),
        PillarReviewRow(
          label: context.l10n.pillarRewardAddress,
          value: _ReviewFigure(rewardAddress, style: mono, whole: true),
        ),
        PillarReviewRow(
          label: context.l10n.pillarProducerAddress,
          value: _ReviewFigure(producerAddress, style: mono, whole: true),
        ),
        PillarReviewRow(
          label: context.l10n.createPillarMomentumShareLabel,
          value: _ReviewFigure('$momentumPercentage%', style: mono),
        ),
        PillarReviewRow(
          label: context.l10n.createPillarDelegationShareLabel,
          value: _ReviewFigure('$delegatePercentage%', style: mono),
        ),
        ...costs,
      ],
    );
  }
}

/// One line of the review: a ledger label, then its value.
class PillarReviewRow extends StatelessWidget {
  /// Creates a line.
  const PillarReviewRow({required this.label, required this.value, super.key});

  /// A line whose value is [amount] of [token], in the coin's ink and
  /// without trailing zeros.
  factory PillarReviewRow.amount({
    required BuildContext context,
    required String label,
    required BigInt amount,
    required Token token,
  }) => PillarReviewRow(
    label: label,
    value: AmountText(
      amount,
      decimals: token.decimals,
      style: accFieldTextStyle(context),
      symbol: token.symbol,
      symbolColor: cardTokenInk(token.tokenStandard, context),
    ),
  );

  /// What the value is, in sentence case; shown in capitals.
  final String label;

  /// The value.
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        // On the first line of a value that takes two.
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          SizedBox(
            width: _kReviewLabelWidth,
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ledgerLabelStyle(context),
            ),
          ),
          SizedBox(width: AppTokens.of(context).cardGap),
          Expanded(child: value),
        ],
      ),
    );
  }
}

/// A value of the review that is an address or a percentage: drawn left to
/// right in every language, at the app's start.
class _ReviewFigure extends StatelessWidget {
  const _ReviewFigure(this.text, {required this.style, this.whole = false});

  final String text;
  final TextStyle style;

  /// Whether every character must be read: an address. It then takes a
  /// second line before it is cut, and shows whole on hover.
  final bool whole;

  @override
  Widget build(BuildContext context) {
    final Widget figure = Text(
      text,
      maxLines: whole ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      textDirection: TextDirection.ltr,
      textAlign: ltrTextAlign(context),
      style: style,
    );
    return whole && text.isNotEmpty
        ? Tooltip(message: text, child: figure)
        : figure;
  }
}
