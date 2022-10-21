import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cake_wallet/palette.dart';

class BaseAlertDialog extends StatelessWidget {
  String get titleText => '';
  String get contentText => '';
  String get leftActionButtonText => '';
  String get rightActionButtonText => '';
  bool get isDividerExists => false;
  VoidCallback get actionLeft => () {};
  VoidCallback get actionRight => () {};
  bool get barrierDismissible => true;
  Widget? get contentWidget => null;
  EdgeInsets? get contentPadding => null;
  Color? get leftActionButtonColor => null;
  Color? get rightActionButtonColor => null;
  Color? get titleColor => null;

  Widget title(BuildContext context) {
    return Text(
      titleText,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 20,
        fontFamily: 'Lato',
        fontWeight: FontWeight.w600,
        color: titleColor ?? Theme.of(context).primaryTextTheme.headline6!.color!,
        decoration: TextDecoration.none,
      ),
    );
  }

  Widget content(BuildContext context) {
    return contentWidget ?? Text(
      contentText.toString(),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        fontFamily: 'Lato',
        color: Theme.of(context).primaryTextTheme.headline6!.color!,
        decoration: TextDecoration.none,
      ),
    );
  }

  Widget actionButtons(BuildContext context) {
    return Container(
      height: 52,
      child: Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Flexible(
          child: Container(
            width: double.infinity,
            color: leftActionButtonColor ?? Theme.of(context).accentTextTheme.bodyText1!.decorationColor!,
            child: TextButton(
                onPressed: actionLeft,
                child: Text(
                  leftActionButtonText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontFamily: 'Lato',
                    fontWeight: FontWeight.w600,
                    color: leftActionButtonColor != null
                        ? Colors.white
                        : Theme.of(context).primaryTextTheme.bodyText1!.backgroundColor!,
                    decoration: TextDecoration.none,
                  ),
                )),
          ),
        ),
        if (leftActionButtonColor == null && rightActionButtonColor == null)
          Container(
            width: 1,
            color: Theme.of(context).dividerColor,
          ),
        Flexible(
          child: Container(
            width: double.infinity,
            color: rightActionButtonColor ?? Theme.of(context).accentTextTheme.bodyText2!.backgroundColor!,
            child: TextButton(
                onPressed: actionRight,
                child: Text(
                  rightActionButtonText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontFamily: 'Lato',
                    fontWeight: FontWeight.w600,
                    color: rightActionButtonColor != null
                        ? Colors.white
                        : Theme.of(context).primaryTextTheme.bodyText2!.backgroundColor!,
                    decoration: TextDecoration.none,
                  ),
                )),
          ),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => barrierDismissible ? Navigator.of(context).pop() : null,
      child: Container(
        color: Colors.transparent,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
          child: Container(
            decoration: BoxDecoration(color: PaletteDark.darkNightBlue.withOpacity(0.75)),
            child: Center(
              child: GestureDetector(
                onTap: () => null,
                child: ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(30)),
                  child: Container(
                    width: 300,
                    color: Theme.of(context).accentTextTheme.headline6!.decorationColor!,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Padding(
                              padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
                              child: title(context),
                            ),
                            isDividerExists
                                ? Padding(
                                    padding: EdgeInsets.only(top: 16, bottom: 8),
                                    child: Container(
                                      height: 1,
                                      color: Theme.of(context).dividerColor,
                                    ),
                                  )
                                : Offstage(),
                            Padding(
                              padding: contentPadding ?? EdgeInsets.fromLTRB(24, 8, 24, 32),
                              child: content(context),
                            )
                          ],
                        ),
                        Container(
                          height: 1,
                          color: Theme.of(context).dividerColor,
                        ),
                        actionButtons(context)
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
