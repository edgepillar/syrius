import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/pillar_parts/pillar_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/screens/screens.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The selected address's own pillar, under the pillar animation.
///
/// Without one, the card offers to spawn a pillar. With one, it names it,
/// offers to update it, and counts down to the next revocation window; while
/// that window is open it also offers to disassemble the pillar.
class PillarStatsCard extends StatelessWidget {
  /// {@macro default_constructor}
  const PillarStatsCard({
    required this._onStepperNotificationSeeMorePressed,
    super.key,
  });

  final VoidCallback _onStepperNotificationSeeMorePressed;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Your pillar',
      actions: <Widget>[
        RefreshButton(onPressed: () => _refreshOwnPillar(context)),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: <Widget>[
            // The animation stays put while the states under it change.
            const NodeObject.pillar(),
            const SizedBox(height: 6),
            BlocBuilder<PillarsByOwnerBloc, FetchState<List<PillarInfo>>>(
              builder: (_, FetchState<List<PillarInfo>> state) {
                return switch (state) {
                  FetchInitial<List<PillarInfo>>() => const CardStates(
                    state: 'loading',
                    fill: false,
                    child: _Loading(),
                  ),
                  FetchFailure<List<PillarInfo>>() => CardStates(
                    state: 'error',
                    fill: false,
                    child: _Note(cardErrorText(state.exception)),
                  ),
                  FetchPopulated<List<PillarInfo>>() =>
                    state.data.isEmpty
                        ? CardStates(
                            state: 'empty',
                            fill: false,
                            child: _Empty(
                              onStepperNotificationSeeMorePressed:
                                  _onStepperNotificationSeeMorePressed,
                            ),
                          )
                        : CardStates(
                            state: 'populated',
                            fill: false,
                            child: _Populated(
                              pillarInfo: state.data.first,
                              onStepperNotificationSeeMorePressed:
                                  _onStepperNotificationSeeMorePressed,
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

/// Reads the address's own pillar again.
void _refreshOwnPillar(BuildContext context) {
  context.read<PillarsByOwnerBloc>().add(
    FetchRequestData(address: Address.parse(kSelectedAddress!)),
  );
}

/// Bars where the name and the button will be.
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

/// The address owns no pillar: say so, and offer to spawn one.
class _Empty extends StatelessWidget {
  const _Empty({required this.onStepperNotificationSeeMorePressed});

  final VoidCallback onStepperNotificationSeeMorePressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('None yet', style: cardDimStyle(context)),
        const SizedBox(height: kCardGap),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (BuildContext context) => StepperScreen(
                  stepper: const CreatePillarStepperPage(),
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

/// The address's pillar: its name, Update, the countdown to the revocation
/// window and, while that window is open, Disassemble.
class _Populated extends StatelessWidget {
  const _Populated({
    required this.pillarInfo,
    required this.onStepperNotificationSeeMorePressed,
  });

  final PillarInfo pillarInfo;
  final VoidCallback onStepperNotificationSeeMorePressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          pillarInfo.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: cardValueStyle(context).copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: kCardGap),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => StepperScreen(
                      stepper: UpdatePillarStepperPage(pillarInfo: pillarInfo),
                      onStepperNotificationSeeMorePressed:
                          onStepperNotificationSeeMorePressed,
                    ),
                  ),
                );
              },
              child: const Text('Update'),
            ),
            if (pillarInfo.isRevocable)
              RevokePillarButton(
                pillarName: pillarInfo.name,
                onRevoked: () => _refresh(context),
              ),
          ],
        ),
        const SizedBox(height: kCardGap),
        Tooltip(
          message: pillarInfo.isRevocable
              ? context.l10n.revocationWindowOpen
              : context.l10n.untilRevocationWindowOpens,
          child: RevokeCountdown(
            seconds: pillarInfo.revokeCooldown,
            open: pillarInfo.isRevocable,
            onFinished: () => _refresh(context),
          ),
        ),
      ],
    );
  }

  /// The window opened or closed, or the pillar is gone: read both the
  /// address's pillar and the list again.
  void _refresh(BuildContext context) {
    _refreshOwnPillar(context);
    context.read<PillarsBloc>().add(const InfiniteListRefreshRequested());
  }
}
