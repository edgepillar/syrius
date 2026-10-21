import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notification_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notifiers/app_theme_notifier.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notifiers/locale_notifier.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notifiers/text_scaling_notifier.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';

enum TextScaling {
  system,
  small,
  normal,
  large,
  huge,
}

/// Theme, text size and language.
///
/// A choice applies and is saved the moment it is picked. These used to be
/// radios that changed the window at once but were forgotten at the next
/// start unless "Confirm theme" or "Confirm scale" was pressed as well.
class DisplayWidget extends StatefulWidget {
  const DisplayWidget({super.key});

  @override
  State<DisplayWidget> createState() => _DisplayWidget();
}

class _DisplayWidget extends State<DisplayWidget> {
  @override
  Widget build(BuildContext context) {
    final ThemeMode? themeMode = context
        .watch<AppThemeNotifier>()
        .currentThemeMode;
    final TextScaling? textScaling = context
        .watch<TextScalingNotifier>()
        .currentTextScaling;
    final AppLanguage language = context
        .watch<LocaleNotifier>()
        .currentLanguage;
    // As tall as its rows: at 240 high the three rows fitted the Normal text
    // size only, and Large or Huge pushed the last one under the edge.
    return SettingsSection(
      children: <Widget>[
        Panel(
          title: 'Display',
          shrinkWrap: true,
          child: SettingsList(
            children: <Widget>[
              SettingRow(
                label: 'Theme',
                trailing: ChoicePills<ThemeMode>(
                  values: ThemeMode.values,
                  selected: themeMode,
                  labelOf: FormatUtils.extractNameFromEnum<ThemeMode>,
                  onSelected: _onThemeModeSelected,
                ),
              ),
              SettingRow(
                label: 'Text size',
                trailing: ChoicePills<TextScaling>(
                  values: TextScaling.values,
                  selected: textScaling,
                  labelOf: FormatUtils.extractNameFromEnum<TextScaling>,
                  onSelected: _onTextScalingSelected,
                ),
              ),
              // A menu, not pills: six pills outgrow the row at the
              // smallest window once the text size is Large or Huge.
              SettingRow(
                label: 'Language',
                trailing: _LanguageMenu(
                  selected: language,
                  onSelected: _onLanguageSelected,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _onThemeModeSelected(ThemeMode themeMode) async {
    Provider.of<AppThemeNotifier>(
      context,
      listen: false,
    ).changeThemeMode(themeMode);
    try {
      await sharedPrefsService!.put(kThemeModeKey, themeMode.toString());
    } catch (e) {
      await NotificationUtils.sendNotificationError(
        e,
        'Theme mode change failed',
      );
    }
  }

  Future<void> _onTextScalingSelected(TextScaling textScaling) async {
    Provider.of<TextScalingNotifier>(
      context,
      listen: false,
    ).changeTextScaling(textScaling);
    try {
      await sharedPrefsService!.put(kTextScalingKey, textScaling.toString());
    } catch (e) {
      await NotificationUtils.sendNotificationError(
        e,
        'Text scale change failed',
      );
    }
  }

  Future<void> _onLanguageSelected(AppLanguage language) async {
    Provider.of<LocaleNotifier>(
      context,
      listen: false,
    ).changeLanguage(language);
    try {
      await sharedPrefsService!.put(kLanguageKey, language.toString());
    } catch (e) {
      await NotificationUtils.sendNotificationError(
        e,
        'Language change failed',
      );
    }
  }
}

/// The languages, each under its own name.
class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({required this.selected, required this.onSelected});

  final AppLanguage selected;
  final ValueChanged<AppLanguage> onSelected;

  @override
  Widget build(BuildContext context) {
    final Color faint = AppTokens.of(context).faint;
    return DropdownMenu<AppLanguage>(
      key: const Key('display_language_menu'),
      initialSelection: selected,
      dropdownMenuEntries: <DropdownMenuEntry<AppLanguage>>[
        for (final AppLanguage language in AppLanguage.values)
          DropdownMenuEntry<AppLanguage>(
            value: language,
            label: language.nativeName,
          ),
      ],
      onSelected: (AppLanguage? language) {
        if (language != null && language != selected) {
          onSelected(language);
        }
      },
      selectOnly: true,
      trailingIcon: Icon(Icons.keyboard_arrow_down_rounded, color: faint),
      selectedTrailingIcon: Icon(
        Icons.keyboard_arrow_up_rounded,
        color: faint,
      ),
    );
  }
}
