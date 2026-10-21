import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/exceptions/exceptions.dart';

/// The delegation when it could not be read.
///
/// An address that backs no pillar is not an error to the person, although
/// the bloc reports it as one; the card shows `DelegationStatsEmpty` for it.
class DelegationStatsError extends StatelessWidget {
  /// Creates a DelegationError object.
  const DelegationStatsError({required this.error, super.key});

  /// The object that holds the representation of the error
  final SyriusException error;

  @override
  Widget build(BuildContext context) {
    return CardNote.error(error);
  }
}
