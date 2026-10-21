import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/exceptions/exceptions.dart';

/// A widget that displays an error message
class ReceiveError extends StatelessWidget {
  /// Creates a new instance.
  const ReceiveError({required this.error, super.key});

  /// The field that holds the error message.
  final SyriusException error;

  @override
  Widget build(BuildContext context) {
    return CardNote.error(error.message);
  }
}
