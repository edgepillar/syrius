import 'dart:io';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final Map<String, String> _referenceSymbols = <String, String>{
  for (final RegExpMatch entry in RegExp(
    '<symbol id="([^"]+)" viewBox="0 0 24 24">(.*?)</symbol>',
    dotAll: true,
  ).allMatches(File('mockups/redesign/src/00-head.html').readAsStringSync()))
    entry.group(1)!: entry.group(2)!,
};

/// Checks the original HTML's path, painted size and owning control's ink.
void expectMockupSymbol(
  WidgetTester tester, {
  required Finder within,
  required String symbol,
  required double size,
  Color? color,
}) {
  final String? content = _referenceSymbols[symbol];
  expect(content, isNotNull);
  // Loader equality compares the actual source without private field access.
  final SvgStringLoader expected = SvgStringLoader(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
    'fill="none" stroke="currentColor" stroke-width="1.8" '
    'stroke-linecap="round" stroke-linejoin="round">$content</svg>',
  );
  final Finder graphic = find.descendant(
    of: within,
    matching: find.byWidgetPredicate(
      (Widget widget) => widget is SvgPicture && widget.bytesLoader == expected,
    ),
  );
  expect(graphic, findsOneWidget);
  final SvgPicture svg = tester.widget<SvgPicture>(graphic);
  expect(tester.getSize(graphic), Size(size, size));
  expect(
    svg.colorFilter,
    ColorFilter.mode(
      color ?? IconTheme.of(tester.element(graphic)).color!,
      BlendMode.srcIn,
    ),
  );
  expect(svg.excludeFromSemantics, isTrue);
  expect(svg.matchTextDirection, isFalse);
}
