import 'dart:async';

import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/fused_plasma/model/fusion_entry_wrapper.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/plasma_stats/model/plasma_info_wrapper.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/blocs/blocs.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// When [FusionsFollowUp] reloads after a fuse or a cancel, counted from the
/// moment the send was published.
///
/// The send is published at once, but the plasma contract makes or drops the
/// fusion only when it receives it, about two momentums later. A reload at
/// the moment of publishing found nothing, and the list and the plasma card
/// stayed as they were until Refresh was pressed.
const List<Duration> kFusionsFollowUpDelays = <Duration>[
  Duration(seconds: 10),
  Duration(seconds: 20),
  Duration(seconds: 40),
  Duration(seconds: 60),
];

/// Reloads the fusions and the plasma levels after a fuse or a cancel until
/// each shows the change, and at most until the last of [delays].
///
/// The two are waited for apart. The levels can be read a momentum behind
/// the fusions: on devnet the new row showed while the card still read the
/// old plasma and fused QSR, and stopping both with the list left the card
/// stale until Refresh. So the list is reloaded until its fusion ids change,
/// and the levels until the selected address's fused QSR differs from where
/// it stood, up or down, since a cancel lowers it. A change in the list
/// that names no fusion for the selected address cannot move its levels;
/// the levels' wait then ends with the list's.
///
/// Both reload with [InfiniteListRequested], which keeps the rows and the
/// figures on screen until the new ones arrive. [InfiniteListRefreshRequested]
/// first empties the state, so each reload would flash the loading bars.
class FusionsFollowUp {
  /// Creates a follow-up over the page's fusions and the plasma levels.
  FusionsFollowUp({
    required this._fusions,
    required this._levels,
    required this._address,
    this.delays = kFusionsFollowUpDelays,
  });

  final InfiniteListBloc<FusionEntryWrapper> _fusions;
  final InfiniteListBloc<PlasmaInfoWrapper> _levels;

  /// The address whose fusions are listed and whose levels are watched, read
  /// at each reload: the selected address can change while the follow-up
  /// runs.
  final Address Function() _address;

  /// When to reload, counted from [start].
  final List<Duration> delays;

  final List<Timer> _timers = <Timer>[];
  StreamSubscription<InfiniteListState<FusionEntryWrapper>>? _fusionsSub;
  StreamSubscription<InfiniteListState<PlasmaInfoWrapper>>? _levelsSub;

  /// The fusions last seen, id to beneficiary; null until a loaded list has
  /// been seen.
  Map<String, Address>? _seen;

  /// The changes started and not yet seen in the list. Two fuses a few
  /// seconds apart can land in different momentums; the first to show must
  /// not end the wait for the second.
  int _pending = 0;

  /// Of the fusions that came or went, those for the selected address: the
  /// only ones that move its levels.
  int _ownChanges = 0;

  /// The selected address's fused QSR last seen, and the address it was
  /// read for; null until loaded levels listing it have been seen.
  BigInt? _amount;
  String? _amountFor;

  /// The changes started and not yet seen in the levels, and those seen.
  int _levelsPending = 0;
  int _levelsChanges = 0;

  bool _listWaiting = false;
  bool _levelsWaiting = false;

  /// Whether reloads are still to come.
  bool get isRunning => _timers.any((Timer t) => t.isActive);

  /// Reloads now and at each of [delays] from now, until the list and the
  /// levels have changed.
  void start() {
    // What is left of a run that ended without seeing its change is not
    // owed to this one.
    if (!isRunning) stop();
    _seen ??= _entriesOf(_fusions.state);
    _readAmount(_levels.state);
    _pending++;
    _levelsPending++;
    _listWaiting = true;
    _levelsWaiting = true;
    _fusionsSub ??= _fusions.stream.listen(_onFusions);
    _levelsSub ??= _levels.stream.listen(_onLevels);
    for (final Timer t in _timers) {
      t.cancel();
    }
    _timers
      ..clear()
      ..addAll(delays.map((Duration d) => Timer(d, _reload)));
    _reload();
  }

  /// Stops reloading.
  void stop() {
    for (final Timer t in _timers) {
      t.cancel();
    }
    _timers.clear();
    unawaited(_fusionsSub?.cancel());
    unawaited(_levelsSub?.cancel());
    _fusionsSub = null;
    _levelsSub = null;
    _seen = null;
    _pending = 0;
    _ownChanges = 0;
    _amount = null;
    _amountFor = null;
    _levelsPending = 0;
    _levelsChanges = 0;
    _listWaiting = false;
    _levelsWaiting = false;
  }

  /// Stops reloading for good: the page that owned it is gone.
  void dispose() => stop();

  void _reload() {
    if (_listWaiting) {
      _fusions.add(InfiniteListRequested(address: _address()));
    }
    if (_levelsWaiting) _levels.add(const InfiniteListRequested());
  }

  void _onFusions(InfiniteListState<FusionEntryWrapper> state) {
    if (!_listWaiting) return;
    final Map<String, Address>? entries = _entriesOf(state);
    if (entries == null) return;
    final Map<String, Address>? seen = _seen;
    _seen = entries;
    // The first loaded list is where the wait starts from, not a change.
    if (seen == null) return;
    final String own = _address().toString();
    final List<Address> changed = <Address>[
      for (final MapEntry<String, Address> e in entries.entries)
        if (!seen.containsKey(e.key)) e.value,
      for (final MapEntry<String, Address> e in seen.entries)
        if (!entries.containsKey(e.key)) e.value,
    ];
    if (changed.isEmpty) return;
    _ownChanges += changed.where((Address a) => a.toString() == own).length;
    _pending -= changed.length;
    if (_pending > 0) return;
    _listWaiting = false;
    // The levels can still owe only what the list says changed for the
    // selected address; a fuse for another address leaves them as they are.
    _levelsPending = _ownChanges - _levelsChanges;
    if (_levelsPending <= 0) _levelsWaiting = false;
    // The levels were asked for with the list, and may have been read a
    // momentum before it: ask once more, after the list has the change. The
    // beneficiary's own row is in the levels too when it is in this wallet.
    _levels.add(const InfiniteListRequested());
    _stopIfDone();
  }

  void _onLevels(InfiniteListState<PlasmaInfoWrapper> state) {
    if (!_levelsWaiting) return;
    if (!_readAmount(state)) return;
    _levelsChanges++;
    _levelsPending--;
    if (_levelsPending > 0) return;
    _levelsWaiting = false;
    _stopIfDone();
  }

  /// Takes the selected address's fused QSR from [state], and says whether
  /// it moved from the amount last seen for the same address. The first
  /// amount seen for an address is where the wait starts from.
  bool _readAmount(InfiniteListState<PlasmaInfoWrapper> state) {
    final List<PlasmaInfoWrapper>? data = state.data;
    if (state.status != InfiniteListStatus.success || data == null) {
      return false;
    }
    final String own = _address().toString();
    BigInt? amount;
    for (final PlasmaInfoWrapper w in data) {
      if (w.address == own) amount = w.plasmaInfo.qsrAmount;
    }
    if (amount == null) return false;
    final bool moved =
        _amountFor == own && _amount != null && _amount != amount;
    _amount = amount;
    _amountFor = own;
    return moved;
  }

  void _stopIfDone() {
    if (!_listWaiting && !_levelsWaiting) stop();
  }

  static Map<String, Address>? _entriesOf(
    InfiniteListState<FusionEntryWrapper> state,
  ) {
    final List<FusionEntryWrapper>? data = state.data;
    if (state.status != InfiniteListStatus.success || data == null) {
      return null;
    }
    return <String, Address>{
      for (final FusionEntryWrapper w in data)
        w.fusionEntry.id.toString(): w.fusionEntry.beneficiary,
    };
  }
}
