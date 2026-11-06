import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';

/// A simple button that helps paste content inside a [TextField] or
/// [TextFormField]
class PasteContentButton extends StatefulWidget {
  /// Creates a button that pastes clipboard text into [controller].
  const PasteContentButton({
    required TextEditingController controller,
    super.key,
  }) : _controller = controller;

  final TextEditingController _controller;

  @override
  State<PasteContentButton> createState() => _PasteContentButtonState();
}

class _PasteContentButtonState extends State<PasteContentButton> {
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    widget._controller.addListener(_invalidatePaste);
  }

  @override
  void didUpdateWidget(PasteContentButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget._controller, widget._controller)) {
      oldWidget._controller.removeListener(_invalidatePaste);
      _invalidatePaste();
      widget._controller.addListener(_invalidatePaste);
    }
  }

  @override
  void dispose() {
    widget._controller.removeListener(_invalidatePaste);
    super.dispose();
  }

  void _invalidatePaste() => _revision++;

  void _paste() {
    final TextEditingController controller = widget._controller;
    final int revision = ++_revision;
    ClipboardUtils.pasteToClipboard(
      callback: (String value) {
        // A late clipboard answer must not replace a newer edit or field.
        if (!mounted ||
            revision != _revision ||
            !identical(controller, widget._controller)) {
          return;
        }
        controller.text = value;
      },
    );
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.l10n.securitySettingsPaste,
    onPressed: _paste,
    icon: const Icon(Icons.content_paste),
  );
}
