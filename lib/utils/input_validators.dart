import 'package:convert/convert.dart';
import 'package:logging/logging.dart';
import 'package:validators/validators.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class InputValidators {
  static String kEVMAddressRegex = r'^(0x)([a-fA-F0-9]){40}$';

  static String? evmAddress(String? address) {
    if (address != null && RegExp(kEVMAddressRegex).hasMatch(address)) {
      return null;
    }
    return currentL10n.validatorInvalidAddress;
  }

  static String? node(String? node) {
    if (node != null &&
        RegExp(r'^(wss?://)([0-9]{1,3}(?:.[0-9]{1,3}){3}|[^/]+):([0-9]{1,5})$')
            .hasMatch(node)) {
      return null;
    }
    return currentL10n.validatorInvalidNode;
  }

  static String? recipientAddress(String recipientAddress) {
    if (!kDefaultAddressList.contains(recipientAddress)) {
      return currentL10n.validatorAddressNotInWallet;
    }
    return null;
  }

  static String? notEmpty(String fieldName, String? value) {
    return (value ?? '').isEmpty
        ? currentL10n.validatorFieldEmpty(fieldName)
        : null;
  }

  static String? validateNumber(String? number) {
    try {
      if (number == null || number.isEmpty) {
        return currentL10n.validatorNumberRequired;
      }
      int.parse(number);
      return null;
    } catch (e, stackTrace) {
      Logger('InputValidators')
          .log(Level.SEVERE, 'validateNumber ', e, stackTrace);
      return currentL10n.validatorInvalidNumber;
    }
  }

  static String? validateAmount(String? value) {
    if (value != null) {
      try {
        if (value.isEmpty) {
          return currentL10n.validatorInvalidAmount;
        }
        BigInt.parse(value);
        return null;
      } catch (e, stackTrace) {
        Logger('InputValidators')
            .log(Level.SEVERE, 'validateAmount', e, stackTrace);
        return currentL10n.validatorError;
      }
    } else {
      return currentL10n.validatorValueNull;
    }
  }

  static String? correctValue(
    String? value,
    BigInt maxValue,
    int decimals,
    BigInt minValue, {
    bool canBeEqualToMin = false,
    bool canBeBlank = false,
  }) {
    if (value != null) {
      try {
        if (maxValue == BigInt.zero) {
          if (canBeEqualToMin) {
            return null;
          }
          return currentL10n.validatorEmptyBalance;
        }
        if (value.isEmpty) {
          if (canBeBlank) {
            return null;
          } else {
            return currentL10n.validatorEnterValidAmount;
          }
        }

        final BigInt inputNum = value.extractDecimals(decimals);

        if (value.contains('.') && value.split('.')[1].length > decimals) {
          return currentL10n.validatorTooManyDecimals;
        }
        if (maxValue < minValue) {
          return currentL10n.validatorBalanceBelowMin(
            minValue.addDecimals(decimals),
          );
        }
        if (canBeEqualToMin) {
          return minValue <= inputNum && inputNum <= maxValue
              ? null
              : maxValue == minValue
                  ? currentL10n.validatorValueMustBeMinAllowed(
                      minValue.addDecimals(decimals),
                    )
                  : currentL10n.validatorValueOutOfRange(
                      minValue.addDecimals(decimals),
                      maxValue.addDecimals(decimals),
                    );
        }
        return minValue < inputNum && inputNum <= maxValue
            ? null
            : maxValue == minValue
                ? currentL10n.validatorValueMustBe(
                    minValue.addDecimals(decimals),
                  )
                : currentL10n.validatorValueOutOfRange(
                    minValue.addDecimals(decimals),
                    maxValue.addDecimals(decimals),
                  );
      } catch (e, stackTrace) {
        Logger('InputValidators')
            .log(Level.SEVERE, 'correctValue', e, stackTrace);
        return currentL10n.validatorError;
      }
    }
    return currentL10n.validatorValueEmpty;
  }

  static String? checkAddress(String? value) {
    if (value != null) {
      if (value.isEmpty) {
        return currentL10n.validatorEnterAddress;
      }
      return Address.isValid(value) ? null : currentL10n.validatorInvalidAddress;
    } else {
      return currentL10n.validatorValueNull;
    }
  }

  static String? checkPasswordMatch(String firstPass, String? secondPass) {
    if (firstPass != secondPass) {
      return currentL10n.validatorPasswordsDoNotMatch;
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value != null) {
      if (value.length < 8) {
        return currentL10n.validatorPasswordTooWeak;
      }
      const String pattern =
          r'''^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[`~!@#$%^&*()\-_=+\[\]\{\}\\|;:",<.>\/\?']).{8,}$''';
      final RegExp regExp = RegExp(pattern);
      if (regExp.hasMatch(value)) {
        return null;
      }
      return currentL10n.validatorInvalidPassword;
    } else {
      return currentL10n.validatorValueNull;
    }
  }

  static String? validatePillarMomentumAddress(String? value) {
    if (value != null) {
      if (checkAddress(value) == null) {
        if (kDefaultAddressList.contains(value)) {
          return currentL10n.validatorPillarProducerAddressSameSeed;
        }
      } else {
        return checkAddress(value);
      }
      return null;
    } else {
      return currentL10n.validatorValueNull;
    }
  }

  static String? isMaxSupplyZero(String? value) {
    if (value != null) {
      try {
        if (BigInt.parse(value) != BigInt.zero) {
          return currentL10n.validatorMaxSupplyNotZero;
        }
        return null;
      } catch (e, stackTrace) {
        Logger('InputValidators')
            .log(Level.SEVERE, 'isMaxSupplyZero', e, stackTrace);
        return currentL10n.validatorError;
      }
    } else {
      return currentL10n.validatorValueNull;
    }
  }

  static String? checkUrl(String? value) {
    final List<String> protocols = <String>['https'];

    if (isURL(value, protocols: protocols)) {
      return null;
    }
    return currentL10n.validatorInvalidUrl;
  }

  static String? checkHash(String? value) {
    try {
      if (Hash.parse(value!).runtimeType == Hash) {
        return null;
      }
    } catch (e) {
      return currentL10n.validatorInvalidHash;
    }
    return currentL10n.validatorInvalidHash;
  }

  static Future<String?> checkSecret(HtlcInfo htlc, String? value) async {
    if (value != null) {
      try {
        final Hash preimageCheck = htlc.hashType == htlcHashTypeSha3
            ? Hash.digest(hex.decode(value))
            : Hash.fromBytes(await Crypto.sha256Bytes(hex.decode(value)));

        if (preimageCheck == Hash.fromBytes(htlc.hashLock)) {
          return null;
        }
      } catch (e) {
        return currentL10n.validatorInvalidSecret;
      }
    }
    return currentL10n.validatorInvalidSecret;
  }
}
