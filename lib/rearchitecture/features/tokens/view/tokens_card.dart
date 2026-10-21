import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:nested/nested.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

const String _kSearchHint = 'Search tokens';
const String _kClearSearch = 'Clear';
const String _kNoMatch = 'No match';

/// The token list: every ZTS token on the network, searchable, one row
/// each, with what the selected address may do to a token on its row.
class TokensCard extends StatelessWidget {
  /// Creates a new instance.
  const TokensCard({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <SingleChildWidget>[
        BlocProvider<TokensBloc>(
          create: (_) =>
              TokensBloc(zenon: zenon!)..add(const InfiniteListRequested()),
        ),
        BlocProvider<SearchTokenBloc>(
          create: (_) => SearchTokenBloc(zenon: zenon!),
        ),
      ],
      child: const _View(),
    );
  }
}

class _View extends StatefulWidget {
  const _View();

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: context.l10n.tokens,
      actions: <Widget>[RefreshButton(onPressed: _onRefreshPressed)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: CardFields(
              child: _SearchField(
                controller: _searchController,
                onChanged: _onSearchChanged,
              ),
            ),
          ),
          const TokenListHeader(),
          const SizedBox(height: 8),
          const Divider(),
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (_, TextEditingValue value, _) {
                final String query = value.text.trim();
                return StateSwitcher(
                  child: query.isEmpty
                      ? const _AllTokens(key: ValueKey<String>('all'))
                      : _SearchResults(
                          key: const ValueKey<String>('search'),
                          query: query,
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onRefreshPressed() {
    _searchController.clear();
    context.read<TokensBloc>().add(const InfiniteListRefreshRequested());
    context.read<SearchTokenBloc>().add(
      const SearchTokenRequested(query: '', refresh: true),
    );
  }

  void _onSearchChanged(String value) {
    context.read<SearchTokenBloc>().add(
      SearchTokenRequested(query: value.trim()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (BuildContext context, TextEditingValue value, _) => TextField(
        key: const Key('tokens_search_field'),
        controller: controller,
        style: cardValueStyle(context),
        decoration: InputDecoration(
          hintText: _kSearchHint,
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: value.text.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: TokenRowAction(
                    tooltip: _kClearSearch,
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
                ),
          suffixIconConstraints: const BoxConstraints(),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

/// The list while it is being read: a bar where each of the first rows
/// will be, at the rows' pitch, so the list arrives where the bars stood.
class _Loading extends StatelessWidget {
  const _Loading({super.key});

  /// The height of one bar (`Skeleton`'s default).
  static const double _bar = 12;

  @override
  Widget build(BuildContext context) {
    // A short card shows fewer bars instead of overflowing.
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, (kTokenRowHeight - _bar) / 2, 16, 0),
      child: SkeletonRows(rows: 4, gap: kTokenRowHeight + 1 - _bar),
    );
  }
}

/// Every token, a page at a time.
class _AllTokens extends StatelessWidget {
  const _AllTokens({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TokensBloc, InfiniteListState<Token>>(
      builder: (BuildContext context, InfiniteListState<Token> state) {
        return StateSwitcher(
          child: switch (state.status) {
            InfiniteListStatus.initial => const _Loading(
              key: ValueKey<String>('loading'),
            ),
            InfiniteListStatus.failure => CardNote.error(
              state.error!,
              key: const ValueKey<String>('error'),
            ),
            InfiniteListStatus.success => _TokenList(
              key: const ValueKey<String>('populated'),
              emptyText: context.l10n.noItemsFound,
              hasReachedMax: state.hasReachedMax,
              onMoreRequested: () => context.read<TokensBloc>().add(
                const InfiniteListMoreRequested(),
              ),
              storageKey: const PageStorageKey<String>('tokens_all'),
              tokens: state.data!,
            ),
          },
        );
      },
    );
  }
}

/// The tokens matching what was typed.
class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.query, super.key});

  final String query;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchTokenBloc, SearchTokenState>(
      builder: (BuildContext context, SearchTokenState state) {
        return StateSwitcher(
          // Until the bloc has caught up with the field, its state is the
          // answer to an older question.
          child: state.query != query
              ? const _Loading(key: ValueKey<String>('loading'))
              : switch (state) {
                  SearchTokenInitial() || SearchTokenLoading() =>
                    const _Loading(key: ValueKey<String>('loading')),
                  SearchTokenFailure(:final SyriusException exception) =>
                    CardNote.error(
                      exception,
                      key: const ValueKey<String>('error'),
                    ),
                  SearchTokenPopulated(:final List<Token> tokens) => _TokenList(
                    key: const ValueKey<String>('populated'),
                    emptyText: _kNoMatch,
                    hasReachedMax: true,
                    onMoreRequested: () {},
                    storageKey: const PageStorageKey<String>(
                      'tokens_search',
                    ),
                    tokens: tokens,
                  ),
                },
        );
      },
    );
  }
}

/// A lazy list of token rows that asks for the next page as its end nears.
///
/// The rows are sorted here and sorted again when a favorite changes, so a
/// star moves its row without the list being read from the network again.
class _TokenList extends StatefulWidget {
  const _TokenList({
    required this.emptyText,
    required this.hasReachedMax,
    required this.onMoreRequested,
    required this.storageKey,
    required this.tokens,
    super.key,
  });

  /// What the card says when there is no row to show.
  final String emptyText;
  final bool hasReachedMax;
  final VoidCallback onMoreRequested;
  final PageStorageKey<String> storageKey;
  final List<Token> tokens;

  @override
  State<_TokenList> createState() => _TokenListState();
}

class _TokenListState extends State<_TokenList> {
  /// A row and the line under it.
  static const double _itemExtent = kTokenRowHeight + 1;

  final ScrollController _scrollController = ScrollController();

  late List<Token> _sorted = _sortTokens(widget.tokens);
  bool _isRequestingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _requestMoreIfViewportIsNotFilled();
  }

  @override
  void didUpdateWidget(covariant _TokenList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.tokens, widget.tokens) ||
        oldWidget.hasReachedMax != widget.hasReachedMax) {
      _sorted = _sortTokens(widget.tokens);
      _isRequestingMore = false;
      _requestMoreIfViewportIsNotFilled();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Whether there is a row is known only here, once ZNN and QSR are taken
    // out, so the empty state fades in and out here too.
    return StateSwitcher(
      child: _sorted.isNotEmpty
          ? _buildRows()
          // A page holding only ZNN and QSR shows no row, and is not the end.
          : widget.hasReachedMax
          ? CardNote(widget.emptyText, key: const ValueKey<String>('empty'))
          : const _Loading(key: ValueKey<String>('loading')),
    );
  }

  Widget _buildRows() {
    final Map<String, int> indexOf = <String, int>{
      for (int i = 0; i < _sorted.length; i++)
        _sorted[i].tokenStandard.toString(): i,
    };

    return ListView.builder(
      key: widget.storageKey,
      controller: _scrollController,
      itemExtent: _itemExtent,
      itemCount: _sorted.length + (widget.hasReachedMax ? 0 : 1),
      // A row keeps its state when a favorite moves it.
      findChildIndexCallback: (Key key) =>
          key is ValueKey<String> ? indexOf[key.value] : null,
      itemBuilder: (BuildContext context, int index) {
        if (index == _sorted.length) {
          // The page being read: one bar where its first row will be.
          return const Padding(
            padding: kTokenRowPadding,
            child: Center(child: Skeleton()),
          );
        }
        final Token token = _sorted[index];
        return Column(
          key: ValueKey<String>(token.tokenStandard.toString()),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: TokenCard(
                favoritesCallback: _onFavoriteChanged,
                token: token,
              ),
            ),
            const Divider(),
          ],
        );
      },
    );
  }

  void _onFavoriteChanged() {
    if (mounted) {
      setState(() {
        _sorted = _sortTokens(widget.tokens);
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final ScrollPosition position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 2 * _itemExtent) {
      _requestMore();
    }
  }

  void _requestMore() {
    if (_isRequestingMore || widget.hasReachedMax) return;
    _isRequestingMore = true;
    widget.onMoreRequested();
  }

  /// A first page shorter than the card would otherwise never scroll, and
  /// so never ask for the second.
  void _requestMoreIfViewportIsNotFilled() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients ||
          _scrollController.position.maxScrollExtent == 0) {
        _requestMore();
      }
    });
  }

  // TODO(maznnwell): Remove this sorting. Reordering a partially loaded list
  //  moves items as pages load or favorites change, disrupting the user's
  //  position.
  List<Token> _sortTokens(List<Token> tokens) {
    final Set<TokenStandard> coins = <TokenStandard>{
      kZnnCoin.tokenStandard,
      kQsrCoin.tokenStandard,
    };
    final Set<dynamic> favorites = Hive.box<dynamic>(
      kFavoriteTokensBox,
    ).values.toSet();

    bool isOwned(Token token) =>
        kDefaultAddressList.contains(token.owner.toString());
    bool isFavorite(Token token) =>
        favorites.contains(token.tokenStandard.toString());

    final List<Token> zts = tokens
        .where((Token token) => !coins.contains(token.tokenStandard))
        .toList();
    final List<Token> owned = <Token>[
      ...zts.where(isOwned),
      ...zts.where((Token token) => !isOwned(token)),
    ];
    return <Token>[
      ...owned.where(isFavorite),
      ...owned.where((Token token) => !isFavorite(token)),
    ];
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
