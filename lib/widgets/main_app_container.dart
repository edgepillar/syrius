import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:clipboard_watcher/clipboard_watcher.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/handlers/htlc_swaps_handler.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/go_to_palette.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/motion/motion.dart';
import 'package:zenon_syrius_wallet_flutter/utils/account_block_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/address_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/clipboard_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/extensions.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notification_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notifiers/text_scaling_notifier.dart';
import 'package:zenon_syrius_wallet_flutter/utils/zts_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/tab_children_widgets/wallet_connect_tab_child.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/shell.dart';

export 'package:zenon_syrius_wallet_flutter/widgets/shell/rail.dart'
    show RailCollapse, ShellRail;
export 'package:zenon_syrius_wallet_flutter/widgets/shell/tabs.dart';

class MainAppContainer extends StatefulWidget {
  const MainAppContainer({
    super.key,
    this.redirectedFromWalletSuccess = false,
  });

  final bool redirectedFromWalletSuccess;

  static const String route = 'main-app-container';

  @override
  State<MainAppContainer> createState() => _MainAppContainerState();
}

class _MainAppContainerState extends State<MainAppContainer>
    with ClipboardListener, WindowListener {
  late StreamSubscription _lockBlockStreamSubscription;
  late StreamSubscription _incomingLinkSubscription;
  late LockBloc _lockBloc;

  Timer? _navigateToLockTimer;
  bool _initialUriIsHandled = false;

  /// The page shown, as an index into [kTabs]. The rail and the page area
  /// listen to it, so a change of page rebuilds those two and not the shell.
  final ValueNotifier<int> _tabIndex = ValueNotifier<int>(
    kWalletInitCompleted ? 0 : kTabs.length - 1,
  );

  /// The page shown before the current one: where an unlock returns to.
  int _previousTabIndex = 0;

  /// Whether the wallet is locked, for the rail. It follows the auto-lock
  /// timer, which changes without a change of page (the countdown starting
  /// after a new wallet is made), so the rail cannot read it at build time.
  final ValueNotifier<bool> _locked = ValueNotifier<bool>(true);

  late final Listenable _railState = Listenable.merge(<Listenable>[
    _tabIndex,
    _locked,
  ]);

  /// Whether the rail is collapsed to its icons. Held here and not in the
  /// rail because the shortcut that changes it is the shell's.
  final RailCollapse _railCollapse = RailCollapse();

  /// The send form's half-typed values, kept here because the page that
  /// shows them is disposed when another is opened. Cleared on a send and on
  /// lock.
  final SendDraftCubit _sendDraft = SendDraftCubit();

  final AppLinks _appLinks = AppLinks();
  final NodeSyncStatusCubit _nodeSyncStatusCubit = NodeSyncStatusCubit(
    zenon: zenon!,
  );

  @override
  void initState() {
    clipboardWatcher.addListener(this);
    windowManager.addListener(this);

    ClipboardUtils.toggleClipboardWatcherStatus();

    _previousTabIndex = _tabIndex.value;
    kCurrentPage = kWalletInitCompleted ? Tabs.dashboard : Tabs.lock;
    _initLockBlock();
    _handleIncomingLinks();
    _handleInitialUri();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <SingleChildWidget>[
        BlocProvider<LatestTransactionsBloc>(
          create: (_) => sl.get<LatestTransactionsBloc>()
            ..add(
              InfiniteListRequested(
                address: Address.parse(kSelectedAddress!),
              ),
            ),
        ),
        BlocProvider<SendTransactionBloc>(
          create: (_) => SendTransactionBloc(),
        ),
        BlocProvider<SendDraftCubit>.value(value: _sendDraft),
        BlocProvider<MultipleBalanceBloc>(
          create: (_) => sl.get<MultipleBalanceBloc>(),
        ),
        BlocProvider<PendingTransactionsBloc>(
          create: (_) => sl.get<PendingTransactionsBloc>()
            ..add(
              InfiniteListRequested(
                address: Address.parse(kSelectedAddress!),
              ),
            ),
        ),
        BlocProvider<PillarRewardsHistoryBloc>(
          create: (_) =>
              PillarRewardsHistoryBloc(
                zenon: zenon!,
              )..add(
                FetchRequestData(
                  address: Address.parse(kSelectedAddress!),
                ),
              ),
        ),
        BlocProvider<SentinelRewardsHistoryBloc>(
          create: (_) =>
              SentinelRewardsHistoryBloc(
                zenon: zenon!,
              )..add(
                FetchRequestData(
                  address: Address.parse(kSelectedAddress!),
                ),
              ),
        ),
        BlocProvider<StakingRewardsHistoryBloc>(
          create: (_) =>
              StakingRewardsHistoryBloc(
                zenon: zenon!,
              )..add(
                FetchRequestData(
                  address: Address.parse(kSelectedAddress!),
                ),
              ),
        ),
        BlocProvider<PillarsByOwnerBloc>(
          create: (_) =>
              PillarsByOwnerBloc(
                zenon: zenon!,
              )..add(
                FetchRequestData(
                  address: Address.parse(kSelectedAddress!),
                ),
              ),
        ),
        BlocProvider<AllTokensBloc>(
          create: (_) => AllTokensBloc(
            zenon: zenon!,
          )..add(const AllTokensRequested()),
        ),
        BlocProvider<DelegationStatsBloc>(
          create: (_) => DelegationStatsBloc(zenon: zenon!)
            ..add(FetchRequestData(address: Address.parse(kSelectedAddress!))),
        ),
      ],
      child: BlocListener<SendTransactionBloc, SendTransactionState>(
        // A send that lands while another page is shown finds no form to
        // clear, so the draft is cleared here, above the pages.
        listenWhen:
            (SendTransactionState previous, SendTransactionState next) =>
                previous.status != next.status &&
                next.status == SendTransactionStatus.success,
        listener: (_, _) => _sendDraft.clear(),
        child: Consumer<TextScalingNotifier>(
          // Built with the shell and handed to the builder, so a change of
          // text scale gives the tree a new MediaQuery and not a new shell.
          child: _buildShortcuts(child: _buildBody()),
          builder:
              (
                BuildContext context,
                TextScalingNotifier textScalingNotifier,
                Widget? child,
              ) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(
                    textScalingNotifier.getTextScaleFactor(context),
                  ),
                ),
                child: child!,
              ),
        ),
      ),
    );
  }

  /// The rail, the page and the status strip.
  ///
  /// Nothing here calls setState: each part listens to what it shows (the
  /// page index, the lock, a cubit), so a notification, a new momentum or a
  /// change of page rebuilds that part and leaves the rest alone. The shell
  /// used to rebuild whole, pages included, for every notification.
  Widget _buildBody() {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(10, 14, 18, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // The rail, the page and the strip each animate on their own
            // (hover, page switch, a flashing height, the plasma glow), so
            // each gets a layer: one repainting does not repaint the others.
            // The rail has no width here: it is as wide as it is open, and
            // the page takes the rest.
            RepaintBoundary(child: _buildRail()),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: NotificationOverlay(
                      banner: _buildNotificationBanner(),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(kCardRadius),
                        child: RepaintBoundary(child: _buildCurrentPage()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  RepaintBoundary(
                    child: StatusStrip(
                      syncCubit: _nodeSyncStatusCubit,
                      page: _tabIndex,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The latest notification, floating over the top of the page.
  ///
  /// The banner rebuilds itself when a notification arrives or is dismissed
  /// and takes no room from the page, so the shell has nothing to do for
  /// one. It is rebuilt on a change of page because its "See more" is not
  /// offered on the lock screen.
  Widget _buildNotificationBanner() {
    return ValueListenableBuilder<int>(
      valueListenable: _tabIndex,
      builder: (BuildContext context, int index, Widget? child) =>
          NotificationWidget(
            onSeeMorePressed: () => _navigateTo(Tabs.notifications),
            popBeforeSeeMoreIsPressed: false,
            floating: true,
          ),
    );
  }

  /// The shell's keyboard shortcuts: the chord key (Ctrl; Cmd on macOS) with
  /// 1 to 9 opens the rail's pages in order, with L locks, with K opens the
  /// "Go to" palette, with B opens or collapses the rail (the chord editors
  /// use for their side bar).
  ///
  /// They are a Shortcuts widget round the shell and not a global key
  /// handler, so they stop by themselves where they should: a dialog is
  /// another route and hears none of them. Locked, the map is empty: the
  /// only way past the lock screen is the password.
  ///
  /// Nothing is taken from a text field. Every binding needs the chord key,
  /// and none of these chords edits text on the platform it is bound on
  /// (Ctrl+K kills a line on macOS, which is why macOS gets Cmd). AltGr,
  /// which Windows reports as Ctrl+Alt, does not match: the bindings want
  /// Ctrl alone.
  ///
  /// The FocusScope gives the shell a focus node of its own under the
  /// Shortcuts. Without it, focus falls back to the route's scope when a
  /// focused field is disposed by a change of page, and that scope is above
  /// the Shortcuts, so the keys would go dead until something was clicked.
  Widget _buildShortcuts({required Widget child}) {
    return ValueListenableBuilder<bool>(
      valueListenable: _locked,
      child: FocusScope(autofocus: true, child: child),
      builder: (BuildContext context, bool locked, Widget? child) => Shortcuts(
        shortcuts: locked
            ? const <ShortcutActivator, Intent>{}
            : kShellShortcuts,
        child: Actions(actions: _shellActions, child: child!),
      ),
    );
  }

  late final Map<Type, Action<Intent>> _shellActions = <Type, Action<Intent>>{
    OpenPageIntent: CallbackAction<OpenPageIntent>(
      onInvoke: (OpenPageIntent intent) {
        _onRailTap(intent.tab);
        return null;
      },
    ),
    OpenGoToIntent: CallbackAction<OpenGoToIntent>(
      onInvoke: (OpenGoToIntent intent) {
        unawaited(_openGoTo());
        return null;
      },
    ),
    ToggleRailIntent: CallbackAction<ToggleRailIntent>(
      onInvoke: (ToggleRailIntent intent) {
        _toggleRail();
        return null;
      },
    ),
  };

  bool _goToOpen = false;

  /// Opens the "Go to" palette and shows the page chosen in it.
  Future<void> _openGoTo() async {
    if (_isWalletLocked() || _goToOpen) {
      return;
    }
    _goToOpen = true;
    final Tabs? tab = await showGoToPalette<Tabs>(
      context: context,
      entries: <GoToEntry<Tabs>>[
        for (int i = 0; i < kRailPages.length; i++)
          GoToEntry<Tabs>(
            value: kRailPages[i].tab,
            label: kRailPages[i].label,
            icon: kRailPages[i].icon,
            shortcut: i < 9 ? '$kChordName ${i + 1}' : null,
          ),
        for (final RailEntry entry in railWalletEntries(onLock: false))
          GoToEntry<Tabs>(
            value: entry.tab,
            label: entry.label,
            icon: entry.icon,
            shortcut: entry.tab == Tabs.lock ? '$kChordName L' : null,
          ),
      ],
    );
    _goToOpen = false;
    // The wallet may have locked itself while the palette was open;
    // _onRailTap refuses then.
    if (tab != null && mounted) {
      _onRailTap(tab);
    }
  }

  /// The side rail of mockup B: its labels shown when it is open, its icons
  /// alone when it is collapsed. It sets its own width.
  Widget _buildRail() {
    return ListenableBuilder(
      listenable: _railState,
      builder: (BuildContext context, Widget? child) => ShellRail(
        collapse: _railCollapse,
        selected: kTabs[_tabIndex.value],
        locked: _locked.value,
        onSelected: _onRailTap,
      ),
    );
  }

  void _toggleRail() {
    // The same rule as [_onRailTap]: locked, nothing in the rail answers.
    if (_isWalletLocked()) {
      return;
    }
    _railCollapse.toggle();
  }

  void _onRailTap(Tabs tab) {
    // The rail takes no pointer and no focus while locked; this is the
    // same rule for any path that reaches it anyway.
    if (_isWalletLocked() || kTabs[_tabIndex.value] == tab) {
      return;
    }
    _navigateTo(tab);
    if (tab == Tabs.lock) {
      unawaited(_onNavigateToLock());
    }
  }

  Future<void> _onNavigateToLock() async {
    if (kWalletFile != null) kWalletFile!.close();
    kWalletFile = null;
    _navigateToLockTimer?.cancel();
    _sendDraft.clear();
    _syncLocked();
  }

  bool _isWalletLocked() {
    return _navigateToLockTimer == null ||
        _navigateToLockTimer != null && !_navigateToLockTimer!.isActive;
  }

  /// Tells the rail after anything that starts or stops the auto-lock timer.
  void _syncLocked() => _locked.value = _isWalletLocked();

  /// The page for the selected rail item.
  ///
  /// Only that page is built. It used to be a TabBarView, which slid
  /// sideways through every page between two rail items and kept the
  /// neighbours built, each with its own fetches. The rail's destinations
  /// have no left-to-right order, so the new page fades in and rises a few
  /// pixels instead, and the old one is gone 100 ms after it is left.
  Widget _buildCurrentPage() {
    return ValueListenableBuilder<int>(
      valueListenable: _tabIndex,
      builder: (BuildContext context, int index, Widget? child) => RiseSwitcher(
        child: KeyedSubtree(
          key: ValueKey<int>(index),
          child: _buildPage(kTabs[index]),
        ),
      ),
    );
  }

  Widget _buildPage(Tabs tab) {
    return switch (tab) {
      Tabs.dashboard => DashboardTabChild(changePage: _navigateTo),
      // Not const, so another page's constructor can change without
      // breaking the shell.
      Tabs.transfer => TransferTabChild(),
      Tabs.pillars => PillarsTabChild(
        onStepperNotificationSeeMorePressed: () =>
            _navigateTo(Tabs.notifications),
      ),
      Tabs.sentinels => SentinelsTabChild(
        onStepperNotificationSeeMorePressed: () =>
            _navigateTo(Tabs.notifications),
      ),
      Tabs.staking => const StakingTabChild(),
      Tabs.plasma => const PlasmaTabChild(),
      Tabs.tokens => TokensTabChild(
        onStepperNotificationSeeMorePressed: () =>
            _navigateTo(Tabs.notifications),
      ),
      Tabs.p2pSwap => P2pSwapTabChild(
        onStepperNotificationSeeMorePressed: () =>
            _navigateTo(Tabs.notifications),
      ),
      Tabs.walletConnect => const WalletConnectTabChild(),
      Tabs.accelerator => AcceleratorTabChild(
        onStepperNotificationSeeMorePressed: () =>
            _navigateTo(Tabs.notifications),
      ),
      Tabs.notifications => const NotificationsTabChild(),
      Tabs.settings => SettingsTabChild(
        _onChangeAutoLockTime,
        onStepperNotificationSeeMorePressed: () =>
            _navigateTo(Tabs.notifications),
        onNodeChangedCallback: () => _navigateTo(Tabs.dashboard),
      ),
      // Never shown: [_navigateTo] refuses the disabled tabs.
      Tabs.generation || Tabs.sync => const SizedBox.shrink(),
      Tabs.lock => LockTabChild(_mainLockCallback, _afterAppInitCallback),
    };
  }

  Future<void> _mainLockCallback(String password) async {
    _startAutoLockTimer();
    if (kLastWalletConnectUriNotifier.value != null) {
      _navigateTo(Tabs.walletConnect);
    } else {
      _lockBloc.addEvent(LockEvent.navigateToPreviousTab);
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _nodeSyncStatusCubit.close();
    _sendDraft.close();
    _navigateToLockTimer?.cancel();
    _lockBlockStreamSubscription.cancel();
    _incomingLinkSubscription.cancel();
    _tabIndex.dispose();
    _locked.dispose();
    _railCollapse.dispose();
    super.dispose();
  }

  Future<void> _onChangeAutoLockTime() async {
    await sl.get<NotificationsBloc>().addNotification(
      WalletNotification(
        title: 'Auto-lock interval changed successfully',
        details:
            'Auto-lock interval changed successfully to '
            '$kAutoLockWalletMinutes minutes.',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        type: NotificationType.autoLockIntervalChanged,
      ),
    );
    _lockBloc.addEvent(LockEvent.resetTimer);
  }

  void _afterAppInitCallback() {
    _nodeSyncStatusCubit.fetchDataPeriodically();
    _startAutoLockTimer();
    if (kLastWalletConnectUriNotifier.value != null) {
      _navigateTo(Tabs.walletConnect);
    } else {
      _lockBloc.addEvent(LockEvent.navigateToDashboard);
    }

    _listenToAutoReceiveTxWorkerNotifications();
  }

  void _listenToAutoReceiveTxWorkerNotifications() {
    sl<AutoReceiveTxWorker>().stream.listen((WalletNotification event) {
      sl<NotificationsBloc>().addNotification(event);
    });
  }

  /// Shows [page]. Every change of page goes through here: the rail, the
  /// lock, a deep link, a page's own "see more".
  ///
  /// This is what the TabController did, without its ticker: a page that is
  /// not in [kTabs] (WalletConnect without a project id) or is disabled is
  /// refused, and the page left is remembered for the next unlock.
  void _navigateTo(Tabs page) {
    final int index = kTabs.indexOf(page);
    if (index < 0 || index == _tabIndex.value || kDisabledTabs.contains(page)) {
      return;
    }
    _previousTabIndex = _tabIndex.value;
    kCurrentPage = page;
    _tabIndex.value = index;
    DappBridge.instance.selectionChanged();
  }

  void _initLockBlock() {
    _lockBloc = Provider.of<LockBloc>(context, listen: false);
    _lockBlockStreamSubscription = _lockBloc.stream.listen((LockEvent event) {
      switch (event) {
        case LockEvent.countDown:
          if (kCurrentPage != Tabs.lock) {
            _startAutoLockTimer();
          }
        case LockEvent.navigateToDashboard:
          _navigateTo(Tabs.dashboard);
        case LockEvent.navigateToLock:
          if (Navigator.of(context).canPop()) {
            Navigator.popUntil(
              context,
              ModalRoute.withName(MainAppContainer.route),
            );
          }
          _onNavigateToLock();
          _navigateTo(Tabs.lock);
        case LockEvent.resetTimer:
          if (_navigateToLockTimer != null && _navigateToLockTimer!.isActive) {
            _startAutoLockTimer();
          }
        case LockEvent.navigateToPreviousTab:
          _navigateTo(kTabs[_previousTabIndex]);
      }
    });
    if (widget.redirectedFromWalletSuccess) {
      _lockBloc.addEvent(LockEvent.countDown);
    }
  }

  /// Starts the auto-lock countdown afresh, and is the only place that
  /// makes its timer.
  ///
  /// The timer is periodic, so that a lock put off by an incoming swap is
  /// tried again one interval later. A periodic timer that is replaced
  /// without being cancelled keeps firing: the countdown, an unlock and the
  /// end of initialisation each used to assign a new one over the last, and
  /// the one left behind locked the wallet on its own, earlier schedule.
  /// Cancelling here first means there is never more than one.
  void _startAutoLockTimer() {
    _navigateToLockTimer?.cancel();
    _navigateToLockTimer = Timer.periodic(
      Duration(minutes: kAutoLockWalletMinutes!),
      (Timer timer) {
        if (!sl<HtlcSwapsHandler>().hasActiveIncomingSwaps) {
          _lockBloc.addEvent(LockEvent.navigateToLock);
        }
      },
    );
    _syncLocked();
  }

  void _handleIncomingLinks() async {
    if (!kIsWeb && !Platform.isLinux) {
      _incomingLinkSubscription = _appLinks.uriLinkStream.listen(
        (Uri? uri) async {
          if (!await windowManager.isFocused() ||
              !await windowManager.isVisible()) {
            windowManager.show();
          }

          if (uri != null) {
            String uriRaw = uri.toString();

            Logger(
              'MainAppContainer',
            ).log(Level.INFO, '_handleIncomingLinks $uriRaw');

            if (context.mounted) {
              if (uri.host == 'wc') {
                if (Platform.isWindows) {
                  uriRaw = uriRaw.replaceAll('/?', '?');
                }
                String wcUri = Uri.decodeFull(uriRaw.split('wc?uri=').last);
                if (Uri.tryParse(wcUri) != null) {
                  await _updateWalletConnectUri(wcUri);
                }
                return;
              }

              // Deep link query parameters
              String queryAddress = '';
              String queryAmount = ''; // with decimals
              int queryDuration = 0; // in months
              String queryZTS = '';
              String queryPillarName = '';
              Token? token;

              if (uri.hasQuery) {
                uri.queryParametersAll.forEach((
                  String key,
                  List<String> value,
                ) async {
                  if (key == 'amount') {
                    queryAmount = value.first;
                  } else if (key == 'zts') {
                    queryZTS = value.first;
                  } else if (key == 'address') {
                    queryAddress = value.first;
                  } else if (key == 'duration') {
                    queryDuration = int.parse(value.first);
                  } else if (key == 'pillar') {
                    queryPillarName = value.first;
                  }
                });
              }

              if (queryZTS.isNotEmpty) {
                if (queryZTS == 'znn' || queryZTS == 'ZNN') {
                  token = kZnnCoin;
                } else if (queryZTS == 'qsr' || queryZTS == 'QSR') {
                  token = kQsrCoin;
                } else {
                  token = await zenon!.embedded.token.getByZts(
                    TokenStandard.parse(queryZTS),
                  );
                }
              }

              final SendTransactionBloc sendTransactionBloc =
                  SendTransactionBloc();
              final DelegationBloc delegationBloc = DelegationBloc(
                accountBlockUtils: AccountBlockUtils(),
                zenon: zenon!,
              );
              final FusePlasmaBloc fusePlasmaBloc = FusePlasmaBloc(
                accountBlockUtils: AccountBlockUtils(),
                zenon: zenon!,
                zenonAddressUtils: ZenonAddressUtils(),
              );

              if (context.mounted) {
                switch (uri.host) {
                  // A page asks for the wallet to be started or brought
                  // forward, then talks to it over the loopback channel.
                  case 'open':
                    break;
                  case 'transfer':
                    await sl<NotificationsBloc>().addNotification(
                      WalletNotification(
                        title: 'Transfer action detected',
                        timestamp: DateTime.now().millisecondsSinceEpoch,
                        details: 'Deep link: $uriRaw',
                        type: NotificationType.paymentReceived,
                      ),
                    );

                    if (kCurrentPage != Tabs.lock) {
                      _navigateTo(Tabs.transfer);

                      if (token != null) {
                        final bool?
                        actionAccepted = await showDialogWithNoAndYesOptions(
                          context: context,
                          title: 'Transfer action',
                          isBarrierDismissible: true,
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                'Are you sure you want transfer $queryAmount ${token.symbol} from $kSelectedAddress to $queryAddress?',
                              ),
                            ],
                          ),
                        );

                        if (actionAccepted ?? false) {
                          context.read<SendTransactionBloc>().add(
                            SendTransactionInitiate(
                              fromAddress: kSelectedAddress!,
                              toAddress: queryAddress,
                              amount: queryAmount.extractDecimals(
                                token.decimals,
                              ),
                              token: token,
                            ),
                          );
                        }
                      }
                    }
                  case 'stake':
                    await sl<NotificationsBloc>().addNotification(
                      WalletNotification(
                        title: 'Stake action detected',
                        timestamp: DateTime.now().millisecondsSinceEpoch,
                        details: 'Deep link: $uriRaw',
                        type: NotificationType.paymentReceived,
                      ),
                    );

                    if (kCurrentPage != Tabs.lock) {
                      _navigateTo(Tabs.staking);

                      final bool?
                      actionAccepted = await showDialogWithNoAndYesOptions(
                        context: context,
                        title: 'Stake ${kZnnCoin.symbol} action',
                        isBarrierDismissible: true,
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              'Are you sure you want stake $queryAmount ${kZnnCoin.symbol} for $queryDuration month(s)?',
                            ),
                          ],
                        ),
                      );

                      if (actionAccepted ?? false) {
                        final AccountBlockTemplate block = zenon!.embedded.stake
                            .stake(
                              queryDuration * stakeTimeUnitSec,
                              queryAmount.extractDecimals(kZnnCoin.decimals),
                            );

                        sendTransactionBloc.add(
                          SendTransactionInitiateFromBlock(
                            block: block,
                            fromAddress: kSelectedAddress!,
                            reasonForGeneratingPlasma:
                                context.l10n.plasmaPurposeCreateStake,
                          ),
                        );
                      }
                    }

                  case 'delegate':
                    await sl<NotificationsBloc>().addNotification(
                      WalletNotification(
                        title: 'Delegate action detected',
                        timestamp: DateTime.now().millisecondsSinceEpoch,
                        details: 'Deep link: $uriRaw',
                        type: NotificationType.paymentReceived,
                      ),
                    );

                    if (kCurrentPage != Tabs.lock) {
                      _navigateTo(Tabs.pillars);

                      final bool?
                      actionAccepted = await showDialogWithNoAndYesOptions(
                        context: context,
                        title: 'Delegate ${kZnnCoin.symbol} action',
                        isBarrierDismissible: true,
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              'Are you sure you want delegate the ${kZnnCoin.symbol} from $kSelectedAddress to Pillar $queryPillarName?',
                            ),
                          ],
                        ),
                      );

                      if (actionAccepted ?? false) {
                        delegationBloc.add(
                          DelegationRequested(
                            address: Address.parse(kSelectedAddress!),
                            pillarName: queryPillarName,
                          ),
                        );
                      }
                    }

                  case 'fuse':
                    await sl<NotificationsBloc>().addNotification(
                      WalletNotification(
                        title: 'Fuse ${kQsrCoin.symbol} action detected',
                        timestamp: DateTime.now().millisecondsSinceEpoch,
                        details: 'Deep link: $uriRaw',
                        type: NotificationType.paymentReceived,
                      ),
                    );

                    if (kCurrentPage != Tabs.lock) {
                      _navigateTo(Tabs.plasma);

                      final bool?
                      actionAccepted = await showDialogWithNoAndYesOptions(
                        context: context,
                        title: 'Fuse ${kQsrCoin.symbol} action',
                        isBarrierDismissible: true,
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              'Are you sure you want fuse $queryAmount ${kQsrCoin.symbol} for address $queryAddress?',
                            ),
                          ],
                        ),
                      );

                      if (actionAccepted ?? false) {
                        fusePlasmaBloc.add(
                          FusePlasmaRequested(
                            beneficiaryAddress: queryAddress,
                            amount: queryAmount.extractDecimals(
                              kQsrCoin.decimals,
                            ),
                          ),
                        );
                      }
                    }

                  case 'sentinel':
                    await sl<NotificationsBloc>().addNotification(
                      WalletNotification(
                        title: 'Deploy Sentinel action detected',
                        timestamp: DateTime.now().millisecondsSinceEpoch,
                        details: 'Deep link: $uriRaw',
                        type: NotificationType.paymentReceived,
                      ),
                    );

                    if (kCurrentPage != Tabs.lock) {
                      _navigateTo(Tabs.sentinels);
                    }

                  case 'pillar':
                    await sl<NotificationsBloc>().addNotification(
                      WalletNotification(
                        title: 'Deploy Pillar action detected',
                        timestamp: DateTime.now().millisecondsSinceEpoch,
                        details: 'Deep link: $uriRaw',
                        type: NotificationType.paymentReceived,
                      ),
                    );

                    if (kCurrentPage != Tabs.lock) {
                      _navigateTo(Tabs.pillars);
                    }

                  default:
                    await sl<NotificationsBloc>().addNotification(
                      WalletNotification(
                        title: 'Incoming link detected',
                        timestamp: DateTime.now().millisecondsSinceEpoch,
                        details: 'Deep link: $uriRaw',
                        type: NotificationType.paymentReceived,
                      ),
                    );
                    break;
                }
              }
              return;
            }
          }
        },
        onDone: () {
          Logger(
            'MainAppContainer',
          ).log(Level.INFO, '_handleIncomingLinks', 'done');
        },
        onError: (Object err) async {
          await NotificationUtils.sendNotificationError(
            err,
            'Handle incoming link failed',
          );
          Logger(
            'MainAppContainer',
          ).log(Level.WARNING, '_handleIncomingLinks', err);
          if (!mounted) return;
        },
      );
    }
  }

  Future<void> _handleInitialUri() async {
    if (!_initialUriIsHandled) {
      _initialUriIsHandled = true;
      try {
        final Uri? uri = await _appLinks.getInitialLink();
        if (uri != null) {
          Logger('MainAppContainer').log(Level.INFO, '_handleInitialUri $uri');
        }
        if (!mounted) return;
      } on PlatformException catch (e, stackTrace) {
        Logger('MainAppContainer').log(
          Level.WARNING,
          '_handleInitialUri PlatformException',
          e,
          stackTrace,
        );
      } on FormatException catch (e, stackTrace) {
        Logger('MainAppContainer').log(
          Level.WARNING,
          '_handleInitialUri FormatException',
          e,
          stackTrace,
        );
        if (!mounted) return;
      }
    }
  }

  @override
  Future<void> onClipboardChanged() async {
    final ClipboardData? newClipboardData = await Clipboard.getData(
      Clipboard.kTextPlain,
    );
    final text = newClipboardData?.text ?? '';
    if (text.isNotEmpty && Uri.tryParse(text) != null) {
      // This check is needed because onClipboardChanged is called twice sometimes
      if (kLastWalletConnectUriNotifier.value != text) {
        _updateWalletConnectUri(text);
      }
    }
  }

  Future<void> _updateWalletConnectUri(String text) async {
    kLastWalletConnectUriNotifier.value = text;
    if (!_isWalletLocked()) {
      if (kCurrentPage != Tabs.walletConnect) {
        await sl<NotificationsBloc>().addNotification(
          WalletNotification(
            title: 'WalletConnect link detected. Open Connected sites.',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            details:
                'A WalletConnect link has been copied to clipboard. '
                'Open Connected sites to connect to the dApp through ${kLastWalletConnectUriNotifier.value}',
            type: NotificationType.copiedToClipboard,
          ),
        );
        _navigateTo(Tabs.walletConnect);
      }
    }
  }
}
