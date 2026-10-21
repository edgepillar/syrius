import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/app_lottie.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';

/// The program that runs a Pillar node. A name: the same in every language.
const String _kControllerName = 'znn-controller';

/// Success UI shown after a pillar has been registered.
class PillarRegisteredSuccess extends StatelessWidget {
  /// Creates a [PillarRegisteredSuccess].
  const PillarRegisteredSuccess({
    required this.onRegisterAnotherPressed,
    required this.onViewPillarsPressed,
    super.key,
  });

  /// Called when the user wants to register another pillar.
  final VoidCallback onRegisterAnotherPressed;

  /// Called when the user wants to return to the pillars view.
  final VoidCallback onViewPillarsPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _SuccessMessage(
          onControllerPressed: () {
            unawaited(NavigationUtils.openUrl(kZnnController));
          },
        ),
        // The quiet way on first, the main one last, as under every step.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextButton.icon(
              style: quietButtonStyle(context),
              onPressed: onRegisterAnotherPressed,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(context.l10n.registerAnotherPillar),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onViewPillarsPressed,
              child: Text(context.l10n.viewPillars),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// Animated pillar success illustration.
class PillarRegisteredSuccessAnimation extends StatelessWidget {
  /// Creates a [PillarRegisteredSuccessAnimation].
  const PillarRegisteredSuccessAnimation({super.key});

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

/// The sentence that says the Pillar is registered, with the controller's
/// name in it as a link.
class _SuccessMessage extends StatefulWidget {
  const _SuccessMessage({required this.onControllerPressed});

  final VoidCallback onControllerPressed;

  @override
  State<_SuccessMessage> createState() => _SuccessMessageState();
}

class _SuccessMessageState extends State<_SuccessMessage> {
  late final TapGestureRecognizer _controllerTap = TapGestureRecognizer()
    ..onTap = () => widget.onControllerPressed();

  @override
  void dispose() {
    _controllerTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final TextStyle? text = Theme.of(context).textTheme.titleMedium;
    // One whole message, so a translation orders it as its language does.
    // The name went in as the placeholder; the message is cut where it came
    // out, and the link is drawn there.
    final String message = context.l10n.createPillarSuccessMessage(
      _kControllerName,
    );
    final int at = message.indexOf(_kControllerName);
    final String before = at < 0 ? message : message.substring(0, at);
    final String after = at < 0
        ? ''
        : message.substring(at + _kControllerName.length);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 50),
      margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 50),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
      ),
      child: Text.rich(
        TextSpan(
          style: text,
          children: <InlineSpan>[
            TextSpan(text: before),
            if (at >= 0) ...<InlineSpan>[
              TextSpan(
                text: _kControllerName,
                style: TextStyle(
                  color: tokens.znnInk,
                  decoration: TextDecoration.underline,
                ),
                recognizer: _controllerTap,
                mouseCursor: SystemMouseCursors.click,
              ),
              WidgetSpan(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 4),
                  child: Icon(
                    MaterialCommunityIcons.link,
                    size: 20,
                    color: tokens.znnInk,
                  ),
                ),
              ),
            ],
            TextSpan(text: after),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
