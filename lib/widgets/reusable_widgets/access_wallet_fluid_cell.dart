import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/svg.dart';
import 'package:layout/layout.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

/// One way into a wallet, as a tile of the old welcome grid.
///
/// The welcome screen no longer uses it; it is kept, restyled, for anything
/// else that lays the choices out on a grid.
class AccessWalletFluidCell extends FluidCell {
  AccessWalletFluidCell({
    required this.onPressed,
    required this.buttonIconLocation,
    required this.buttonText,
    required this.context,
  }) : super(
         width: context.layout.value(
           xl: kStaggeredNumOfColumns ~/ 3,
           lg: kStaggeredNumOfColumns ~/ 3,
           md: kStaggeredNumOfColumns ~/ 3,
           sm: kStaggeredNumOfColumns ~/ 2,
           xs: kStaggeredNumOfColumns,
         ),
         child: MaterialButton(
           disabledColor: Theme.of(context).colorScheme.primary,
           padding: const EdgeInsets.all(24),
           elevation: 0,
           hoverElevation: 0,
           focusElevation: 0,
           highlightElevation: 0,
           color: Theme.of(context).colorScheme.primary,
           hoverColor: Theme.of(context).colorScheme.primaryContainer,
           shape: const RoundedRectangleBorder(
             borderRadius: BorderRadius.all(Radius.circular(kCardRadius)),
           ),
           onPressed: onPressed,
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: <Widget>[
               SizedBox.square(
                 dimension: 40,
                 child: SvgPicture.asset(
                   buttonIconLocation,
                   colorFilter: const ColorFilter.mode(
                     AppColors.znnColor,
                     BlendMode.srcIn,
                   ),
                 ),
               ),
               const SizedBox(height: 16),
               Text(
                 buttonText,
                 textAlign: TextAlign.center,
                 style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                   fontSize: 15,
                   fontWeight: FontWeight.w500,
                 ),
               ),
             ],
           ),
         ),
       );

  /// Opens this way in.
  final VoidCallback? onPressed;

  /// The asset path of its icon.
  final String buttonIconLocation;

  /// Its name.
  final String buttonText;

  /// The context the tile is built in.
  final BuildContext context;
}
