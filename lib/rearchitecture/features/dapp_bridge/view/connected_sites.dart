import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/cubit/connected_sites_cubit.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_channel.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_consent.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

/// What a connection lets a site do, the same for every site: it sees the
/// selected address while it is one it was shown, and it may ask. Every
/// signature and every send is still put to the person.
const List<String> _kGranted = <String>[
  'See address',
  'Ask to sign',
  'Ask to send',
];

/// The sites with consent to talk to this wallet, each with the addresses it
/// was shown, what it may do, and a Disconnect.
///
/// Given a bounded height (a `PageGrid` cell) it is a titled panel whose
/// list scrolls; in a scrolling column it takes the height of its rows.
class ConnectedSites extends StatelessWidget {
  /// Creates the list over [control]; the app's channel
  /// (`DappBridge.instance`) when null.
  const ConnectedSites({this.control, super.key});

  /// The channel listed. Tests pass a fake.
  final DappBridgeControl? control;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ConnectedSitesCubit>(
      create: (_) => ConnectedSitesCubit(control ?? DappBridgeControl.of()),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectedSitesCubit, ConnectedSitesState>(
      builder: (BuildContext context, ConnectedSitesState state) {
        final Widget count = Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(
            '${state.sites.length}',
            style: ledgerLabelStyle(context),
          ),
        );
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            if (constraints.hasBoundedHeight) {
              return Panel(
                title: 'Connected sites',
                actions: <Widget>[count],
                child: state.sites.isEmpty
                    ? _buildEmpty(context)
                    : ListView.separated(
                        itemCount: state.sites.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (BuildContext context, int i) =>
                            _Site(site: state.sites[i]),
                      ),
              );
            }
            return Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    height: 48,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Connected sites',
                              style: panelTitleStyle(context),
                            ),
                          ),
                          count,
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  if (state.sites.isEmpty) _buildEmpty(context),
                  for (int i = 0; i < state.sites.length; i++) ...<Widget>[
                    if (i > 0) const Divider(height: 1),
                    _Site(site: state.sites[i]),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
    child: Text(
      'None yet',
      key: const Key('connected_sites_empty'),
      style: Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 14),
    ),
  );
}

class _Site extends StatelessWidget {
  const _Site({required this.site});

  final DappBridgeSite site;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle faint = monoStyle(
      theme.textTheme.titleSmall,
    ).copyWith(fontSize: 12, color: AppColors.faint);
    return Padding(
      key: Key('connected_site_${site.requester}'),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        site.origin,
                        overflow: TextOverflow.ellipsis,
                        style: monoStyle(
                          theme.textTheme.bodyLarge,
                        ).copyWith(fontSize: 14),
                      ),
                    ),
                    if (site.viaLink) ...<Widget>[
                      const SizedBox(width: 8),
                      Text('LINK', style: ledgerLabelStyle(context)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                for (final String address in site.addresses)
                  Tooltip(
                    message: address,
                    child: Text(_short(address), style: faint),
                  ),
                const SizedBox(height: 2),
                Text(
                  _kGranted.join(' · '),
                  style: theme.textTheme.titleSmall!.copyWith(
                    fontSize: 12,
                    color: AppColors.faint,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            key: Key('dapp_bridge_disconnect_${site.requester}'),
            onPressed: () =>
                context.read<ConnectedSitesCubit>().disconnect(site.requester),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  String _short(String address) => address.length <= 14
      ? address
      : '${address.substring(0, 8)}…${address.substring(address.length - 6)}';
}
