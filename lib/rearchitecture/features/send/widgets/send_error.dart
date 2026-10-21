import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/exceptions/exceptions.dart';

/// A widget that display an error message
class SendError extends StatelessWidget {
  /// Creates a new instance.
  const SendError({required this.error, super.key});

  /// The object containing the error message
  final SyriusException error;

  @override
  Widget build(BuildContext context) {
    return CardNote.error(error);
  }
}
