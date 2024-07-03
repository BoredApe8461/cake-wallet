import 'package:breez_sdk/breez_sdk.dart';
import 'package:breez_sdk/bridge_generated.dart' as BZG;
import 'package:cake_wallet/entities/fiat_currency.dart';
import 'package:cake_wallet/entities/priority_for_wallet_type.dart';
import 'package:cake_wallet/lightning/lightning.dart';
import 'package:cake_wallet/src/screens/receive/widgets/anonpay_currency_input_field.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/src/widgets/base_text_form_field.dart';
import 'package:cake_wallet/src/widgets/keyboard_done_button.dart';
import 'package:cake_wallet/src/widgets/picker.dart';
import 'package:cake_wallet/themes/extensions/exchange_page_theme.dart';
import 'package:cake_wallet/themes/extensions/keyboard_theme.dart';
import 'package:cake_wallet/themes/extensions/send_page_theme.dart';
import 'package:cake_wallet/themes/theme_base.dart';
import 'package:cake_wallet/utils/responsive_layout_util.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/lightning_send_view_model.dart';
import 'package:cake_wallet/view_model/lightning_view_model.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/src/widgets/scollable_with_bottom_section.dart';
import 'package:cake_wallet/generated/i18n.dart';

class LightningSendConfirmPage extends BasePage {
  LightningSendConfirmPage({this.btcAddress, this.invoice, required this.lightningSendViewModel})
      : _formKey = GlobalKey<FormState>() {
    initialSatAmount = ((invoice?.amountMsat ?? 0) ~/ 1000);
    _amountController = TextEditingController();
    _fiatAmountController = TextEditingController();
    _amountController.text = initialSatAmount.toString();
    _fiatAmountController.text = lightningSendViewModel.formattedFiatAmount(initialSatAmount);
    assert(btcAddress != null || invoice != null);
  }

  final GlobalKey<FormState> _formKey;
  final controller = PageController(initialPage: 0);

  BZG.LNInvoice? invoice;
  final String? btcAddress;
  late int initialSatAmount;
  late TextEditingController _amountController;
  late TextEditingController _fiatAmountController;
  final FocusNode _depositAmountFocus = FocusNode();
  final LightningSendViewModel lightningSendViewModel;

  bool _effectsInstalled = false;

  @override
  String get title => S.current.send;

  @override
  bool get gradientAll => true;

  @override
  bool get resizeToAvoidBottomInset => false;

  @override
  bool get extendBodyBehindAppBar => true;

  @override
  Widget? leading(BuildContext context) {
    final _backButton = Icon(
      Icons.arrow_back_ios,
      color: titleColor(context),
      size: 16,
    );
    final _closeButton =
        currentTheme.type == ThemeType.dark ? closeButtonImageDarkTheme : closeButtonImage;

    bool isMobileView = responsiveLayoutUtil.shouldRenderMobileUI;

    return MergeSemantics(
      child: SizedBox(
        height: isMobileView ? 37 : 45,
        width: isMobileView ? 37 : 45,
        child: ButtonTheme(
          minWidth: double.minPositive,
          child: Semantics(
            label: !isMobileView ? S.of(context).close : S.of(context).seed_alert_back,
            child: TextButton(
              style: ButtonStyle(
                overlayColor: MaterialStateColor.resolveWith((states) => Colors.transparent),
              ),
              onPressed: () => onClose(context),
              child: !isMobileView ? _closeButton : _backButton,
            ),
          ),
        ),
      ),
    );
  }

  @override
  AppBarStyle get appBarStyle => AppBarStyle.transparent;

  @override
  void onClose(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget body(BuildContext context) {
    _setEffects(context);

    return WillPopScope(
      onWillPop: () => _onNavigateBack(context),
      child: KeyboardActions(
        disableScroll: true,
        config: KeyboardActionsConfig(
            keyboardActionsPlatform: KeyboardActionsPlatform.IOS,
            keyboardBarColor: Theme.of(context).extension<KeyboardTheme>()!.keyboardBarColor,
            nextFocus: false,
            actions: [
              KeyboardActionsItem(
                focusNode: FocusNode(),
                toolbarButtons: [(_) => KeyboardDoneButton()],
              ),
            ]),
        child: Container(
          color: Theme.of(context).colorScheme.background,
          child: ScrollableWithBottomSection(
            contentPadding: EdgeInsets.only(bottom: 24),
            content: Container(
              decoration: responsiveLayoutUtil.shouldRenderMobileUI
                  ? BoxDecoration(
                      borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context)
                              .extension<ExchangePageTheme>()!
                              .firstGradientTopPanelColor,
                          Theme.of(context)
                              .extension<ExchangePageTheme>()!
                              .secondGradientTopPanelColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    )
                  : null,
              child: Observer(builder: (_) {
                late String initialValue;
                if (btcAddress != null) {
                  initialValue = btcAddress!;
                } else {
                  initialValue = "${S.of(context).invoice}: ${invoice?.bolt11}";
                }
                return Padding(
                  padding: EdgeInsets.fromLTRB(24, 120, 24, 0),
                  child: Column(
                    children: [
                      BaseTextFormField(
                        enabled: false,
                        borderColor: Theme.of(context)
                            .extension<ExchangePageTheme>()!
                            .textFieldBorderTopPanelColor,
                        initialValue: initialValue,
                        placeholderTextStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).extension<ExchangePageTheme>()!.hintTextColor,
                        ),
                        textStyle: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                        validator: null,
                        maxLines: 2,
                      ),
                      SizedBox(height: 12),
                      if (initialSatAmount == 0)
                        Observer(builder: (_) {
                          return AnonpayCurrencyInputField(
                            controller: _amountController,
                            focusNode: _depositAmountFocus,
                            maxAmount: '',
                            minAmount: '',
                            selectedCurrency: CryptoCurrency.btcln,
                          );
                        })
                      else
                        BaseTextFormField(
                          enabled: false,
                          borderColor: Theme.of(context)
                              .extension<ExchangePageTheme>()!
                              .textFieldBorderTopPanelColor,
                          suffixIcon: SizedBox(width: 36),
                          initialValue:
                              "sats: ${lightning!.bitcoinAmountToLightningString(amount: initialSatAmount)}",
                          placeholderTextStyle: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).extension<ExchangePageTheme>()!.hintTextColor,
                          ),
                          textStyle: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                          validator: null,
                        ),
                      SizedBox(height: 12),
                      BaseTextFormField(
                        enabled: false,
                        controller: _fiatAmountController,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(top: 9),
                          child: Text(
                            lightningSendViewModel.fiat.title + ':',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        borderColor: Theme.of(context)
                            .extension<ExchangePageTheme>()!
                            .textFieldBorderTopPanelColor,
                        suffixIcon: SizedBox(width: 36),
                        placeholderTextStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).extension<ExchangePageTheme>()!.hintTextColor,
                        ),
                        textStyle: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                        validator: null,
                      ),
                      SizedBox(height: 12),
                      if (invoice?.description?.isNotEmpty ?? false) ...[
                        BaseTextFormField(
                          enabled: false,
                          initialValue: "${S.of(context).description}: ${invoice?.description}",
                          textInputAction: TextInputAction.next,
                          borderColor: Theme.of(context)
                              .extension<ExchangePageTheme>()!
                              .textFieldBorderTopPanelColor,
                          suffixIcon: SizedBox(width: 36),
                          placeholderTextStyle: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).extension<ExchangePageTheme>()!.hintTextColor,
                          ),
                          textStyle: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                          validator: null,
                        ),
                        SizedBox(height: 12),
                      ],
                      if (btcAddress != null) ...[
                        Observer(
                          builder: (_) => GestureDetector(
                            onTap: () => pickTransactionPriority(context),
                            child: Container(
                              padding: EdgeInsets.only(top: 24),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    S.of(context).send_estimated_fee,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white),
                                  ),
                                  Container(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.start,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              "${lightningSendViewModel.estimatedFeeSats} ${lightningSendViewModel.currency.toString()}",
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsets.only(top: 5),
                                              child: lightningSendViewModel.isFiatDisabled
                                                  ? const SizedBox(height: 14)
                                                  : Text(
                                                      "${lightningSendViewModel.estimatedFeeFiatAmount} ${lightningSendViewModel.fiat.title}",
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: Theme.of(context)
                                                            .extension<SendPageTheme>()!
                                                            .textFieldHintColor,
                                                      ),
                                                    ),
                                            ),
                                          ],
                                        ),
                                        Padding(
                                          padding: EdgeInsets.only(top: 2, left: 5),
                                          child: Icon(
                                            Icons.arrow_forward_ios,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        )
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                      ],
                    ],
                  ),
                );
              }),
            ),
            bottomSectionPadding: EdgeInsets.only(left: 24, right: 24, bottom: 24),
            bottomSection: Observer(builder: (_) {
              return Column(
                children: <Widget>[
                  LoadingPrimaryButton(
                    text: S.of(context).send,
                    onPressed: () async {
                      try {
                        if (invoice != null) {
                          await lightningSendViewModel.sendInvoice(
                              invoice!, int.parse(_amountController.text));
                        } else if (btcAddress != null) {
                          await lightningSendViewModel.sendBtc(
                              btcAddress!, int.parse(_amountController.text));
                        }

                        await showPopUp<void>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertWithOneAction(
                                  alertTitle: '',
                                  alertContent:
                                      S.of(context).send_success(CryptoCurrency.btc.toString()),
                                  buttonText: S.of(context).ok,
                                  buttonAction: () {
                                    Navigator.of(context).pop();
                                    // todo: Navigator.popUntil(context, (route) => route.isFirst);
                                  });
                            });
                        Navigator.of(context).pop();
                      } catch (e) {
                        showPopUp<void>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertWithOneAction(
                                  alertTitle: S.of(context).error,
                                  alertContent: e.toString(),
                                  buttonText: S.of(context).ok,
                                  buttonAction: () => Navigator.of(context).pop());
                            });
                      }
                    },
                    color: Theme.of(context).primaryColor,
                    textColor: Colors.white,
                    isLoading: lightningSendViewModel.loading,
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Future<bool> _onNavigateBack(BuildContext context) async {
    onClose(context);
    return false;
  }

  void _setEffects(BuildContext context) {
    if (_effectsInstalled) {
      return;
    }

    _amountController.addListener(() {
      final amount = _amountController.text;
      if (amount.isNotEmpty) {
        _fiatAmountController.text = lightningSendViewModel.formattedFiatAmount(int.parse(amount));
        lightningSendViewModel.setCryptoAmount(int.parse(amount));
      }
    });

    _effectsInstalled = true;
  }

  Future<void> pickTransactionPriority(BuildContext context) async {
    final items = priorityForWalletType(WalletType.bitcoin);
    final selectedItem = items.indexOf(lightningSendViewModel.transactionPriority);
    final customItemIndex = lightningSendViewModel.getCustomPriorityIndex(items);
    double? maxCustomFeeRate = (await lightningSendViewModel.maxCustomFeeRate)?.toDouble();
    double? customFeeRate = lightningSendViewModel.customBitcoinFeeRate.toDouble();

    await showPopUp<void>(
      context: context,
      builder: (BuildContext context) {
        int selectedIdx = selectedItem;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Picker(
              items: items,
              displayItem: (TransactionPriority priority) =>
                  lightningSendViewModel.displayFeeRate(priority, customFeeRate?.round()),
              selectedAtIndex: selectedIdx,
              customItemIndex: customItemIndex,
              maxValue: maxCustomFeeRate,
              title: S.of(context).please_select,
              headerEnabled: false,
              closeOnItemSelected: false,
              mainAxisAlignment: MainAxisAlignment.center,
              sliderValue: customFeeRate,
              onSliderChanged: (double newValue) => setState(() => customFeeRate = newValue),
              onItemSelected: (TransactionPriority priority) {
                lightningSendViewModel.setTransactionPriority(priority);
                setState(() => selectedIdx = items.indexOf(priority));
              },
            );
          },
        );
      },
    );
    lightningSendViewModel.customBitcoinFeeRate = customFeeRate!.round();
  }
}
