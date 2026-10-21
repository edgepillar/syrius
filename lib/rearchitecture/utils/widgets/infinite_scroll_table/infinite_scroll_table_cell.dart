part of 'infinite_scroll_table.dart';

/// A cell in a table
///
/// It's based on the [Expanded] widgets, so the [child] will be forced to
/// occupy the entire available space. The space in the row is determined by
/// the [flex].
class InfiniteScrollTableCell extends StatelessWidget {
  /// Creates a new instance.
  const InfiniteScrollTableCell({
    required this.child,
    this.flex = 1,
    super.key,
  });

  /// A constructor used when the main child widget is a [Text].
  ///
  /// If [tooltipMessage] is not empty, then a tooltip message will appear
  /// If [textToBeCopied] is not null, then the cell will also have a
  /// [CopyToClipboardButton] widget that copies to clipboard the
  /// [textToBeCopied] - which is not already the same as the [content] value.
  ///
  /// [textDirection] is left to right for an address, a hash, an amount: a
  /// right-to-left interface otherwise swaps the two ends of a shortened
  /// hash that is all digits. The row still puts the text at the app's
  /// start. Null, for words, follows the app.
  factory InfiniteScrollTableCell.withText({
    required String content,
    String? textToBeCopied,
    TextStyle? textStyle,
    int flex = 1,
    String tooltipMessage = '',
    TextDirection? textDirection,
  }) => InfiniteScrollTableCell(
    flex: flex,
    child: Row(
      children: <Widget>[
        Flexible(
          child: Tooltip(
            message: tooltipMessage,
            child: Text(
              content,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textDirection: textDirection,
              style: textStyle,
            ),
          ),
        ),
        if (textToBeCopied != null)
          Row(
            children: <Widget>[
              CopyToClipboardButton(
                textToBeCopied,
                iconSize: 15,
              ),
              const SizedBox(
                width: 10,
              ),
            ],
          ),
      ],
    ),
  );

  /// A constructor that helps creating cell content starting from an [address].
  ///
  /// Useful especially for styling cell content when the address is one of the
  /// user's wallet
  factory InfiniteScrollTableCell.textFromAddress({
    required Address address,
    bool isStakeAddress = false,
    bool isShortVersion = true,
    int flex = 2,
  }) {
    final bool hasLabel = kAddressLabelMap[address.toString()] != null;
    final bool isOwn =
        address.isEmbedded() ||
        (isStakeAddress && address.toString() == kSelectedAddress);

    final String content = hasLabel
        ? ZenonAddressUtils.getLabel(address.toString())
        : isShortVersion
        ? address.toShortString()
        : address.toString();

    // The green is text, so it takes the theme's ZNN ink: the brand green is
    // too pale to read on the light theme's white card. The factory has no
    // context, hence the Builder.
    return InfiniteScrollTableCell(
      flex: flex,
      child: Builder(
        builder: (BuildContext context) {
          final TextStyle? ownStyle = isOwn
              ? TextStyle(
                  color: AppTokens.of(context).znnInk,
                  fontWeight: FontWeight.bold,
                )
              : null;
          final TextStyle? textStyle = hasLabel
              ? ownStyle
              : monoStyle(ownStyle);

          return InfiniteScrollTableCell.withText(
            content: content,
            flex: flex,
            textStyle: textStyle,
            tooltipMessage: address.toString(),
            textToBeCopied: address.toString(),
            // An address runs left to right in every language; a label is
            // the user's own words and follows the app.
            textDirection: hasLabel ? null : TextDirection.ltr,
          ).child;
        },
      ),
    );
  }

  /// The child that represents the content of the cell
  final Widget child;

  /// Represents the space amount in a row assign to the cell
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: child,
    );
  }
}
