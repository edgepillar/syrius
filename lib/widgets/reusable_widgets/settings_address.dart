import 'package:material_ui/material_ui.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notification_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

/// One address in Settings: its label over the address, a rename and a copy.
class SettingsAddress extends StatefulWidget {
  const SettingsAddress({
    required this.address,
    required this.onAddressLabelPressed,
    super.key,
  });
  final String? address;
  final void Function(String?) onAddressLabelPressed;

  @override
  State<SettingsAddress> createState() => _SettingsAddressState();
}

class _SettingsAddressState extends State<SettingsAddress> {
  bool _editable = false;

  final TextEditingController _labelController = TextEditingController();

  final GlobalKey<MyOutlinedButtonState> _changeButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (kAddressLabelMap[widget.address] != null) {
      _labelController.text = kAddressLabelMap[widget.address]!;
    } else {
      // No context can be read in initState.
      _labelController.text = currentL10n.addressDefaultLabel(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: _editable
          ? _buildAddressLabelInputField()
          : _buildAddressLabel(context),
    );
  }

  Widget _buildAddressLabel(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(kCardRadius),
            onTap: () => widget.onAddressLabelPressed(widget.address),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _labelController.text,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 2),
                  _buildAddressText(),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: context.l10n.settingsAddressRenameTooltip,
          visualDensity: VisualDensity.compact,
          iconSize: 16,
          icon: const Icon(Icons.edit_outlined, color: AppColors.faint),
          onPressed: () {
            setState(() {
              _editable = true;
            });
          },
        ),
        CopyToClipboardButton(widget.address!, iconSize: 16),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildAddressLabelInputField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: InputField(
                  controller: _labelController,
                  hintText: context.l10n.settingsAddressLabelHint,
                  onSubmitted: (String value) {
                    if (_labelController.text !=
                        kAddressLabelMap[widget.address]!) {
                      _onChangeButtonPressed();
                    }
                  },
                  onChanged: (String value) {
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 10),
              SecondaryAction(
                child: SettingsButton(
                  onPressed:
                      _labelController.text != kAddressLabelMap[widget.address]!
                      ? _onChangeButtonPressed
                      : null,
                  text: context.l10n.commonSave,
                  key: _changeButtonKey,
                ),
              ),
              IconButton(
                tooltip: context.l10n.cancel,
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                icon: const Icon(Icons.close, color: AppColors.faint),
                onPressed: () {
                  setState(() {
                    _labelController.text = kAddressLabelMap[widget.address]!;
                    _editable = false;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          _buildAddressText(),
        ],
      ),
    );
  }

  Widget _buildAddressText() {
    return Text(
      widget.address!,
      overflow: TextOverflow.ellipsis,
      style: settingMonoStyle(context).copyWith(fontSize: 12),
    );
  }

  Future<void> _onChangeButtonPressed() async {
    try {
      _changeButtonKey.currentState!.showLoadingIndicator(true);
      if (_labelController.text.isNotEmpty &&
          _labelController.text.length <= kAddressLabelMaxLength &&
          !kAddressLabelMap.containsValue(_labelController.text)) {
        await Hive.box(kAddressLabelsBox).put(
          widget.address,
          _labelController.text,
        );
        kAddressLabelMap[widget.address!] = _labelController.text;
        setState(() {
          _editable = false;
        });
      } else if (_labelController.text.isEmpty) {
        await NotificationUtils.sendNotificationError(
          currentL10n.settingsAddressLabelEmptyError,
          currentL10n.settingsAddressLabelEmptyError,
        );
      } else if (_labelController.text.length > kAddressLabelMaxLength) {
        await NotificationUtils.sendNotificationError(
          currentL10n.settingsAddressLabelTooLongNotificationDetails(
            _labelController.text,
            _labelController.text.length,
            kAddressLabelMaxLength,
          ),
          currentL10n.settingsAddressLabelTooLongNotificationTitle(
            kAddressLabelMaxLength,
          ),
        );
      } else {
        await NotificationUtils.sendNotificationError(
          currentL10n.settingsAddressLabelExistsNotificationDetails(
            _labelController.text,
          ),
          currentL10n.settingsAddressLabelExistsNotificationTitle,
        );
      }
    } catch (e) {
      await NotificationUtils.sendNotificationError(
        e,
        currentL10n.settingsAddressRenameFailedNotificationTitle,
      );
    } finally {
      _changeButtonKey.currentState!.showLoadingIndicator(false);
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }
}
