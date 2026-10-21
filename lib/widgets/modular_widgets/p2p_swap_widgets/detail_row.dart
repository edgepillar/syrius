import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/copy_to_clipboard_button.dart';

/// One line of a swap's details: a label, and its value in mono.
///
/// Every value here is an id, an address, a hash or a countdown, so the
/// value is always mono and the copy button copies [value] in full even when
/// [valueToShow] is a shortened form of it.
class DetailRow extends StatelessWidget {
  /// Creates a detail line.
  const DetailRow({
    required this.label,
    required this.value,
    this.valueToShow,
    this.prefixWidget,
    this.canBeCopied = true,
    super.key,
  });

  /// What the value is.
  final String label;

  /// The full value; what the copy button copies.
  final String value;

  /// A shorter form of [value] to show in its place.
  final String? valueToShow;

  /// A mark shown before the value.
  final Widget? prefixWidget;

  /// Whether the line ends in a copy button.
  final bool canBeCopied;

  @override
  Widget build(BuildContext context) {
    final TextStyle dim = Theme.of(
      context,
    ).textTheme.titleMedium!.copyWith(fontSize: 13);
    return SizedBox(
      height: 32,
      child: Row(
        children: <Widget>[
          Text(label, style: dim),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (prefixWidget != null) ...<Widget>[
                  prefixWidget!,
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    valueToShow ?? value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: monoStyle(dim),
                  ),
                ),
                if (canBeCopied) CopyToClipboardButton(value, iconSize: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
