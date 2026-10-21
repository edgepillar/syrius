import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';

/// The rule a new wallet password must meet, said once.
const String kPasswordRuleHint =
    'At least 8 characters, with an upper and a lower case letter, a number '
    'and a symbol';

/// The frame of every screen between the welcome and the wallet: a quiet
/// "Back" and the step position at the top, one centred column, and the
/// step's one primary action at the bottom.
///
/// The column scrolls when the window is too short for it; the top and the
/// action stay where they are.
class OnboardingScaffold extends StatelessWidget {
  /// Creates the frame.
  const OnboardingScaffold({
    required this.title,
    required this.child,
    this.subtitle,
    this.help,
    this.step,
    this.steps = 5,
    this.primary,
    this.onBack,
    this.maxWidth = 440,
    this.header,
    super.key,
  });

  /// The heading.
  final String title;

  /// One short line under the heading.
  final String? subtitle;

  /// More about the step, behind a help mark after [subtitle].
  final String? help;

  /// This step's position, from 1; no position shown when null.
  final int? step;

  /// How many steps there are.
  final int steps;

  /// The step's content.
  final Widget child;

  /// The one main action, under the column.
  final Widget? primary;

  /// Goes back a step; no "Back" when null.
  final VoidCallback? onBack;

  /// The widest the column gets.
  final double maxWidth;

  /// Above the heading, full width: the app's notification banner.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                height: 40,
                child: Stack(
                  children: <Widget>[
                    if (step != null)
                      Center(
                        child: OnboardingStepPosition(
                          step: step!,
                          steps: steps,
                        ),
                      ),
                    if (onBack != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: onBack,
                          style: quietButtonStyle(context),
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Back'),
                        ),
                      ),
                  ],
                ),
              ),
              ?header,
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: RiseIn(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium!.copyWith(
                                fontSize: 24,
                                height: 1.2,
                              ),
                            ),
                            if (subtitle != null) ...<Widget>[
                              const SizedBox(height: 8),
                              _buildSubtitle(context),
                            ],
                            const SizedBox(height: 28),
                            child,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (primary != null) Center(child: primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    final Text line = Text(
      subtitle!,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 14, height: 1.45, color: dimColorOf(context)),
    );
    if (help == null) return line;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(child: line),
        const SizedBox(width: 6),
        Tooltip(
          message: help,
          child: const Icon(
            Icons.help_outline,
            size: 16,
            color: AppColors.faint,
          ),
        ),
      ],
    );
  }
}

/// Where the person is in the steps: "STEP 2 OF 5" over a row of short
/// bars, the ones done green. The current bar fills as the step opens.
class OnboardingStepPosition extends StatelessWidget {
  /// Creates the position for [step] of [steps].
  const OnboardingStepPosition({
    required this.step,
    required this.steps,
    super.key,
  });

  /// The current step, from 1.
  final int step;

  /// How many there are.
  final int steps;

  @override
  Widget build(BuildContext context) {
    final Color rest = lineColorOf(context);
    final int shown = step.clamp(0, steps);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'STEP $shown OF $steps',
          style: ledgerLabelStyle(context),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 1; i <= steps; i++) ...<Widget>[
              if (i > 1) const SizedBox(width: 4),
              SizedBox(
                width: 28,
                height: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: i < shown ? AppColors.znnColor : rest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: i == shown
                      ? TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: Durations.medium4,
                          curve: Easing.emphasizedDecelerate,
                          builder: (_, double t, _) => FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: t,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.znnColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
