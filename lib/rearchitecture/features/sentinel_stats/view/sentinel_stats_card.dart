import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/pillar_parts/pillar_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/screens/screens.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The selected address's own sentinel, under the sentinel animation.
///
/// If the address does not own one, the card offers to spawn one. If it
/// does, the card says so; an address cannot hold a second sentinel.
///
/// The card has four states, which cross-fade: loading (bars), populated,
/// empty (no sentinel on the address) and error.
class SentinelStatsCard extends StatelessWidget {
  /// {@macro default_constructor}
  const SentinelStatsCard({
    required this._onStepperNotificationSeeMorePressed,
    super.key,
  });

  final VoidCallback _onStepperNotificationSeeMorePressed;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SentinelsByOwnerBloc>(
      create: (_) =>
          SentinelsByOwnerBloc(
            zenon: zenon!,
          )..add(
            FetchRequestData(
              address: Address.parse(kSelectedAddress!),
            ),
          ),
      child: _View(
        onStepperNotificationSeeMorePressed:
            _onStepperNotificationSeeMorePressed,
      ),
    );
  }
}

class _View extends StatelessWidget {
  const _View({
    required this.onStepperNotificationSeeMorePressed,
  });

  final VoidCallback onStepperNotificationSeeMorePressed;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Your sentinel',
      actions: <Widget>[
        RefreshButton(
          onPressed: () {
            context.read<SentinelsByOwnerBloc>().add(
              FetchRequestData(
                address: Address.parse(kSelectedAddress!),
              ),
            );
          },
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: <Widget>[
            // The sentinel animation is kept from the old card. It plays
            // once, on its own layer, so the page does not repaint with it.
            const NodeObject.sentinel(),
            const SizedBox(height: 8),
            // The four states cross-fade under the animation, which stays
            // put. They are keyed apart, so a refresh that lands on the same
            // state does not fade.
            BlocBuilder<SentinelsByOwnerBloc, FetchState<List<SentinelInfo>>>(
              builder: (_, FetchState<List<SentinelInfo>> state) {
                return switch (state) {
                  FetchInitial<List<SentinelInfo>>() => const CardStates(
                    state: 'loading',
                    fill: false,
                    child: _Loading(),
                  ),
                  FetchFailure<List<SentinelInfo>>() => CardStates(
                    state: 'error',
                    fill: false,
                    child: _Note(cardErrorText(state.exception)),
                  ),
                  FetchPopulated<List<SentinelInfo>>() =>
                    state.data.any(
                          (SentinelInfo sentinelInfo) => sentinelInfo.active,
                        )
                        ? const CardStates(
                            state: 'populated',
                            fill: false,
                            child: _Populated(),
                          )
                        : CardStates(
                            state: 'empty',
                            fill: false,
                            child: _Empty(
                              onStepperNotificationSeeMorePressed:
                                  onStepperNotificationSeeMorePressed,
                            ),
                          ),
                };
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Bars where the line and the button will be.
class _Loading extends StatelessWidget {
  const _Loading();

  static const double _width = 140;

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 6),
      child: SizedBox(width: _width, child: SkeletonRows(rows: 2)),
    );
  }
}

/// One quiet, centred line: an error.
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: cardDimStyle(context),
    );
  }
}

/// The address owns a sentinel: say so. The icon says why it cannot spawn
/// another.
class _Populated extends StatelessWidget {
  const _Populated();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: Text(
            context.l10n.sentinelDetectedOnThisAddress,
            textAlign: TextAlign.center,
            style: cardValueStyle(context),
          ),
        ),
        const SizedBox(width: 4),
        StandardTooltipIcon(
          context.l10n.cannotReuseAddressForSentinel,
          Icons.info_outline,
          iconColor: AppTokens.of(context).faint,
        ),
      ],
    );
  }
}

/// The address owns no sentinel: say so, and offer to spawn one.
class _Empty extends StatelessWidget {
  const _Empty({required this.onStepperNotificationSeeMorePressed});

  final VoidCallback onStepperNotificationSeeMorePressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('No sentinel on this address', style: cardDimStyle(context)),
        SizedBox(height: AppTokens.of(context).cardGap),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (BuildContext context) => StepperScreen(
                  stepper: const CreateSentinelStepperPage(),
                  onStepperNotificationSeeMorePressed:
                      onStepperNotificationSeeMorePressed,
                ),
              ),
            );
          },
          label: Text(context.l10n.spawn),
          icon: const Icon(Icons.add, size: 18),
        ),
      ],
    );
  }
}
