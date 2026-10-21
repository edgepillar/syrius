import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The ledger line under a project or phase name: owner, id, age and, while
/// a project is voted on, when voting closes.
///
/// One line that fades rather than wraps, so every row of a list keeps the
/// same height. Labels are faint, values mono.
class AcceleratorProjectDetails extends StatelessWidget {
  /// Creates the line from whichever parts are known.
  const AcceleratorProjectDetails({
    this.owner,
    this.hash,
    this.creationTimestamp,
    this.acceleratorProjectStatus,
    this.isPhase = false,
    super.key,
  });

  /// The project's owner.
  final Address? owner;

  /// The project's or phase's id.
  final Hash? hash;

  /// When it was created, in Unix seconds.
  final int? creationTimestamp;

  /// Its status; a project in voting also shows when voting closes.
  final AcceleratorProjectStatus? acceleratorProjectStatus;

  /// Phases have no voting deadline of their own.
  final bool isPhase;

  @override
  Widget build(BuildContext context) {
    final TextStyle value = monoStyle(
      Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 12),
    );
    final TextStyle label = value.copyWith(
      fontFamily: kSansFontFamily,
      color: AppColors.faint,
    );
    final List<(String, String)> parts = <(String, String)>[
      if (owner != null) ('Owner ', _getOwnerDetails()),
      if (hash != null) ('ID ', hash!.toShortString()),
      if (creationTimestamp != null) ...<(String, String)>[
        ('Created ', _formatData(creationTimestamp! * 1000)),
        if (!isPhase &&
            acceleratorProjectStatus == AcceleratorProjectStatus.voting)
          _getTimeUntilVotingCloses(context.l10n),
      ],
    ];
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          for (int i = 0; i < parts.length; i++) ...<InlineSpan>[
            if (i > 0) TextSpan(text: '  ·  ', style: label),
            TextSpan(text: parts[i].$1, style: label),
            TextSpan(text: parts[i].$2, style: value),
          ],
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
    );
  }

  String _formatData(int transactionMillis) {
    final int currentMillis = DateTime.now().millisecondsSinceEpoch;
    if (currentMillis - transactionMillis <=
        const Duration(
          days: 1,
        ).inMilliseconds) {
      return FormatUtils.formatDataShort(currentMillis - transactionMillis);
    }
    return FormatUtils.formatDate(transactionMillis);
  }

  /// The label and the value of the time left to vote.
  ///
  /// One message, cut where the time stands in it, so that the time keeps
  /// the value's style and each language its own order of words. What a
  /// language says after the time stays with it, in the value.
  (String, String) _getTimeUntilVotingCloses(AppLocalizations l10n) {
    final DateTime creationDate = DateTime.fromMillisecondsSinceEpoch(
      (creationTimestamp ?? 0) * 1000,
    );
    final DateTime votingEnds = creationDate.add(kProjectVotingPeriod);
    final Duration difference = votingEnds.difference(DateTime.now());
    if (difference.isNegative) {
      return ('Voting closed', '');
    }
    const String mark = '\u0000';
    final List<String> around = l10n.acceleratorClosesIn(mark).split(mark);
    final String left = FormatUtils.formatDurationCoarse(l10n, difference);
    return (around.first, '$left${around.skip(1).join()}');
  }

  String _getOwnerDetails() {
    if (kDefaultAddressList.contains(owner.toString())) {
      return kAddressLabelMap[owner.toString()] ?? owner!.toShortString();
    }
    return owner!.toShortString();
  }
}
