import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';

/// A widget that display a loading indicator.
class SendLoading extends StatelessWidget {
  /// Creates a new instance.
  const SendLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const CardLoading();
  }
}
