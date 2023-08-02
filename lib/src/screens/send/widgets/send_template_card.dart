import 'package:cake_wallet/src/screens/send/widgets/prefix_currency_icon_widget.dart';
import 'package:cake_wallet/utils/payment_request.dart';
import 'package:cake_wallet/view_model/send/template_view_model.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/view_model/send/send_template_view_model.dart';
import 'package:cake_wallet/src/widgets/address_text_field.dart';
import 'package:cake_wallet/src/widgets/base_text_form_field.dart';
import 'package:mobx/mobx.dart';

class SendTemplateCard extends StatelessWidget {
  SendTemplateCard(
      {super.key,
      required this.template,
      required this.index,
      required this.sendTemplateViewModel});

  final TemplateViewModel template;
  final int index;
  final SendTemplateViewModel sendTemplateViewModel;

  final _addressController = TextEditingController();
  final _cryptoAmountController = TextEditingController();
  final _fiatAmountController = TextEditingController();
  final _nameController = TextEditingController();
  final FocusNode _cryptoAmountFocus = FocusNode();
  final FocusNode _fiatAmountFocus = FocusNode();

  bool _effectsInstalled = false;

  @override
  Widget build(BuildContext context) {
    _setEffects(context);

    return Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24)),
            gradient: LinearGradient(colors: [
              Theme.of(context).primaryTextTheme.titleMedium!.color!,
              Theme.of(context).primaryTextTheme.titleMedium!.decorationColor!
            ], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Column(children: <Widget>[
          Padding(
              padding: EdgeInsets.fromLTRB(24, 90, 24, 32),
              child: Column(children: <Widget>[
                if (index == 0)
                  BaseTextFormField(
                      controller: _nameController,
                      hintText: sendTemplateViewModel.recipients.length > 1
                          ? S.of(context).template_name
                          : S.of(context).send_name,
                      borderColor: Theme.of(context)
                          .primaryTextTheme
                          .headlineSmall!
                          .color!,
                      textStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white),
                      placeholderTextStyle: TextStyle(
                          color: Theme.of(context)
                              .primaryTextTheme
                              .headlineSmall!
                              .decorationColor!,
                          fontWeight: FontWeight.w500,
                          fontSize: 14),
                      validator: sendTemplateViewModel.templateValidator),
                Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: AddressTextField(
                        selectedCurrency: sendTemplateViewModel.cryptoCurrency,
                        controller: _addressController,
                        onURIScanned: (uri) {
                          final paymentRequest = PaymentRequest.fromUri(uri);
                          _addressController.text = paymentRequest.address;
                          _cryptoAmountController.text = paymentRequest.amount;
                        },
                        options: [
                          AddressTextFieldOption.paste,
                          AddressTextFieldOption.qrCode,
                          AddressTextFieldOption.addressBook
                        ],
                        onPushPasteButton: (context) async {
                          template.output.resetParsedAddress();
                          await template.output.fetchParsedAddress(context);
                        },
                        onPushAddressBookButton: (context) async {
                          template.output.resetParsedAddress();
                          await template.output.fetchParsedAddress(context);
                        },
                        buttonColor: Theme.of(context)
                            .primaryTextTheme
                            .headlineMedium!
                            .color!,
                        borderColor: Theme.of(context)
                            .primaryTextTheme
                            .headlineSmall!
                            .color!,
                        textStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white),
                        hintStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context)
                                .primaryTextTheme
                                .headlineSmall!
                                .decorationColor!),
                        validator: sendTemplateViewModel.addressValidator)),
                Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Focus(
                        onFocusChange: (hasFocus) {
                          if (hasFocus) {
                            template.selectCurrency();
                          }
                        },
                        child: BaseTextFormField(
                            focusNode: _cryptoAmountFocus,
                            controller: _cryptoAmountController,
                            keyboardType: TextInputType.numberWithOptions(
                                signed: false, decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(
                                  RegExp('[\\-|\\ ]'))
                            ],
                            prefixIcon: Observer(
                                builder: (_) => PrefixCurrencyIcon(
                                    title: sendTemplateViewModel
                                        .cryptoCurrency.title,
                                    isSelected: template.isCurrencySelected)),
                            hintText: '0.0000',
                            borderColor: Theme.of(context)
                                .primaryTextTheme
                                .headlineSmall!
                                .color!,
                            textStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white),
                            placeholderTextStyle: TextStyle(
                                color: Theme.of(context)
                                    .primaryTextTheme
                                    .headlineSmall!
                                    .decorationColor!,
                                fontWeight: FontWeight.w500,
                                fontSize: 14),
                            validator: sendTemplateViewModel.amountValidator))),
                Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Focus(
                        onFocusChange: (hasFocus) {
                          if (hasFocus) {
                            template.selectFiat();
                          }
                        },
                        child: BaseTextFormField(
                            focusNode: _fiatAmountFocus,
                            controller: _fiatAmountController,
                            keyboardType: TextInputType.numberWithOptions(
                                signed: false, decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(
                                  RegExp('[\\-|\\ ]'))
                            ],
                            prefixIcon: Observer(
                                builder: (_) => PrefixCurrencyIcon(
                                    title: sendTemplateViewModel.fiatCurrency,
                                    isSelected: template.isFiatSelected)),
                            hintText: '0.00',
                            borderColor: Theme.of(context)
                                .primaryTextTheme
                                .headlineSmall!
                                .color!,
                            textStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white),
                            placeholderTextStyle: TextStyle(
                                color: Theme.of(context)
                                    .primaryTextTheme
                                    .headlineSmall!
                                    .decorationColor!,
                                fontWeight: FontWeight.w500,
                                fontSize: 14))))
              ]))
        ]));
  }

  void _setEffects(BuildContext context) {
    if (_effectsInstalled) {
      return;
    }

    final output = template.output;

    if (template.address.isNotEmpty) {
      _addressController.text = template.address;
    }
    if (template.name.isNotEmpty) {
      _nameController.text = template.name;
    }
    if (template.output.cryptoAmount.isNotEmpty) {
      _cryptoAmountController.text = template.output.cryptoAmount;
    }
    if (template.output.fiatAmount.isNotEmpty) {
      _fiatAmountController.text = template.output.fiatAmount;
    }

    _addressController.addListener(() {
      final address = _addressController.text;

      if (template.address != address) {
        template.address = address;
      }
    });
    _cryptoAmountController.addListener(() {
      final amount = _cryptoAmountController.text;

      if (amount != output.cryptoAmount) {
        output.setCryptoAmount(amount);
      }
    });
    _fiatAmountController.addListener(() {
      final amount = _fiatAmountController.text;

      if (amount != output.fiatAmount) {
        output.setFiatAmount(amount);
      }
    });
    _nameController.addListener(() {
      final name = _nameController.text;

      if (name != template.name) {
        template.name = name;
      }
    });

    reaction((_) => template.address, (String address) {
      if (address != _addressController.text) {
        _addressController.text = address;
      }
    });
    reaction((_) => output.cryptoAmount, (String amount) {
      if (amount != _cryptoAmountController.text) {
        _cryptoAmountController.text = amount;
      }
    });
    reaction((_) => output.fiatAmount, (String amount) {
      if (amount != _fiatAmountController.text) {
        _fiatAmountController.text = amount;
      }
    });
    reaction((_) => template.name, (String name) {
      if (name != _nameController.text) {
        _nameController.text = name;
      }
    });

    _effectsInstalled = true;
  }
}
