import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/home/widgets/amount_text.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/ltr.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// A block the wallet published that no momentum has taken in yet.
@immutable
class InFlightBlock {
  /// Creates the record of a published send.
  const InFlightBlock({
    required this.hash,
    required this.amount,
    required this.decimals,
    required this.symbol,
  });

  /// The published block's hash.
  final Hash hash;

  /// What it sends, in the token's smallest unit.
  final BigInt amount;

  /// The token's decimals.
  final int decimals;

  /// The token's symbol.
  final String symbol;
}

/// Asks the node whether a momentum has taken the block in.
typedef ConfirmationLookup = Future<bool> Function(Hash hash);

Future<bool> _askNode(Hash hash) async =>
    (await zenon!.ledger.getAccountBlockByHash(hash))?.confirmationDetail !=
    null;

/// The sends that are waiting for their momentum, for the strip's chip.
///
/// Nothing in the wallet followed a block after it was published: the send
/// flow reported "published" and stopped, and the page showed a fixed wait.
/// This is the one place that knows, with two calls for whoever publishes:
///
///  * [sent], with the block the node accepted;
///  * [settle], only by a caller that learns of the confirmation itself.
///
/// A caller that does not is covered by [check], which the strip runs at
/// each new momentum and which asks the node about every block held here.
class InFlightBlocks extends ChangeNotifier
    implements ValueListenable<List<InFlightBlock>> {
  /// Creates an empty set. [lookup] is the node's ledger when null.
  InFlightBlocks({ConfirmationLookup? lookup}) : _lookup = lookup ?? _askNode;

  /// The wallet's own, shown by the strip unless it is given another.
  static final InFlightBlocks wallet = InFlightBlocks();

  final ConfirmationLookup _lookup;
  List<InFlightBlock> _blocks = const <InFlightBlock>[];
  bool _checking = false;

  /// The blocks in flight, oldest first.
  @override
  List<InFlightBlock> get value => _blocks;

  /// Records a send the node has accepted. Call it with the published
  /// block's hash, as soon as the send returns.
  void sent({
    required Hash hash,
    required BigInt amount,
    required int decimals,
    required String symbol,
  }) {
    if (_blocks.any((InFlightBlock block) => block.hash == hash)) {
      return;
    }
    _blocks = <InFlightBlock>[
      ..._blocks,
      InFlightBlock(
        hash: hash,
        amount: amount,
        decimals: decimals,
        symbol: symbol,
      ),
    ];
    notifyListeners();
  }

  /// Takes [hash] out: a momentum has it, or it will never have one.
  void settle(Hash hash) {
    final List<InFlightBlock> rest = <InFlightBlock>[
      for (final InFlightBlock block in _blocks)
        if (block.hash != hash) block,
    ];
    if (rest.length != _blocks.length) {
      _blocks = rest;
      notifyListeners();
    }
  }

  /// Forgets every block: the wallet was locked, or the node was changed
  /// and the new one may never have heard of them.
  void clear() {
    if (_blocks.isNotEmpty) {
      _blocks = const <InFlightBlock>[];
      notifyListeners();
    }
  }

  /// Asks about each block held and settles the confirmed ones.
  ///
  /// A node that does not answer leaves the block where it is: "waiting" is
  /// still the truth as far as the wallet can tell.
  Future<void> check() async {
    if (_checking || _blocks.isEmpty) {
      return;
    }
    _checking = true;
    try {
      for (final InFlightBlock block in _blocks.toList()) {
        try {
          if (await _lookup(block.hash)) {
            settle(block.hash);
          }
        } on Object {
          continue;
        }
      }
    } finally {
      _checking = false;
    }
  }
}

/// Says what is being sent while it waits for a momentum; nothing when no
/// block is in flight.
class FlightChip extends StatelessWidget {
  /// Creates the chip over [blocks].
  const FlightChip({required this.blocks, super.key});

  /// The sends in flight.
  final ValueListenable<List<InFlightBlock>> blocks;

  /// Stands in the translated sentence where the amount goes, so the
  /// amount can be drawn left to right wherever the language puts it.
  static const String _slot = '\u{FFFC}';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<InFlightBlock>>(
      valueListenable: blocks,
      builder: (BuildContext context, List<InFlightBlock> blocks, _) {
        if (blocks.isEmpty) {
          return const SizedBox.shrink();
        }
        final AppTokens tokens = AppTokens.of(context);
        final TextStyle dim = Theme.of(
          context,
        ).textTheme.titleMedium!.copyWith(fontSize: 13);
        final List<InlineSpan> what;
        if (blocks.length == 1) {
          final InFlightBlock block = blocks.single;
          final (String digits, _) = splitAmount(block.amount, block.decimals);
          final List<String> around = context.l10n
              .stripSending(_slot)
              .split(_slot);
          what = <InlineSpan>[
            TextSpan(text: around.first),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Ltr(
                child: Text(
                  '$digits ${block.symbol}',
                  style: monoStyle(dim),
                ),
              ),
            ),
            if (around.length > 1) TextSpan(text: around.last),
          ];
        } else {
          what = <InlineSpan>[
            TextSpan(text: context.l10n.stripSendingMany(blocks.length)),
          ];
        }
        return Row(
          key: const Key('strip_flight'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            RepaintBoundary(child: _LiveDot(color: tokens.qsrInk)),
            SizedBox(width: tokens.cardGap - 2),
            Flexible(
              child: Text.rich(
                TextSpan(
                  style: dim,
                  children: <InlineSpan>[
                    ...what,
                    TextSpan(
                      text: ' · ${context.l10n.stripWaitingMomentum}',
                      style: TextStyle(color: tokens.faint),
                    ),
                  ],
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A dot that breathes for as long as it is shown: the block is still out.
class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.color});

  final Color color;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.35).animate(
        CurvedAnimation(parent: _controller, curve: Easing.standard),
      ),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
