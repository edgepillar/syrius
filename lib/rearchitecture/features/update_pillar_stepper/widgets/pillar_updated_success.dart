import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/app_lottie.dart';

/// Success action shown after a pillar has been updated.
class PillarUpdatedSuccess extends StatelessWidget {
  /// Creates a [PillarUpdatedSuccess].
  const PillarUpdatedSuccess({
    required this.onViewPillarsPressed,
    super.key,
  });

  /// Called when the user wants to return to the pillars view.
  final VoidCallback onViewPillarsPressed;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      bottom: 20,
      start: 0,
      end: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          OutlinedButton(
            onPressed: onViewPillarsPressed,
            child: Text(context.l10n.viewPillars),
          ),
        ],
      ),
    );
  }
}

/// Animated pillar success illustration.
class PillarUpdatedSuccessAnimation extends StatelessWidget {
  /// Creates a [PillarUpdatedSuccessAnimation].
  const PillarUpdatedSuccessAnimation({super.key});

  @override
  Widget build(BuildContext context) {
    // At the end of the line, so it stays clear of the steps when the
    // interface runs right to left.
    return const PositionedDirectional(
      end: 50,
      child: SizedBox(
        width: 400,
        height: 400,
        child: Center(
          child: AppLottie(AppLottieAsset.pillar, size: 400, repeat: false),
        ),
      ),
    );
  }
}
