import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class ReceiveCell extends StatelessWidget {
  const ReceiveCell({required this.hash, super.key});

  final Hash hash;

  @override
  Widget build(BuildContext context) {
    final AutoReceiveTxWorker worker = sl<AutoReceiveTxWorker>();
    return InfiniteScrollTableCell(
      child: Align(
        alignment: Alignment.centerLeft,
        // While this row's receive is being made, published or confirmed,
        // the button is off and turns: see [AutoReceiveTxWorker.inFlight].
        child: ValueListenableBuilder<Set<Hash>>(
          valueListenable: worker.inFlight,
          builder: (BuildContext context, Set<Hash> inFlight, _) {
            final bool busy = inFlight.contains(hash);
            return IconButton(
              key: ValueKey<String>('receive_$hash'),
              tooltip: busy ? null : context.l10n.pressToReceive,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.call_received_rounded),
              color: AppColors.znnColor,
              onPressed: busy
                  ? null
                  : () => worker.autoReceiveTransactionHash(hash),
            );
          },
        ),
      ),
    );
  }
}
