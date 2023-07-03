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
  Color get primaryTextColor => Palette.darkBlueCraiola;
  @override
  Color get containerColor => Palette.moderateLavender;

  @override
  ThemeData get themeData => super.themeData.copyWith(
      indicatorColor: Colors.white.withOpacity(0.5), // page indicator
      hoverColor: Colors.white, // amount hint text (receive page)
      dividerColor: Palette.paleBlue,
      hintColor: Palette.gray,
      textTheme: TextTheme(
          // title -> titleLarge
          titleLarge: TextStyle(
            color: Colors.white, // sync_indicator text
            backgroundColor: Colors.white.withOpacity(0.2), // synced sync_indicator
            decorationColor: Colors.white.withOpacity(0.15), // not synced sync_indicator
          ),
          bodySmall: TextStyle(
            color: Palette.shineOrange, // not synced light
            decorationColor: Colors.white, // filter icon
          ),
          labelSmall: TextStyle(
              color: Colors.white.withOpacity(0.2), // filter button
              backgroundColor:
                  Colors.white.withOpacity(0.5), // date section row
              decorationColor: Colors.white
                  .withOpacity(0.2) // icons (transaction and trade rows)
              ),
          // subhead -> titleMedium
          titleMedium: TextStyle(
            color: Colors.white.withOpacity(0.2), // address button border
            decorationColor: Colors.white.withOpacity(0.4), // copy button (qr widget)
          ),
          // headline -> headlineSmall
          headlineSmall: TextStyle(
            color: Colors.white, // qr code
            decorationColor: Colors.white.withOpacity(0.5), // bottom border of amount (receive page)
          ),
          // display1 -> headlineMedium
          headlineMedium: TextStyle(
            color: PaletteDark.lightBlueGrey, // icons color (receive page)
            decorationColor: Palette.lavender, // icons background (receive page)
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
          // subtitle -> titleSmall
          titleSmall: TextStyle(
              color: Palette
                  .moderateSlateBlue, // text color of current tile (account list)
              decorationColor:
                  Colors.white // background of current tile (account list)
              ),
          // body -> bodyMedium
          bodyMedium: TextStyle(
              color: Palette.moderatePurpleBlue, // scrollbar thumb
              decorationColor: Palette.periwinkleCraiola // scrollbar background
              ),
          // body2 -> bodyLarge
          bodyLarge: TextStyle(
            color: Palette.moderateLavender, // menu header
            decorationColor: Colors.white, // menu background
          )
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: MaterialStateProperty.all(Palette.moderatePurpleBlue),
        trackColor: MaterialStateProperty.all(Palette.periwinkleCraiola),
        radius: Radius.circular(3),
        thickness: MaterialStateProperty.all(6),
        thumbVisibility: MaterialStateProperty.all(true),
        crossAxisMargin: 6,
      ),
      primaryTextTheme: TextTheme(
          titleLarge: TextStyle(
              color: Palette.darkBlueCraiola, // title color
              backgroundColor: Palette.wildPeriwinkle // textfield underline
              ),
          bodySmall: TextStyle(
              color: PaletteDark.pigeonBlue, // secondary text
              decorationColor: Palette.wildLavender // menu divider
              ),
          labelSmall: TextStyle(
            color: Palette.darkGray, // transaction/trade details titles
            decorationColor: Colors.white.withOpacity(0.5), // placeholder
          ),
          // subhead -> titleMedium
          titleMedium: TextStyle(
              color: Palette.blueCraiola, // first gradient color (send page)
              decorationColor:
                  Palette.pinkFlamingo // second gradient color (send page)
              ),
          // headline -> headlineSmall
          headlineSmall: TextStyle(
            color: Colors.white
                .withOpacity(0.5), // text field border color (send page)
            decorationColor: Colors.white
                .withOpacity(0.5), // text field hint color (send page)
          ),
          // display1 -> headlineMedium
          headlineMedium: TextStyle(
              color: Colors.white
                  .withOpacity(0.2), // text field button color (send page)
              decorationColor:
                  Colors.white // text field button icon color (send page)
              ),
          // display2 -> displaySmall
          displaySmall: TextStyle(
              color: Colors.white.withOpacity(0.5), // estimated fee (send page)
              backgroundColor: PaletteDark.darkCyanBlue
                  .withOpacity(0.67), // dot color for indicator on send page
              decorationColor:
                  Palette.shadowWhite // template dotted border (send page)
              ),
          // display3 -> displayMedium
          displayMedium: TextStyle(
              color: Palette.darkBlueCraiola, // template new text (send page)
              backgroundColor: PaletteDark
                  .darkNightBlue, // active dot color for indicator on send page
              decorationColor:
                  Palette.shadowWhite // template background color (send page)
              ),
          // display4 -> displayLarge
          displayLarge: TextStyle(
              color: Palette.darkBlueCraiola, // template title (send page)
              backgroundColor:
                  Colors.white, // icon color on order row (moonpay)
              decorationColor:
                  Palette.niagara // receive amount text (exchange page)
              ),
          // subtitle -> titleSmall
          titleSmall: TextStyle(
              color: Palette
                  .blueCraiola, // first gradient color top panel (exchange page)
              decorationColor: Palette
                  .pinkFlamingo // second gradient color top panel (exchange page)
              ),
          // body -> bodyMedium
          bodyMedium: TextStyle(
              color: Palette.blueCraiola.withOpacity(
                  0.7), // first gradient color bottom panel (exchange page)
              decorationColor: Palette.pinkFlamingo.withOpacity(
                  0.7), // second gradient color bottom panel (exchange page)
              backgroundColor:
                  Palette.moderateSlateBlue // alert right button text
              ),
          // body2 -> bodyLarge
          bodyLarge: TextStyle(
              color: Colors.white.withOpacity(
                  0.5), // text field border on top panel (exchange page)
              decorationColor: Colors.white.withOpacity(
                  0.5), // text field border on bottom panel (exchange page)
              backgroundColor: Palette.brightOrange // alert left button text
          )
      ),
      focusColor: Colors.white.withOpacity(0.2), // text field button (exchange page)
      accentTextTheme: TextTheme(
        // title -> titleLarge
        titleLarge: TextStyle(
            backgroundColor: Palette.periwinkleCraiola, // picker divider
            decorationColor: Colors.white // dialog background
            ),
        bodySmall: TextStyle(
          color: Palette.moderateLavender, // container (confirm exchange)
          backgroundColor: Palette.moderateLavender, // button background (confirm exchange)
          decorationColor: Palette.darkBlueCraiola, // text color (information page)
        ),
        // subtitle -> titleSmall
        titleSmall: TextStyle(
            color: Palette.darkBlueCraiola, // QR code (exchange trade page)
            backgroundColor: Palette.wildPeriwinkle, // divider (exchange trade page)
            //decorationColor: Palette.blueCraiola // crete new wallet button background (wallet list page)
            decorationColor: Palette
                .moderateSlateBlue // crete new wallet button background (wallet list page)
            ),
        // headline -> headlineSmall
        headlineSmall: TextStyle(
            color: Palette
                .moderateLavender, // first gradient color of wallet action buttons (wallet list page)
            backgroundColor: Palette
                .moderateLavender, // second gradient color of wallet action buttons (wallet list page)
            decorationColor: Colors
                .white // restore wallet button text color (wallet list page)
            ),
        // subhead -> titleMedium
        titleMedium: TextStyle(
            color: Palette.darkGray, // titles color (filter widget)
            backgroundColor: Palette.periwinkle, // divider color (filter widget)
            decorationColor: Colors.white // checkbox background (filter widget)
            ),
        labelSmall: TextStyle(
          color: Palette.wildPeriwinkle, // checkbox bounds (filter widget)
          decorationColor: Colors.white, // menu subname
        ),
        // display1 -> headlineMedium
        headlineMedium: TextStyle(
            color: Palette.blueCraiola, // first gradient color (menu header)
            decorationColor: Palette.pinkFlamingo, // second gradient color(menu header)
            backgroundColor: Colors.white // active dot color
            ),
        // display2 -> displaySmall
        displaySmall: TextStyle(
            color:
                Palette.shadowWhite, // action button color (address text field)
            decorationColor: Palette.darkGray, // hint text (seed widget)
            backgroundColor:
                Colors.white.withOpacity(0.5) // text on balance page
            ),
        // display3 -> displayMedium
        displayMedium: TextStyle(
            color: Palette.darkGray, // hint text (new wallet page)
            decorationColor:
                Palette.periwinkleCraiola, // underline (new wallet page)
            backgroundColor:
                Colors.white // menu, icons, balance (dashboard page)
            ),
        // display4 -> displayLarge
        displayLarge: TextStyle(
            color: Palette.darkGray, // switch background (settings page)
            backgroundColor:
                Colors.black, // icon color on support page (moonpay, github)
            decorationColor:
                Colors.white.withOpacity(0.4) // hint text (exchange page)
            ),
        // body -> bodyMedium
        bodyMedium: TextStyle(
            color: Palette.darkGray, // indicators (PIN code)
            decorationColor: Palette.darkGray, // switch (PIN code)
            backgroundColor: Colors.white // alert right button
            ),
        // body2 -> bodyLarge
        bodyLarge: TextStyle(
            color: Palette.moderateSlateBlue, // primary buttons
            decorationColor: Colors.white, // alert left button,
            backgroundColor: Palette.dullGray // keyboard bar color
        )
      ));
}
