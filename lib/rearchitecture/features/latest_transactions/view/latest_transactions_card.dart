import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/ltr.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/copy_to_clipboard_button.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/formatted_amount_with_tooltip.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// A widget that displayed the latest transactions for an address
class LatestTransactionsCard extends StatelessWidget {
  /// Creates a new instance.
  ///
  /// There is also a check to make sure that the [type] can be found among
  /// the supported list of types
  LatestTransactionsCard({required this.type, super.key})
    : assert(
        <CardType>[
          CardType.latestTransactions,
          CardType.latestTransactionsDashboard,
        ].contains(type),
        'make sure that the type refers only to latest transactions types',
      );

  /// The card type, either [CardType.latestTransactions] or
  /// [CardType.latestTransactionsDashboard]
  final CardType type;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: _title,
      actions: <Widget>[
        RefreshButton(
          onPressed: () {
            context.read<LatestTransactionsBloc>().add(
              InfiniteListRefreshRequested(
                address: Address.parse(kSelectedAddress!),
              ),
            );
          },
        ),
      ],
      child:
          BlocBuilder<LatestTransactionsBloc, InfiniteListState<AccountBlock>>(
            builder:
                (
                  _,
                  InfiniteListState<AccountBlock> state,
                ) {
                  final InfiniteListStatus status = state.status;

                  return switch (status) {
                    InfiniteListStatus.initial =>
                      const _LatestTransactionsInitial(),
                    InfiniteListStatus.failure => _LatestTransactionsFailure(
                      exception: state.error!,
                    ),
                    InfiniteListStatus.success => _LatestTransactionsPopulated(
                      hasReachedMax: state.hasReachedMax,
                      transactions: state.data!,
                      type: type,
                    ),
                  };
                },
          ),
    );
  }

  // Mockup B's word for an address's history, on the home page and on
  // Transfer alike.
  String get _title => switch (type) {
    CardType.latestTransactions => 'Activity',
    CardType.latestTransactionsDashboard => 'Activity',
  };
}

class _LatestTransactionsInitial extends StatelessWidget {
  const _LatestTransactionsInitial();

  @override
  Widget build(BuildContext context) {
    return const CardLoading();
  }
}

class _LatestTransactionsFailure extends StatelessWidget {
  const _LatestTransactionsFailure({required this.exception});

  final SyriusException exception;

  @override
  Widget build(BuildContext context) {
    return CardNote.error(exception);
  }
}

class _LatestTransactionsPopulated extends StatefulWidget {
  const _LatestTransactionsPopulated({
    required this.hasReachedMax,
    required this.transactions,
    required this.type,
  });

  final bool hasReachedMax;
  final List<AccountBlock> transactions;
  final CardType type;

  @override
  State<_LatestTransactionsPopulated> createState() =>
      _LatestTransactionsPopulatedState();
}

class _LatestTransactionsPopulatedState
    extends State<_LatestTransactionsPopulated> {
  late List<AccountBlock> _transactions;

  bool _sortAscending = true;

  _Flex get _flex => widget.type == CardType.latestTransactionsDashboard
      ? _Flex.dashboard
      : _Flex.transfer;

  @override
  Widget build(BuildContext context) {
    return InfiniteScrollTable<AccountBlock>(
      items: widget.transactions,
      hasReachedMax: widget.hasReachedMax,
      columns: widget.type == CardType.latestTransactionsDashboard
          ? _getHeaderColumnsForDashboardWidget()
          : _getHeaderColumnsForTransferWidget(),
      heads: _flex.heads,
      generateRowCells: _rowCellsGenerator,
      onScrollReachedBottom: () {
        context.read<LatestTransactionsBloc>().add(
          InfiniteListMoreRequested(
            address: Address.parse(kSelectedAddress!),
          ),
        );
      },
    );
  }

  List<Widget> _rowCellsGenerator(
    AccountBlock transaction,
  ) => widget.type == CardType.latestTransactionsDashboard
      ? _getCellsForDashboardWidget(transaction)
      : _getCellsForTransferWidget(transaction);

  List<Widget> _getCellsForTransferWidget(
    AccountBlock transactionBlock,
  ) {
    final AccountBlock infoBlock =
        BlockUtils.isReceiveBlock(transactionBlock.blockType)
        ? transactionBlock.pairedAccountBlock!
        : transactionBlock;
    final _Flex flex = _flex;
    return <Widget>[
      _IdCell.address(infoBlock.address, flex: flex.id),
      _IdCell.address(infoBlock.toAddress, flex: flex.id),
      _IdCell.hash(infoBlock.hash, flex: flex.id),
      _AmountCell(block: infoBlock, flex: flex.amount),
      _Span(flex: flex.date, cell: DateCell(block: infoBlock)),
      _Span(flex: flex.type, cell: TypeCell(block: transactionBlock)),
      _Span(flex: flex.asset, cell: AssetCell(block: infoBlock)),
    ];
  }

  List<InfiniteScrollTableColumnType> _getHeaderColumnsForTransferWidget() {
    return <InfiniteScrollTableColumnType>[
      InfiniteScrollTableColumnType.sender,
      InfiniteScrollTableColumnType.receiver,
      InfiniteScrollTableColumnType.hash,
      InfiniteScrollTableColumnType.amount,
      InfiniteScrollTableColumnType.date,
      InfiniteScrollTableColumnType.type,
      InfiniteScrollTableColumnType.asset,
    ];
  }

  List<InfiniteScrollTableColumnType> _getHeaderColumnsForDashboardWidget() {
    return <InfiniteScrollTableColumnType>[
      InfiniteScrollTableColumnType.sender,
      InfiniteScrollTableColumnType.amount,
      InfiniteScrollTableColumnType.date,
      InfiniteScrollTableColumnType.type,
      InfiniteScrollTableColumnType.asset,
    ];
  }

  List<Widget> _getCellsForDashboardWidget(
    AccountBlock transactionBlock,
  ) {
    final AccountBlock infoBlock =
        BlockUtils.isReceiveBlock(transactionBlock.blockType)
        ? transactionBlock.pairedAccountBlock!
        : transactionBlock;

    final _Flex flex = _flex;
    return <Widget>[
      _IdCell.address(infoBlock.address, flex: flex.id),
      _AmountCell(block: infoBlock, flex: flex.amount),
      _Span(flex: flex.date, cell: DateCell(block: infoBlock)),
      _Span(flex: flex.type, cell: TypeCell(block: transactionBlock)),
      _Span(flex: flex.asset, cell: AssetCell(block: infoBlock)),
    ];
  }

  // TODO(maznnwell): to be used when sorting is enabled
  // ignore: unused_element
  void _onSortArrowsPressed(InfiniteScrollTableColumnType columnType) {
    switch (columnType) {
      case InfiniteScrollTableColumnType.sender:
        _sortAscending
            ? _transactions.sort(
                (AccountBlock a, AccountBlock b) =>
                    a.address.toString().compareTo(
                      b.address.toString(),
                    ),
              )
            : _transactions.sort(
                (AccountBlock a, AccountBlock b) =>
                    b.address.toString().compareTo(
                      a.address.toString(),
                    ),
              );
      case InfiniteScrollTableColumnType.receiver:
        _sortAscending
            ? _transactions.sort(
                (AccountBlock a, AccountBlock b) =>
                    a.toAddress.toString().compareTo(
                      b.toAddress.toString(),
                    ),
              )
            : _transactions.sort(
                (AccountBlock a, AccountBlock b) =>
                    b.toAddress.toString().compareTo(
                      a.toAddress.toString(),
                    ),
              );
      case InfiniteScrollTableColumnType.hash:
        _sortAscending
            ? _transactions.sort(
                (AccountBlock a, AccountBlock b) => a.hash.toString().compareTo(
                  b.hash.toString(),
                ),
              )
            : _transactions.sort(
                (AccountBlock a, AccountBlock b) => b.hash.toString().compareTo(
                  a.hash.toString(),
                ),
              );
      case InfiniteScrollTableColumnType.amount:
        _sortAscending
            ? _transactions.sort(
                (AccountBlock a, AccountBlock b) =>
                    a.amount.compareTo(b.amount),
              )
            : _transactions.sort(
                (AccountBlock a, AccountBlock b) =>
                    b.amount.compareTo(a.amount),
              );
      case InfiniteScrollTableColumnType.date:
        _sortAscending
            ? _transactions.sort(
                (AccountBlock a, AccountBlock b) =>
                    a.confirmationDetail!.momentumTimestamp.compareTo(
                      b.confirmationDetail!.momentumTimestamp,
                    ),
              )
            : _transactions.sort(
                (AccountBlock a, AccountBlock b) =>
                    b.confirmationDetail!.momentumTimestamp.compareTo(
                      a.confirmationDetail!.momentumTimestamp,
                    ),
              );
      case InfiniteScrollTableColumnType.type:
        _sortAscending
            ? _transactions.sort(
                (AccountBlock a, AccountBlock b) =>
                    a.blockType.compareTo(b.blockType),
              )
            : _transactions.sort(
                (AccountBlock a, AccountBlock b) =>
                    b.blockType.compareTo(a.blockType),
              );
      case InfiniteScrollTableColumnType.asset:
        _sortAscending
            ? _transactions.sort(
                (AccountBlock a, AccountBlock b) =>
                    a.token!.symbol.compareTo(b.token!.symbol),
              )
            : _transactions.sort(
                (AccountBlock a, AccountBlock b) =>
                    b.token!.symbol.compareTo(a.token!.symbol),
              );
      default:
        _sortAscending
            ? _transactions.sort(
                (AccountBlock a, AccountBlock b) =>
                    a.tokenStandard.toString().compareTo(
                      b.tokenStandard.toString(),
                    ),
              )
            : _transactions.sort(
                (AccountBlock a, AccountBlock b) =>
                    b.tokenStandard.toString().compareTo(
                      a.tokenStandard.toString(),
                    ),
              );
    }

    setState(() {
      _sortAscending = !_sortAscending;
    });
  }
}

/// The space each column of the table takes, the head and the cells alike.
///
/// The card is three fifths of the page, 538 px of table in the narrowest
/// window (1200 px). With the column types' own flex, Transfer's seven columns
/// gave a date 54 px and cut it; here a date, an amount, the type's arrow and
/// a symbol get what they need to be whole, and the addresses and the hash,
/// which are shortened in the middle anyway, share the rest.
enum _Flex {
  /// Sender, receiver and hash, then the four narrow columns.
  transfer(id: 20, amount: 15, date: 18, type: 8, asset: 11),

  /// One address, so every column has room to spare.
  dashboard(id: 22, amount: 12, date: 12, type: 7, asset: 9);

  const _Flex({
    required this.id,
    required this.amount,
    required this.date,
    required this.type,
    required this.asset,
  });

  /// An address or a hash.
  final int id;
  final int amount;
  final int date;
  final int type;
  final int asset;

  Map<InfiniteScrollTableColumnType, InfiniteScrollTableHead> get heads =>
      <InfiniteScrollTableColumnType, InfiniteScrollTableHead>{
        .sender: InfiniteScrollTableHead(flex: id),
        .receiver: InfiniteScrollTableHead(flex: id),
        .hash: InfiniteScrollTableHead(flex: id),
        .amount: InfiniteScrollTableHead(flex: amount),
        .date: InfiniteScrollTableHead(flex: date),
        .type: InfiniteScrollTableHead(flex: type),
        .asset: InfiniteScrollTableHead(flex: asset),
      };
}

/// Gives a shared cell, which sets its own flex, the flex this table wants:
/// alone in a row, the cell fills it whatever its own flex is.
class _Span extends StatelessWidget {
  const _Span({required this.flex, required this.cell});

  final int flex;
  final Widget cell;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Row(children: <Widget>[cell]),
    );
  }
}

/// An address or a hash: as much of it as the column holds, cut in the
/// middle, with the whole of it on hover and behind the copy button.
///
/// The shared cells show a fixed short form and let the column cut its end
/// off, which left "z1qqqqq…" for every address in a narrow window. An
/// address the user has labelled shows the label instead.
class _IdCell extends StatelessWidget {
  const _IdCell({
    required this.value,
    required this.flex,
    this.label,
    this.style,
  });

  factory _IdCell.address(Address address, {required int flex}) {
    final String value = address.toString();
    final String? label = kAddressLabelMap[value];
    final TextStyle? own = address.isEmbedded()
        ? const TextStyle(
            color: AppColors.znnColor,
            fontWeight: FontWeight.bold,
          )
        : null;

    return _IdCell(
      value: value,
      flex: flex,
      label: label,
      style: label == null ? monoStyle(own) : own,
    );
  }

  factory _IdCell.hash(Hash hash, {required int flex}) => _IdCell(
    value: hash.toString(),
    flex: flex,
    style: monoStyle(null),
  );

  final String value;
  final int flex;
  final String? label;
  final TextStyle? style;

  /// The copy button at 24 px, not the 32 px of an icon button: three of
  /// them in a row are otherwise a fifth of the narrowest table.
  static final IconButtonThemeData _copyButton = IconButtonThemeData(
    style: IconButton.styleFrom(
      padding: const EdgeInsets.all(4),
      minimumSize: const Size.square(24),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final String? label = this.label;

    return Expanded(
      flex: flex,
      child: Row(
        children: <Widget>[
          Flexible(
            child: Tooltip(
              message: value,
              child: label == null
                  ? _MiddleCut(value: value, style: style)
                  : Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
            ),
          ),
          IconButtonTheme(
            data: _copyButton,
            child: CopyToClipboardButton(value, iconSize: 15),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

/// [value] on one line: whole when it fits, otherwise its two ends around an
/// ellipsis, with as many characters as the width holds.
class _MiddleCut extends StatelessWidget {
  const _MiddleCut({required this.value, this.style});

  final String value;
  final TextStyle? style;

  /// Fewer characters than this say nothing, so no less is ever shown; the
  /// columns are sized so that it does not come to that.
  static const int _fewest = 4;

  @override
  Widget build(BuildContext context) {
    final TextStyle resolved = DefaultTextStyle.of(context).style.merge(style);
    final TextScaler scaler = MediaQuery.textScalerOf(context);

    // Left to right in every language, like the measuring below: under a
    // right-to-left interface the two ends of a hash that is all digits
    // would otherwise swap around the ellipsis.
    final TextAlign align = ltrTextAlign(context);

    return LayoutBuilder(
      builder: (_, BoxConstraints constraints) => Text(
        _fit(constraints.maxWidth, resolved, scaler),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        textDirection: TextDirection.ltr,
        textAlign: align,
        style: style,
      ),
    );
  }

  String _fit(double width, TextStyle style, TextScaler scaler) {
    if (value.length <= _fewest + 1) return value;

    final TextPainter painter = TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    );
    double measure(String text) {
      painter
        ..text = TextSpan(text: text, style: style)
        ..layout();
      return painter.width;
    }

    try {
      final double whole = measure(value);
      if (whole <= width) return value;

      // The font is monospaced, so the whole says how many characters fit.
      // The ellipsis may come from another font and be wider, hence the
      // measuring of each candidate.
      int kept = ((width / (whole / value.length)).floor() - 1).clamp(
        _fewest,
        value.length - 1,
      );
      while (kept > _fewest && measure(_cut(kept)) > width) {
        kept--;
      }
      return _cut(kept);
    } finally {
      painter.dispose();
    }
  }

  /// The first and last characters of [value], [kept] of them in all, the
  /// odd one at the start.
  String _cut(int kept) {
    final int head = (kept + 1) ~/ 2;
    final int tail = kept - head;
    return '${value.substring(0, head)}…'
        '${value.substring(value.length - tail)}';
  }
}

/// The amount, always whole: on one line, and scaled down in the rare case
/// (a dust amount with eight decimals) that it is wider than its column.
class _AmountCell extends StatelessWidget {
  const _AmountCell({required this.block, required this.flex});

  final AccountBlock block;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      // The amount runs left to right in every language (the tooltip widget
      // pins it); the cell puts it at the app's start, under its head.
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: FormattedAmountWithTooltip(
              amount: block.amount.addDecimals(block.token?.decimals ?? 0),
              tokenSymbol: block.token?.symbol ?? '',
              builder: (String formattedAmount, String tokenSymbol) => Text(
                formattedAmount,
                maxLines: 1,
                style: monoStyle(null),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
