import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/pow_generating_status_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/home/cubit/home_cubit.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/home/select_address.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/home/widgets/amount_text.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/transfer/view/transfer_page.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/dollar_text.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/eye_toggle.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/hero_field.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/ltr.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/motion/motion.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/plasma_meter.dart';
import 'package:zenon_syrius_wallet_flutter/seams/seam.dart';
import 'package:zenon_syrius_wallet_flutter/services/price_feed.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/clipboard_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notifiers/balance_visibility.dart';
import 'package:zenon_syrius_wallet_flutter/utils/zts_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/primary_pill.dart';

part 'home_hero_balances.dart';
part 'home_hero_controls.dart';
part 'home_hero_plasma.dart';

/// One address's balances, available plasma and transfer entry points.
///
/// The page owns its snapshot and navigation. Keeping this surface separate
/// lets the activity and side cards change without altering the money header.
class HomeHero extends StatelessWidget {
  /// Draws the current [snapshot], retaining it through a failed refresh.
  const HomeHero({
    required this.address,
    required this.snapshot,
    required this.failed,
    required this.onOpenTransfer,
    this.visibility,
    this.priceFeed,
    this.powStatus,
    super.key,
  });

  /// The selected address, whose label and switcher use the wallet's state.
  final String address;

  /// The last successful read, or null before one has arrived.
  final HomeSnapshot? snapshot;

  /// Whether the node's last read failed.
  final bool failed;

  /// Opens the selected mode of the session's existing Transfer page.
  final ValueChanged<TransferMode> onOpenTransfer;

  /// The shared privacy choice; the wallet's notifier when omitted.
  final BalanceVisibility? visibility;

  /// The existing feed; injectable so isolated previews need no network.
  final PriceFeed? priceFeed;

  /// Owned generation displays; the wallet's live stream by default.
  final Stream<PowGenerationState>? powStatus;

  @override
  Widget build(BuildContext context) {
    final BalanceVisibility balances = visibility ?? BalanceVisibility.instance;
    final PriceFeed prices = priceFeed ?? PriceFeed.instance;
    final AppTokens tokens = AppTokens.of(context);
    return Panel(
      child: Stack(
        children: <Widget>[
          const Positioned.fill(child: IgnorePointer(child: HeroField())),
          Padding(
            padding: tokens.heroPadding,
            child: ListenableBuilder(
              listenable: balances,
              builder: (BuildContext context, Widget? child) => LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double scale = math.max(
                    1,
                    MediaQuery.textScalerOf(context).scale(
                          tokens.heroAmountText.fontSize!,
                        ) /
                        tokens.heroAmountText.fontSize!,
                  );
                  final Widget balancesColumn = _buildBalances(
                    context,
                    balances,
                    prices,
                  );
                  final Widget plasma = SizedBox(
                    width: math.min(
                      tokens.heroPlasmaWidth * scale,
                      constraints.maxWidth,
                    ),
                    child: _HomeHeroPlasma(
                      snapshot: snapshot,
                      status:
                          powStatus ?? sl.get<PowGeneratingStatusBloc>().stream,
                    ),
                  );
                  final Widget actions = _HomeHeroActions(
                    onOpenTransfer: onOpenTransfer,
                  );
                  // Keep the measured desktop row at normal type size. Larger
                  // text gets another line instead of clipping an amount or
                  // making one of the actions unreachable.
                  final double requiredWidth =
                      _balanceWidth(context, balances.hidden) +
                      tokens.heroPlasmaWidth * scale +
                      _actionsWidth(context) +
                      2 * tokens.heroGap;
                  if (constraints.maxWidth < requiredWidth) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        balancesColumn,
                        SizedBox(height: tokens.heroStackGap),
                        Wrap(
                          spacing: tokens.heroGap,
                          runSpacing: tokens.heroStackGap,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[plasma, actions],
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: <Widget>[
                      Expanded(child: balancesColumn),
                      SizedBox(width: tokens.heroGap),
                      plasma,
                      SizedBox(width: tokens.heroGap),
                      actions,
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _balanceWidth(BuildContext context, bool hidden) {
    final HomeSnapshot? current = snapshot;
    if (current == null) return 0;
    final AppTokens tokens = AppTokens.of(context);
    // A large holding must not lose its final base unit to the headline's
    // fade. Hidden layout is measured from dots, never from the hidden value.
    final double znn = _textWidth(
      context,
      hidden
          ? kHiddenAmountDots
          : splitAmount(current.znn, kZnnCoin.decimals).$1,
      tokens.heroAmountText.copyWith(
        letterSpacing: hidden
            ? tokens.heroAmountText.fontSize! * tokens.hiddenAmountTrackingEm
            : tokens.heroAmountText.letterSpacing,
      ),
    );
    final double qsr = _textWidth(
      context,
      hidden
          ? kHiddenAmountDots
          : splitAmount(current.qsr, kQsrCoin.decimals).$1,
      tokens.heroSecondaryAmountText.copyWith(
        letterSpacing: hidden
            ? tokens.heroSecondaryAmountText.fontSize! *
                  tokens.hiddenAmountTrackingEm
            : tokens.heroSecondaryAmountText.letterSpacing,
      ),
    );
    final TextStyle symbol = tokens.heroSymbolText;
    return math.max(
          znn + _textWidth(context, kZnnCoin.symbol, symbol),
          qsr + _textWidth(context, kQsrCoin.symbol, symbol),
        ) +
        tokens.heroSymbolGap;
  }

  double _actionsWidth(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final TextStyle style = tokens.buttonText;
    return _textWidth(context, context.l10n.send, style) +
        _textWidth(context, context.l10n.receive, style) +
        _textWidth(context, context.l10n.transferZap, style) +
        // Per action: horizontal padding, icon and label gap. Two row gaps.
        3 *
            (tokens.heroActionPadding.horizontal +
                tokens.heroIconSize +
                tokens.inlineGap) +
        2 * tokens.heroActionGap;
  }

  double _textWidth(BuildContext context, String text, TextStyle style) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final double width = painter.width;
    painter.dispose();
    return width;
  }

  Widget _buildBalances(
    BuildContext context,
    BalanceVisibility balances,
    PriceFeed prices,
  ) {
    final HomeSnapshot? current = snapshot;
    final AppTokens tokens = AppTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _HomeHeroAddress(address: address, visibility: balances),
        SizedBox(height: tokens.heroBalanceGap),
        if (current == null)
          Text(
            failed
                ? context.l10n.homeNodeNotAnswering
                : context.l10n.homeLoading,
            key: const Key('home_hero_status'),
            style: tokens.heroLoadingText,
          )
        else
          _HomeHeroBalances(
            snapshot: current,
            visibility: balances,
            feed: prices,
          ),
      ],
    );
  }
}
