import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/navigation_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

/// The network as the connected node sees it: its latest momentum and how
/// many peers it has.
class GeneralWidget extends StatefulWidget {
  const GeneralWidget({super.key});

  @override
  State createState() {
    return GeneralWidgetState();
  }
}

class GeneralWidgetState extends State<GeneralWidget> {
  GeneralStatsBloc? _generalStatsBloc;

  @override
  void initState() {
    _generalStatsBloc = GeneralStatsBloc();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Network',
      child: _buildStreamBuilder(),
    );
  }

  Widget _buildBody(GeneralStats generalStats) {
    final ThemeData theme = Theme.of(context);
    final TextStyle figure = monoStyle(
      theme.textTheme.headlineSmall,
    ).copyWith(fontSize: 18, fontWeight: FontWeight.w500);
    final String hash = generalStats.frontierMomentum.hash.toString();
    final int peers = generalStats.networkInfo.peers.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Wrap(
            spacing: 28,
            runSpacing: 10,
            children: <Widget>[
              _Figure(
                label: 'Momentum',
                child: NumberAnimation(
                  end: generalStats.frontierMomentum.height,
                  isInt: true,
                  style: figure,
                ),
              ),
              _Figure(
                label: 'Peers',
                child: Text(
                  '$peers',
                  style: figure.copyWith(
                    color: peers == 0 ? AppColors.warn : null,
                  ),
                ),
              ),
              _Figure(
                label: 'Time',
                child: Text(
                  FormatUtils.formatTimeSeconds(
                    generalStats.frontierMomentum.timestamp * 1000,
                  ),
                  style: figure,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Tooltip(
                  message: hash,
                  child: Text(
                    hash,
                    overflow: TextOverflow.ellipsis,
                    style: settingMonoStyle(context),
                  ),
                ),
              ),
              CopyToClipboardButton(hash, iconSize: 16),
              IconButton(
                tooltip: 'Open in explorer',
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                icon: const Icon(Icons.open_in_new, color: AppColors.faint),
                onPressed: () => NavigationUtils.openUrl(
                  '$kExplorer/momentum/${generalStats.frontierMomentum.hash}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreamBuilder() {
    return StreamBuilder<GeneralStats>(
      stream: _generalStatsBloc!.stream,
      builder: (_, AsyncSnapshot<GeneralStats> snapshot) {
        if (snapshot.hasData) {
          return _buildBody(snapshot.data!);
        } else if (snapshot.hasError) {
          return QuietNote.error(snapshot.error!);
        }
        return const QuietNote.loading();
      },
    );
  }

  @override
  void dispose() {
    _generalStatsBloc!.dispose();
    super.dispose();
  }
}

/// A ledger label over a value that is a widget rather than a string, so a
/// counting number fits where the shared `Figure` takes text.
class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label.toUpperCase(), style: ledgerLabelStyle(context)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}
