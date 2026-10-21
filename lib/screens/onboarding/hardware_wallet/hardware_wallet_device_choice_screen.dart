import 'package:material_ui/material_ui.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/notifications_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/database/notification_type.dart';
import 'package:zenon_syrius_wallet_flutter/model/database/wallet_notification.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/onboarding_scaffold.dart';
import 'package:zenon_syrius_wallet_flutter/screens/screens.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_ledger_dart/znn_ledger_dart.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class HardwareWalletDeviceChoiceScreen extends StatefulWidget {
  const HardwareWalletDeviceChoiceScreen({super.key});

  @override
  State<HardwareWalletDeviceChoiceScreen> createState() =>
      _HardwareWalletDeviceChoiceScreenState();
}

class _HardwareWalletDeviceChoiceScreenState
    extends State<HardwareWalletDeviceChoiceScreen> {
  final List<WalletManager> _walletManagers = <WalletManager>[
    LedgerWalletManager(),
  ];
  List<WalletDefinition> _devices = <WalletDefinition>[];
  WalletDefinition? _selectedDevice;
  final Map<String, ValueNotifier<String?>> _deviceValueMap =
      <String, ValueNotifier<String?>>{};

  @override
  void initState() {
    super.initState();
    _openHiveAddressesBox();
  }

  void _openHiveAddressesBox() {
    Hive.boxExists(kAddressesBox).then(
      (bool addressesBoxExists) {
        if (addressesBoxExists) {
          Hive.openBox(
            kAddressesBox,
          ).then((Box addressesBox) => addressesBox.clear());
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 1,
      steps: 4,
      title: 'Choose your device',
      subtitle: 'Connect it and unlock it first',
      onBack: () {
        Navigator.pop(context);
      },
      header: const NotificationWidget(),
      primary: _getContinueButton(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(child: _getScanDevicesContainer()),
          if (_devices.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Material(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(kCardRadius),
              clipBehavior: Clip.antiAlias,
              child: Column(children: _getDevices()),
            ),
          ],
        ],
      ),
    );
  }

  Widget _getScanDevicesContainer() {
    return OutlinedButton.icon(
      style: secondaryButtonStyle(context),
      onPressed: () async {
        await _scanDevices();
      },
      icon: const Icon(Icons.search, size: 18),
      label: const Text('Scan devices'),
    );
  }

  Future<void> _scanDevices() async {
    final List<Future<Iterable<WalletDefinition>>> futures = _walletManagers
        .map((WalletManager manager) => manager.getWalletDefinitions())
        .toList();

    final List<Iterable<WalletDefinition>> listOfDefinitions =
        await Future.wait(futures);

    // Combine all the iterables into a single list using fold or expand
    // For example, using fold:
    final List<WalletDefinition> combinedList = listOfDefinitions
        .fold<List<WalletDefinition>>(
          <WalletDefinition>[],
          (
            List<WalletDefinition> previousList,
            Iterable<WalletDefinition> element,
          ) => previousList..addAll(element),
        );

    for (final WalletDefinition device in combinedList) {
      if (!_deviceValueMap.containsKey(device.walletId)) {
        _deviceValueMap[device.walletId] = ValueNotifier<String?>(null);
      }
    }

    setState(() {
      _devices = combinedList;
      _selectedDevice = null;

      for (final ValueNotifier<String?> valueNotifier
          in _deviceValueMap.values) {
        valueNotifier.value = null;
      }
    });
  }

  List<Widget> _getDevices() {
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < _devices.length; i++) {
      final WalletDefinition e = _devices[i];
      if (i > 0) rows.add(const Divider());
      rows.add(
        InkWell(
          onTap: () => _onDevicePressedCallback(e),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
            child: Row(
              children: <Widget>[
                Radio<WalletDefinition?>(
                  value: e,
                  groupValue: _selectedDevice,
                  onChanged: _onDevicePressedCallback,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _getWalletName(e),
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      ValueListenableBuilder<String?>(
                        valueListenable: _deviceValueMap[e.walletId]!,
                        builder: (BuildContext context, String? value, _) =>
                            _buildDeviceLine(value),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return rows;
  }

  /// Under a device's name: a hint until it is chosen, then the address it
  /// gave (mono), or what went wrong.
  Widget _buildDeviceLine(String? value) {
    if (value == null) {
      return Text(
        'Select to connect',
        style: TextStyle(fontSize: 13, color: dimColorOf(context)),
      );
    }
    // The line holds either the device's address or an error's text.
    final bool isAddress = value.startsWith('z1');
    return Text(
      value,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: isAddress
          ? monoStyle(
              TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodyLarge!.color,
              ),
            )
          : const TextStyle(fontSize: 13, color: AppColors.errorColor),
    );
  }

  Future<void> _onDevicePressedCallback(
    WalletDefinition? walletDefinition,
  ) async {
    Wallet? wallet;
    try {
      for (final WalletManager walletManager in _walletManagers) {
        final WalletDefinition wd = walletDefinition!;
        if (await walletManager.supportsWallet(wd)) {
          wallet = await walletManager.getWallet(walletDefinition);
          break;
        }
      }
      if (wallet == null) {
        throw const LedgerError.connectionError(
          origMessage:
              'Not connected, please connect the device and try again.',
        );
      }
      final Address walletAddress = await _getWalletAddress(wallet);
      setState(() {
        _deviceValueMap[walletDefinition!.walletId]!.value = walletAddress
            .toString();
        _selectedDevice = walletDefinition;
      });
    } catch (e) {
      _mapError(walletDefinition, e);
    } finally {
      if (wallet != null) {
        try {
          await (wallet as LedgerWallet).disconnect();
        } catch (_) {}
      }
      wallet = null;
    }
  }

  Future<Address> _getWalletAddress(Wallet wallet) async {
    final WalletAccount account = await wallet.getAccount();
    if (account is LedgerWalletAccount) {
      await sl.get<NotificationsBloc>().addNotification(
        WalletNotification(
          title:
              'Resolving address, please confirm the address on your hardware device',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          details: 'Confirm address for account index: 0',
          type: NotificationType.confirm,
        ),
      );
      return account.getAddress(true);
    } else {
      return account.getAddress();
    }
  }

  void _mapError(WalletDefinition? walletDefinition, Object err) {
    String? errorText;
    if (err is LedgerError) {
      errorText = err.toFriendlyString();
    } else {
      errorText = 'Error: $err';
    }
    setState(() {
      _deviceValueMap[walletDefinition!.walletId]!.value = errorText;
      _selectedDevice = null;
    });
  }

  String _getWalletName(WalletDefinition walletDefinition) {
    if (walletDefinition is LedgerWalletDefinition) {
      return 'Ledger ${walletDefinition.walletName}';
    }
    return walletDefinition.walletName;
  }

  Widget _getContinueButton() {
    return OnboardingButton(
      onPressed: _selectedDevice != null
          ? () {
              NavigationUtils.push(
                context,
                HardwareWalletPasswordScreen(_selectedDevice!),
              );
            }
          : null,
      text: 'Continue',
    );
  }
}
