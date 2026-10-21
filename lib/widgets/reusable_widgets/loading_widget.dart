import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';

/// The app's "working on it": a thin green ring.
///
/// Small by default, so a card that is loading stays quiet. A caller that
/// passes a size or a stroke gets what it asked for.
class SyriusLoadingWidget extends StatelessWidget {
  /// Creates the indicator.
  const SyriusLoadingWidget({
    this.size = 24.0,
    this.strokeWidth = 2.0,
    this.padding = 4.0,
    super.key,
  });

  /// The diameter of the ring.
  final double size;

  /// The thickness of the ring.
  final double strokeWidth;

  /// The space round the ring.
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(padding),
      // Sized to the ring when it may be, centred when a parent forces a
      // larger box on it; never stretched.
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: SizedBox.square(
          dimension: size,
          // A ring repaints every frame; keep that off the card under it.
          child: RepaintBoundary(
            child: CircularProgressIndicator(
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.znnColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
