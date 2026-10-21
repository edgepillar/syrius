import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';

/// The send form before the first balances arrive.
class SendEmpty extends StatelessWidget {
  /// Creates new instance.
  const SendEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return const CardLoading();
  }
}
