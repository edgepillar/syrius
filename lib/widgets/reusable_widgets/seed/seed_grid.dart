import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/extensions.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/seed/seed_cell.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart' show Mnemonic;

class SeedGrid extends StatefulWidget {
  const SeedGrid(
    this.seedWords, {
    this.isContinueButtonDisabled = false,
    this.enableSeedInputFields = true,
    this.onTextFieldChangedCallback,
    super.key,
  });
  final List<String> seedWords;
  final bool isContinueButtonDisabled;
  final bool enableSeedInputFields;
  final VoidCallback? onTextFieldChangedCallback;

  @override
  State createState() {
    return SeedGridState();
  }
}

class SeedGridState extends State<SeedGrid> {
  final List<SeedGridElement> _seedGridElements = <SeedGridElement>[];

  int? _textCursor;
  int? _onHoverText;

  bool? _seedError;
  bool? continueButtonDisabled;

  late List<FocusNode> _focusNodes;

  Map<Type, Action<Intent>>? _actionMap;
  Map<LogicalKeySet, Intent>? _shortcutMap;

  @override
  void initState() {
    super.initState();
    _initSeedGridElements(widget.seedWords);
    _initFocusNodes(_seedGridElements.length);
    continueButtonDisabled = widget.isContinueButtonDisabled;
    _actionMap = <Type, Action<Intent>>{
      ActivateIntent: CallbackAction(
        onInvoke: (Intent intent) => _changeFocusToNextNode(),
      ),
    };
    _shortcutMap = <LogicalKeySet, Intent>{
      LogicalKeySet(LogicalKeyboardKey.tab): const ActivateIntent(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return _getSeedInputWidgetsGrid();
  }

  Widget _getSeedInputWidgetsGrid() {
    final int divider = widget.seedWords.length ~/ kSeedGridNumOfRows;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // The old cells were a fixed 200 px: six of them did not fit a
        // window at its narrowest. A cell now takes its share of the width.
        final double cellWidth = seedCellWidth(
          constraints,
          divider,
          kSeedWordCellWidth,
        );

        List<Widget> columnChildren = <Widget>[];

        for (int i = 0; i <= widget.seedWords.length / divider - 1; i++) {
          columnChildren.add(
            _getSeedRow(
              List.generate(
                divider,
                (int index) => index + (divider * i),
              ),
              cellWidth,
            ),
          );
        }

        columnChildren = columnChildren.zip<Widget>(
          List.generate(
            kSeedGridNumOfRows - 1,
            (int index) => const SizedBox(
              height: kSeedCellGap,
            ),
          ),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: constraints.hasBoundedWidth
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.center,
          children: columnChildren,
        );
      },
    );
  }

  Widget _getSeedRow(List<int> rangeIndexes, double cellWidth) {
    final List<Widget> children = rangeIndexes.fold<List<Widget>>(
      <Widget>[],
      (List<Widget> previousValue, int index) {
        previousValue.add(_seedWordWidget(index, cellWidth));
        if (rangeIndexes.last != index) {
          previousValue.add(
            const SizedBox(
              width: kSeedCellGap,
            ),
          );
        }
        return previousValue;
      },
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }

  Widget _seedWordWidget(int seedWordIndex, double cellWidth) {
    final String seedWord = _seedGridElements[seedWordIndex].word;

    final TextEditingController controller = TextEditingController();
    controller.text = seedWord;

    if (_textCursor == seedWordIndex) {
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    }

    // "isShown" reads backwards: true means the word is hidden behind dots
    // until the pointer is on it; false means it was pinned open.
    final bool pinned = !_seedGridElements[seedWordIndex].isShown;
    final bool revealed = pinned || _onHoverText == seedWordIndex;
    final Color foreground = Theme.of(context).textTheme.bodyLarge!.color!;

    void onHover(bool x) {
      if (x) {
        setState(() {
          _onHoverText = seedWordIndex;
        });
      } else {
        setState(() {
          _onHoverText = null;
        });
      }
    }

    return ListenableBuilder(
      listenable: _focusNodes[seedWordIndex],
      builder: (BuildContext context, Widget? field) => SeedCell(
        number: seedWordIndex + 1,
        width: cellWidth,
        lineColor: _getLineColor(
          seedWord,
          revealed: revealed,
          focused: _focusNodes[seedWordIndex].hasFocus,
        ),
        numberColor: pinned
            ? _getTone(seedWord, rest: foreground)
            : _onHoverText == seedWordIndex
            ? foreground
            : AppColors.faint,
        onNumberTap: () {
          _seedGridElements[seedWordIndex].isShown =
              !_seedGridElements[seedWordIndex].isShown;
        },
        onNumberHover: onHover,
        field: field!,
      ),
      child: FocusableActionDetector(
        actions: _actionMap,
        shortcuts: _shortcutMap,
        onShowHoverHighlight: onHover,
        child: Material(
          color: Colors.transparent,
          child: TextField(
            focusNode: _focusNodes[seedWordIndex],
            onChanged: (String text) {
              controller.text = text;
              _seedGridElements[seedWordIndex].word = text;
              _seedGridElements[seedWordIndex].isValid = Mnemonic.isValidWord(
                text,
              );
              setState(() {
                _textCursor = seedWordIndex;
              });
              _checkIfSeedIsValid();
              widget.onTextFieldChangedCallback?.call();
            },
            inputFormatters: <TextInputFormatter>[
              LengthLimitingTextInputFormatter(8),
            ],
            enabled: widget.enableSeedInputFields,
            controller: controller,
            obscureText: _onHoverText == seedWordIndex
                ? false
                : _seedGridElements[seedWordIndex].isShown,
            cursorColor: AppColors.znnColor,
            textAlignVertical: TextAlignVertical.center,
            style: seedWordStyle(
              revealed ? foreground : _getTone(seedWord, rest: AppColors.faint),
            ),
            decoration: kSeedFieldDecoration,
          ),
        ),
      ),
    );
  }

  /// A word's colour when it is not shown in full: green when it is a seed
  /// word, red when it is not (or is missing after an error), [rest]
  /// otherwise.
  Color _getTone(String seedValue, {required Color rest}) {
    final Color indicator = getIndicatorColor(seedValue);
    return indicator == AppColors.seedUnderlineBorderColor ? rest : indicator;
  }

  /// A wrong word is always outlined in red; otherwise the line follows the
  /// focus, then a revealed right word, then rests.
  Color _getLineColor(
    String seedValue, {
    required bool revealed,
    required bool focused,
  }) {
    final Color indicator = getIndicatorColor(seedValue);
    if (indicator == AppColors.errorColor) return AppColors.errorColor;
    if (focused) return AppColors.znnColor;
    if (revealed && indicator == AppColors.znnColor) {
      return AppColors.znnColor.withValues(alpha: 0.6);
    }
    return seedRestLine(context);
  }

  Color getIndicatorColor(String seedValue) {
    if (Mnemonic.isValidWord(seedValue)) {
      return AppColors.znnColor;
    } else if (Mnemonic.isValidWord(seedValue) == false && seedValue != '' ||
        (seedValue == '' && _seedError == true)) {
      return AppColors.errorColor;
    } else {
      return AppColors.seedUnderlineBorderColor;
    }
  }

  void _checkIfSeedIsValid() {
    _seedError = false;
    continueButtonDisabled = false;
    if (_foundInvalidSeedGridElement()) {
      _seedError = true;
      continueButtonDisabled = true;
    }
    setState(() {});
  }

  bool _foundInvalidSeedGridElement() {
    return _seedGridElements.any((SeedGridElement element) => !element.isValid);
  }

  void changedSeed(List<String> newSeed) {
    setState(() {
      _seedGridElements.clear();
      _initFocusNodes(newSeed.length);
      _initSeedGridElements(newSeed);
    });
  }

  List<String> get getSeedWords =>
      _seedGridElements.map((SeedGridElement e) => e.word).toList();

  String get getSeed => getSeedWords.join(' ');

  void _initFocusNodes(int length) => _focusNodes = List.generate(
    length,
    (int index) => FocusNode(),
  );

  void _changeFocusToNextNode() {
    final int indexOfFocusedNode = _focusNodes.indexOf(
      _focusNodes.firstWhere(
        (FocusNode node) => node.hasFocus,
      ),
    );
    if (indexOfFocusedNode + 1 < _focusNodes.length) {
      _focusNodes[indexOfFocusedNode + 1].requestFocus();
    } else {
      _focusNodes[0].requestFocus();
    }
  }

  void _initSeedGridElements(List<String> seed) {
    for (final String word in seed) {
      _seedGridElements.add(
        SeedGridElement(
          word: word,
          isValid: Mnemonic.isValidWord(word),
          isShown: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final FocusNode focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }
}

class SeedGridElement {
  SeedGridElement({
    required this.word,
    required this.isValid,
    required this.isShown,
  });
  String word;
  bool isValid;
  bool isShown;
}
