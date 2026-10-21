import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:open_filex/open_filex.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/metadata.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// What this wallet is and what it runs on: versions, the node, this
/// computer and where the files are. The update check is in its title row.
///
/// It used to be 25 collapsed panels, one value behind each. They are rows
/// now, all visible, and the wallet's own rows no longer wait for the node.
class AboutCard extends StatefulWidget {
  const AboutCard({super.key});

  @override
  State createState() {
    return AboutCardState();
  }
}

class AboutCardState extends State<AboutCard> {
  GeneralStatsBloc? _generalStatsBloc;

  @override
  void initState() {
    _generalStatsBloc = GeneralStatsBloc();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'About',
      actions: <Widget>[
        SecondaryAction(
          child: OutlinedButton(
            key: const Key('about_check_update'),
            onPressed: () => NavigationUtils.openUrl(kGithubReleasesLink),
            child: const Text('Check for updates'),
          ),
        ),
        const SizedBox(width: 8),
      ],
      child: StreamBuilder<GeneralStats>(
        stream: _generalStatsBloc!.stream,
        builder: (_, AsyncSnapshot<GeneralStats> snapshot) => _buildBody(
          snapshot.data,
          snapshot.hasError
              ? QuietNote.error(snapshot.error!).text
              : 'Loading',
        ),
      ),
    );
  }

  Widget _buildBody(GeneralStats? stats, String waiting) {
    final ThemeData theme = Theme.of(context);
    String node(String Function(GeneralStats s) read) =>
        stats == null ? waiting : read(stats);
    // Twenty-odd rows each with a copy button: the buttons are made small
    // here so the rows sit close.
    return Theme(
      data: theme.copyWith(
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(30, 30),
            padding: const EdgeInsets.all(6),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SettingGroupLabel('Syrius'),
            const _InfoRow('Version', kWalletVersion),
            _InfoRow('Wallet type', kWalletFile?.walletType ?? ''),
            const _InfoRow('SDK', znnSdkVersion),
            const _InfoRow('Branch', gitBranchName),
            const _InfoRow('Commit', gitCommitHash),
            const _InfoRow('Commit message', gitCommitMessage),
            const _InfoRow('Commit date', gitCommitDate),
            _InfoRow(
              'Origin',
              gitOriginUrl,
              openTooltip: 'Open link',
              onOpen: () => NavigationUtils.openUrl(gitOriginUrl),
            ),
            const SettingGroupLabel('Node'),
            _InfoRow(
              'Chain identifier',
              node(
                (GeneralStats s) =>
                    s.frontierMomentum.chainIdentifier.toString(),
              ),
            ),
            _InfoRow(
              'Client chain identifier',
              getChainIdentifier().toString(),
            ),
            _InfoRow(
              'Build',
              node((GeneralStats s) => s.processInfo.version),
            ),
            _InfoRow(
              'Commit',
              node((GeneralStats s) => s.processInfo.commit),
            ),
            _InfoRow(
              'Kernel',
              node((GeneralStats s) => s.osInfo.kernelVersion),
            ),
            _InfoRow(
              'Operating system',
              node((GeneralStats s) => s.osInfo.os),
            ),
            _InfoRow(
              'Platform',
              node((GeneralStats s) => s.osInfo.platform),
            ),
            _InfoRow(
              'Platform version',
              node((GeneralStats s) => s.osInfo.platformVersion),
            ),
            _InfoRow(
              'Processors',
              node((GeneralStats s) => s.osInfo.numCPU.toString()),
            ),
            const SettingGroupLabel('This computer'),
            _InfoRow('Hostname', Platform.localHostname),
            _InfoRow('Local IP address', kLocalIpAddress ?? ''),
            _InfoRow('Operating system', Platform.operatingSystem),
            _InfoRow('Version', Platform.operatingSystemVersion),
            _InfoRow('Processors', Platform.numberOfProcessors.toString()),
            const SettingGroupLabel('Paths'),
            _buildPathRow('Zenon data', znnDefaultPaths.main.absolute.path),
            _buildPathRow('Cache', znnDefaultPaths.cache.absolute.path),
            _buildPathRow('Wallet', znnDefaultPaths.wallet.absolute.path),
          ],
        ),
      ),
    );
  }

  Widget _buildPathRow(String label, String path) {
    return _InfoRow(
      label,
      path,
      openTooltip: 'Open folder',
      onOpen: () async {
        await OpenFilex.open(path);
      },
    );
  }

  @override
  void dispose() {
    _generalStatsBloc!.dispose();
    super.dispose();
  }
}

/// A name and a value, the value mono and copyable.
class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.onOpen, this.openTooltip});

  final String label;
  final String value;
  final VoidCallback? onOpen;
  final String? openTooltip;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 1, 10, 1),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 170,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: settingHintStyle(context),
            ),
          ),
          Expanded(
            child: Tooltip(
              message: value,
              child: Text(
                value.isEmpty ? '-' : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: settingMonoStyle(context).copyWith(
                  color: theme.textTheme.bodyLarge!.color,
                ),
              ),
            ),
          ),
          if (value.isNotEmpty) CopyToClipboardButton(value, iconSize: 14),
          if (onOpen != null)
            IconButton(
              tooltip: openTooltip,
              iconSize: 14,
              icon: const Icon(Icons.open_in_new, color: AppColors.faint),
              onPressed: onOpen,
            ),
        ],
      ),
    );
  }
}
