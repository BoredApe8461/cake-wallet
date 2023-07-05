import 'package:cake_wallet/themes/extensions/balance_page_theme.dart';
import 'package:cake_wallet/themes/extensions/dashboard_page_theme.dart';
import 'package:cake_wallet/themes/extensions/exchange_page_theme.dart';
import 'package:cake_wallet/themes/extensions/filter_theme.dart';
import 'package:cake_wallet/themes/extensions/indicator_dot_theme.dart';
import 'package:cake_wallet/themes/extensions/menu_theme.dart';
import 'package:cake_wallet/themes/extensions/new_wallet_theme.dart';
import 'package:cake_wallet/themes/extensions/order_theme.dart';
import 'package:cake_wallet/themes/extensions/send_page_theme.dart';
import 'package:cake_wallet/themes/extensions/sync_indicator_theme.dart';
import 'package:cake_wallet/themes/extensions/wallet_list_theme.dart';
import 'package:cake_wallet/themes/light_theme.dart';
import 'package:cake_wallet/themes/theme_base.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/palette.dart';
import 'package:flutter/material.dart';

class BrightTheme extends LightTheme {
  BrightTheme({required int raw}) : super(raw: raw);

  @override
  String get title => S.current.bright_theme;
  @override
  ThemeType get type => ThemeType.bright;
  @override
  Color get primaryColor => Palette.moderateSlateBlue;
  @override
  Color get containerColor => Palette.moderateLavender;

  @override
  DashboardPageTheme get dashboardPageTheme =>
      super.dashboardPageTheme.copyWith(
          firstGradientBackgroundColor: Palette.blueCraiola,
          secondGradientBackgroundColor: Palette.pinkFlamingo,
          thirdGradientBackgroundColor: Palette.redHat,
          textColor: Colors.white,
          indicatorDotTheme: IndicatorDotTheme(
              indicatorColor: Colors.white.withOpacity(0.5),
              activeIndicatorColor: Colors.white));

  @override
  SyncIndicatorTheme get syncIndicatorStyle =>
      super.syncIndicatorStyle.copyWith(
          textColor: Colors.white,
          syncedBackgroundColor: Colors.white.withOpacity(0.2),
          notSyncedBackgroundColor: Colors.white.withOpacity(0.15));

  @override
  ExchangePageTheme get exchangePageTheme => super.exchangePageTheme.copyWith(
      secondGradientBottomPanelColor: Palette.pinkFlamingo.withOpacity(0.7),
      firstGradientBottomPanelColor: Palette.blueCraiola.withOpacity(0.7),
      secondGradientTopPanelColor: Palette.pinkFlamingo,
      firstGradientTopPanelColor: Palette.blueCraiola);

  @override
  NewWalletTheme get newWalletTheme => NewWalletTheme(
      hintTextColor: Palette.darkGray,
      underlineColor: Palette.periwinkleCraiola);

  @override
  BalancePageTheme get balancePageTheme =>
      BalancePageTheme(textColor: Colors.white.withOpacity(0.5));

  @override
  CakeMenuTheme get menuTheme => super.menuTheme.copyWith(
      headerSecondGradientColor: Palette.pinkFlamingo,
      iconColor: PaletteDark.pigeonBlue);

  @override
  FilterTheme get filterTheme => super.filterTheme.copyWith(
      checkboxBackgroundColor: Colors.white,
      buttonColor: Colors.white.withOpacity(0.2),
      iconColor: Colors.white);

  @override
  WalletListTheme get walletListTheme => super.walletListTheme.copyWith(
      createNewWalletButtonBackgroundColor: Palette.moderateSlateBlue);

  @override
  OrderTheme get orderTheme => OrderTheme(iconColor: Colors.white);

  @override
  SendPageTheme get sendPageTheme => super.sendPageTheme.copyWith(
      templateBackgroundColor: Palette.shadowWhite,
      templateDotterBorderColor: Palette.shadowWhite,
      secondGradientColor: Palette.pinkFlamingo);

  @override
  ThemeData get themeData => super.themeData.copyWith(
      indicatorColor: Colors.white.withOpacity(0.5), // page indicator
      hoverColor: Colors.white, // amount hint text (receive page)
      dividerColor: Palette.paleBlue,
      hintColor: Palette.gray,
      textTheme: TextTheme(
          labelSmall: TextStyle(
              backgroundColor:
                  Colors.white.withOpacity(0.5), // date section row
              decorationColor: Colors.white
                  .withOpacity(0.2) // icons (transaction and trade rows)
              ),
          // subhead -> titleMedium
          titleMedium: TextStyle(
            color: Colors.white.withOpacity(0.2), // address button border
            decorationColor:
                Colors.white.withOpacity(0.4), // copy button (qr widget)
          ),
          // headline -> headlineSmall
          headlineSmall: TextStyle(
            color: Colors.white, // qr code
            decorationColor: Colors.white
                .withOpacity(0.5), // bottom border of amount (receive page)
          ),
          // display1 -> headlineMedium
          headlineMedium: TextStyle(
            color: PaletteDark.lightBlueGrey, // icons color (receive page)
            decorationColor:
                Palette.lavender, // icons background (receive page)
          ),
          // display2 -> displaySmall
          displaySmall: TextStyle(
              color:
                  Palette.darkBlueCraiola, // text color of tiles (receive page)
              decorationColor:
                  Colors.white // background of tiles (receive page)
              ),
          // display3 -> displayMedium
          displayMedium: TextStyle(
              color: Colors.white, // text color of current tile (receive page),
              //decorationColor: Palette.blueCraiola // background of current tile (receive page)
              decorationColor: Palette
                  .moderateSlateBlue // background of current tile (receive page)
              ),
          // display4 -> displayLarge
          displayLarge: TextStyle(
              color: Palette.violetBlue, // text color of tiles (account list)
              decorationColor:
                  Colors.white // background of tiles (account list)
              ),
          ),
      primaryTextTheme: TextTheme(
          titleLarge: TextStyle(
              color: Palette.darkBlueCraiola, // title color
              backgroundColor: Palette.wildPeriwinkle // textfield underline
              ),
          bodySmall: TextStyle(
              color: PaletteDark.pigeonBlue, // secondary text
              ),
          labelSmall: TextStyle(
            color: Palette.darkGray, // transaction/trade details titles
            decorationColor: Colors.white.withOpacity(0.5), // placeholder
          ),
        ),
      );
}
