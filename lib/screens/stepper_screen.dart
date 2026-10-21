import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

/// The full-window frame the pillar, sentinel, token and accelerator
/// steppers open in: the app's notifications on top, the stepper on one card
/// under them, and a close button.
class StepperScreen extends StatelessWidget {
  const StepperScreen({
    required this.stepper,
    required this.onStepperNotificationSeeMorePressed,
    super.key,
  });

  final VoidCallback onStepperNotificationSeeMorePressed;
  final Widget stepper;

  @override
  Widget build(BuildContext context) {
    final ThemeData app = Theme.of(context);
    //TODO: to delete Theme widget once only the new theme is being used
    return Theme(
      data: _stepperTheme(context.newThemeData, app),
      child: Scaffold(
        backgroundColor: app.scaffoldBackgroundColor,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              NotificationWidget(
                onSeeMorePressed: onStepperNotificationSeeMorePressed,
              ),
              Expanded(
                child: RiseIn(
                  child: Material(
                    color: app.colorScheme.primary,
                    borderRadius: BorderRadius.circular(kCardRadius),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        // Tab walks the step's form before it reaches the
                        // close button.
                        FocusTraversalGroup(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: stepper,
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: IconButton(
                            tooltip: 'Close',
                            iconSize: 20,
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: const Icon(
                              Icons.clear,
                              color: AppColors.faint,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The steppers were written against the "new" theme, which has neither
  /// the app's faces nor its buttons. This keeps that theme and lends it the
  /// app's type, hairline and main action, so a stepper reads as part of the
  /// refreshed interface: the step buttons become the filled green pill
  /// every other page uses for its main action.
  static ThemeData _stepperTheme(ThemeData steppers, ThemeData app) {
    return steppers.copyWith(
      textTheme: steppers.textTheme.apply(
        fontFamily: kSansFontFamily,
        fontFamilyFallback: kFontFamilyFallback,
      ),
      primaryTextTheme: steppers.primaryTextTheme.apply(
        fontFamily: kSansFontFamily,
        fontFamilyFallback: kFontFamilyFallback,
      ),
      dividerTheme: app.dividerTheme,
      outlinedButtonTheme: app.outlinedButtonTheme,
      textSelectionTheme: app.textSelectionTheme,
      scaffoldBackgroundColor: app.scaffoldBackgroundColor,
    );
  }
}
