import 'package:material_ui/material_ui.dart';
import 'package:reown_walletkit/reown_walletkit.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/wallet_connect/wallet_connect_sessions_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/extensions.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

/// The sites connected over WalletConnect: one row per live session.
class WalletConnectSessionsCard extends StatefulWidget {
  const WalletConnectSessionsCard({super.key});

  @override
  State<WalletConnectSessionsCard> createState() =>
      _WalletConnectSessionsCardState();
}

class _WalletConnectSessionsCardState extends State<WalletConnectSessionsCard> {
  final WalletConnectSessionsBloc _sessionsBloc = sl
      .get<WalletConnectSessionsBloc>();

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'WalletConnect',
      actions: <Widget>[
        IconButton(
          tooltip: 'Refresh',
          iconSize: 18,
          icon: const Icon(Icons.refresh, color: AppColors.faint),
          onPressed: _sessionsBloc.refreshResults,
        ),
      ],
      child: _buildSessionsTable(),
    );
  }

  Widget _buildSessionsTable() {
    return InfiniteScrollTable<SessionData>(
      disposeBloc: false,
      bloc: _sessionsBloc,
      headerColumns: const <InfiniteScrollTableHeaderColumn>[
        InfiniteScrollTableHeaderColumn(
          columnName: 'Site',
        ),
        InfiniteScrollTableHeaderColumn(
          columnName: 'URL',
          flex: 2,
        ),
        InfiniteScrollTableHeaderColumn(
          columnName: 'Pairing',
        ),
        InfiniteScrollTableHeaderColumn(
          columnName: 'Session',
        ),
        InfiniteScrollTableHeaderColumn(
          columnName: 'Expires',
        ),
        InfiniteScrollTableHeaderColumn(
          columnName: 'Acked',
        ),
      ],
      generateRowCells: (SessionData sessionData, bool isSelected) {
        return <Widget>[
          InfiniteScrollTableCell.withText(
            context,
            sessionData.peer.metadata.name,
          ),
          InfiniteScrollTableCell(
            _buildTableUrlWidget(sessionData.peer.metadata.url),
            flex: 2,
          ),
          if (isSelected)
            InfiniteScrollTableCell.withMarquee(
              sessionData.pairingTopic,
            )
          else
            InfiniteScrollTableCell.withText(
              context,
              sessionData.pairingTopic.short,
              textStyle: settingMonoStyle(context),
            ),
          if (isSelected)
            InfiniteScrollTableCell.withMarquee(
              sessionData.topic,
            )
          else
            InfiniteScrollTableCell.withText(
              context,
              sessionData.topic.short,
              textStyle: settingMonoStyle(context),
            ),
          InfiniteScrollTableCell.withText(
            context,
            _formatExpiryDateTime(sessionData.expiry),
            textStyle: settingMonoStyle(context),
          ),
          InfiniteScrollTableCell.withText(
            context,
            sessionData.acknowledged ? 'Yes' : 'No',
          ),
        ];
      },
    );
  }

  Widget _buildTableUrlWidget(String? peerUrl) {
    return Row(
      children: <Widget>[
        Flexible(
          child: Text(
            peerUrl ?? '-',
            overflow: TextOverflow.ellipsis,
            style: settingMonoStyle(context),
          ),
        ),
        if (peerUrl != null) LinkIcon(url: peerUrl),
      ],
    );
  }

  String _formatExpiryDateTime(int expirySeconds) =>
      FormatUtils.formatDayMonthTime(expirySeconds * 1000);
}
