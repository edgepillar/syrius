import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/ltr.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';

// TODO(maznnwell): to be refactored, the controller should be just Text
class DisabledAddressField extends StatelessWidget {

  const DisabledAddressField(
    this._addressController, {
    this.contentLeftPadding = 8.0,
    super.key,
  });
  final TextEditingController _addressController;
  final double contentLeftPadding;

  @override
  Widget build(BuildContext context) {
    // The field shows the address's label, the address itself is the
    // tooltip. A label in Latin letters ("Address 1") reads left to right in
    // every language; one written right to left keeps the app's direction.
    // Either way it stands at the app's start, with the padding on that side.
    final String? label = kAddressLabelMap[_addressController.text];

    return Tooltip(
      message: _addressController.text,
      child: TextField(
        enabled: false,
        controller: TextEditingController(
          text: label,
        ),
        textDirection: ltrUnlessRtl(label ?? ''),
        textAlign: ltrTextAlign(context, TextAlign.start),
        decoration: InputDecoration(
          contentPadding: EdgeInsetsDirectional.only(
            start: contentLeftPadding,
          ),
        ),
      ),
    );
  }
}
