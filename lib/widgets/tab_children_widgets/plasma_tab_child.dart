import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The height of the Fuse form: its two fields, the balance over them and
/// the preview under them, with room for one error line.
const double _kFuseHeight = 272;

/// The least height the list of fusions keeps when the window is short.
const double _kFusedMinHeight = 220;

/// Plasma: the plasma mark and every address's level down the left; the
/// Fuse form over the address's fusions on the right.
///
/// Each card reads the state it shows. The page used to sit inside one
/// builder on the plasma levels, which put a spinner over the whole page
/// until they loaded and rebuilt all three cards whenever they changed.
class PlasmaTabChild extends StatelessWidget {
  /// Creates a Plasma tab child.
  const PlasmaTabChild({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FusedPlasmaBloc>(
      create: (_) => FusedPlasmaBloc(zenon: zenon!)
        ..add(
          InfiniteListRequested(address: Address.parse(kSelectedAddress!)),
        ),
      child: const PageGrid(
        rows: <PageRow>[
          PageRow.fill(
            <PageCell>[
              PageCell(
                PlasmaStatsCard(version: PlasmaStatsWidgetVersion.plasmaTab),
              ),
              PageCell(_FuseColumn(), flex: 2),
            ],
            height: _kFuseHeight + kPanelGap + _kFusedMinHeight,
          ),
        ],
      ),
    );
  }
}

/// The Fuse form over the list of fusions, which takes the height left.
///
/// After a fuse or a cancel it reloads the fusions and the plasma levels
/// until the fusions show the change: the contract makes or drops a fusion
/// about two momentums after the send, and a single reload at the send
/// found nothing. Leaving the page, which locking the wallet does too,
/// stops the reloads.
class _FuseColumn extends StatefulWidget {
  const _FuseColumn();

  @override
  State<_FuseColumn> createState() => _FuseColumnState();
}

class _FuseColumnState extends State<_FuseColumn> {
  late final FusionsFollowUp _followUp;

  @override
  void initState() {
    super.initState();
    _followUp = FusionsFollowUp(
      fusions: context.read<FusedPlasmaBloc>(),
      levels: context.read<PlasmaStatsBloc>(),
      address: () => Address.parse(kSelectedAddress!),
    );
  }

  @override
  void dispose() {
    _followUp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: _kFuseHeight,
          child: FusePlasmaCard(onPlasmaFused: _followUp.start),
        ),
        const SizedBox(height: kPanelGap),
        Expanded(
          child: FusedPlasmaCard(onFusionCancelled: _followUp.start),
        ),
      ],
    );
  }
}
