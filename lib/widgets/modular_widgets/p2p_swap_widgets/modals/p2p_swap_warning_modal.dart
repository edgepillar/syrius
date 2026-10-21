import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/base_modal.dart';

/// Shown once, before the first swap: P2P swaps are experimental.
class P2PSwapWarningModal extends StatelessWidget {
  /// Creates the warning. [onAccepted] runs when the person continues.
  const P2PSwapWarningModal({
    required this.onAccepted,
    super.key,
  });

  /// Called when the person continues.
  final VoidCallback onAccepted;

  @override
  Widget build(BuildContext context) {
    return BaseModal(
      title: 'Before you swap',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 20),
          Text(
            'P2P swaps are experimental and funds can be lost. Split a large '
            'swap into smaller ones.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge!.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            key: const Key('p2p_warning_continue'),
            onPressed: onAccepted,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
