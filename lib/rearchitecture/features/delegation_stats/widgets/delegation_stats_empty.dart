import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

/// The delegation of an address that backs no pillar.
///
/// It keeps the populated card's first line, so the card reads the same way
/// with and without a delegation.
class DelegationStatsEmpty extends StatelessWidget {
  /// Creates a DelegationEmpty object.
  const DelegationStatsEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    return SingleChildScrollView(
      padding: kCardBodyPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Figure(
            label: 'Delegated to',
            value: 'None yet',
            valueStyle: cardValueStyle(context).copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: tokens.faint,
            ),
          ),
          SizedBox(height: tokens.cardGap),
          Text('Pick a pillar below.', style: cardDimStyle(context)),
        ],
      ),
    );
  }
}
