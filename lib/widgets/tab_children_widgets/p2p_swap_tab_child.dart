import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/utils/wallet_context_revision.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/swap_list_binding.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/swap_list_presenter.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/swap_list_view.dart';

/// Refreshes one captured catalogue without replacing an active action owner.
class P2pSwapTabChild extends StatefulWidget {
  /// Defers periodic list replacement while an owned modal is open.
  const P2pSwapTabChild({
    required this.onStepperNotificationSeeMorePressed,
    this.captureBinding = captureSwapListBinding,
    super.key,
  });

  /// Legacy parent notification navigation hook retained for callers.
  final VoidCallback onStepperNotificationSeeMorePressed;

  /// Captures the catalogue belonging to the current wallet and node.
  final SwapListBinding? Function() captureBinding;

  @override
  State<P2pSwapTabChild> createState() => _P2pSwapTabChildState();
}

class _P2pSwapTabChildState extends State<P2pSwapTabChild> {
  SwapListPresenter? _presenter;
  Timer? _refreshTimer;
  bool _reading = false;
  bool _modalOpen = false;
  int _modalEpoch = 0;

  @override
  void initState() {
    super.initState();
    WalletContextRevision.changes.addListener(_contextChanged);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refresh(),
    );
    _refresh();
  }

  void _contextChanged() {
    if (mounted) setState(() {});
    _refresh();
  }

  void _refresh() {
    if (!mounted || _reading || _modalOpen || _presenter?.deleting == true) {
      return;
    }
    final int modalEpoch = _modalEpoch;
    final SwapListBinding? binding = widget.captureBinding();
    final SwapListPresenter? next = binding == null
        ? null
        : SwapListPresenter(binding);
    if (next == null) {
      _presenter?.removeListener(_changed);
      _presenter?.dispose();
      setState(() => _presenter = null);
      return;
    }
    if (_presenter == null) {
      _presenter = next;
      next.addListener(_changed);
    }
    _reading = true;
    unawaited(
      next.load().whenComplete(() {
        _reading = false;
        if (!mounted) {
          if (!identical(_presenter, next)) next.dispose();
          return;
        }
        // A read begun before a modal cannot replace its owner or publish a
        // pre-action catalogue after that modal has closed.
        if (_modalOpen || modalEpoch != _modalEpoch) {
          if (!identical(_presenter, next)) next.dispose();
          if (!_modalOpen) _refresh();
          return;
        }
        if (!identical(_presenter, next)) {
          _presenter?.removeListener(_changed);
          _presenter?.dispose();
          _presenter = next;
          next.addListener(_changed);
        }
        setState(() {});
      }),
    );
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _modalChanged(bool value) {
    if (_modalOpen == value) return;
    _modalOpen = value;
    if (value) {
      _modalEpoch++;
    } else {
      _refresh();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WalletContextRevision.changes.removeListener(_contextChanged);
    _presenter?.removeListener(_changed);
    _presenter?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SwapListView(
    presenter: _presenter,
    onRefresh: _refresh,
    onBusyChanged: _modalChanged,
  );
}
