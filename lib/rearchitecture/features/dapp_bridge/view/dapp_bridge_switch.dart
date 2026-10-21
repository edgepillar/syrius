import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/cubit/dapp_bridge_switch_cubit.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_channel.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

/// The Settings switch for the page-to-desktop channel: on, it listens on
/// loopback and shows the port; off, no page can reach the wallet. The
/// choice is kept.
///
/// It sizes itself to its content, so it sits in a fixed row of a
/// `PageGrid` or in a scrolling column alike.
class DappBridgeSwitch extends StatelessWidget {
  /// Creates the switch over [control]; the app's channel
  /// (`DappBridge.instance`) when null.
  const DappBridgeSwitch({this.control, super.key});

  /// The channel switched. Tests pass a fake.
  final DappBridgeControl? control;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DappBridgeSwitchCubit>(
      create: (_) => DappBridgeSwitchCubit(control ?? DappBridgeControl.of()),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return BlocBuilder<DappBridgeSwitchCubit, DappBridgeSwitchState>(
      builder: (BuildContext context, DappBridgeSwitchState state) {
        return Panel(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('Web apps', style: panelTitleStyle(context)),
                    const SizedBox(height: 4),
                    Text(
                      _status(state),
                      key: const Key('dapp_bridge_status'),
                      style: monoStyle(
                        theme.textTheme.titleSmall,
                      ).copyWith(fontSize: 12, color: _statusColor(state)),
                    ),
                  ],
                ),
              ),
              Switch(
                key: const Key('dapp_bridge_switch'),
                value: state.enabled,
                onChanged: state.saving
                    ? null
                    : (bool on) => context
                          .read<DappBridgeSwitchCubit>()
                          .setEnabled(enabled: on),
              ),
            ],
          ),
        );
      },
    );
  }

  String _status(DappBridgeSwitchState state) {
    if (state.failed) {
      return 'Not saved';
    }
    if (!state.enabled) {
      return 'Off';
    }
    if (state.saving) {
      return 'Starting';
    }
    return state.port == null ? 'No free port' : '127.0.0.1:${state.port}';
  }

  Color _statusColor(DappBridgeSwitchState state) =>
      state.failed || (state.enabled && !state.saving && state.port == null)
      ? AppColors.warn
      : AppColors.faint;
}
