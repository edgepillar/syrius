import 'package:material_ui/material_ui.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/navigation_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';

/// Where the Zenon community is: sites, explorers, social and documents.
/// Each row opens its link in the browser.
class CommunityCard extends StatelessWidget {
  const CommunityCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Community',
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SettingGroupLabel('Websites'),
            const _Link(MaterialCommunityIcons.home, 'Zenon Network', kWebsite),
            const _Link(
              MaterialCommunityIcons.forum,
              'Community forum',
              kOrgCommunityForum,
            ),
            const _Link(MaterialCommunityIcons.tools, 'Zenon Tools', kTools),
            const _Link(
              MaterialCommunityIcons.web,
              'Zenon ORG',
              kOrgCommunityWebsite,
            ),
            const _Link(
              MaterialCommunityIcons.lan,
              'Zenon Hub',
              kHubCommunityWebsite,
            ),
            const SettingGroupLabel('Explorers'),
            const _Link(Icons.explore_outlined, 'Explorer', kExplorer),
            const _Link(
              Icons.explore_outlined,
              'Hub explorer',
              kHubCommunityExplorer,
            ),
            const SettingGroupLabel('Social'),
            const _Link(MaterialCommunityIcons.twitter, 'Twitter', kTwitter),
            const _Link(MaterialCommunityIcons.discord, 'Discord', kDiscord),
            const _Link(Icons.telegram, 'Telegram', kTelegram),
            const _Link(Icons.article_outlined, 'Medium', kMedium),
            const _Link(MaterialCommunityIcons.github, 'GitHub', kGithub),
            const _Link(
              MaterialCommunityIcons.bitcoin,
              'Bitcoin Talk',
              kBitcoinTalk,
            ),
            const _Link(MaterialCommunityIcons.reddit, 'Reddit', kReddit),
            const _Link(MaterialCommunityIcons.youtube, 'YouTube', kYoutube),
            const SettingGroupLabel('Documentation'),
            const _Link(
              MaterialCommunityIcons.book_open_page_variant,
              'Wiki',
              kWiki,
            ),
            const _Link(
              MaterialCommunityIcons.book_multiple,
              'Community wiki',
              kOrgCommunityWiki,
            ),
            const _Link(
              MaterialCommunityIcons.file_document,
              'Whitepaper',
              kWhitepaper,
            ),
          ],
        ),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link(this.icon, this.title, this.url);

  final IconData icon;
  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: url,
      waitDuration: Durations.long2,
      child: InkWell(
        onTap: () => NavigationUtils.openUrl(url),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: AppColors.faint),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const Icon(Icons.open_in_new, size: 14, color: AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}
