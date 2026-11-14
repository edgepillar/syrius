import 'package:material_ui/material_ui.dart';

/// Lets the entry card select its status presentation within the same shell.
class EntryStatusVisibility extends Notification {
  /// Normal entry shows status; password errors and the open picker hide it.
  const EntryStatusVisibility({required this.visible});

  /// Changes presentation without replacing the page or its status owner.
  final bool visible;
}
