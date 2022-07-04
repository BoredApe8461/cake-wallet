import 'dart:ui';
import 'package:cake_wallet/src/widgets/base_alert_dialog.dart';
import 'package:flutter/cupertino.dart';

class AlertWithTwoActions extends BaseAlertDialog {
  AlertWithTwoActions({
    @required this.alertTitle,
    @required this.leftButtonText,
    @required this.rightButtonText,
    @required this.actionLeftButton,
    @required this.actionRightButton,
    this.alertBarrierDismissible = true,
    this.isDividerExists = false,
    this.alertContent,
    this.contentWidget,
  }) : assert(alertContent != null || contentWidget != null);

  final String alertTitle;
  final String alertContent;
  final String leftButtonText;
  final String rightButtonText;
  final VoidCallback actionLeftButton;
  final VoidCallback actionRightButton;
  final bool alertBarrierDismissible;
  @override
  final Widget contentWidget;
  @override
  final bool isDividerExists;

  @override
  String get titleText => alertTitle;
  @override
  String get contentText => alertContent;
  @override
  String get leftActionButtonText => leftButtonText;
  @override
  String get rightActionButtonText => rightButtonText;
  @override
  VoidCallback get actionLeft => actionLeftButton;
  @override
  VoidCallback get actionRight => actionRightButton;
  @override
  bool get barrierDismissible => alertBarrierDismissible;
}