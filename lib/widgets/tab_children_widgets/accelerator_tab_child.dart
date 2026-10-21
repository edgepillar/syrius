import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/motion/motion.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notifiers/default_address_notifier.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// Accelerator: the project list is the page.
///
/// A fixed row on top holds the fund's figures and the two actions; the
/// list of projects takes the rest. Whether the selected address owns a
/// Pillar decides the vote buttons and filters, so that lookup is made once
/// per address, not on every build.
class AcceleratorTabChild extends StatefulWidget {
  /// Creates the Accelerator page.
  const AcceleratorTabChild({
    required this.onStepperNotificationSeeMorePressed,
    super.key,
  });

  /// Opens the notifications page from a stepper.
  final VoidCallback onStepperNotificationSeeMorePressed;

  @override
  State<AcceleratorTabChild> createState() => _AcceleratorTabChildState();
}

class _AcceleratorTabChildState extends State<AcceleratorTabChild> {
  String? _address;
  Future<List<PillarInfo>>? _pillars;

  /// The Pillars [address] owns, fetched again only when the address
  /// changes. The old page asked for them in `build`, so every rebuild sent
  /// a request and showed a spinner over the whole page.
  Future<List<PillarInfo>> _pillarsOf(String address) {
    if (_pillars == null || _address != address) {
      _address = address;
      _pillars = zenon!.embedded.pillar.getByOwner(Address.parse(address));
    }
    return _pillars!;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SelectedAddressNotifier>(
      builder: (BuildContext context, _, _) {
        final String address = kSelectedAddress!;
        return FutureBuilder<List<PillarInfo>>(
          future: _pillarsOf(address),
          builder: (_, AsyncSnapshot<List<PillarInfo>> snapshot) {
            // While another address's lookup runs, the snapshot still holds
            // the previous answer; it must not be shown under this address.
            final bool ready =
                snapshot.connectionState == ConnectionState.done &&
                snapshot.hasData;
            final PillarInfo? pillarInfo = ready && snapshot.data!.isNotEmpty
                ? snapshot.data!.first
                : null;
            return PageGrid(
              rows: <PageRow>[
                PageRow.fixed(88, <PageCell>[
                  PageCell(
                    AcceleratorStats(
                      pillarInfo: pillarInfo,
                      onStepperNotificationSeeMorePressed:
                          widget.onStepperNotificationSeeMorePressed,
                    ),
                  ),
                ]),
                PageRow.fill(<PageCell>[
                  PageCell(
                    _buildProjects(snapshot, address, pillarInfo, ready: ready),
                  ),
                ]),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildProjects(
    AsyncSnapshot<List<PillarInfo>> snapshot,
    String address,
    PillarInfo? pillarInfo, {
    required bool ready,
  }) {
    final Widget state;
    if (snapshot.hasError) {
      state = Panel(
        key: const ValueKey<String>('error'),
        title: 'Projects',
        child: RepaintBoundary(
          child: SyriusErrorWidget(snapshot.error.toString()),
        ),
      );
    } else if (!ready) {
      state = const Panel(
        key: ValueKey<String>('loading'),
        title: 'Projects',
        padding: EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topLeft,
          child: SkeletonRows(rows: 4, gap: 18),
        ),
      );
    } else {
      state = AccProjectList(
        // The list's bloc is made with the Pillar it votes as; another
        // address needs another list, not the old one rebuilt.
        key: ValueKey<String>('$address/${pillarInfo?.name}'),
        onStepperNotificationSeeMorePressed:
            widget.onStepperNotificationSeeMorePressed,
        pillarInfo: pillarInfo,
      );
    }
    return StateSwitcher(child: state);
  }
}
