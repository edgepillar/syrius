import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/cubits/timer_cubit.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/pair.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// How many momentums the node is short of the network's height, or null
/// when it is in step or has not said.
///
/// It reads the node's own answer (the pair's second half), not the cubit's
/// remembered state: that one stays "synced" after the socket stops. Within
/// three momentums counts as in step, the same slack the cubit allows: the
/// node is always a momentum or two behind what its peers announce.
int? momentumsBehind(NodeSyncStatusState state) {
  final Pair<SyncState, SyncInfo>? data = state.data;
  if (state.status != TimerStatus.success || data == null) {
    return null;
  }
  final SyncInfo info = data.second;
  if (info.state == SyncState.syncDone ||
      info.currentHeight <= 0 ||
      info.targetHeight <= 0) {
    return null;
  }
  final int behind = info.targetHeight - info.currentHeight;
  return behind < 3 ? null : behind;
}

/// The node connection as one dot: green when connected and in sync, the
/// warning tone while connecting, syncing or stalled, the error colour when
/// the node cannot be reached. The tooltip names the state.
///
/// A dot and not the progress ring this replaced: the ring asks for 36 px
/// each way, and in the strip's 28 by 18 box it was drawn as an empty oval.
class SyncDot extends StatelessWidget {
  /// Creates the dot for [state].
  const SyncDot({required this.state, super.key});

  /// The sync cubit's latest state.
  final NodeSyncStatusState state;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final Pair<SyncState, SyncInfo>? data = state.data;
    final Color color;
    final String message;
    if (state.status == TimerStatus.failure) {
      color = Theme.of(context).colorScheme.error;
      message = 'Disconnected';
    } else if (state.status != TimerStatus.success || data == null) {
      color = tokens.warn;
      message = 'Connecting';
    } else {
      final SyncInfo info = data.second;
      final bool hasHeights = info.currentHeight > 0 && info.targetHeight > 0;
      if (info.state == SyncState.syncDone ||
          (hasHeights && momentumsBehind(state) == null)) {
        color = tokens.znnInk;
        message = 'Connected and in sync';
      } else if (hasHeights) {
        color = tokens.warn;
        message =
            'Syncing, momentum ${info.currentHeight} of ${info.targetHeight}';
      } else {
        color = tokens.warn;
        message = 'Connecting';
      }
    }
    return Tooltip(
      message: message,
      // Wider and taller than the dot, so the tooltip is not an 8 px target.
      child: SizedBox(
        width: 16,
        height: 40,
        child: Center(
          child: AnimatedContainer(
            key: const Key('strip_sync'),
            duration: Durations.short4,
            curve: Easing.standard,
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

/// Names a node that is behind, in the dot's warning tone: a send made now
/// waits until the node has caught up, and the dot alone does not say by
/// how much. Nothing when the node is in step.
class SyncBehind extends StatelessWidget {
  /// Creates the line for [state].
  const SyncBehind({required this.state, super.key});

  /// The sync cubit's latest state.
  final NodeSyncStatusState state;

  @override
  Widget build(BuildContext context) {
    final int? behind = momentumsBehind(state);
    if (behind == null) {
      return const SizedBox.shrink();
    }
    return Text(
      context.l10n.stripMomentumsBehind(behind),
      key: const Key('strip_behind'),
      style: Theme.of(context).textTheme.titleMedium!.copyWith(
        fontSize: 13,
        color: AppTokens.of(context).warn,
      ),
      maxLines: 1,
      softWrap: false,
    );
  }
}
