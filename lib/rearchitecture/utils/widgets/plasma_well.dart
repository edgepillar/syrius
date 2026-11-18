import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';

/// Blends the plasma mark's pink and blue halo into the surrounding card.
class PlasmaWell extends StatelessWidget {
  /// Sets [child], a square mark, in the well.
  const PlasmaWell({required this.child, this.overhang = 0, super.key});

  /// The mark, laid out at its own size; the well takes no more room.
  final Widget child;

  /// How far the halo reaches past the mark's square on each side, painted
  /// outside the layout so the page around does not move.
  final double overhang;

  static final BoxDecoration _halo = BoxDecoration(
    shape: BoxShape.circle,
    gradient: RadialGradient(
      colors: <Color>[
        AppColors.plasmaPink.withValues(alpha: .36),
        AppColors.qsrColor.withValues(alpha: .17),
        AppColors.qsrColor.withValues(alpha: 0),
      ],
      stops: const <double>[0, .45, 1],
    ),
  );

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: <Widget>[
      Positioned(
        left: -overhang,
        top: -overhang,
        right: -overhang,
        bottom: -overhang,
        child: DecoratedBox(
          key: const Key('plasma_well'),
          decoration: _halo,
        ),
      ),
      child,
    ],
  );
}
