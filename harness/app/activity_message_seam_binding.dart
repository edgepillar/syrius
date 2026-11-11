import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart' as app;
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/latest_transactions/bloc/latest_transactions_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/latest_transactions/view/activity_row.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/latest_transactions/view/latest_transactions_card.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/models/card/card_type.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/main_app_container.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modals.dart'
    show showFrostedDialog;
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

import 'fixtures/activity_message_preview.dart';

/// The harness-owned preview's existing close control.
const String activityMessagePreviewClose = 'activity_message_preview_close';

/// Tries the original Message widget using real history and explicit preview
/// metadata. Only the harness imports this route; the normal app is unchanged.
Future<void> observeActivityMessageSeam({
  required void Function() requireWallet,
  required Future<void> Function() settle,
  required Future<void> Function(String, void Function()) observe,
  required Future<void> Function(String, void Function()) tap,
}) async {
  requireWallet();
  final Element? root = WidgetsBinding.instance.rootElement;
  final NavigatorState? navigator = app.globalNavigatorKey.currentState;
  final String? address = kSelectedAddress;
  if (root == null || navigator == null || address == null ||
      kCurrentPage != Tabs.dashboard) {
    throw const ActivityMessagePreviewRefused();
  }
  final List<Element> cards = <Element>[];
  void visit(Element element) {
    final Widget widget = element.widget;
    if (widget is LatestTransactionsCard &&
        widget.type == CardType.latestTransactionsDashboard &&
        (widget.address ?? kSelectedAddress) == address &&
        ModalRoute.of(element)?.isCurrent == true) {
      cards.add(element);
    }
    element.visitChildren(visit);
  }
  visit(root);
  if (cards.length != 1) throw const ActivityMessagePreviewRefused();
  final Element card = cards.single;
  final ModalRoute<dynamic>? home = ModalRoute.of(card);
  final LatestTransactionsBloc history = card.read<LatestTransactionsBloc>();
  void current() {
    requireWallet();
    if (!root.mounted || !card.mounted || !navigator.mounted ||
        !identical(WidgetsBinding.instance.rootElement, root) ||
        !identical(app.globalNavigatorKey.currentState, navigator) ||
        !identical(ModalRoute.of(card), home) || home?.isActive != true ||
        !identical(home?.navigator, navigator) ||
        kCurrentPage != Tabs.dashboard || kSelectedAddress != address ||
        history.isClosed) {
      throw const ActivityMessagePreviewRefused();
    }
  }
  final ActivityMessagePreview preview = ActivityMessagePreview.capture(
    source: history, readSource: () => card.read<LatestTransactionsBloc>(),
    readBlocks: () => history.state.data ?? <AccountBlock>[],
    requireOwner: current, owner: address,
  );
  ModalRoute<dynamic>? route;
  bool closing = false;
  void presentation() {
    preview.requireCurrent();
    if (closing ? home?.isCurrent != true :
        route?.isCurrent != true || route?.isActive != true ||
            !identical(route?.navigator, navigator)) {
      throw const ActivityMessagePreviewRefused();
    }
  }
  Object? closeError;
  StackTrace? closeTrace;
  final Future<void> closed = showFrostedDialog<void>(
    context: card, barrierDismissible: false,
    builder: (BuildContext context) {
      route ??= ModalRoute.of(context);
      return _Preview(
        preview: preview, requireCurrent: presentation,
        close: () {
          presentation();
          if (closing) throw const ActivityMessagePreviewRefused();
          closing = true;
          Navigator.of(context).pop();
        },
      );
    },
  ).then<void>((_) {}, onError: (Object error, StackTrace trace) {
    closeError = error;
    closeTrace = trace;
  });
  await settle();
  presentation();
  await observe('activity_message:${preview.entry.hash}', presentation);
  presentation();
  await tap(activityMessagePreviewClose, presentation);
  await closed;
  if (closeError != null) {
    Error.throwWithStackTrace(closeError!, closeTrace!);
  }
  preview.requireCurrent();
  if (!closing || home?.isCurrent != true) {
    throw const ActivityMessagePreviewRefused();
  }
}

class _Preview extends StatefulWidget {
  const _Preview({
    required this.preview, required this.requireCurrent, required this.close,
  });
  final ActivityMessagePreview preview;
  final void Function() requireCurrent;
  final VoidCallback close;
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  Timer? _clock;
  bool _expired = false;
  final DateTime _now = DateTime.now();
  bool _current() {
    if (_expired) return false;
    try {
      widget.requireCurrent();
      return true;
    } on Object {
      _expired = true;
      return false;
    }
  }
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && !_expired && !_current()) setState(() {});
    });
  }
  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final bool current = _current();
    return Dialog(child: SizedBox(width: 900, child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        const Text('Isolated activity preview; no Zap receipt is claimed.'),
        const SizedBox(height: 16),
        if (current) ActivityRow(
          entry: widget.preview.entry, now: _now, chainId: 321,
        ) else const Text('Preview unavailable.'),
        const SizedBox(height: 16),
        OutlinedButton(key: const Key(activityMessagePreviewClose),
          onPressed: current ? widget.close : null, child: const Text('Close')),
      ]),
    )));
  }
}
