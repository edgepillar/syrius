import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/ltr.dart';
import 'package:zenon_syrius_wallet_flutter/services/price_feed.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

/// An amount of one token: base units, the token's decimals, and which
/// priced coin it is. A null coin is any other token, which has no price.
typedef CoinAmount = ({BigInt amount, int decimals, PricedCoin? coin});

/// What stands in for a value while balances are hidden.
const String _kDots = '••••';

/// What an amount is worth in dollars: dim, mono, 13 px, after the coin
/// amount. The coin is the headline, never the dollars.
///
/// It draws nothing, and takes no room, for a token with no price, before
/// the first price has arrived, and while Dollar values is off in Settings.
/// Put any gap before it inside the same condition, or use a `Wrap` or a
/// `Row` spacing that skips an empty child.
///
/// It listens to the [PriceFeed] while it is mounted and at no other time,
/// and the feed asks only while something listens. That is the whole of
/// "prices are fetched only while a screen that shows a value is open":
/// do not hold a mounted one off stage.
class DollarText extends StatefulWidget {
  /// The worth of [amount] base units of [coin], which has [decimals].
  DollarText({
    required BigInt amount,
    required int decimals,
    required PricedCoin? coin,
    this.approx = false,
    this.hidden = false,
    this.color,
    this.feed,
    super.key,
  }) : parts = <CoinAmount>[
          (amount: amount, decimals: decimals, coin: coin),
        ];

  /// The worth of several amounts together: both balances, or everything
  /// there is to collect. A sum is an estimate, so [approx] is on.
  ///
  /// If one of [parts] has no price the sum is not drawn: a total that
  /// leaves something out is a wrong total.
  const DollarText.sum(
    this.parts, {
    this.approx = true,
    this.hidden = false,
    this.color,
    this.feed,
    super.key,
  });

  /// What is added up; one entry for a single amount.
  final List<CoinAmount> parts;

  /// Whether `≈ ` goes in front: a sum or an estimate.
  final bool approx;

  /// Whether balances are hidden. Dots then, in the same place.
  final bool hidden;

  /// The text colour, where the faint token is not it: the total under
  /// the two balances is one step stronger.
  final Color? color;

  /// The feed to read. The wallet's own when null; a test passes one that
  /// never touches the network.
  final PriceFeed? feed;

  @override
  State<DollarText> createState() => _DollarTextState();
}

class _DollarTextState extends State<DollarText> {
  /// The feed this state is listening to, or null when it is not.
  PriceFeed? _listeningTo;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(DollarText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _listen();
  }

  @override
  void dispose() {
    _listeningTo?.removeListener(_onFeed);
    super.dispose();
  }

  /// Listens to the widget's feed if any part can have a price, and to
  /// nothing otherwise: a list of other tokens must not cause a request.
  void _listen() {
    final PriceFeed? wanted =
        widget.parts.isNotEmpty &&
                widget.parts.every((CoinAmount part) => part.coin != null)
            ? widget.feed ?? PriceFeed.instance
            : null;
    if (identical(wanted, _listeningTo)) {
      return;
    }
    _listeningTo?.removeListener(_onFeed);
    _listeningTo = wanted?..addListener(_onFeed);
  }

  void _onFeed() => setState(() {});

  /// The parts' worth together, or null when there is nothing to draw.
  Usd? _worth() {
    final PriceFeed? feed = _listeningTo;
    if (feed == null) {
      return null;
    }
    Usd? total;
    for (final CoinAmount part in widget.parts) {
      final PricedCoin? coin = part.coin;
      final Usd? price = coin == null ? null : feed.priceOf(coin);
      if (price == null) {
        return null;
      }
      final Usd worth = price.worth(part.amount, part.decimals);
      total = total == null ? worth : total + worth;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final Usd? worth = _worth();
    if (worth == null) {
      return const SizedBox.shrink();
    }
    final String text = widget.hidden
        ? '${widget.approx ? '≈ ' : ''}$_kDots'
        : worth.format(approx: widget.approx);
    // Read above the pin: under it the app's direction is gone.
    final TextAlign align = ltrTextAlign(context);
    return Ltr(
      child: Text(
        text,
        style: monoStyle(
          TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
            color: widget.color ?? AppTokens.of(context).faint,
          ),
        ),
        textAlign: align,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.fade,
      ),
    );
  }
}
