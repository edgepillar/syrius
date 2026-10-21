import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/pillar_parts/pillar_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The selected address's delegation: the pillar it backs, with how much,
/// and the way out.
///
/// It sat on the old dashboard and had no page after the home was rebuilt,
/// which left no way to undelegate; it is on the Pillars page now.
///
/// The card has four states, which cross-fade: loading (bars), populated,
/// empty (the address backs no pillar) and error.
class DelegationCard extends StatelessWidget {
  /// Creates a DelegationCard object.
  const DelegationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UndelegateBloc>(
      create: (_) => UndelegateBloc(
        accountBlockUtils: AccountBlockUtils(),
        zenon: zenon!,
      ),
      child: Panel(
        title: 'Delegation',
        actions: <Widget>[
          RefreshButton(
            onPressed: () {
              context.read<DelegationStatsBloc>().add(
                FetchRequestData(address: Address.parse(kSelectedAddress!)),
              );
            },
          ),
        ],
        child: BlocBuilder<DelegationStatsBloc, FetchState<DelegationInfo>>(
          builder: (_, FetchState<DelegationInfo> state) {
            final _Shown shown = _Shown.of(state);
            return CardStates(
              state: shown,
              child: switch (state) {
                FetchInitial<DelegationInfo>() =>
                  const DelegationStatsLoading(),
                FetchPopulated<DelegationInfo>() => DelegationStatsPopulated(
                  delegationInfo: state.data,
                ),
                FetchFailure<DelegationInfo>() =>
                  shown == _Shown.empty
                      ? const DelegationStatsEmpty()
                      : DelegationStatsError(error: state.exception),
              },
            );
          },
        ),
      ),
    );
  }
}

/// The four states of the card.
enum _Shown {
  loading,
  populated,
  empty,
  error;

  /// The bloc reports an address that backs no pillar as a failure; to the
  /// person it is the empty state.
  static _Shown of(FetchState<DelegationInfo> state) => switch (state) {
    FetchInitial<DelegationInfo>() => loading,
    FetchPopulated<DelegationInfo>() => populated,
    FetchFailure<DelegationInfo>() =>
      state.exception is NoDelegationStatsException ? empty : error,
  };
}
