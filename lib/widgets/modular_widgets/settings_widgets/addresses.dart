import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:number_selector/number_selector.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/address_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

/// The wallet's addresses: pick the one the wallet acts as, rename, copy,
/// and derive more.
class Addresses extends StatefulWidget {
  const Addresses({
    required this.accountChainStatsBloc,
    super.key,
  });

  final AccountChainStatsBloc accountChainStatsBloc;

  @override
  State createState() {
    return AddressesState();
  }
}

class AddressesState extends State<Addresses> {
  String? _selectedAddress = kSelectedAddress;

  Future<void>? _futureChangeDefaultAddress;

  Future<void>? _futureGenerateNewAddress;

  late ScrollController _scrollController;

  bool _shouldScrollToTheEnd = false;
  int numberOfAddressesToAdd = 1;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Addresses',
      actions: <Widget>[
        Text(
          '${kDefaultAddressList.length}',
          style: ledgerLabelStyle(context),
        ),
        const SizedBox(width: 8),
      ],
      child: _buildGenerateNewAddressFutureBuilder(),
    );
  }

  Future<void> _changeDefaultAddress(String? newDefaultAddress) async {
    try {
      // The switch itself is shared with the home's address picker.
      await selectWalletAddress(context, newDefaultAddress!);
      if (!mounted) return;
      widget.accountChainStatsBloc.updateStream();
      _selectedAddress = newDefaultAddress;
    } catch (e) {
      rethrow;
    }
  }

  Widget _buildAddAddressRow() {
    final ThemeData theme = Theme.of(context);
    final Color line = theme.dividerTheme.color!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: <Widget>[
          NumberSelector.plain(
            width: 132,
            height: 36,
            contentPadding: 4,
            borderRadius: kCardRadius,
            hasBorder: true,
            showMinMax: false,
            showSuffix: false,
            borderColor: line,
            iconColor: theme.textTheme.titleMedium!.color!,
            textStyle: settingMonoStyle(context).copyWith(
              color: theme.textTheme.bodyLarge!.color,
            ),
            current: numberOfAddressesToAdd,
            min: 1,
            max: 10,
            onUpdate: _onAddAddressPressedCallback,
          ),
          const SizedBox(width: 12),
          SecondaryAction(
            child: OutlinedButton.icon(
              key: const Key('settings_add_address'),
              onPressed: () {
                setState(() {
                  _futureGenerateNewAddress =
                      ZenonAddressUtils.generateNewAddress(
                        numAddr: numberOfAddressesToAdd,
                        callback: () {
                          setState(() {
                            _shouldScrollToTheEnd = true;
                          });
                        },
                      );
                });
              },
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                numberOfAddressesToAdd == 1
                    ? 'Add 1 address'
                    : 'Add $numberOfAddressesToAdd addresses',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddresses() {
    final List<Widget> addresses = kDefaultAddressList
        .map(
          (String? e) => Row(
            children: <Widget>[
              const SizedBox(width: 6),
              Radio<String?>(
                value: e,
                groupValue: _selectedAddress,
                onChanged: _onAddressPressedCallback,
              ),
              Expanded(
                child: SettingsAddress(
                  address: e,
                  onAddressLabelPressed: _onAddressPressedCallback,
                ),
              ),
            ],
          ),
        )
        .toList();

    final Widget listView = ListView.builder(
      controller: _scrollController,
      key: const PageStorageKey('Addresses list view'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: addresses.length,
      itemBuilder: (BuildContext context, int index) {
        return addresses[index];
      },
    );

    if (_shouldScrollToTheEnd) {
      Timer(
        const Duration(milliseconds: 1),
        () {
          if (mounted && _scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
            _shouldScrollToTheEnd = false;
          }
        },
      );
    }

    return Scrollbar(
      controller: _scrollController,
      child: listView,
    );
  }

  Widget _buildCardBody() {
    return Column(
      children: <Widget>[
        Expanded(
          child: _buildAddresses(),
        ),
        const Divider(),
        _buildAddAddressRow(),
      ],
    );
  }

  Widget _buildGenerateNewAddressFutureBuilder() {
    return FutureBuilder(
      future: _futureGenerateNewAddress,
      builder: (_, AsyncSnapshot<void> snapshot) {
        if (snapshot.hasError) {
          return QuietNote.error(snapshot.error!);
        } else if (<ConnectionState>[
          ConnectionState.none,
          ConnectionState.done,
        ].contains(snapshot.connectionState)) {
          return _buildChangeDefaultAddressFutureBuilder();
        }
        return const QuietNote('Adding');
      },
    );
  }

  Widget _buildChangeDefaultAddressFutureBuilder() {
    return FutureBuilder(
      future: _futureChangeDefaultAddress,
      builder: (_, AsyncSnapshot<void> snapshot) {
        if (snapshot.hasError) {
          return QuietNote.error(snapshot.error!);
        } else if (<ConnectionState>[
          ConnectionState.none,
          ConnectionState.done,
        ].contains(snapshot.connectionState)) {
          return _buildCardBody();
        }
        return const QuietNote('Switching');
      },
    );
  }

  void _onAddAddressPressedCallback(int value) {
    setState(() {
      numberOfAddressesToAdd = value;
    });
  }

  void _onAddressPressedCallback(String? value) {
    setState(() {
      _futureChangeDefaultAddress = _changeDefaultAddress(value);
      numberOfAddressesToAdd = 1;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
