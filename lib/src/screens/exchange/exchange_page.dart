import 'dart:ui';
import 'package:cake_wallet/entities/sync_status.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:mobx/mobx.dart';
import 'package:cake_wallet/exchange/exchange_provider.dart';
import 'package:cake_wallet/core/execution_state.dart';
import 'package:cake_wallet/exchange/exchange_template.dart';
import 'package:cake_wallet/exchange/exchange_trade_state.dart';
import 'package:cake_wallet/exchange/limits_state.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/widgets/alert_with_two_actions.dart';
import 'package:cake_wallet/src/widgets/keyboard_done_button.dart';
import 'package:cake_wallet/src/widgets/template_tile.dart';
import 'package:cake_wallet/src/widgets/trail_button.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/entities/crypto_currency.dart';
import 'package:cake_wallet/exchange/xmrto/xmrto_exchange_provider.dart';
import 'package:cake_wallet/src/screens/exchange/widgets/exchange_card.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/src/widgets/scollable_with_bottom_section.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/view_model/exchange/exchange_view_model.dart';
import 'package:cake_wallet/core/address_validator.dart';
import 'package:cake_wallet/core/amount_validator.dart';
import 'package:cake_wallet/src/screens/exchange/widgets/present_provider_picker.dart';

class ExchangePage extends BasePage {
  ExchangePage(this.exchangeViewModel);

  final ExchangeViewModel exchangeViewModel;
  final depositKey = GlobalKey<ExchangeCardState>();
  final receiveKey = GlobalKey<ExchangeCardState>();
  final _formKey = GlobalKey<FormState>();
  final _depositAmountFocus = FocusNode();
  final _receiveAmountFocus = FocusNode();
  var _isReactionsSet = false;

  @override
  String get title => S.current.exchange;

  @override
  Color get titleColor => Colors.white;

  @override
  bool get resizeToAvoidBottomPadding => false;

  @override
  bool get extendBodyBehindAppBar => true;

  @override
  AppBarStyle get appBarStyle => AppBarStyle.transparent;

  @override
  Widget middle(BuildContext context) =>
      PresentProviderPicker(exchangeViewModel: exchangeViewModel);

  @override
  Widget trailing(BuildContext context) => TrailButton(
      caption: S.of(context).reset, onPressed: () {
        _formKey.currentState.reset();
        exchangeViewModel.reset();
  });

  @override
  Widget body(BuildContext context) {
    final arrowBottomPurple = Image.asset(
      'assets/images/arrow_bottom_purple_icon.png',
      color: Colors.white,
      height: 8,
    );
    final arrowBottomCakeGreen = Image.asset(
      'assets/images/arrow_bottom_cake_green.png',
      color: Colors.white,
      height: 8,
    );

    final depositWalletName =
        exchangeViewModel.depositCurrency == CryptoCurrency.xmr
            ? exchangeViewModel.wallet.name
            : null;
    final receiveWalletName =
        exchangeViewModel.receiveCurrency == CryptoCurrency.xmr
            ? exchangeViewModel.wallet.name
            : null;

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _setReactions(context, exchangeViewModel));

    return KeyboardActions(
        config: KeyboardActionsConfig(
            keyboardActionsPlatform: KeyboardActionsPlatform.IOS,
            keyboardBarColor: isDarkTheme
                ? Color.fromRGBO(48, 51, 60, 1.0)
                : Color.fromRGBO(98, 98, 98, 1.0),
            nextFocus: false,
            actions: [
              KeyboardActionsItem(
                  focusNode: _depositAmountFocus,
                  toolbarButtons: [(_) => KeyboardDoneButton()]),
              KeyboardActionsItem(
                  focusNode: _receiveAmountFocus,
                  toolbarButtons: [(_) => KeyboardDoneButton()])
            ]),
        child: Container(
          height: 1,
          color: Theme.of(context).backgroundColor,
          child: Form(
              key: _formKey,
              child: ScrollableWithBottomSection(
                contentPadding: EdgeInsets.only(bottom: 24),
                content: Column(
                  children: <Widget>[
                    Container(
                      padding: EdgeInsets.only(bottom: 32),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(24),
                            bottomRight: Radius.circular(24)),
                        gradient: LinearGradient(
                            colors: [
                              Theme.of(context).primaryTextTheme.body1.color,
                              Theme.of(context)
                                  .primaryTextTheme
                                  .body1
                                  .decorationColor,
                            ],
                            stops: [
                              0.35,
                              1.0
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                      ),
                      child: Column(
                        children: <Widget>[
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(24),
                                  bottomRight: Radius.circular(24)),
                              gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context)
                                        .primaryTextTheme
                                        .subtitle
                                        .color,
                                    Theme.of(context)
                                        .primaryTextTheme
                                        .subtitle
                                        .decorationColor,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight),
                            ),
                            padding: EdgeInsets.fromLTRB(24, 100, 24, 32),
                            child: Observer(
                              builder: (_) => ExchangeCard(
                                amountFocusNode: _depositAmountFocus,
                                key: depositKey,
                                title: S.of(context).you_will_send,
                                initialCurrency:
                                    exchangeViewModel.depositCurrency,
                                initialWalletName: depositWalletName,
                                initialAddress:
                                    exchangeViewModel.depositCurrency ==
                                            exchangeViewModel.wallet.currency
                                        ? exchangeViewModel.wallet.address
                                        : exchangeViewModel.depositAddress,
                                initialIsAmountEditable: true,
                                initialIsAddressEditable:
                                    exchangeViewModel.isDepositAddressEnabled,
                                isAmountEstimated: false,
                                hasRefundAddress: true,
                                currencies: CryptoCurrency.all,
                                onCurrencySelected: (currency) =>
                                    exchangeViewModel.changeDepositCurrency(
                                        currency: currency),
                                imageArrow: arrowBottomPurple,
                                currencyButtonColor: Colors.transparent,
                                addressButtonsColor:
                                    Theme.of(context).focusColor,
                                borderColor: Theme.of(context)
                                    .primaryTextTheme
                                    .body2
                                    .color,
                                currencyValueValidator: AmountValidator(
                                    type: exchangeViewModel.wallet.type),
                                addressTextFieldValidator: AddressValidator(
                                    type: exchangeViewModel.depositCurrency),
                              ),
                            ),
                          ),
                          Padding(
                            padding:
                                EdgeInsets.only(top: 29, left: 24, right: 24),
                            child: Observer(
                                builder: (_) => ExchangeCard(
                                      amountFocusNode: _receiveAmountFocus,
                                      key: receiveKey,
                                      title: S.of(context).you_will_get,
                                      initialCurrency:
                                          exchangeViewModel.receiveCurrency,
                                      initialWalletName: receiveWalletName,
                                      initialAddress: exchangeViewModel
                                                  .receiveCurrency ==
                                              exchangeViewModel.wallet.currency
                                          ? exchangeViewModel.wallet.address
                                          : exchangeViewModel.receiveAddress,
                                      initialIsAmountEditable: exchangeViewModel
                                              .provider is XMRTOExchangeProvider
                                          ? true
                                          : false,
                                      initialIsAddressEditable:
                                          exchangeViewModel
                                              .isReceiveAddressEnabled,
                                      isAmountEstimated: true,
                                      currencies: CryptoCurrency.all,
                                      onCurrencySelected: (currency) =>
                                          exchangeViewModel
                                              .changeReceiveCurrency(
                                                  currency: currency),
                                      imageArrow: arrowBottomCakeGreen,
                                      currencyButtonColor: Colors.transparent,
                                      addressButtonsColor:
                                          Theme.of(context).focusColor,
                                      borderColor: Theme.of(context)
                                          .primaryTextTheme
                                          .body2
                                          .decorationColor,
                                      currencyValueValidator: AmountValidator(
                                          type: exchangeViewModel.wallet.type),
                                      addressTextFieldValidator:
                                          AddressValidator(
                                              type: exchangeViewModel
                                                  .receiveCurrency),
                                    )),
                          )
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 30, left: 24, bottom: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            S.of(context).send_templates,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                    .primaryTextTheme
                                    .display4
                                    .color),
                          )
                        ],
                      ),
                    ),
                    Container(
                        height: 40,
                        width: double.infinity,
                        padding: EdgeInsets.only(left: 24),
                        child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: <Widget>[
                                GestureDetector(
                                  onTap: () => Navigator.of(context)
                                      .pushNamed(Routes.exchangeTemplate),
                                  child: Container(
                                    padding:
                                        EdgeInsets.only(left: 1, right: 10),
                                    child: DottedBorder(
                                        borderType: BorderType.RRect,
                                        dashPattern: [6, 4],
                                        color: Theme.of(context)
                                            .primaryTextTheme
                                            .display2
                                            .decorationColor,
                                        strokeWidth: 2,
                                        radius: Radius.circular(20),
                                        child: Container(
                                          height: 34,
                                          width: 75,
                                          padding: EdgeInsets.only(
                                              left: 10, right: 10),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(20)),
                                            color: Colors.transparent,
                                          ),
                                          child: Text(
                                            S.of(context).send_new,
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(context)
                                                    .primaryTextTheme
                                                    .display3
                                                    .color),
                                          ),
                                        )),
                                  ),
                                ),
                                Observer(builder: (_) {
                                  final templates = exchangeViewModel.templates;
                                  final itemCount = templates.length;

                                  return ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      itemCount: itemCount,
                                      itemBuilder: (context, index) {
                                        final template = templates[index];

                                        return TemplateTile(
                                          key: UniqueKey(),
                                          amount: template.amount,
                                          from: template.depositCurrency,
                                          to: template.receiveCurrency,
                                          onTap: () {
                                            applyTemplate(
                                                exchangeViewModel, template);
                                          },
                                          onRemove: () {
                                            showPopUp<void>(
                                                context: context,
                                                builder: (dialogContext) {
                                                  return AlertWithTwoActions(
                                                      alertTitle: S
                                                          .of(context)
                                                          .template,
                                                      alertContent: S
                                                          .of(context)
                                                          .confirm_delete_template,
                                                      rightButtonText:
                                                          S.of(context).delete,
                                                      leftButtonText:
                                                          S.of(context).cancel,
                                                      actionRightButton: () {
                                                        Navigator.of(
                                                                dialogContext)
                                                            .pop();
                                                        exchangeViewModel
                                                            .removeTemplate(
                                                                template:
                                                                    template);
                                                        exchangeViewModel
                                                            .updateTemplate();
                                                      },
                                                      actionLeftButton: () =>
                                                          Navigator.of(
                                                                  dialogContext)
                                                              .pop());
                                                });
                                          },
                                        );
                                      });
                                }),
                              ],
                            )))
                  ],
                ),
                bottomSectionPadding:
                    EdgeInsets.only(left: 24, right: 24, bottom: 24),
                bottomSection: Column(children: <Widget>[
                  Padding(
                    padding: EdgeInsets.only(bottom: 15),
                    child: Observer(builder: (_) {
                      final description =
                          exchangeViewModel.provider is XMRTOExchangeProvider
                              ? S.of(context).amount_is_guaranteed
                              : S.of(context).amount_is_estimate;
                      return Center(
                        child: Text(
                          description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .primaryTextTheme
                                  .display4
                                  .decorationColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 12),
                        ),
                      );
                    }),
                  ),
                  Observer(
                    builder: (_) => LoadingPrimaryButton(
                      text: S.of(context).exchange,
                      onPressed: () {
                        if (_formKey.currentState.validate()) {
                          if ((exchangeViewModel.depositCurrency == CryptoCurrency.xmr)
                          &&(!(exchangeViewModel.status is SyncedSyncStatus))) {
                            showPopUp<void>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertWithOneAction(
                                  alertTitle: S.of(context).exchange,
                                  alertContent: S.of(context).exchange_sync_alert_content,
                                  buttonText: S.of(context).ok,
                                  buttonAction: () => Navigator.of(context).pop());
                              });
                          } else {
                            exchangeViewModel.isValidAmount()
                            ? exchangeViewModel.createTrade()
                            : showPopUp<void>(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertWithOneAction(
                                      alertTitle: S.of(context).xmr_to_error,
                                      alertContent: S.of(context).xmr_to_error_description,
                                      buttonText: S.of(context).ok,
                                      buttonAction: () =>
                                          Navigator.of(context).pop());
                                });
                          }
                        }
                      },
                      color: Theme.of(context).accentTextTheme.body2.color,
                      textColor: Colors.white,
                      isLoading: exchangeViewModel.tradeState
                                 is TradeIsCreating)),
                ]),
              )),
        ));
  }

  void applyTemplate(
      ExchangeViewModel exchangeViewModel, ExchangeTemplate template) {
    exchangeViewModel.changeDepositCurrency(
        currency: CryptoCurrency.fromString(template.depositCurrency));
    exchangeViewModel.changeReceiveCurrency(
        currency: CryptoCurrency.fromString(template.receiveCurrency));

    switch (template.provider) {
      case 'XMR.TO':
        exchangeViewModel.changeProvider(
            provider: exchangeViewModel.providerList[0]);
        break;
      case 'ChangeNOW':
        exchangeViewModel.changeProvider(
            provider: exchangeViewModel.providerList[1]);
        break;
      case 'MorphToken':
        exchangeViewModel.changeProvider(
            provider: exchangeViewModel.providerList[2]);
        break;
    }

    exchangeViewModel.changeDepositAmount(amount: template.amount);
    exchangeViewModel.depositAddress = template.depositAddress;
    exchangeViewModel.receiveAddress = template.receiveAddress;
    exchangeViewModel.isReceiveAmountEntered = false;
  }

  void _setReactions(
      BuildContext context, ExchangeViewModel exchangeViewModel) {
    if (_isReactionsSet) {
      return;
    }

    final depositAddressController = depositKey.currentState.addressController;
    final depositAmountController = depositKey.currentState.amountController;
    final receiveAddressController = receiveKey.currentState.addressController;
    final receiveAmountController = receiveKey.currentState.amountController;
    final limitsState = exchangeViewModel.limitsState;

    if (limitsState is LimitsLoadedSuccessfully) {
      final min = limitsState.limits.min != null
          ? limitsState.limits.min.toString()
          : null;
      final max = limitsState.limits.max != null
          ? limitsState.limits.max.toString()
          : null;
      final key = depositKey;
      key.currentState.changeLimits(min: min, max: max);
    }

    _onCurrencyChange(
        exchangeViewModel.receiveCurrency, exchangeViewModel, receiveKey);
    _onCurrencyChange(
        exchangeViewModel.depositCurrency, exchangeViewModel, depositKey);

    reaction(
        (_) => exchangeViewModel.wallet.name,
        (String _) => _onWalletNameChange(
            exchangeViewModel, exchangeViewModel.receiveCurrency, receiveKey));

    reaction(
        (_) => exchangeViewModel.wallet.name,
        (String _) => _onWalletNameChange(
            exchangeViewModel, exchangeViewModel.depositCurrency, depositKey));

    reaction(
        (_) => exchangeViewModel.receiveCurrency,
        (CryptoCurrency currency) =>
            _onCurrencyChange(currency, exchangeViewModel, receiveKey));

    reaction(
        (_) => exchangeViewModel.depositCurrency,
        (CryptoCurrency currency) =>
            _onCurrencyChange(currency, exchangeViewModel, depositKey));

    reaction((_) => exchangeViewModel.depositAmount, (String amount) {
      if (depositKey.currentState.amountController.text != amount) {
        depositKey.currentState.amountController.text = amount;
      }
    });

    reaction((_) => exchangeViewModel.depositAddress, (String address) {
      if (depositKey.currentState.addressController.text != address) {
        depositKey.currentState.addressController.text = address;
      }
    });

    reaction((_) => exchangeViewModel.isDepositAddressEnabled,
        (bool isEnabled) {
      depositKey.currentState.isAddressEditable(isEditable: isEnabled);
    });

    reaction((_) => exchangeViewModel.receiveAmount, (String amount) {
      if (receiveKey.currentState.amountController.text != amount) {
        receiveKey.currentState.amountController.text = amount;
      }
    });

    reaction((_) => exchangeViewModel.receiveAddress, (String address) {
      if (receiveKey.currentState.addressController.text != address) {
        receiveKey.currentState.addressController.text = address;
      }
    });

    reaction((_) => exchangeViewModel.isReceiveAddressEnabled,
        (bool isEnabled) {
      receiveKey.currentState.isAddressEditable(isEditable: isEnabled);
    });

    reaction((_) => exchangeViewModel.provider, (ExchangeProvider provider) {
      provider is XMRTOExchangeProvider
          ? receiveKey.currentState.isAmountEditable(isEditable: true)
          : receiveKey.currentState.isAmountEditable(isEditable: false);
    });

    reaction((_) => exchangeViewModel.tradeState, (ExchangeTradeState state) {
      if (state is TradeIsCreatedFailure) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showPopUp<void>(
              context: context,
              builder: (BuildContext context) {
                return AlertWithOneAction(
                    alertTitle: state.title,
                    alertContent: state.error,
                    buttonText: S.of(context).ok,
                    buttonAction: () => Navigator.of(context).pop());
              });
        });
      }
      if (state is TradeIsCreatedSuccessfully) {
        Navigator.of(context).pushNamed(Routes.exchangeConfirm);
      }
    });

    reaction((_) => exchangeViewModel.limitsState, (LimitsState state) {
      String min;
      String max;

      if (state is LimitsLoadedSuccessfully) {
        min = state.limits.min != null ? state.limits.min.toString() : null;
        max = state.limits.max != null ? state.limits.max.toString() : null;
      }

      if (state is LimitsLoadedFailure) {
        min = '0';
        max = '0';
      }

      if (state is LimitsIsLoading) {
        min = '...';
        max = '...';
      }

      depositKey.currentState.changeLimits(min: min, max: max);
      receiveKey.currentState.changeLimits(min: null, max: null);
    });

    depositAddressController.addListener(
        () => exchangeViewModel.depositAddress = depositAddressController.text);

    depositAmountController.addListener(() {
      if (depositAmountController.text != exchangeViewModel.depositAmount) {
        exchangeViewModel.changeDepositAmount(
            amount: depositAmountController.text);
        exchangeViewModel.isReceiveAmountEntered = false;
      }
    });

    receiveAddressController.addListener(
        () => exchangeViewModel.receiveAddress = receiveAddressController.text);

    receiveAmountController.addListener(() {
      if (receiveAmountController.text != exchangeViewModel.receiveAmount) {
        exchangeViewModel.changeReceiveAmount(
            amount: receiveAmountController.text);
        exchangeViewModel.isReceiveAmountEntered = true;
      }
    });

    reaction((_) => exchangeViewModel.wallet.address, (String address) {
      if (exchangeViewModel.depositCurrency == CryptoCurrency.xmr) {
        depositKey.currentState.changeAddress(address: address);
      }

      if (exchangeViewModel.receiveCurrency == CryptoCurrency.xmr) {
        receiveKey.currentState.changeAddress(address: address);
      }
    });

    _isReactionsSet = true;
  }

  void _onCurrencyChange(CryptoCurrency currency,
      ExchangeViewModel exchangeViewModel, GlobalKey<ExchangeCardState> key) {
    final isCurrentTypeWallet = currency == exchangeViewModel.wallet.currency;

    key.currentState.changeSelectedCurrency(currency);
    key.currentState.changeWalletName(
        isCurrentTypeWallet ? exchangeViewModel.wallet.name : null);

    key.currentState.changeAddress(
        address: isCurrentTypeWallet ? exchangeViewModel.wallet.address : '');

    key.currentState.changeAmount(amount: '');
  }

  void _onWalletNameChange(ExchangeViewModel exchangeViewModel,
      CryptoCurrency currency, GlobalKey<ExchangeCardState> key) {
    final isCurrentTypeWallet = currency == exchangeViewModel.wallet.currency;

    if (isCurrentTypeWallet) {
      key.currentState.changeWalletName(exchangeViewModel.wallet.name);
      key.currentState.addressController.text =
          exchangeViewModel.wallet.address;
    } else if (key.currentState.addressController.text ==
        exchangeViewModel.wallet.address) {
      key.currentState.changeWalletName(null);
      key.currentState.addressController.text = null;
    }
  }
}
