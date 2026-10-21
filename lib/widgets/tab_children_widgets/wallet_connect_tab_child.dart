import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/dapp_bridge.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

/// The least height of the Desktop panel: its title, the switch, the list's
/// own title and one site.
const double _kDesktopRowHeight = 236;

/// The least height of the WalletConnect tables: title, header and two rows.
const double _kWalletConnectRowHeight = 176;

/// The height of the link panel: its title, the field and room for the
/// field's error line.
const double _kPairRowHeight = 136;

/// Connected sites: every site that can ask this wallet for something, and
/// the way to add one.
///
/// Top to bottom in the order a person needs them. The desktop channel
/// first, since a page in this computer's browser connects by itself and
/// only has to be switched on and watched. WalletConnect second: its
/// sessions and the pairings under them. The inputs that start a new
/// WalletConnect pairing last.
///
/// It was five cards: three ways to read a WalletConnect link (screen QR,
/// pasted link, camera) and two tables.
class WalletConnectTabChild extends StatelessWidget {
  const WalletConnectTabChild({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageGrid(
      rows: <PageRow>[
        PageRow.fill(
          <PageCell>[PageCell(_DesktopPanel())],
          height: _kDesktopRowHeight,
        ),
        PageRow.fill(
          <PageCell>[
            PageCell(WalletConnectSessionsCard(), flex: 3),
            PageCell(WalletConnectPairingsCard(), flex: 2),
          ],
          height: _kWalletConnectRowHeight,
        ),
        PageRow.fixed(_kPairRowHeight, <PageCell>[PageCell(_PairPanel())]),
      ],
    );
  }
}

/// The page-to-desktop channel: its switch over the sites it has let in.
class _DesktopPanel extends StatelessWidget {
  const _DesktopPanel();

  @override
  Widget build(BuildContext context) {
    return Panel(
      key: const Key('connected_sites_desktop'),
      title: 'Desktop',
      // The app creates its channel at start. Without one there is nothing
      // to switch, and the two widgets would have no channel to find.
      child: DappBridgeControl.app == null
          ? const QuietNote('Not running')
          : const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DappBridgeSwitch(),
                Divider(),
                Expanded(child: ConnectedSites()),
              ],
            ),
    );
  }
}

/// Starts a WalletConnect pairing: the link field with Connect, the page's
/// one main action, and beside it the two ways to read the link off a QR
/// code.
class _PairPanel extends StatelessWidget {
  const _PairPanel();

  @override
  Widget build(BuildContext context) {
    return Panel(
      key: const Key('connected_sites_pair'),
      title: 'New WalletConnect pairing',
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: FocusTraversalGroup(
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: WalletConnectUriCard()),
            SizedBox(width: 10),
            // As tall as the field, so the pills sit on its middle.
            SizedBox(
              height: kWalletConnectFieldHeight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  WalletConnectQrCard(),
                  WalletConnectCameraCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
