import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/services/price_feed.dart'
    show PricedCoin;
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

/// The reference coin mark for native tokens in Transfer selectors.
Widget? buildTransferTokenMark(
  String tokenStandard,
  AppTokens tokens, {
  required Key markKey,
}) {
  final PricedCoin? coin = PricedCoin.ofTokenStandard(tokenStandard);
  if (coin == null) return null;

  final bool znn = coin == PricedCoin.znn;
  return ExcludeSemantics(
    child: Center(
      child: Container(
        key: markKey,
        width: tokens.transferTokenMarkSize,
        height: tokens.transferTokenMarkSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: znn ? tokens.znn : tokens.qsr,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            znn ? 'Z' : 'Q',
            style: tokens.transferTokenMarkText.copyWith(
              color: znn ? tokens.onZnn : tokens.transferTokenMarkText.color,
            ),
          ),
        ),
      ),
    ),
  );
}
