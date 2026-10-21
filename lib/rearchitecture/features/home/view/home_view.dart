import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/models/card/card.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/hero_field.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/motion/motion.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/plasma_meter.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/clipboard_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notifiers/default_address_notifier.dart';
import 'package:zenon_syrius_wallet_flutter/utils/zts_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/main_app_container.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/sheen.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The balance-first home of mockup B: one address's balance, plasma and
/// actions on top; its activity, what it can collect and its other tokens
/// under them.
///
/// Every figure flashes once when a new read changes it ([ValueFlash]); a
/// read that changes nothing moves nothing.
class HomeView extends StatelessWidget {
  /// Creates the home. [changePage] moves to another tab.
  const HomeView({required this.changePage, super.key});

  /// Moves to another tab.
  final void Function(Tabs) changePage;

  @override
  Widget build(BuildContext context) {
    return Consumer<SelectedAddressNotifier>(
      builder: (BuildContext context, _, _) {
        final String address = kSelectedAddress!;
        return BlocProvider<HomeCubit>(
          // Keyed by address: switching makes a new cubit, so an answer for
          // the previous address is never shown under this one, and the new
          // address's figures appear without a flash.
          key: ValueKey<String>(address),
          create: (_) {
            final HomeCubit cubit = HomeCubit(
              read: () => HomeSnapshot.read(zenon!, Address.parse(address)),
            );
            unawaited(cubit.refresh());
            return cubit;
          },
          child: _View(address: address, changePage: changePage),
        );
      },
    );
  }
}

class _View extends StatelessWidget {
  const _View({required this.address, required this.changePage});

  final String address;
  final void Function(Tabs) changePage;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (BuildContext context, HomeState state) {
        final HomeSnapshot? snapshot = state.snapshot;
        final double gap = AppTokens.of(context).panelGap;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Hero(
              address: address,
              snapshot: snapshot,
              failed: state.status == HomeStatus.failed,
              changePage: changePage,
            ),
            SizedBox(height: gap),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: LatestTransactionsCard(
                      type: CardType.latestTransactionsDashboard,
                    ),
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _Collect(snapshot: snapshot, changePage: changePage),
                        SizedBox(height: gap),
                        Expanded(child: _Tokens(snapshot: snapshot)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.address,
    required this.snapshot,
    required this.failed,
    required this.changePage,
  });

  final String address;
  final HomeSnapshot? snapshot;
  final bool failed;
  final void Function(Tabs) changePage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color fg = theme.textTheme.headlineSmall!.color!;
    final AppTokens tokens = AppTokens.of(context);
    final HomeSnapshot? s = snapshot;
    // The field runs to the card's edges, under the padding, and takes the
    // card's size from the row: the panel clips both to its corners.
    return Panel(
      child: Stack(
        children: <Widget>[
          const Positioned.fill(child: HeroField()),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
            child: _buildRow(context, theme, fg, tokens, s),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    ThemeData theme,
    Color fg,
    AppTokens tokens,
    HomeSnapshot? s,
  ) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _AddressLine(address: address),
              const SizedBox(height: 6),
              if (s == null)
                Text(
                  failed ? 'Node not answering' : 'Loading',
                  style: theme.textTheme.titleMedium!.copyWith(fontSize: 15),
                )
              else ...<Widget>[
                ValueFlash(
                  value: s.znn,
                  child: AmountText(
                    s.znn,
                    key: const Key('home_znn'),
                    decimals: kZnnCoin.decimals,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                      color: fg,
                      height: 1.1,
                    ),
                    symbol: kZnnCoin.symbol,
                    symbolColor: tokens.znnInk,
                  ),
                ),
                const SizedBox(height: 4),
                ValueFlash(
                  value: s.qsr,
                  color: tokens.qsrInk,
                  child: AmountText(
                    s.qsr,
                    key: const Key('home_qsr'),
                    decimals: kQsrCoin.decimals,
                    style: theme.textTheme.titleMedium!.copyWith(
                      fontSize: 18,
                    ),
                    symbol: kQsrCoin.symbol,
                    symbolColor: tokens.qsrInk,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 24),
        SizedBox(width: 210, child: _Plasma(snapshot: s)),
        const SizedBox(width: 28),
        Sheen(
          child: ElevatedButton.icon(
            key: const Key('home_send'),
            onPressed: () => changePage(Tabs.transfer),
            icon: const Icon(Icons.arrow_upward, size: 18),
            label: const Text('Send'),
            style: ElevatedButton.styleFrom(
              foregroundColor: kOnZnnColor,
              textStyle: kOutlinedButtonTextStyle,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _PillButton(
          key: const Key('home_receive'),
          icon: Icons.arrow_downward,
          label: 'Receive',
          onPressed: () => changePage(Tabs.transfer),
        ),
        const SizedBox(width: 10),
        _PillButton(
          key: const Key('home_swap'),
          icon: Icons.swap_horiz,
          label: 'Swap',
          onPressed: () => changePage(Tabs.p2pSwap),
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color ink = theme.textTheme.bodyLarge!.color!;
    final Color hover = AppTokens.of(context).hover;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      // The app theme makes every OutlinedButton the filled green action, so
      // its text and icon default to the dark green that sits on that fill.
      // On this quiet surface that ink reads as a disabled button: a
      // secondary action names its own.
      style:
          OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            foregroundColor: ink,
            iconColor: ink,
            backgroundColor: theme.colorScheme.primaryContainer,
            side: BorderSide(color: theme.dividerTheme.color!),
            textStyle: kOutlinedButtonTextStyle,
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith(
              (Set<WidgetState> states) =>
                  states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused) ||
                      states.contains(WidgetState.pressed)
                  ? hover
                  : null,
            ),
          ),
    );
  }
}

class _AddressLine extends StatelessWidget {
  const _AddressLine({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    final TextStyle label = ledgerLabelStyle(context);
    final AppTokens tokens = AppTokens.of(context);
    final String name = kAddressLabelMap[address] ?? 'Address';
    final String short =
        '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(name.toUpperCase(), style: label),
        const SizedBox(width: 8),
        Tooltip(
          message: address,
          child: Text(
            short,
            style: label.copyWith(
              letterSpacing: 0,
              color: Theme.of(context).textTheme.titleMedium!.color,
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          key: const Key('home_copy_address'),
          tooltip: 'Copy address',
          visualDensity: VisualDensity.compact,
          iconSize: 14,
          onPressed: () => ClipboardUtils.copyToClipboard(address, context),
          icon: Icon(Icons.copy_outlined, color: tokens.faint),
        ),
        if (kDefaultAddressList.length > 1)
          PopupMenuButton<String>(
            key: const Key('home_switch_address'),
            tooltip: 'Switch address',
            iconSize: 18,
            icon: Icon(Icons.expand_more, color: tokens.faint),
            onSelected: (String a) => selectWalletAddress(context, a),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              for (final String? a in kDefaultAddressList)
                if (a != null)
                  PopupMenuItem<String>(
                    value: a,
                    child: Text(
                      kAddressLabelMap[a] ?? a,
                      style: TextStyle(
                        color: a == address ? tokens.znnInk : null,
                      ),
                    ),
                  ),
            ],
          ),
      ],
    );
  }
}

class _Plasma extends StatelessWidget {
  const _Plasma({required this.snapshot});

  final HomeSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle label = ledgerLabelStyle(context);
    final Color qsrInk = AppTokens.of(context).qsrInk;
    final HomeSnapshot? s = snapshot;
    final double ratio = s == null || s.maxPlasma == 0
        ? 0
        : (s.currentPlasma / s.maxPlasma).clamp(0, 1).toDouble();
    final String level = s == null
        ? ''
        : s.maxPlasma == 0
        ? 'None'
        : ratio >= 0.66
        ? 'High'
        : ratio >= 0.33
        ? 'Medium'
        : 'Low';
    final String note = s == null
        ? ''
        : s.sendsCovered == 0
        ? 'Sends need proof of work'
        : s.sendsCovered == 1
        ? 'Enough for 1 send'
        : 'Enough for about ${s.sendsCovered} sends';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text('PLASMA', style: label)),
            ValueFlash(
              // A new flash per load state: the first read is not a change.
              key: ValueKey<bool>(s == null),
              value: level,
              color: qsrInk,
              child: Text(level.toUpperCase(), style: label),
            ),
          ],
        ),
        const SizedBox(height: 6),
        PlasmaMeter(
          value: ratio,
          trackColor: theme.dividerTheme.color ?? theme.dividerColor,
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: ValueFlash(
            key: ValueKey<bool>(s == null),
            value: note,
            color: qsrInk,
            child: Text(
              note,
              key: const Key('home_plasma_note'),
              style: theme.textTheme.titleMedium!.copyWith(fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

class _Collect extends StatelessWidget {
  const _Collect({required this.snapshot, required this.changePage});

  final HomeSnapshot? snapshot;
  final void Function(Tabs) changePage;

  static const Map<String, Tabs> _where = <String, Tabs>{
    'Delegation': Tabs.pillars,
    'Sentinel': Tabs.sentinels,
    'Staking': Tabs.staking,
  };

  /// Space above the first row and below the last.
  static const double _kPadding = 10;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppTokens tokens = AppTokens.of(context);
    final Map<String, UncollectedReward> due =
        snapshot?.rewardsDue ?? <String, UncollectedReward>{};
    final TextStyle dim = theme.textTheme.titleMedium!.copyWith(fontSize: 14);
    final TextStyle value = theme.textTheme.bodyLarge!.copyWith(fontSize: 14);
    // Rows of one height, tall enough for the Collect button at the app's
    // largest text scale. The panel is as tall as its rows (shrinkWrap): it
    // sits in a column that gives it no height of its own.
    final double row = math.max(
      36,
      MediaQuery.textScalerOf(context).scale(14) + 22,
    );
    return Panel(
      title: 'To collect',
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, _kPadding, 16, _kPadding),
      child: due.isEmpty
          ? SizedBox(
              height: row,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('None yet', style: dim),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final MapEntry<String, UncollectedReward> e in due.entries)
                  SizedBox(
                    key: ValueKey<String>(e.key),
                    height: row,
                    child: Row(
                      children: <Widget>[
                        Expanded(child: Text(e.key, style: dim)),
                        if (e.value.znnAmount > BigInt.zero)
                          ValueFlash(
                            value: e.value.znnAmount,
                            child: AmountText(
                              e.value.znnAmount,
                              decimals: kZnnCoin.decimals,
                              style: value.copyWith(color: tokens.znnInk),
                              symbol: kZnnCoin.symbol,
                              symbolColor: tokens.znnInk,
                            ),
                          ),
                        if (e.value.qsrAmount > BigInt.zero) ...<Widget>[
                          const SizedBox(width: 10),
                          ValueFlash(
                            value: e.value.qsrAmount,
                            color: tokens.qsrInk,
                            child: AmountText(
                              e.value.qsrAmount,
                              decimals: kQsrCoin.decimals,
                              style: value.copyWith(color: tokens.qsrInk),
                              symbol: kQsrCoin.symbol,
                              symbolColor: tokens.qsrInk,
                            ),
                          ),
                        ],
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: () => changePage(_where[e.key]!),
                          child: const Text('Collect'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Tokens extends StatelessWidget {
  const _Tokens({required this.snapshot});

  final HomeSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<BalanceInfoListItem> tokens =
        snapshot?.tokens ?? <BalanceInfoListItem>[];
    return Panel(
      title: 'Tokens',
      actions: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ValueFlash(
            // The first read is not a change.
            key: ValueKey<bool>(snapshot == null),
            value: tokens.length,
            child: Text('${tokens.length}', style: ledgerLabelStyle(context)),
          ),
        ),
      ],
      child: tokens.isEmpty
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Text(
                'None yet',
                style: theme.textTheme.titleMedium!.copyWith(fontSize: 14),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: tokens.length,
              itemBuilder: (BuildContext context, int i) {
                final Token token = tokens[i].token!;
                return Padding(
                  // Keyed by token, so a row that now shows another token is
                  // a new row and does not flash the other token's balance.
                  key: ValueKey<String>(token.tokenStandard.toString()),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.ztsColor,
                        child: Text(
                          token.symbol.isEmpty ? '?' : token.symbol[0],
                          style: monoStyle(
                            const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Tooltip(
                          message: token.tokenStandard.toString(),
                          child: Text(
                            token.symbol,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge!.copyWith(
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      ValueFlash(
                        value: tokens[i].balance,
                        child: AmountText(
                          tokens[i].balance!,
                          decimals: token.decimals,
                          style: theme.textTheme.bodyLarge!.copyWith(
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
