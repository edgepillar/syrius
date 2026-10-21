import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';

/// The choice between a 24 and a 12 word seed, as a two-part switch.
class SeedChoice extends StatefulWidget {
  /// Creates the switch.
  const SeedChoice({
    required this.onSeed24Selected,
    required this.onSeed12Selected,
    required this.isSeed12Selected,
    super.key,
  });

  /// Called when 24 words is chosen.
  final VoidCallback onSeed24Selected;

  /// Called when 12 words is chosen.
  final VoidCallback onSeed12Selected;

  /// Which one is chosen.
  final bool isSeed12Selected;

  @override
  State<SeedChoice> createState() => _SeedChoiceState();
}

class _SeedChoiceState extends State<SeedChoice> {
  bool _seed24Hovered = false;
  bool _seed12Hovered = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: lineColorOf(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildOption(
            asset: 'assets/svg/ic_seed_24.svg',
            label: context.l10n.seedChoiceWordsLabel(24),
            selected: !widget.isSeed12Selected,
            hovered: _seed24Hovered,
            onHover: (bool x) => setState(() => _seed24Hovered = x),
            onTap: () {
              setState(() {
                widget.onSeed24Selected();
              });
            },
          ),
          _buildOption(
            asset: 'assets/svg/ic_seed_12.svg',
            label: context.l10n.seedChoiceWordsLabel(12),
            selected: widget.isSeed12Selected,
            hovered: _seed12Hovered,
            onHover: (bool x) => setState(() => _seed12Hovered = x),
            onTap: () {
              setState(() {
                widget.onSeed12Selected();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required String asset,
    required String label,
    required bool selected,
    required bool hovered,
    required ValueChanged<bool> onHover,
    required VoidCallback onTap,
  }) {
    final ThemeData theme = Theme.of(context);
    final Color fg = theme.textTheme.bodyLarge!.color!;
    final Color tone = selected || hovered ? fg : dimColorOf(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: FocusableActionDetector(
        onShowHoverHighlight: onHover,
        child: AnimatedContainer(
          duration: Durations.short3,
          curve: Easing.standard,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? lineColorOf(context) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SvgPicture.asset(
                asset,
                height: 13,
                colorFilter: ColorFilter.mode(tone, BlendMode.srcIn),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: kSansFontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: tone,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
