import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_error.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_origin.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_service.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

/// How long an approval waits for the person. The extension's number.
const Duration kDappBridgeApprovalTtl = Duration(minutes: 30);

/// How long the approving button stays dead after its dialog appears.
///
/// A page decides when the wallet comes forward: it sends the request. A
/// click the person was already making, on the page or anywhere else, would
/// otherwise land on a button that was not there when they aimed.
const Duration kDappBridgeApprovalArm = Duration(seconds: 1);

/// The approvals of each navigator, in a line: the next is shown when the
/// one on screen is answered.
final Expando<Future<void>> _lines = Expando<Future<void>>();

/// Asks the person to approve what [requester] wants, on [navigator].
///
/// Returns which button they pressed, or [DappBridgeAnswer.dismissed] when
/// the dialog went without one, as when the wallet locks. Throws
/// [DappBridgeError.expired] when nobody answers within [ttl] of the call:
/// the dialog is taken down first, so an approval the page has already been
/// told is over can never be pressed.
///
/// One approval is on screen at a time. Stacked, the second sits exactly
/// under the first with its button already live, and a double click on the
/// first approves both. A request that waits its turn is asked [stillWanted]
/// when the turn comes, and is dismissed unshown when that is false, as when
/// the wallet locked meanwhile.
Future<DappBridgeAnswer> showDappBridgeApproval(
  NavigatorState navigator, {
  required String title,
  required String requester,
  required String action,
  required List<(String, String)> rows,
  Duration ttl = kDappBridgeApprovalTtl,
  bool Function()? stillWanted,
}) {
  final Completer<DappBridgeAnswer> done = Completer<DappBridgeAnswer>();
  DialogRoute<bool>? route;
  final Timer timer = Timer(ttl, () {
    if (done.isCompleted) {
      return;
    }
    final DialogRoute<bool>? shown = route;
    if (shown != null && shown.isActive) {
      navigator.removeRoute(shown);
    }
    done.completeError(const DappBridgeError.expired());
  });

  final Future<void> before = _lines[navigator] ?? Future<void>.value();
  _lines[navigator] = before
      .then((_) => done.future)
      .then<void>((_) {}, onError: (Object _) {});
  unawaited(
    before.then((_) {
      if (done.isCompleted) {
        // Expired while it waited its turn.
        return;
      }
      if (!navigator.mounted || !(stillWanted?.call() ?? true)) {
        timer.cancel();
        done.complete(DappBridgeAnswer.dismissed);
        return;
      }
      final DialogRoute<bool> pushed = route = DialogRoute<bool>(
        context: navigator.context,
        barrierDismissible: false,
        builder: (BuildContext context) => _ApprovalDialog(
          title: title,
          requester: requester,
          action: action,
          rows: rows,
        ),
      );
      unawaited(
        navigator.push(pushed).then((bool? approved) {
          timer.cancel();
          if (!done.isCompleted) {
            // Popped without an answer, as when the wallet locks: nobody
            // declined, so it is not reported as a decline.
            done.complete(switch (approved) {
              true => DappBridgeAnswer.approved,
              false => DappBridgeAnswer.declined,
              null => DappBridgeAnswer.dismissed,
            });
          }
        }),
      );
    }),
  );
  return done.future;
}

class _ApprovalDialog extends StatefulWidget {
  const _ApprovalDialog({
    required this.title,
    required this.requester,
    required this.action,
    required this.rows,
  });

  final String title;
  final String requester;
  final String action;
  final List<(String, String)> rows;

  @override
  State<_ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends State<_ApprovalDialog> {
  late final Timer _arming;
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    _arming = Timer(kDappBridgeApprovalArm, () {
      if (mounted) {
        setState(() => _armed = true);
      }
    });
  }

  @override
  void dispose() {
    _arming.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final TextStyle value = monoStyle(text.bodyLarge).copyWith(fontSize: 13);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Over the socket this is the browser's own Origin header, not
              // a name the page chose for itself.
              SelectableText(
                dappBridgeShownOrigin(widget.requester),
                key: const Key('dapp_bridge_origin'),
                style: monoStyle(
                  text.titleMedium,
                ).copyWith(fontSize: 15, color: AppColors.znnColor),
              ),
              if (dappBridgeIsLink(widget.requester)) ...<Widget>[
                const SizedBox(height: 6),
                // A link names its own requester. The person is told so.
                Text(
                  'From a link. Sender not verified.',
                  key: const Key('dapp_bridge_unverified'),
                  style: text.titleSmall?.copyWith(color: AppColors.warn),
                ),
              ],
              for (final (String label, String shown)
                  in widget.rows) ...<Widget>[
                const SizedBox(height: 14),
                Text(label.toUpperCase(), style: ledgerLabelStyle(context)),
                const SizedBox(height: 2),
                SelectableText(shown, style: value),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('dapp_bridge_decline'),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Decline'),
        ),
        OutlinedButton(
          key: const Key('dapp_bridge_approve'),
          onPressed: _armed ? () => Navigator.pop(context, true) : null,
          child: Text(widget.action),
        ),
      ],
    );
  }
}
