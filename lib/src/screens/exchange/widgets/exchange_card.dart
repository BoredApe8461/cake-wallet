import 'package:cake_wallet/entities/contact_base.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/widgets/alert_with_two_actions.dart';
import 'package:cake_wallet/utils/show_bar.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/utils/payment_request.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cake_wallet/src/widgets/address_text_field.dart';
import 'package:cake_wallet/src/widgets/base_text_form_field.dart';
import 'package:cake_wallet/src/screens/exchange/widgets/currency_picker.dart';

class ExchangeCard extends StatefulWidget {
  ExchangeCard(
      {Key key,
      this.title = '',
      this.initialCurrency,
      this.initialAddress,
      this.initialWalletName,
      this.initialIsAmountEditable,
      this.initialIsAddressEditable,
      this.isAmountEstimated,
      this.hasRefundAddress = false,
      this.isMoneroWallet = false,
      this.currencies,
      this.onCurrencySelected,
      this.imageArrow,
      this.currencyButtonColor = Colors.transparent,
      this.addressButtonsColor = Colors.transparent,
      this.borderColor = Colors.transparent,
      this.currencyValueValidator,
      this.addressTextFieldValidator,
      this.amountFocusNode,
      this.addressFocusNode,
      this.hasAllAmount = false,
      this.allAmount,
      this.onPushPasteButton,
      this.onPushAddressBookButton})
      : super(key: key);

  final List<CryptoCurrency> currencies;
  final Function(CryptoCurrency) onCurrencySelected;
  final String title;
  final CryptoCurrency initialCurrency;
  final String initialWalletName;
  final String initialAddress;
  final bool initialIsAmountEditable;
  final bool initialIsAddressEditable;
  final bool isAmountEstimated;
  final bool hasRefundAddress;
  final bool isMoneroWallet;
  final Image imageArrow;
  final Color currencyButtonColor;
  final Color addressButtonsColor;
  final Color borderColor;
  final FormFieldValidator<String> currencyValueValidator;
  final FormFieldValidator<String> addressTextFieldValidator;
  final FocusNode amountFocusNode;
  final FocusNode addressFocusNode;
  final bool hasAllAmount;
  final Function allAmount;
  final Function(BuildContext context) onPushPasteButton;
  final Function(BuildContext context) onPushAddressBookButton;

  @override
  ExchangeCardState createState() => ExchangeCardState();
}

class ExchangeCardState extends State<ExchangeCard> {
  final addressController = TextEditingController();
  final amountController = TextEditingController();

  String _title;
  String _min;
  String _max;
  CryptoCurrency _selectedCurrency;
  String _walletName;
  bool _isAmountEditable;
  bool _isAddressEditable;
  bool _isAmountEstimated;
  bool _isMoneroWallet;

  @override
  void initState() {
    _title = widget.title;
    _isAmountEditable = widget.initialIsAmountEditable;
    _isAddressEditable = widget.initialIsAddressEditable;
    _walletName = widget.initialWalletName;
    _selectedCurrency = widget.initialCurrency;
    _isAmountEstimated = widget.isAmountEstimated;
    _isMoneroWallet = widget.isMoneroWallet;
    addressController.text = widget.initialAddress;
    super.initState();
  }

  void changeLimits({String min, String max}) {
    setState(() {
      _min = min;
      _max = max;
    });
  }

  void changeSelectedCurrency(CryptoCurrency currency) {
    setState(() => _selectedCurrency = currency);
  }

  void changeWalletName(String walletName) {
    setState(() => _walletName = walletName);
  }

  void changeIsAction(bool isActive) {
    setState(() => _isAmountEditable = isActive);
  }

  void isAmountEditable({bool isEditable = true}) {
    setState(() => _isAmountEditable = isEditable);
  }

  void isAddressEditable({bool isEditable = true}) {
    setState(() => _isAddressEditable = isEditable);
  }

  void changeAddress({String address}) {
    setState(() => addressController.text = address);
  }

  void changeAmount({String amount}) {
    setState(() => amountController.text = amount);
  }

  void changeIsAmountEstimated(bool isEstimated) {
    setState(() => _isAmountEstimated = isEstimated);
  }

  @override
  Widget build(BuildContext context) {
    final copyImage = Image.asset('assets/images/copy_content.png',
        height: 16,
        width: 16,
        color: Theme.of(context).primaryTextTheme.display2.color);

    return Container(
      width: double.infinity,
      color: Colors.transparent,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <
          Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Text(
              _title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.headline.color),
            )
          ],
        ),
        Padding(
            padding: EdgeInsets.only(top: 20),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.only(right: 8),
                  height: 32,
                  color: widget.currencyButtonColor,
                  child: InkWell(
                    onTap: () => _presentPicker(context),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Padding(
                            padding: EdgeInsets.only(right: 5),
                            child: widget.imageArrow,
                          ),
                          Text(_selectedCurrency.toString() + ':',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.white))
                        ]),
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: BaseTextFormField(
                            focusNode: widget.amountFocusNode,
                            controller: amountController,
                            enabled: _isAmountEditable,
                            textAlign: TextAlign.left,
                            keyboardType: TextInputType.numberWithOptions(
                                signed: false, decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(
                                  RegExp('[\\-|\\ ]'))
                            ],
                            hintText: '0.0000',
                            borderColor: Colors.transparent,
                            //widget.borderColor,
                            textStyle: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                            placeholderTextStyle: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                    .accentTextTheme
                                    .display4
                                    .decorationColor),
                            validator: _isAmountEditable
                                ? widget.currencyValueValidator
                                : null),
                      ),
                      if (widget.hasAllAmount)
                        Container(
                          height: 32,
                          width: 32,
                          decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .primaryTextTheme
                                  .display1
                                  .color,
                              borderRadius:
                              BorderRadius.all(Radius.circular(6))),
                          child: InkWell(
                            onTap: () => widget.allAmount?.call(),
                            child: Center(
                              child: Text(S.of(context).all,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .primaryTextTheme
                                          .display1
                                          .decorationColor)),
                            ),
                          ),
                        )
                    ],
                  ),
                ),
              ],
            )),
        Divider(height: 1,color: Theme.of(context)
            .primaryTextTheme
            .headline
            .decorationColor),
        Padding(
          padding: EdgeInsets.only(top: 5),
          child: Container(
              height: 15,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    _min != null
                        ? Text(
                            S
                                .of(context)
                                .min_value(_min, _selectedCurrency.toString()),
                            style: TextStyle(
                                fontSize: 10,
                                height: 1.2,
                                color: Theme.of(context)
                                    .accentTextTheme
                                    .display4
                                    .decorationColor),
                          )
                        : Offstage(),
                    _min != null ? SizedBox(width: 10) : Offstage(),
                    _max != null
                        ? Text(
                            S
                                .of(context)
                                .max_value(_max, _selectedCurrency.toString()),
                            style: TextStyle(
                                fontSize: 10,
                                height: 1.2,
                                color: Theme.of(context)
                                    .accentTextTheme
                                    .display4
                                    .decorationColor))
                        : Offstage(),
                  ])),
        ),
        !_isAddressEditable && widget.hasRefundAddress
            ? Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text(
                  S.of(context).refund_address,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context)
                          .accentTextTheme
                          .display4
                          .decorationColor),
                ))
            : Offstage(),
        _isAddressEditable
            ? Padding(
                padding: EdgeInsets.only(top: 20),
                child: AddressTextField(
                    focusNode: widget.addressFocusNode,
                    controller: addressController,
                    onURIScanned: (uri) {
                      final paymentRequest = PaymentRequest.fromUri(uri);
                      addressController.text = paymentRequest.address;

                      if (amountController.text.isNotEmpty) {
                        _showAmountPopup(context, paymentRequest);
                      } else {
                        amountController.text = paymentRequest.amount;
                      }
                    },
                    placeholder: widget.hasRefundAddress
                        ? S.of(context).refund_address
                        : null,
                    options: [
                      AddressTextFieldOption.paste,
                      AddressTextFieldOption.qrCode,
                      AddressTextFieldOption.addressBook,
                    ],
                    isBorderExist: false,
                    textStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                    hintStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context)
                            .accentTextTheme
                            .display4
                            .decorationColor),
                    buttonColor: widget.addressButtonsColor,
                    validator: widget.addressTextFieldValidator,
                    onPushPasteButton: widget.onPushPasteButton,
                    onPushAddressBookButton: widget.onPushAddressBookButton
                ),

              )
            : Padding(
                padding: EdgeInsets.only(top: 10),
                child: Builder(
                    builder: (context) => Stack(children: <Widget>[
                          BaseTextFormField(
                              controller: addressController,
                              readOnly: true,
                              borderColor: Colors.transparent,
                              suffixIcon:
                                  SizedBox(width: _isMoneroWallet ? 80 : 36),
                              textStyle: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                              validator: widget.addressTextFieldValidator),
                          Positioned(
                              top: 2,
                              right: 0,
                              child: SizedBox(
                                  width: _isMoneroWallet ? 80 : 36,
                                  child: Row(children: <Widget>[
                                    if (_isMoneroWallet)
                                      Padding(
                                        padding: EdgeInsets.only(left: 10),
                                        child: Container(
                                            width: 34,
                                            height: 34,
                                            padding: EdgeInsets.only(top: 0),
                                            child: InkWell(
                                              onTap: () async {
                                                final contact =
                                                    await Navigator.of(context,
                                                            rootNavigator: true)
                                                        .pushNamed(Routes
                                                            .pickerAddressBook);

                                                if (contact is ContactBase &&
                                                    contact.address != null) {
                                                  setState(() =>
                                                      addressController.text =
                                                          contact.address);
                                                  widget.onPushAddressBookButton
                                                      ?.call(context);
                                                }
                                              },
                                              child: Container(
                                                  padding: EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                      color: widget
                                                          .addressButtonsColor,
                                                      borderRadius:
                                                          BorderRadius.all(
                                                              Radius.circular(
                                                                  6))),
                                                  child: Image.asset(
                                                    'assets/images/open_book.png',
                                                    color: Theme.of(context)
                                                        .primaryTextTheme
                                                        .display1
                                                        .decorationColor,
                                                  )),
                                            )),
                                      ),
                                    Padding(
                                        padding: EdgeInsets.only(left: 2),
                                        child: Container(
                                            width: 34,
                                            height: 34,
                                            padding: EdgeInsets.only(top: 0),
                                            child: InkWell(
                                              onTap: () {
                                                Clipboard.setData(ClipboardData(
                                                    text: addressController
                                                        .text));
                                                showBar<void>(
                                                    context,
                                                    S
                                                        .of(context)
                                                        .copied_to_clipboard);
                                              },
                                              child: Container(
                                                  padding: EdgeInsets.fromLTRB(
                                                      8, 8, 0, 8),
                                                  color: Colors.transparent,
                                                  child: copyImage),
                                            )))
                                  ])))
                        ])),
              ),
      ]),
    );
  }

  void _presentPicker(BuildContext context) {
    showPopUp<void>(
        builder: (_) => CurrencyPicker(
            selectedAtIndex: widget.currencies.indexOf(_selectedCurrency),
            items: widget.currencies,
            hintText: S.of(context).search_currency,
            isMoneroWallet: _isMoneroWallet,
            isConvertFrom: widget.hasRefundAddress,
            onItemSelected: (CryptoCurrency item) =>
                widget.onCurrencySelected != null
                    ? widget.onCurrencySelected(item)
                    : null),
        context: context);
  }

  void _showAmountPopup(BuildContext context, PaymentRequest paymentRequest) {
    showPopUp<void>(
        context: context,
        builder: (dialogContext) {
          return AlertWithTwoActions(
              alertTitle: S.of(context).overwrite_amount,
              alertContent: S.of(context).qr_payment_amount,
              rightButtonText: S.of(context).ok,
              leftButtonText: S.of(context).cancel,
              actionRightButton: () {
                amountController.text = paymentRequest.amount;
                Navigator.of(context).pop();
              },
              actionLeftButton: () => Navigator.of(dialogContext).pop());
        }
    );
  }
}
