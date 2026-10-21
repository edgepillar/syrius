import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/models/card/card.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/widgets.dart';

/// Transfer: the send form and the receive request side by side, the
/// address's activity and what waits to be received under them.
///
/// The forms sit in a fixed row. Send puts its button on the amount's line,
/// so the row holds both forms with an error under every field; each form
/// also scrolls inside its card, so nothing is ever cut off. The two lists
/// share whatever height is left.
class TransferTabChild extends StatelessWidget {
  const TransferTabChild({super.key});

  @override
  Widget build(BuildContext context) {
    return PageGrid(
      rows: <PageRow>[
        const PageRow.fixed(330, <PageCell>[
          PageCell(SendCard(), flex: 3),
          PageCell(ReceiveCard(), flex: 2),
        ]),
        PageRow.fill(<PageCell>[
          PageCell(
            LatestTransactionsCard(type: CardType.latestTransactions),
            flex: 3,
          ),
          const PageCell(PendingTransactionsCard(), flex: 2),
        ]),
      ],
    );
  }
}
