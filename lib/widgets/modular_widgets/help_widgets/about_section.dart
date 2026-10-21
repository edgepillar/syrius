import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/help_widgets/about_card.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/help_widgets/community_card.dart';

/// What the Help page was: about this wallet, the update check and the
/// community's links. It is the About section of Settings.
class AboutSection extends StatelessWidget {
  /// Creates the section.
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageGrid(
      rows: <PageRow>[
        PageRow.fill(<PageCell>[
          PageCell(AboutCard(), flex: 3),
          PageCell(CommunityCard(), flex: 2),
        ]),
      ],
    );
  }
}
