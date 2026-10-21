import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';

/// Sets the plasma mark in a dark round window in the light theme.
///
/// `PlasmaGlow` was drawn for a dark ground: the bolt's body is transparent,
/// its halo shades towards a deep blue, and the shader's grain covers its
/// whole square. On a white card that read as a white bolt in a grainy blot
/// inside a pale rectangle. Behind the mark this lays a disc in the dark
/// theme's card colour and clips the mark to its inscribed circle, which
/// hides the square's corners; the halo has faded out by then.
///
/// In the dark theme it adds nothing and clips nothing, so the mark looks
/// exactly as it did. The tree keeps one shape in both themes, so a theme
/// switch does not restart the mark's shader.
class PlasmaWell extends StatelessWidget {
  /// Sets [child], a square mark, in the well.
  const PlasmaWell({required this.child, this.overhang = 0, super.key});

  /// The mark, laid out at its own size; the well takes no more room.
  final Widget child;

  /// How far the disc reaches past the mark's square on each side, painted
  /// outside the layout so the page around does not move.
  final double overhang;

  /// The ground the glow was made on: the dark theme's card.
  static const Color ground = AppColors.darkPrimary;

  @override
  Widget build(BuildContext context) {
    final bool light = Theme.of(context).brightness == Brightness.light;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: <Widget>[
        Positioned(
          left: -overhang,
          top: -overhang,
          right: -overhang,
          bottom: -overhang,
          child: light
              ? const DecoratedBox(
                  key: Key('plasma_well'),
                  decoration: BoxDecoration(
                    color: ground,
                    shape: BoxShape.circle,
                  ),
                )
              : const SizedBox.shrink(),
        ),
        ClipOval(
          clipBehavior: light ? Clip.antiAlias : Clip.none,
          child: child,
        ),
      ],
    );
  }
}
