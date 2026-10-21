import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:logging/logging.dart';
import 'package:lottie/lottie.dart';
import 'package:reown_walletkit/reown_walletkit.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/screens/screens.dart';
import 'package:zenon_syrius_wallet_flutter/services/i_web3wallet_service.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

class SplashScreen extends StatefulWidget {
  static const String route = 'splash-screen';

  final bool resetWalletFlow;
  final bool deleteCacheFlow;

  const SplashScreen({
    this.resetWalletFlow = false,
    this.deleteCacheFlow = false,
    Key? key,
  }) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // The start-up work runs once, when the animation has played. A rebuild
  // (a theme change, a resize) must not start it again.
  bool _initsScheduled = false;

  // Set when the animation has played and the start-up work is still going.
  bool _waiting = false;

  void _onAnimationLoaded(LottieComposition composition) {
    if (_initsScheduled) return;
    _initsScheduled = true;
    Future.delayed(composition.duration, () {
      if (mounted) setState(() => _waiting = true);
      // What the first pages draw, read while the start-up work waits on
      // the disk and the node: off this isolate, and after the launch
      // animation, so it costs that no frame.
      unawaited(AppLottie.preload());
      _splashInits();
    });
  }

  @override
  Widget build(BuildContext context) {
    // The animation's frames are drawn on black, edge to edge; the window
    // round them is black too, so a window of another shape shows no seam.
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // The launch animation is kept as it was, filling the window, on a
          // layer of its own. Its 56 frames are given back when this screen
          // goes.
          AppLottie(
            AppLottieAsset.splash,
            repeat: false,
            fit: BoxFit.contain,
            onLoaded: _onAnimationLoaded,
          ),
          // Once the animation has played, a thin line says the app is
          // still starting, rather than a still black window.
          Align(
            alignment: const Alignment(0, 0.82),
            child: AnimatedOpacity(
              opacity: _waiting ? 1 : 0,
              duration: Durations.medium2,
              curve: Easing.standard,
              child: SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: _waiting
                      ? const LinearProgressIndicator(
                          minHeight: 2,
                          color: AppColors.znnColor,
                          backgroundColor: Color(0x1FFFFFFF),
                        )
                      : const SizedBox(height: 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _splashInits() async {
    try {
      widget.resetWalletFlow
          ? await _resetWallet()
          : widget.deleteCacheFlow
          ? await _deleteCache().then((value) => exit(0))
          : await InitUtils.initApp(context);
      _navigateToNextScreen();
    } on Exception catch (e) {
      Navigator.pushReplacementNamed(
        context,
        SyriusErrorWidget.route,
        arguments: CustomSyriusErrorWidgetArguments(e.toString()),
      );
    }
  }

  void _navigateToNextScreen() {
    return kWalletPath != null
        ? _checkForDefaultNode()
        : Navigator.pushReplacementNamed(
            context,
            AccessWalletScreen.route,
          );
  }

  void _navigateToHomeScreen() {
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushReplacementNamed(MainAppContainer.route);
  }

  void _navigateToNodeManagementScreen() {
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushReplacementNamed(NodeManagementScreen.route);
  }

  Future<void> _resetWallet() async {
    // In case the notification was not dismissed, we add a null value to be ignored
    // after the user creates or imports a new wallet
    kWalletInitCompleted = false;
    await sl.get<NotificationsBloc>().addNotification(null);
    NodeUtils.stopWebSocketClient();
    if (sl<AutoReceiveTxWorker>().pool.isNotEmpty) {
      sl<AutoReceiveTxWorker>().pool.clear();
    }
    await _deleteCache();
    await _deleteWalletFile();
    if (!mounted) return;
    await InitUtils.initApp(context);
  }

  Future<void> _deleteCache() async {
    await Hive.close();
    await Future.forEach<String>(
      kCacheBoxesToBeDeleted,
      (boxName) async => await Hive.deleteBoxFromDisk(boxName),
    );
    await _deleteWeb3Cache();
  }

  Future<void> _deleteWeb3Cache() async {
    try {
      final IWeb3WalletService web3WalletService = sl<IWeb3WalletService>();
      for (final PairingInfo pairing in web3WalletService.pairings.value) {
        await web3WalletService.deactivatePairing(topic: pairing.topic);
      }
    } catch (e, stackTrace) {
      Logger(
        'SplashScreen',
      ).log(Level.WARNING, '_deleteWeb3Cache', e, stackTrace);
    }
  }

  Future<void> _deleteWalletFile() async {
    await Hive.deleteBoxFromDisk(kKeyStoreBox);
    if (kWalletFile != null) kWalletFile!.close();
    kWalletFile = null;
    if (kWalletPath != null) {
      await FileUtils.deleteFile(kWalletPath!);
      kWalletPath = null;
    }
  }

  void _checkForDefaultNode() =>
      sharedPrefsService!.get(
            kSelectedNodeKey,
          ) !=
          null
      ? _navigateToHomeScreen()
      : _navigateToNodeManagementScreen();

  @override
  void dispose() {
    super.dispose();
  }
}
