import 'package:material_ui/material_ui.dart';
import 'package:reown_walletkit/reown_walletkit.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/wallet_connect/wallet_connect_pairings_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/wallet_connect/wallet_connect_sessions_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/services/i_web3wallet_service.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/extensions.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

/// WalletConnect pairings: the secure link a site made first, under which
/// its sessions run. Removing one ends its sessions too.
class WalletConnectPairingsCard extends StatefulWidget {
  const WalletConnectPairingsCard({super.key});

  @override
  State<WalletConnectPairingsCard> createState() =>
      _WalletConnectPairingsCardState();
}

class _WalletConnectPairingsCardState extends State<WalletConnectPairingsCard> {
  final WalletConnectPairingsBloc _pairingsBloc = sl
      .get<WalletConnectPairingsBloc>();

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Pairings',
      actions: <Widget>[
        IconButton(
          tooltip: 'Refresh',
          iconSize: 18,
          icon: const Icon(Icons.refresh, color: AppColors.faint),
          onPressed: _pairingsBloc.refreshResults,
        ),
      ],
      child: _buildPairingsTable(),
    );
  }

  Widget _buildPairingsTable() {
    return InfiniteScrollTable<PairingInfo>(
      disposeBloc: false,
      bloc: _pairingsBloc,
      headerColumns: const <InfiniteScrollTableHeaderColumn>[
        InfiniteScrollTableHeaderColumn(
          columnName: 'Site',
        ),
        InfiniteScrollTableHeaderColumn(
          columnName: 'URL',
          flex: 2,
        ),
        InfiniteScrollTableHeaderColumn(
          columnName: 'Topic',
        ),
        InfiniteScrollTableHeaderColumn(
          columnName: 'Expires',
        ),
        InfiniteScrollTableHeaderColumn(
          columnName: 'Active',
        ),
        InfiniteScrollTableHeaderColumn(
          columnName: '',
        ),
      ],
      generateRowCells: (PairingInfo pairingInfo, bool isSelected) {
        return <Widget>[
          InfiniteScrollTableCell.withText(
            context,
            pairingInfo.peerMetadata?.name ?? '-',
          ),
          InfiniteScrollTableCell(
            _buildTableUrlWidget(pairingInfo),
            flex: 2,
          ),
          if (isSelected)
            InfiniteScrollTableCell.withMarquee(
              pairingInfo.topic,
            )
          else
            InfiniteScrollTableCell.withText(
              context,
              pairingInfo.topic.short,
              textStyle: settingMonoStyle(context),
            ),
          InfiniteScrollTableCell.withText(
            context,
            _formatExpiryDateTime(pairingInfo.expiry),
            textStyle: settingMonoStyle(context),
          ),
          InfiniteScrollTableCell.withText(
            context,
            pairingInfo.active ? 'Yes' : 'No',
          ),
          InfiniteScrollTableCell(
            _buildDeactivatePairingIcon(pairingInfo),
          ),
        ];
      },
    );
  }

  Widget _buildDeactivatePairingIcon(PairingInfo pairingInfo) {
    return Align(
      alignment: Alignment.centerRight,
      child: IconButton(
        tooltip: 'Remove pairing',
        visualDensity: VisualDensity.compact,
        iconSize: 16,
        icon: const Icon(Icons.close, color: AppColors.faint),
        onPressed: () => _onDeactivatePairingIconPressed(pairingInfo),
      ),
    );
  }

  Widget _buildTableUrlWidget(PairingInfo pairingInfo) {
    final String? url = pairingInfo.peerMetadata?.url;
    return Row(
      children: <Widget>[
        Flexible(
          child: Text(
            url ?? '-',
            overflow: TextOverflow.ellipsis,
            style: settingMonoStyle(context),
          ),
        ),
        if (url != null) LinkIcon(url: url),
      ],
    );
  }

  String _formatExpiryDateTime(int expirySeconds) =>
      FormatUtils.formatDayMonthTime(expirySeconds * 1000);

  Future<void> _onDeactivatePairingIconPressed(PairingInfo pairingInfo) async {
    try {
      await sl<IWeb3WalletService>().deactivatePairing(
        topic: pairingInfo.topic,
      );
      _pairingsBloc.refreshResults();
      sl<WalletConnectSessionsBloc>().refreshResults();
    } catch (e) {
      await sl<NotificationsBloc>().addErrorNotification(
        e,
        'Error while deactivating pair',
      );
    }
  }
}
