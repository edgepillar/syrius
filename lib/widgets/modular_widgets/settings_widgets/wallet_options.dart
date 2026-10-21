import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/screens/screens.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

/// How the wallet behaves: receiving, starting with the computer, desktop
/// notifications and the clipboard watcher. Each switch applies at once.
class WalletOptions extends StatefulWidget {
  const WalletOptions({super.key});

  @override
  State<WalletOptions> createState() => _WalletOptionsState();
}

class _WalletOptionsState extends State<WalletOptions> {
  bool? _launchAtStartup;
  bool? _enableDesktopNotifications;
  bool? _enabledClipboardWatcher;
  bool? _autoReceive;

  @override
  void initState() {
    super.initState();
    _launchAtStartup = sharedPrefsService!.get(
      kLaunchAtStartupKey,
      defaultValue: kLaunchAtStartupDefaultValue,
    );
    _enableDesktopNotifications = sharedPrefsService!.get(
      kEnableDesktopNotificationsKey,
      defaultValue: kEnableDesktopNotificationsDefaultValue,
    );
    _enabledClipboardWatcher = sharedPrefsService!.get(
      kEnableClipboardWatcherKey,
      defaultValue: kEnableClipboardWatcherDefaultValue,
    );
    _autoReceive = sharedPrefsService!.get(
      kAutoReceiveKey,
      defaultValue: kAutoReceiveDefaultValue,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Preferences',
      shrinkWrap: true,
      child: SettingsList(
        children: <Widget>[
          _buildAutoReceiveRow(),
          _buildLaunchAtStartupRow(),
          _buildEnableDesktopNotificationsRow(),
          _buildEnableClipboardWatcherRow(),
        ],
      ),
    );
  }

  Widget _buildLaunchAtStartupRow() {
    return SettingRow(
      label: 'Launch at startup',
      trailing: Switch(
        value: _launchAtStartup ?? false,
        onChanged: (bool value) async {
          setState(() {
            _launchAtStartup = value;
          });
          await _changeLaunchAtStartupStatus(value);
        },
      ),
    );
  }

  Widget _buildAutoReceiveRow() {
    return SettingRow(
      label: 'Auto-receive',
      hint: 'Off: receive each transaction by hand',
      trailing: Switch(
        value: _autoReceive ?? false,
        onChanged: (bool value) async {
          if (value) {
            NodeUtils.getUnreceivedTransactions()
                .then((value) {
                  sl<AutoReceiveTxWorker>().autoReceive();
                })
                .onError((Object? error, StackTrace stackTrace) {
                  Logger('MainAppContainer').log(
                    Level.WARNING,
                    '_getAutoReceiveWidget',
                    error,
                    stackTrace,
                  );
                });
          } else if (sl<AutoReceiveTxWorker>().pool.isNotEmpty) {
            sl<AutoReceiveTxWorker>().pool.clear();
          }
          setState(() {
            _autoReceive = value;
          });
          await _changeAutoReceiveStatus(value);
        },
      ),
    );
  }

  Future<void> _setupLaunchAtStartup() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    launchAtStartup.setup(
      appName: packageInfo.appName,
      appPath: Platform.resolvedExecutable,
    );
  }

  Future<void> _changeAutoReceiveStatus(bool enabled) async {
    try {
      await _saveAutoReceiveValueToCache(enabled);
      await _sendAutoReceiveNotification(enabled);
    } on Exception catch (e) {
      await NotificationUtils.sendNotificationError(
        e,
        'Something went wrong while setting automatic receive preference',
      );
    }
  }

  Future<void> _saveAutoReceiveValueToCache(bool enabled) async {
    await sharedPrefsService!.put(
      kAutoReceiveKey,
      enabled,
    );
  }

  Future<void> _sendAutoReceiveNotification(bool enabled) async {
    await sl.get<NotificationsBloc>().addNotification(
          WalletNotification(
            title: 'Auto-receiver ${enabled ? 'enabled' : 'disabled'}',
            details:
                'Auto-receiver preference was ${enabled ? 'enabled' : 'disabled'}',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            type: NotificationType.paymentSent,
          ),
        );
  }

  Future<void> _changeLaunchAtStartupStatus(bool enabled) async {
    try {
      await _setupLaunchAtStartup();
      if (enabled) {
        await launchAtStartup.enable();
      } else {
        await launchAtStartup.disable();
      }
      await _saveLaunchAtStartupValueToCache(enabled);
      await _sendLaunchAtStartupStatusNotification(enabled);
    } on Exception catch (e) {
      await NotificationUtils.sendNotificationError(
        e,
        'Something went wrong while setting launch at startup preference',
      );
    }
  }

  Future<void> _saveLaunchAtStartupValueToCache(bool enabled) async {
    await sharedPrefsService!.put(
      kLaunchAtStartupKey,
      enabled,
    );
  }

  Future<void> _sendLaunchAtStartupStatusNotification(bool enabled) async {
    await sl.get<NotificationsBloc>().addNotification(
          WalletNotification(
            title: 'Launch startup ${enabled ? 'enabled' : 'disabled'}',
            details:
                'Launch at startup preference was ${enabled ? 'enabled' : 'disabled'}',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            type: NotificationType.paymentSent,
          ),
        );
  }

  Widget _buildEnableDesktopNotificationsRow() {
    return SettingRow(
      label: 'Desktop notifications',
      trailing: Switch(
        value: _enableDesktopNotifications ?? false,
        onChanged: (bool value) {
          setState(() {
            _enableDesktopNotifications = value;
            _changeEnableDesktopNotificationsStatus(value);
          });
        },
      ),
    );
  }

  Widget _buildEnableClipboardWatcherRow() {
    return SettingRow(
      label: 'Clipboard watcher',
      hint: 'Offers to connect when a WalletConnect link is copied',
      trailing: Switch(
        value: _enabledClipboardWatcher ?? false,
        onChanged: (bool value) {
          setState(() {
            _enabledClipboardWatcher = value;
            _changeEnableClipboardWatcherStatus(value);
          });
        },
      ),
    );
  }

  Future<void> _changeEnableDesktopNotificationsStatus(bool enabled) async {
    try {
      await sharedPrefsService!.put(kEnableDesktopNotificationsKey, enabled);
      await _sendEnabledDesktopNotificationsStatusNotification(enabled);
    } on Exception catch (e) {
      await NotificationUtils.sendNotificationError(
        e,
        'Something went wrong while setting desktop notifications preference',
      );
    }
  }

  Future<void> _changeEnableClipboardWatcherStatus(bool enabled) async {
    try {
      await sharedPrefsService!.put(kEnableClipboardWatcherKey, enabled);
      ClipboardUtils.toggleClipboardWatcherStatus();
      await _sendEnableClipboardWatcherStatusNotification(enabled);
    } on Exception catch (e) {
      await NotificationUtils.sendNotificationError(
        e,
        'Something went wrong while changing clipboard watcher preference',
      );
    }
  }

  Future<void> _sendEnabledDesktopNotificationsStatusNotification(
      bool enabled,) async {
    await sl.get<NotificationsBloc>().addNotification(
          WalletNotification(
            title: 'Desktop notifications ${enabled ? 'enabled' : 'disabled'}',
            details:
                'Desktop notifications preference was ${enabled ? 'enabled' : 'disabled'}',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            type: NotificationType.paymentSent,
          ),
        );
  }

  Future<void> _sendEnableClipboardWatcherStatusNotification(
      bool enabled,) async {
    await sl.get<NotificationsBloc>().addNotification(
          WalletNotification(
            title: 'Clipboard watcher ${enabled ? 'enabled' : 'disabled'}',
            details:
                'Clipboard watcher preference was ${enabled ? 'enabled' : 'disabled'}',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            type: NotificationType.paymentSent,
          ),
        );
  }
}

/// The two ways out: delete the cache, or erase the wallet from this
/// computer. Reset opens its own confirmation screen.
class WalletReset extends StatelessWidget {
  /// Creates the panel.
  const WalletReset({super.key});

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Reset',
      shrinkWrap: true,
      child: SettingsList(
        children: <Widget>[
          SettingRow(
            label: 'Delete cache',
            hint: 'Clears cached data and closes the app',
            trailing: SecondaryAction(
              child: SettingsButton(
                onPressed: () {
                  NavigationUtils.pushReplacement(
                    context,
                    const SplashScreen(
                      deleteCacheFlow: true,
                    ),
                  );
                },
                text: 'Delete',
              ),
            ),
          ),
          SettingRow(
            label: 'Reset wallet',
            hint: 'Erases the wallet files. Back up first',
            trailing: DangerAction(
              child: SettingsButton(
                onPressed: () => NavigationUtils.push(
                  context,
                  const ResetWalletScreen(),
                ),
                text: 'Reset',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
