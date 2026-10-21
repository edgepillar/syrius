import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/extensions.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/input_validators.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// A widget that helps the user generate a QR for requesting funds.
///
/// It has two dropdowns:
/// - one for the address on which the funds will be received.
/// - one for the asset that will be transferred - token or native coin.
///
/// And a [TextField] for inputting the transfer amount.
///
/// This data, destination address, asset and amount, is found in the QR.
class ReceivePopulated extends StatefulWidget {
  /// Creates a new instance.
  const ReceivePopulated({
    required this.assets,
    super.key,
  });

  /// The list of available assets on the network - includes tokens and coins
  final List<Token> assets;

  @override
  State<ReceivePopulated> createState() => _ReceivePopulatedState();
}

class _ReceivePopulatedState extends State<ReceivePopulated> {
  final TextEditingController _amountController = TextEditingController();

  String _selectedSenderAddress = kSelectedAddress!;

  late Token _selectedToken;

  String get _amount => _amountController.text;

  String? get _amountErrorText => InputValidators.correctValue(
    _amount,
    kBigP255m1,
    _selectedToken.decimals,
    BigInt.zero,
  );

  @override
  void initState() {
    super.initState();
    _selectedToken = widget.assets.firstWhere(
      (Token asset) => asset.tokenStandard.toString() == znnTokenStandard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Token> sortedAssets = sortAssets(widget.assets);

    return CardFields(
      child: SingleChildScrollView(
        padding: kCardBodyPadding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ReceiveQrImage(
              data: _getQrString(),
              size: 140,
              tokenStandard: _selectedToken.tokenStandard,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildDefaultAddressDropdown(),
                  const SizedBox(height: kCardGap),
                  ZtsDropdown(
                    availableTokens: sortedAssets,
                    onChangeCallback: (Token token) => setState(() {
                      _selectedToken = token;
                    }),
                    selectedToken: _selectedToken,
                  ),
                  const SizedBox(height: kCardGap),
                  // A refused key, a comma for one, says so under the field,
                  // over what the validator says.
                  AmountRefusalScope(
                    controller: _amountController,
                    builder: (_, String? refusal) => TextField(
                      style: monoStyle(const TextStyle(fontSize: 14)),
                      decoration: InputDecoration(
                        errorText:
                            refusal ??
                            (_amount.isNotEmpty ? _amountErrorText : null),
                        hintText: context.l10n.amount,
                      ),
                      onChanged: (String value) => setState(() {}),
                      inputFormatters:
                          FormatUtils.getAmountTextInputFormatters(
                            _amountController.text,
                          ),
                      controller: _amountController,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildAddressLine(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The receiving address in mono, shortened, with its copy button: what
  /// the person reads out or pastes when the QR code will not do.
  Widget _buildAddressLine() {
    final String address = _selectedSenderAddress;
    final String short = address.length > 12
        ? '${address.substring(0, 6)}…${address.substring(address.length - 4)}'
        : address;
    return Row(
      children: <Widget>[
        Expanded(
          child: Tooltip(
            message: address,
            child: Text(
              short,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: monoStyle(cardDimStyle(context)),
            ),
          ),
        ),
        CopyToClipboardButton(address, iconSize: 16),
      ],
    );
  }

  String _getQrString() {
    return '${_selectedToken.symbol.toLowerCase()}:'
        '$_selectedSenderAddress?zts=${_selectedToken.tokenStandard}'
        '&amount=${_getAmount()}';
  }

  BigInt _getAmount() {
    try {
      return _amountController.text.extractDecimals(_selectedToken.decimals);
    } on Exception catch (_) {
      return BigInt.zero;
    }
  }

  Widget _buildDefaultAddressDropdown() {
    return NewAddressesDropdown(
      addresses: kDefaultAddressList.map((String? e) => e!).toList(),
      selectedAddress: _selectedSenderAddress,
      onSelectedCallback: (String value) => setState(
        () {
          _selectedSenderAddress = value;
        },
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}
