import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notifiers/app_theme_notifier.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notifiers/locale_notifier.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notifiers/text_scaling_notifier.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class WidgetUtils {
  static void setThemeMode(BuildContext context) {
    final AppThemeNotifier appThemeNotifier = Provider.of<AppThemeNotifier>(
      context,
      listen: false,
    );
    final ThemeMode savedThemeMode = ThemeMode.values.firstWhere(
      (ThemeMode element) =>
          element.toString() == sharedPrefsService!.get(kThemeModeKey),
      orElse: () => kDefaultThemeMode,
    );
    if (appThemeNotifier.currentThemeMode != savedThemeMode) {
      appThemeNotifier.changeThemeMode(savedThemeMode);
    }
  }

  static void setTextScale(BuildContext context) {
    final TextScalingNotifier textScalingNotifier =
        Provider.of<TextScalingNotifier>(
      context,
      listen: false,
    );

    final TextScaling savedTextScaling = TextScaling.values.firstWhere(
      (TextScaling element) =>
          element.toString() == sharedPrefsService!.get(kTextScalingKey),
      orElse: () => kDefaultTextScaling,
    );
    if (textScalingNotifier.currentTextScaling != savedTextScaling) {
      textScalingNotifier.changeTextScaling(savedTextScaling);
    }
  }

  /// The language picked in Settings, as saved; the default when none was.
  ///
  /// Read twice: by `main`, for the [LocaleNotifier] it creates, so the
  /// first frame is in that language, and by [setLanguage].
  static AppLanguage savedLanguage() =>
      AppLanguage.fromStored(sharedPrefsService?.get(kLanguageKey));

  /// Brings the language back in line with what is saved. At start-up it
  /// changes nothing; after a wallet reset has deleted the preferences it
  /// returns the language to the default, as the theme returns to its own.
  static void setLanguage(BuildContext context) {
    Provider.of<LocaleNotifier>(
      context,
      listen: false,
    ).changeLanguage(savedLanguage());
  }

  static String isWidgetHiddenKey(String widgetTitle) =>
      '${widgetTitle}is_hidden';

  static InfiniteScrollTableCell getMarqueeAddressTableCell(
    Address? address,
    BuildContext context,
  ) {
    final TextStyle? textStyle = address != null && address.isEmbedded()
        ? Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.znnColor,
              fontWeight: FontWeight.bold,
            )
        : null;

    if (address != null && kAddressLabelMap.containsKey(address.toString())) {
      return InfiniteScrollTableCell.tooltipWithMarquee(
        address,
        textStyle: textStyle,
        flex: 2,
      );
    } else {
      return InfiniteScrollTableCell.withMarquee(
        address != null ? address.toString() : '',
        textStyle: textStyle,
        flex: 2,
      );
    }
  }

  static String getPlasmaToolTipMessage(PlasmaInfo plasmaInfo) {
    if (plasmaInfo.currentPlasma >= kPillarPlasmaAmountNeeded) {
      return currentL10n.plasmaLevelHighTooltip;
    } else if (plasmaInfo.currentPlasma >= kIssueTokenPlasmaAmountNeeded &&
        plasmaInfo.currentPlasma < kPillarPlasmaAmountNeeded) {
      return currentL10n.plasmaLevelAverageTooltip;
    } else if (plasmaInfo.currentPlasma >= minPlasmaAmount.toInt() &&
        plasmaInfo.currentPlasma < kIssueTokenPlasmaAmountNeeded) {
      return currentL10n.plasmaLevelLowTooltip;
    } else {
      return currentL10n.plasmaLevelInsufficientTooltip;
    }
  }

  static InfiniteScrollTableCell getTextAddressTableCell(
    Address? address,
    BuildContext context, {
    bool checkIfStakeAddress = false,
    bool isShortVersion = true,
    bool showCopyToClipboardIcon = false,
  }) {
    final TextStyle? textStyle = address != null && address.isEmbedded() ||
            (checkIfStakeAddress && address.toString() == kSelectedAddress)
        ? Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.znnColor,
              fontWeight: FontWeight.bold,
            )
        : null;

    if (address != null && kAddressLabelMap.containsKey(address.toString())) {
      return InfiniteScrollTableCell.tooltipWithText(
        context,
        address,
        textStyle: textStyle,
        flex: 2,
        showCopyToClipboardIcon: showCopyToClipboardIcon,
      );
    } else {
      return InfiniteScrollTableCell.withText(
        context,
        address != null
            ? isShortVersion
                ? address.toShortString()
                : address.toString()
            : '',
        flex: 2,
        textStyle: textStyle,
        showCopyToClipboardIcon: showCopyToClipboardIcon,
      );
    }
  }
}
