import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The peers the connected node talks to.
class PeersWidget extends StatefulWidget {
  const PeersWidget({super.key});

  @override
  State<PeersWidget> createState() => _PeersWidget();
}

class _PeersWidget extends State<PeersWidget> {
  bool _sortAscending = true;

  PeersBloc? _peersBloc;

  List<Peer>? _peers;

  @override
  void initState() {
    _peersBloc = PeersBloc();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Peers',
      child: _buildStreamBuilder(),
    );
  }

  Widget _buildTable() {
    if (_peers!.isEmpty) {
      return const QuietNote('No peers');
    }
    return CustomTable<Peer>(
      items: _peers,
      headerColumns: <CustomHeaderColumn>[
        CustomHeaderColumn(
          columnName: 'IP',
          onSortArrowsPressed: _onSortArrowsPressed,
        ),
        CustomHeaderColumn(
          columnName: 'Public key',
          onSortArrowsPressed: _onSortArrowsPressed,
          flex: 2,
        ),
      ],
      generateRowCells: (Peer peer, bool isSelected, {Object? model}) {
        return <Widget>[
          CustomTableCell.withText(
            context,
            peer.ip,
            textStyle: settingMonoStyle(context),
          ),
          CustomTableCell(
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Tooltip(
                message: peer.publicKey,
                child: Text(
                  peer.publicKey,
                  overflow: TextOverflow.ellipsis,
                  style: settingMonoStyle(context),
                ),
              ),
            ),
            flex: 2,
          ),
        ];
      },
    );
  }

  Widget _buildStreamBuilder() {
    return StreamBuilder<NetworkInfo>(
      stream: _peersBloc!.stream,
      builder: (_, AsyncSnapshot<NetworkInfo> snapshot) {
        if (snapshot.hasData) {
          _peers = snapshot.data!.peers;
          return _buildTable();
        } else if (snapshot.hasError) {
          return QuietNote.error(snapshot.error!);
        }
        return const QuietNote.loading();
      },
    );
  }

  void _onSortArrowsPressed(String columnName) {
    switch (columnName) {
      case 'IP':
        _sortAscending
            ? _peers!.sort((Peer a, Peer b) => a.ip.compareTo(b.ip))
            : _peers!.sort((Peer a, Peer b) => b.ip.compareTo(a.ip));
      case 'Public key':
        _sortAscending
            ? _peers!.sort(
                (Peer a, Peer b) => a.publicKey.compareTo(b.publicKey),
              )
            : _peers!.sort(
                (Peer a, Peer b) => b.publicKey.compareTo(a.publicKey),
              );
      default:
        _sortAscending
            ? _peers!.sort((Peer a, Peer b) => a.ip.compareTo(b.ip))
            : _peers!.sort((Peer a, Peer b) => b.ip.compareTo(a.ip));
    }
    setState(() {
      _sortAscending = !_sortAscending;
    });
  }

  @override
  void dispose() {
    _peersBloc!.dispose();
    super.dispose();
  }
}
