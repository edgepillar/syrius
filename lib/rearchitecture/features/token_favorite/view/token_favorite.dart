import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/token_favorite/bloc/token_favorite_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/token_favorite/exceptions/favorite_tokens_exception.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/tokens/widgets/token_row_action.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notification_utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

const String _kAddTooltip = 'Add to favorites';
const String _kRemoveTooltip = 'Remove from favorites';

/// The star of a token row: adds the token to the wallet's favorites, or
/// takes it out.
class TokenFavorite extends StatelessWidget {
  /// Creates a [TokenFavorite].
  const TokenFavorite({
    required this._token,
    required this._callback,
    super.key,
  });
  final Token _token;
  final VoidCallback _callback;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TokenFavoriteBloc>(
      create: (_) => TokenFavoriteBloc(
        tokenStandard: _token.tokenStandard,
      ),
      child: _View(callback: _callback, token: _token),
    );
  }
}

class _View extends StatelessWidget {
  const _View({required this._callback, required this._token});

  final VoidCallback _callback;
  final Token _token;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TokenFavoriteBloc, TokenFavoriteState>(
      listener: _onTokenFavoriteStateChanged,
      // While the change is being saved the star keeps the look it had: the
      // bloc ignores a second press, and a spinner in a list row would only
      // make the row jump.
      buildWhen: (_, TokenFavoriteState current) =>
          current is! TokenFavoriteLoading,
      builder: (BuildContext context, TokenFavoriteState state) {
        final bool isFavorite = switch (state) {
          TokenFavoriteFavorited() => true,
          TokenFavoriteNotFavorited() || TokenFavoriteLoading() => false,
          TokenFavoriteFailure(:final FavoriteTokensException exception) =>
            exception is RemovingFromFavoriteTokensException,
        };
        return TokenRowAction(
          key: const Key('token_favorite_button'),
          tooltip: isFavorite ? _kRemoveTooltip : _kAddTooltip,
          onPressed: () => context.read<TokenFavoriteBloc>().add(
            isFavorite
                ? const TokenFavoriteRemoved()
                : const TokenFavoriteAdded(),
          ),
          icon: AnimatedSwitcher(
            duration: Durations.short4,
            switchInCurve: Easing.emphasizedDecelerate,
            switchOutCurve: Easing.emphasizedAccelerate,
            transitionBuilder: (Widget child, Animation<double> animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              isFavorite ? Icons.star : Icons.star_border,
              key: ValueKey<bool>(isFavorite),
              color: isFavorite
                  ? AppTokens.of(context).znnInk
                  : AppTokens.of(context).faint,
            ),
          ),
        );
      },
    );
  }

  void _onTokenFavoriteStateChanged(
    BuildContext context,
    TokenFavoriteState state,
  ) {
    if (state is TokenFavoriteFavorited) {
      unawaited(_sendAddedNotification(context));
    } else if (state is TokenFavoriteNotFavorited) {
      unawaited(_sendRemovedNotification(context));
    } else if (state is TokenFavoriteFailure) {
      final String title = switch (state.exception) {
        AddingToFavoriteTokensException() =>
          context.l10n.errorAddingTokenToFavorites(_token.name),
        RemovingFromFavoriteTokensException() =>
          context.l10n.errorRemovingTokenFromFavorites(_token.name),
      };
      unawaited(
        NotificationUtils.sendNotificationError(
          state.exception,
          title,
        ),
      );
    }
  }

  Future<void> _sendAddedNotification(BuildContext context) async {
    await sl.get<NotificationsBloc>().addNotification(
      WalletNotification(
        title: context.l10n.tokenAddedToFavorites(_token.name),
        details: context.l10n.tokenSummary(
          _token.name,
          _token.symbol,
          _token.tokenStandard,
        ),
        timestamp: DateTime.now().millisecondsSinceEpoch,
        type: NotificationType.addedTokenFavourite,
      ),
    );
    _callback();
  }

  Future<void> _sendRemovedNotification(BuildContext context) async {
    await sl.get<NotificationsBloc>().addNotification(
      WalletNotification(
        title: context.l10n.tokenRemovedFromFavorites(_token.name),
        details: context.l10n.tokenSummary(
          _token.name,
          _token.symbol,
          _token.tokenStandard,
        ),
        timestamp: DateTime.now().millisecondsSinceEpoch,
        type: NotificationType.addedTokenFavourite,
      ),
    );
    _callback();
  }
}
