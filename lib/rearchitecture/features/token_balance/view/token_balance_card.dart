import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/home/widgets/amount_text.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/multiple_balance/multiple_balance.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/refresh_button/refresh_button.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

const String _kTitle = 'Balances';

/// The height of a balance row.
const double _kRowHeight = 44;

/// The ZTS tokens the selected address holds, and how much of each.
class TokenBalanceCard extends StatelessWidget {
  /// Creates a new instance.
  const TokenBalanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: _kTitle,
      actions: <Widget>[
        RefreshButton(
          onPressed: () {
            context.read<MultipleBalanceBloc>().add(
              MultipleBalanceFetch(
                addresses: kDefaultAddressList.map((String? e) => e!).toList(),
              ),
            );
          },
        ),
      ],
      child: BlocBuilder<MultipleBalanceBloc, MultipleBalanceState>(
        buildWhen: (MultipleBalanceState previous, MultipleBalanceState next) =>
            previous.status != next.status || previous.data != next.data,
        builder: (BuildContext context, MultipleBalanceState state) {
          // A refresh keeps the last balances on screen; a balance that
          // comes back different flashes.
          final AccountInfo? accountInfo = state.data?[kSelectedAddress];
          return StateSwitcher(
            child: accountInfo != null
                ? _Populated(
                    key: const ValueKey<String>('populated'),
                    accountInfo: accountInfo,
                  )
                : state.status == MultipleBalanceStatus.failure
                ? CardNote.error(
                    state.error!,
                    key: const ValueKey<String>('error'),
                  )
                : const Padding(
                    key: ValueKey<String>('loading'),
                    padding: kCardBodyPadding,
                    child: SkeletonRows(),
                  ),
          );
        },
      ),
    );
  }
}

class _Populated extends StatelessWidget {
  const _Populated({required this.accountInfo, super.key});

  final AccountInfo accountInfo;

  @override
  Widget build(BuildContext context) {
    final Set<TokenStandard> coins = <TokenStandard>{
      kZnnCoin.tokenStandard,
      kQsrCoin.tokenStandard,
    };
    final List<BalanceInfoListItem> balances =
        accountInfo.balanceInfoList
            ?.where(
              (BalanceInfoListItem item) =>
                  item.token != null &&
                  item.balance != null &&
                  !coins.contains(item.token!.tokenStandard),
            )
            .toList() ??
        <BalanceInfoListItem>[];

    if (balances.isEmpty) {
      return CardNote(context.l10n.noItemsFound);
    }

    return ListView.builder(
      key: const PageStorageKey<String>('token_balances'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemExtent: _kRowHeight,
      itemCount: balances.length,
      itemBuilder: (BuildContext context, int index) => _BalanceRow(
        key: ValueKey<String>(balances[index].token!.tokenStandard.toString()),
        balance: balances[index].balance!,
        token: balances[index].token!,
      ),
    );
  }
}

/// A token's symbol and name, and the amount held in mono.
class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.balance, required this.token, super.key});

  final BigInt balance;
  final Token token;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          Text(
            token.symbol.toUpperCase(),
            style: cardValueStyle(context).copyWith(
              fontWeight: FontWeight.w600,
              color: cardTokenInk(token.tokenStandard),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Tooltip(
              message: token.tokenStandard.toString(),
              child: Text(
                token.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: cardDimStyle(context),
              ),
            ),
          ),
          const SizedBox(width: kCardGap),
          // The amount keeps the right half, so the figures of every row
          // end on one edge whatever the length of the name.
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: ValueFlash(
                value: balance,
                child: AmountText(
                  balance,
                  decimals: token.decimals,
                  style: cardValueStyle(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
