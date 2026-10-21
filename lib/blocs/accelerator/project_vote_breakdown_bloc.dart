import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/utils/pair.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class ProjectVoteBreakdownBloc
    extends BaseBloc<Pair<VoteBreakdown, List<PillarVote?>?>?> {
  /// Shows [votes], the tally that came with the project, and asks the
  /// node nothing. For a row that cannot be voted on: its tally only moves
  /// with a vote, which has the project read again, and the Pillar's own
  /// vote is not shown on it.
  void showKnown(VoteBreakdown votes) => addEvent(Pair(votes, null));

  Future<void> getVoteBreakdown(String? pillarName, Hash projectId) async {
    try {
      addEvent(null);
      final VoteBreakdown voteBreakdown =
          await zenon!.embedded.accelerator.getVoteBreakdown(
        projectId,
      );
      List<PillarVote?>? pillarVoteList;
      if (pillarName != null) {
        pillarVoteList = await zenon!.embedded.accelerator.getPillarVotes(
          pillarName,
          <String>[
            projectId.toString(),
          ],
        );
      }
      addEvent(Pair(voteBreakdown, pillarVoteList));
    } catch (e, stackTrace) {
      addError(e, stackTrace);
    }
  }
}
