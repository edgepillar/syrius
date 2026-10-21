import 'dart:isolate';

import 'package:material_ui/material_ui.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:logging/logging.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/embedded_node/embedded_node.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

class NodeManagementScreen extends StatefulWidget {

  const NodeManagementScreen({
    this.nodeConfirmationCallback,
    super.key,
  });
  final VoidCallback? nodeConfirmationCallback;

  static const String route = 'node-management-screen';

  @override
  State<NodeManagementScreen> createState() => _NodeManagementScreenState();
}

class _NodeManagementScreenState extends State<NodeManagementScreen> {
  String? _selectedNode;
  bool? _autoReceive;

  final GlobalKey<LoadingButtonState> _confirmNodeButtonKey = GlobalKey();
  final GlobalKey<LoadingButtonState> _addNodeButtonKey = GlobalKey();

  TextEditingController _newNodeController = TextEditingController();
  GlobalKey<FormState> _newNodeKey = GlobalKey();

  late String _selectedNodeConfirmed;

  @override
  void initState() {
    super.initState();
    kDefaultCommunityNodes.shuffle();
    _autoReceive = sharedPrefsService!.get(
      kAutoReceiveKey,
      defaultValue: kAutoReceiveDefaultValue,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedNode ??= kCurrentNode ?? kEmbeddedNode;
    _selectedNodeConfirmed = _selectedNode ?? kEmbeddedNode;
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScreenFrame(
      top: const NotificationWidget(),
      width: 600,
      title: 'Node',
      note:
          'Syrius runs its own full node, the Embedded Node. It can take up '
          'to a day to sync, and until then nothing can be sent or received. '
          'To start now, pick a community node.',
      actions: <Widget>[_buildConfirmNodeSelectionButton()],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildNodeTiles(),
          const SizedBox(height: 10),
          _buildAddNodeRow(),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 6),
          _buildAutoReceiveRow(),
        ],
      ),
    );
  }

  Widget _buildAutoReceiveRow() {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'Receive transactions automatically',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        Switch(
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
                      '_getAutoReceiveCheckboxContainer',
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
      ],
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

  Future<void> _saveAutoReceiveValueToCache(bool enabled) async {
    await sharedPrefsService!.put(
      kAutoReceiveKey,
      enabled,
    );
  }

  Widget _buildConfirmNodeSelectionButton() {
    return LoadingButton(
      text: 'Continue',
      onPressed: _onConfirmNodeButtonPressed,
      minimumSize: const Size(120, 40),
      key: _confirmNodeButtonKey,
    );
  }

  Future<void> _onConfirmNodeButtonPressed() async {
    // Acquire WakeLock
    if (!await WakelockPlus.enabled) {
      WakelockPlus.enable();
    }

    try {
      _confirmNodeButtonKey.currentState?.animateForward();
      final String url = _selectedNode == kEmbeddedNode
          ? kLocalhostDefaultNodeUrl
          : _selectedNode!;
      bool isConnectionEstablished =
          await NodeUtils.establishConnectionToNode(url);
      if (_selectedNode == kEmbeddedNode) {
        // Check if node is already running
        if (!isConnectionEstablished) {
          // Initialize local full node
          await Isolate.spawn(EmbeddedNode.runNode, <String>[''],
              onExit:
                  sl<ReceivePort>(instanceName: 'embeddedStoppedPort').sendPort,
              debugName: 'EmbeddedNodeIsolate',);
          kEmbeddedNodeRunning = true;
          // The node needs a couple of seconds to actually start
          await Future.delayed(kEmbeddedConnectionDelay);
          isConnectionEstablished =
              await NodeUtils.establishConnectionToNode(url);
        }
      } else {
        if (isConnectionEstablished) {
          await NodeUtils.closeEmbeddedNode();
        }
      }
      if (isConnectionEstablished) {
        await sharedPrefsService!.put(
          kSelectedNodeKey,
          _selectedNode,
        );
        kCurrentNode = _selectedNode;
        await _sendChangingNodeSuccessNotification();
        if (widget.nodeConfirmationCallback != null) {
          widget.nodeConfirmationCallback!();
        } else {
          _navigateToHomeScreen();
        }
      } else {
        throw 'Connection could not be established to $_selectedNode';
      }
    } catch (e) {
      await NotificationUtils.sendNotificationError(
        e,
        'Connection failed',
      );
      setState(() {
        _selectedNode = kCurrentNode;
      });
    } finally {
      _confirmNodeButtonKey.currentState?.animateReverse();
    }
  }

  void _navigateToHomeScreen() {
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushReplacementNamed(MainAppContainer.route);
  }

  Widget _buildAddNodeRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Form(
            key: _newNodeKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: InputField(
              controller: _newNodeController,
              hintText: 'Node address with port',
              onSubmitted: (String value) {
                if (_ifUserInputValid()) {
                  _onAddNodePressed();
                }
              },
              onChanged: (String value) {
                if (value.isNotEmpty) {
                  setState(() {});
                }
              },
              validator: InputValidators.node,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SecondaryAction(
          child: LoadingButton.settings(
            onPressed: _ifUserInputValid() ? _onAddNodePressed : null,
            text: 'Add node',
            key: _addNodeButtonKey,
          ),
        ),
      ],
    );
  }

  bool _ifUserInputValid() =>
      InputValidators.node(_newNodeController.text) == null;

  Future<void> _onAddNodePressed() async {
    if (<String>[...kDbNodes, ...kDefaultCommunityNodes, ...kDefaultNodes]
        .contains(_newNodeController.text)) {
      await NotificationUtils.sendNotificationError(
          'Node ${_newNodeController.text} already exists',
          'Node already exists',);
    } else {
      _addNodeToDb();
    }
  }

  Future<void> _addNodeToDb() async {
    try {
      _addNodeButtonKey.currentState?.animateForward();
      if (!Hive.isBoxOpen(kNodesBox)) {
        await Hive.openBox<String>(kNodesBox);
      }
      Hive.box<String>(kNodesBox).add(_newNodeController.text);
      await NodeUtils.loadDbNodes();
      await _sendAddNodeSuccessNotification();
      setState(() {
        _newNodeController = TextEditingController();
        _newNodeKey = GlobalKey();
      });
    } catch (e) {
      await NotificationUtils.sendNotificationError(e, 'Error while adding new node');
    } finally {
      _addNodeButtonKey.currentState?.animateReverse();
    }
  }

  Widget _buildNodeTiles() {
    return Column(
      children: <String>{
        ...kDefaultNodes,
        ...kDefaultCommunityNodes,
        ...kDbNodes,
      }.toList().map(_buildNodeTile).toList(),
    );
  }

  Widget _buildNodeTile(String node) {
    return Row(
      children: <Widget>[
        Radio<String?>(
          value: node,
          groupValue: _selectedNode,
          onChanged: (String? value) {
            setState(() {
              _selectedNode = value;
            });
          },
        ),
        Expanded(
          child: SettingsNode(
            key: ValueKey(node),
            node: node,
            onNodePressed: (String? value) {
              setState(() {
                _selectedNode = value;
              });
            },
            onChangedOrDeletedNode: () {
              setState(() {});
            },
            currentNode: _selectedNodeConfirmed,
          ),
        ),
      ],
    );
  }

  Future<void> _sendChangingNodeSuccessNotification() async {
    await sl.get<NotificationsBloc>().addNotification(
          WalletNotification(
            title: 'Successfully connected to $_selectedNode',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            details: 'Successfully connected to $_selectedNode',
            type: NotificationType.changedNode,
          ),
        );
  }

  @override
  void dispose() {
    _newNodeController.dispose();
    super.dispose();
  }

  Future<void> _sendAddNodeSuccessNotification() async {
    await sl.get<NotificationsBloc>().addNotification(
          WalletNotification(
            title: 'Successfully added node ${_newNodeController.text}',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            details: 'Successfully added node ${_newNodeController.text}',
            type: NotificationType.changedNode,
          ),
        );
  }
}
