import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/onboarding_scaffold.dart';
import 'package:zenon_syrius_wallet_flutter/screens/screens.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/seed/seed_cell.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

class NewWalletConfirmSeedScreen extends StatefulWidget {
  const NewWalletConfirmSeedScreen(
    this.seedWords, {
    super.key,
  });
  final List<String> seedWords;

  @override
  State<NewWalletConfirmSeedScreen> createState() =>
      _NewWalletConfirmSeedScreenState();
}

class _NewWalletConfirmSeedScreenState
    extends State<NewWalletConfirmSeedScreen> {
  bool _seedError = false;
  int? _hoveredSeedGridIndex;
  int? _textCursor;

  late Widget _actionButton;
  String? _draggedValue;

  final List<SeedGridElement> _seedGridElements = <SeedGridElement>[];
  final List<int> _randomIndexes = <int>[];
  List<int> _foundMissingRandomElementsIndexes = <int>[];

  @override
  void initState() {
    super.initState();
    _actionButton = _getVerifyButton();
    for (final String word in widget.seedWords) {
      _seedGridElements.add(
        SeedGridElement(
          word: word,
          isValid: true,
          isShown: true,
        ),
      );
    }
    _generateRandomIndexes();
    for (final int index in _randomIndexes) {
      _seedGridElements[index].word = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 2,
      title: 'Confirm your seed',
      subtitle: 'Drag the words into the empty boxes',
      help: 'You can drop a word on an empty box or on a wrong one',
      onBack: () {
        Navigator.pop(context);
      },
      maxWidth: 880,
      primary: _actionButton,
      child: Column(
        children: <Widget>[
          _getSeedInputWidgetsGrid(),
          const SizedBox(height: 24),
          _getMissingSeedGridElements(widget.seedWords),
        ],
      ),
    );
  }

  void _generateRandomIndexes() {
    while (_randomIndexes.length < kNumOfSeedWordsToBeFound) {
      _generateRandomIndex();
    }
  }

  void _generateRandomIndex() {
    final int randomNumber = Random().nextInt(_seedGridElements.length);
    if (!_randomIndexes.contains(randomNumber)) {
      _randomIndexes.add(randomNumber);
    }
  }

  /// The line of a box. A box to fill rests on the hairline until the words
  /// are checked, then shows green or red; a given word is not outlined.
  Color _getLineColor(SeedGridElement seedGridElement) {
    final int index = _seedGridElements.indexOf(seedGridElement);
    if (_randomIndexes.contains(index)) {
      if (seedGridElement.isValid && _seedError) {
        return AppColors.znnColor;
      } else if (!seedGridElement.isValid && _seedError) {
        return AppColors.errorColor;
      }
      return _hoveredSeedGridIndex == index
          ? AppColors.faint
          : dimColorOf(context).withValues(alpha: 0.5);
    }
    return seedRestLine(context);
  }

  Widget _seedFieldWidget(SeedGridElement seedGridElement, double width) {
    final int seedGridElementIndex = _seedGridElements.indexOf(seedGridElement);

    final TextEditingController controller = TextEditingController();
    controller.text = seedGridElement.word;
    if (_textCursor == seedGridElementIndex) {
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    }

    final bool toFind = _randomIndexes.contains(seedGridElementIndex);
    final bool hovered = _hoveredSeedGridIndex == seedGridElementIndex;
    final Color foreground = Theme.of(context).textTheme.bodyLarge!.color!;

    void onHover(bool x) {
      if (x) {
        setState(() {
          _hoveredSeedGridIndex = seedGridElementIndex;
        });
      } else {
        setState(() {
          _hoveredSeedGridIndex = null;
        });
      }
    }

    return SeedCell(
      number: seedGridElementIndex + 1,
      width: width,
      lineColor: _getLineColor(seedGridElement),
      numberColor: hovered || toFind ? foreground : AppColors.faint,
      onNumberTap: () {
        setState(() {
          seedGridElement.isShown = !seedGridElement.isShown;
        });
      },
      onNumberHover: onHover,
      field: FocusableActionDetector(
        onShowHoverHighlight: onHover,
        child: DragTarget<String>(
          builder:
              (
                BuildContext context,
                List<String?> accepted,
                List<dynamic> rejected,
              ) {
                return ColoredBox(
                  // A word held over a box that takes it lights the box.
                  color: accepted.isNotEmpty
                      ? AppColors.znnColor.withValues(alpha: 0.12)
                      : Colors.transparent,
                  child: TextField(
                    enabled: false,
                    controller: controller,
                    obscureText: toFind
                        ? false
                        : !seedGridElement.isShown || !hovered,
                    textAlignVertical: TextAlignVertical.center,
                    style: seedWordStyle(
                      hovered || toFind ? foreground : AppColors.znnColor,
                    ),
                    decoration: kSeedFieldDecoration,
                  ),
                );
              },
          onWillAcceptWithDetails: (DragTargetDetails<String> data) {
            return _randomIndexes.contains(seedGridElementIndex) ||
                !seedGridElement.isValid;
          },
          onAcceptWithDetails: (DragTargetDetails<String> data) {
            final SeedGridElement element =
                _seedGridElements[seedGridElementIndex];
            int i = -1;
            if (element.word != '') {
              while ((i = widget.seedWords.indexOf(element.word, i + 1)) !=
                  -1) {
                if (_foundMissingRandomElementsIndexes.contains(i)) {
                  _foundMissingRandomElementsIndexes.remove(i);
                  break;
                }
              }
            }
            i = -1;
            while ((i = widget.seedWords.indexOf(data.data, i + 1)) != -1) {
              if (!_foundMissingRandomElementsIndexes.contains(i) &&
                  _randomIndexes.contains(i)) {
                _foundMissingRandomElementsIndexes.add(i);
                break;
              }
            }
            element.word = data.data;
            setState(() {
              _textCursor = seedGridElementIndex;
            });
          },
        ),
      ),
    );
  }

  Widget _getMissingSeedGridElements(List<String> seedWords) {
    final List<Widget> list = <Widget>[];
    for (final int index in _randomIndexes) {
      if (!_foundMissingRandomElementsIndexes.contains(index)) {
        list.add(
          Draggable<String>(
            feedback: Material(
              type: MaterialType.transparency,
              child: _buildWordChip(seedWords[index], lifted: true),
            ),
            data: seedWords[index],
            onDragStarted: () {
              setState(() {
                _draggedValue = seedWords[index];
              });
            },
            onDragEnd: (_) {
              setState(() {
                _draggedValue = null;
              });
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: AnimatedOpacity(
                duration: Durations.short3,
                opacity: _draggedValue == seedWords[index] ? 0.35 : 1,
                child: _buildWordChip(seedWords[index]),
              ),
            ),
          ),
        );
      }
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: list,
    );
  }

  /// A word still to place: a mono pill, raised a little while it is held.
  Widget _buildWordChip(String word, {bool lifted = false}) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: lifted ? AppColors.znnColor : lineColorOf(context),
        ),
        boxShadow: lifted
            ? const <BoxShadow>[
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Text(
        word,
        style: seedWordStyle(theme.textTheme.bodyLarge!.color),
      ),
    );
  }

  void _checkSeed() {
    _seedError = false;
    for (final SeedGridElement element in _seedGridElements) {
      final int i = _seedGridElements.indexOf(element);
      element.isValid = element.word == widget.seedWords[i];
      if (!element.isValid) {
        _seedError = true;
      }
    }
    if (_seedError) {
      for (final SeedGridElement element in _seedGridElements) {
        final int i = _seedGridElements.indexOf(element);
        if (_randomIndexes.contains(i)) {
          element.isValid = false;
          element.word = '';
        }
      }
    }

    setState(() {
      _seedError = true;
      _foundMissingRandomElementsIndexes = _randomIndexes
          .where((int index) => _seedGridElements[index].isValid)
          .toList();
      _actionButton =
          _foundMissingRandomElementsIndexes.length == kNumOfSeedWordsToBeFound
          ? _getContinueButton()
          : _getVerifyButton();
    });
  }

  Widget _getContinueButton() {
    return OnboardingButton(
      text: 'Continue',
      onPressed: () {
        NavigationUtils.push(
          context,
          NewWalletPasswordScreen(
            _seedGridElements.map((SeedGridElement e) => e.word).toList(),
          ),
        );
      },
    );
  }

  Widget _getVerifyButton() {
    return OnboardingButton(
      text: 'Verify',
      onPressed: _checkSeed,
    );
  }

  Widget _getSeedInputWidgetsGrid() {
    final int divider = widget.seedWords.length ~/ kSeedGridNumOfRows;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = seedCellWidth(
          constraints,
          divider,
          kSeedWordCellWidth,
        );

        List<Widget> columnChildren = <Widget>[];

        for (int i = 0; i <= _seedGridElements.length / divider - 1; i++) {
          columnChildren.add(
            _getSeedRow(
              List.generate(
                divider,
                (int index) => index + (divider * i),
              ),
              width,
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

  Widget _getSeedRow(List<int> rangeIndexes, double width) {
    final List<Widget> children = rangeIndexes.fold<List<Widget>>(
      <Widget>[],
      (List<Widget> previousValue, int index) {
        previousValue.add(
          _seedFieldWidget(
            _seedGridElements[index],
            width,
          ),
        );
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
}
