import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';

/// The height of the strip on top, as on the Accelerator page.
const double _kStripHeight = 88;

/// The least the list row may have before the page scrolls: the search
/// field, the header and four rows.
const double _kListMinHeight = 380;

/// Tokens: the list of every token on the network is the page. A strip on
/// top holds what the address has and the one primary action, creating a
/// token; the address's balances stand beside the list.
///
/// Favourite, mint, burn and transfer ownership are actions on a token's
/// row, not cards of their own.
class TokensTabChild extends StatelessWidget {
  /// Creates a new instance
  const TokensTabChild({
    required this._onStepperNotificationSeeMorePressed,
    super.key,
  });
  final VoidCallback _onStepperNotificationSeeMorePressed;

  @override
  Widget build(BuildContext context) {
    return PageGrid(
      rows: <PageRow>[
        PageRow.fixed(_kStripHeight, <PageCell>[
          PageCell(
            CreateTokenCard(
              onStepperNotificationSeeMorePressed:
                  _onStepperNotificationSeeMorePressed,
            ),
          ),
        ]),
        const PageRow.fill(<PageCell>[
          PageCell(TokensCard(), flex: 5),
          PageCell(TokenBalanceCard(), flex: 2),
        ], height: _kListMinHeight),
      ],
    );
  }
}
