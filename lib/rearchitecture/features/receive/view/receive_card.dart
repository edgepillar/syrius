import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The receive request of the Transfer page: a QR code for an address, an
/// asset and an amount.
class ReceiveCard extends StatelessWidget {
  /// Creates a new instance.
  const ReceiveCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: context.l10n.receive,
      actions: <Widget>[
        RefreshButton(
          onPressed: () {
            context.read<AllTokensBloc>().add(const AllTokensRequested());
          },
        ),
      ],
      child: BlocBuilder<AllTokensBloc, AllTokensState>(
        builder: (_, AllTokensState state) {
          return switch (state) {
            AllTokensFailure(:final SyriusException exception) => ReceiveError(
              error: exception,
            ),
            AllTokensInitial() => const ReceiveInitial(),
            AllTokensPopulated(:final List<Token> data) => ReceivePopulated(
              assets: data,
            ),
          };
        },
      ),
    );
  }
}
