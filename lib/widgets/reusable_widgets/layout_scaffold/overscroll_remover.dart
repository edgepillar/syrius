import 'package:material_ui/material_ui.dart';

class RemoveOverscrollEffect extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details,) {
    return child;
  }
}
