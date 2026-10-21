import 'dart:math' show pow;
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:znn_ledger_dart/znn_ledger_dart.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

extension StringExtensions on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${toLowerCase().substring(1)}';
  }

  num toNum() => num.parse(this);

  BigInt extractDecimals(int decimals) {
    if (!contains('.')) {
      if (decimals == 0 && isEmpty) {
        return BigInt.zero;
      }
      return BigInt.parse(this + ''.padRight(decimals, '0'));
    }
    final List<String> parts = split('.');

    return BigInt.parse(parts[0] +
        (parts[1].length > decimals
            ? parts[1].substring(0, decimals)
            : parts[1].padRight(decimals, '0')),);
  }

  String abs() => this;
}

extension FixedNumDecimals on double {
  String toStringFixedNumDecimals(int numDecimals) {
    return '${(this * pow(10, numDecimals)).truncate() / pow(10, numDecimals)}';
  }
}

extension BigIntExtensions on BigInt {
  String addDecimals(int decimals) {

    return AmountUtils.addDecimals(this, decimals);
  }
}

// This extension takes other list with fewer elements and creates a single one
// by interleaving them, starting with the first element of the first list,
// then the first element of the second list. If second list runs out of elements
// then we continue with the elements from the first list
extension ZipTwoLists on List {
  List<T> zip<T>(List<T> smallerList) {
    return fold(
      <T>[],
      (List<T> previousValue, element) {
        final int elementIndex = indexOf(element);
        previousValue.add(element);
        if (elementIndex < smallerList.length) {
          previousValue.add(
            smallerList[elementIndex],
          );
        }
        return previousValue;
      },
    );
  }
}

extension ShortString on String {
  String get short {
    final String longString = this;
    return '${longString.substring(0, 6)}...'
        '${longString.substring(longString.length - 6)}';
  }
}

extension LedgerErrorExtensions on LedgerError {
  String toFriendlyString() {
    return when(
        connectionError: (String origMessage) => origMessage,
        responseError: _mapStatusWord,);
  }

  String _mapStatusWord(StatusWord statusWord) {
    final AppLocalizations l10n = currentL10n;
    switch (statusWord) {
      case StatusWord.deny:
        return l10n.ledgerStatusDeny;
      case StatusWord.wrongP1P2:
        return l10n.ledgerStatusWrongP1P2;
      case StatusWord.wrongDataLength:
        return l10n.ledgerStatusWrongDataLength;
      case StatusWord.inactiveDevice:
        return l10n.ledgerStatusInactiveDevice;
      case StatusWord.notAllowed:
        return l10n.ledgerStatusNotAllowed;
      case StatusWord.insNotSupported:
        return l10n.ledgerStatusInsNotSupported;
      case StatusWord.claNotSupported:
        return l10n.ledgerStatusClaNotSupported;
      case StatusWord.appIsNotOpen:
        return l10n.ledgerStatusAppIsNotOpen;
      case StatusWord.wrongResponseLength:
        return l10n.ledgerStatusWrongResponseLength;
      case StatusWord.displayBip32PathFail:
        return l10n.ledgerStatusDisplayBip32PathFail;
      case StatusWord.displayAddressFail:
        return l10n.ledgerStatusDisplayAddressFail;
      case StatusWord.displayAmountFail:
        return l10n.ledgerStatusDisplayAmountFail;
      case StatusWord.wrongTxLength:
        return l10n.ledgerStatusWrongTxLength;
      case StatusWord.txParsingFail:
        return l10n.ledgerStatusTxParsingFail;
      case StatusWord.txHashFail:
        return l10n.ledgerStatusTxHashFail;
      case StatusWord.badState:
        return l10n.ledgerStatusBadState;
      case StatusWord.signatureFail:
        return l10n.ledgerStatusSignatureFail;
      case StatusWord.success:
        return l10n.ledgerStatusSuccess;
      case StatusWord.unknownError:
        return l10n.ledgerStatusUnknownError;
    }
  }
}