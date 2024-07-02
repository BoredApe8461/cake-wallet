import 'package:cake_wallet/buy/buy_quote.dart';
import 'package:cake_wallet/buy/payment_method.dart';
import 'package:cake_wallet/core/address_validator.dart';
import 'package:cake_wallet/core/selectable_option.dart';
import 'package:cake_wallet/di.dart';
import 'package:cake_wallet/entities/fiat_currency.dart';
import 'package:cake_wallet/entities/parse_address_from_domain.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/screens/exchange/widgets/desktop_exchange_cards_section.dart';
import 'package:cake_wallet/src/screens/exchange/widgets/exchange_card.dart';
import 'package:cake_wallet/src/screens/exchange/widgets/mobile_exchange_cards_section.dart';
import 'package:cake_wallet/src/screens/send/widgets/extract_address_from_parsed.dart';
import 'package:cake_wallet/src/widgets/keyboard_done_button.dart';
import 'package:cake_wallet/src/widgets/option_tile.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/src/widgets/scollable_with_bottom_section.dart';
import 'package:cake_wallet/src/widgets/trail_button.dart';
import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:cake_wallet/themes/extensions/exchange_page_theme.dart';
import 'package:cake_wallet/themes/extensions/keyboard_theme.dart';
import 'package:cake_wallet/themes/extensions/send_page_theme.dart';
import 'package:cake_wallet/themes/theme_base.dart';
import 'package:cake_wallet/typography.dart';
import 'package:cake_wallet/utils/debounce.dart';
import 'package:cake_wallet/utils/responsive_layout_util.dart';
import 'package:cake_wallet/view_model/buy/buy_sell_view_model.dart';
import 'package:cake_wallet/view_model/exchange/exchange_view_model.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:mobx/mobx.dart';

class BuySellPage extends BasePage {
  BuySellPage(this.buySellViewModel);

  final BuySellViewModel buySellViewModel;
  final cryptoCurrencyKey = GlobalKey<ExchangeCardState>();
  final fiatCurrencyKey = GlobalKey<ExchangeCardState>();
  final _formKey = GlobalKey<FormState>();
  final _fiatAmountFocus = FocusNode();
  final _depositAddressFocus = FocusNode();
  final _cryptoAmountFocus = FocusNode();
  final _receiveAddressFocus = FocusNode();
  final _cryptoAmountDebounce = Debounce(Duration(milliseconds: 500));
  Debounce _depositAmountDebounce = Debounce(Duration(milliseconds: 500));
  var _isReactionsSet = false;

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

  late final String? depositWalletName;
  late final String? receiveWalletName;

  @override
  String get title => S.current.buy + '/' + S.current.sell;

  @override
  bool get gradientBackground => true;

  @override
  bool get gradientAll => true;

  @override
  bool get resizeToAvoidBottomInset => false;

  @override
  bool get extendBodyBehindAppBar => true;

  @override
  AppBarStyle get appBarStyle => AppBarStyle.transparent;

  @override
  Function(BuildContext)? get pushToNextWidget => (context) {
        FocusScopeNode currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus) {
          currentFocus.focusedChild?.unfocus();
        }
      };

  @override
  Widget trailing(BuildContext context) => TrailButton(
      caption: S.of(context).clear,
      onPressed: () {
        _formKey.currentState?.reset();
      });

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
  Widget body(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _setReactions(context, buySellViewModel));

    return KeyboardActions(
        disableScroll: true,
        config: KeyboardActionsConfig(
            keyboardActionsPlatform: KeyboardActionsPlatform.IOS,
            keyboardBarColor: Theme.of(context).extension<KeyboardTheme>()!.keyboardBarColor,
            nextFocus: false,
            actions: [
              KeyboardActionsItem(
                  focusNode: _fiatAmountFocus, toolbarButtons: [(_) => KeyboardDoneButton()]),
              KeyboardActionsItem(
                  focusNode: _cryptoAmountFocus, toolbarButtons: [(_) => KeyboardDoneButton()])
            ]),
        child: Container(
          color: Theme.of(context).colorScheme.background,
          child: Form(
              key: _formKey,
              child: ScrollableWithBottomSection(
                contentPadding: EdgeInsets.only(bottom: 24),
                content: Observer(
                  builder: (_) => Column(
                    children: <Widget>[
                      _exchangeCardsSection(context),
                      if (buySellViewModel.selectedPaymentMethod != null)
                        Observer(builder: (_) {
                          return Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              child: OptionTile(
                                imagePath: buySellViewModel.selectedPaymentMethod!.iconPath,
                                title: buySellViewModel.selectedPaymentMethod!.title,
                                leftSubTitle: '',
                                onPressed: () {
                                  Navigator.of(context).pushNamed(Routes.selectOptions, arguments: [
                                    'S.of(context).payment_methods',
                                    buySellViewModel.paymentMethods,
                                    buySellViewModel.changeOption
                                  ]);
                                },
                                leadingIcon: Icons.arrow_forward_ios,
                                borderRadius: 24,
                                padding: EdgeInsets.fromLTRB(8, 12, 24, 24),
                                titleTextStyle: textLargeBold(
                                    color:
                                        Theme.of(context).extension<CakeTextTheme>()!.titleColor),
                              ));
                        }),
                      if (buySellViewModel.selectedQuote != null)
                        Observer(builder: (_) {
                          final selectedQuote = buySellViewModel.selectedQuote!;
                          return Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                              child: OptionTile(
                                imagePath: selectedQuote.provider!.lightIcon,
                                title: selectedQuote.provider!.title,
                                firstBadgeName: selectedQuote.firstBadgeName,
                                secondBadgeName: selectedQuote.secondBadgeName,
                                leftSubTitle: selectedQuote.leftSubTitle,
                                leftSubTitleMaxLines: 1,
                                leftSubTitleTextStyle: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).extension<CakeTextTheme>()!.titleColor,
                                ),
                                rightSubTitle: selectedQuote.rightSubTitle,
                                onPressed: () {
                                  Navigator.of(context).pushNamed(Routes.selectOptions, arguments: [
                                    'S.of(context).payment_methods',
                                    buySellViewModel.sortedAvailableQuotes,
                                    buySellViewModel.changeOption
                                  ]);
                                },
                                leadingIcon: Icons.arrow_forward_ios,
                                borderRadius: 24,
                                padding: EdgeInsets.fromLTRB(8, 12, 24, 24),
                                titleTextStyle: textLargeBold(
                                    color:
                                        Theme.of(context).extension<CakeTextTheme>()!.titleColor),
                              ));
                        })
                    ],
                  ),
                ),
                bottomSectionPadding: EdgeInsets.only(left: 24, right: 24, bottom: 24),
                bottomSection: Column(children: <Widget>[
                  Observer(
                      builder: (_) => LoadingPrimaryButton(
                          text: 'Next',
                          onPressed: () {},
                          color: Theme.of(context).primaryColor,
                          textColor: Colors.white,
                          isDisabled: false,
                          isLoading: false)),
                ]),
              )),
        ));
  }

  void _setReactions(BuildContext context, BuySellViewModel buySellViewModel) {
    if (_isReactionsSet) {
      return;
    }


    final fiatAmountController = fiatCurrencyKey.currentState!.amountController;
    
    _onCryptoCurrencyChange(buySellViewModel.cryptoCurrency, buySellViewModel, cryptoCurrencyKey);
    _onFiatCurrencyChange(buySellViewModel.fiatCurrency, buySellViewModel, fiatCurrencyKey);

    reaction(
        (_) => buySellViewModel.cryptoCurrency,
        (CryptoCurrency currency) =>
            _onCryptoCurrencyChange(currency, buySellViewModel, cryptoCurrencyKey));

    reaction(
        (_) => buySellViewModel.fiatCurrency,
        (FiatCurrency currency) =>
            _onFiatCurrencyChange(currency, buySellViewModel, fiatCurrencyKey));

    reaction((_) => buySellViewModel.fiatAmount, (String amount) {
      if (fiatCurrencyKey.currentState!.amountController.text != amount ) {
        fiatCurrencyKey.currentState!.amountController.text = amount;
      }
    });

    reaction((_) => buySellViewModel.depositAddress, (String address) {
      if (cryptoCurrencyKey.currentState!.addressController.text != address) {
        cryptoCurrencyKey.currentState!.addressController.text = address;
      }
    });

    reaction((_) => buySellViewModel.cryptoAmount, (String amount) {
      if (cryptoCurrencyKey.currentState!.amountController.text != amount) {
        cryptoCurrencyKey.currentState!.amountController.text = amount;
      }
    });

    fiatAmountController.addListener(() {
      if (fiatAmountController.text != buySellViewModel.cryptoAmount) {
        _cryptoAmountDebounce.run(() {
          buySellViewModel.changeFiatAmount(amount: fiatAmountController.text);
          buySellViewModel.isCryptoAmountEntered = true;
        });
      }
    });

    _isReactionsSet = true;
  }

  void _onCryptoCurrencyChange(CryptoCurrency currency, BuySellViewModel buySellViewModel,
      GlobalKey<ExchangeCardState> key) {
    final isCurrentTypeWallet = currency == buySellViewModel.wallet.currency;

    key.currentState!.changeSelectedCurrency(currency);
    key.currentState!.changeWalletName(isCurrentTypeWallet ? buySellViewModel.wallet.name : '');

    key.currentState!.changeAddress(
        address: isCurrentTypeWallet ? buySellViewModel.wallet.walletAddresses.address : '');

    key.currentState!.changeAmount(amount: '');
  }

  void _onFiatCurrencyChange(
      FiatCurrency currency, BuySellViewModel buySellViewModel, GlobalKey<ExchangeCardState> key) {
    key.currentState!.changeSelectedCurrency(currency);
    key.currentState!.changeAmount(amount: '');
  }

  void _onWalletNameChange(ExchangeViewModel exchangeViewModel, CryptoCurrency currency,
      GlobalKey<ExchangeCardState> key) {
    final isCurrentTypeWallet = currency == exchangeViewModel.wallet.currency;

    if (isCurrentTypeWallet) {
      key.currentState!.changeWalletName(exchangeViewModel.wallet.name);
      key.currentState!.addressController.text = exchangeViewModel.wallet.walletAddresses.address;
    } else if (key.currentState!.addressController.text ==
        exchangeViewModel.wallet.walletAddresses.address) {
      key.currentState!.changeWalletName('');
      key.currentState!.addressController.text = '';
    }
  }

  Future<String> fetchParsedAddress(
      BuildContext context, String domain, CryptoCurrency currency) async {
    final parsedAddress = await getIt.get<AddressResolver>().resolve(context, domain, currency);
    final address = await extractAddressFromParsed(context, parsedAddress);
    return address;
  }

  void disposeBestRateSync() => {};

  Widget _exchangeCardsSection(BuildContext context) {
    final firstExchangeCard = Observer(
        builder: (_) => ExchangeCard(
              onDispose: disposeBestRateSync,
              hasAllAmount: false,
              isAllAmountEnabled: false,
              amountFocusNode: _fiatAmountFocus,
              addressFocusNode: _depositAddressFocus,
              key: fiatCurrencyKey,
              title: 'FIAT ${S.of(context).amount}',
              initialCurrency: buySellViewModel.fiatCurrency,
              initialWalletName: 'depositWalletName' ?? '',
              initialAddress: buySellViewModel.cryptoCurrency == buySellViewModel.wallet.currency
                  ? buySellViewModel.wallet.walletAddresses.address
                  : buySellViewModel.depositAddress,
              initialIsAmountEditable: true,
              initialIsAddressEditable: true,
              isAmountEstimated: false,
              hasRefundAddress: true,
              currencyRowPadding: EdgeInsets.zero,
              addressRowPadding: EdgeInsets.zero,
              isMoneroWallet: true,
              currencies: buySellViewModel.fiatCurrencies,
              onCurrencySelected: (currency) =>
                  buySellViewModel.changeFiatCurrency(currency: currency),
              imageArrow: arrowBottomPurple,
              currencyButtonColor: Colors.transparent,
              addressButtonsColor:
                  Theme.of(context).extension<SendPageTheme>()!.textFieldButtonColor,
              borderColor:
                  Theme.of(context).extension<ExchangePageTheme>()!.textFieldBorderTopPanelColor,
              currencyValueValidator: (value) {
                return null;
              },
              addressTextFieldValidator: AddressValidator(type: buySellViewModel.cryptoCurrency),
              onPushPasteButton: (context) async {},
              onPushAddressBookButton: (context) async {},
            ));

    final secondExchangeCard = Observer(
        builder: (_) => ExchangeCard(
              onDispose: disposeBestRateSync,
              amountFocusNode: _cryptoAmountFocus,
              addressFocusNode: _receiveAddressFocus,
              key: cryptoCurrencyKey,
              title: 'Crypto ${S.of(context).amount}',
              initialCurrency: buySellViewModel.cryptoCurrency,
              initialWalletName: 'receiveWalletName' ?? '',
              initialAddress: buySellViewModel.cryptoCurrency == buySellViewModel.wallet.currency
                  ? buySellViewModel.wallet.walletAddresses.address
                  : buySellViewModel.depositAddress,
              initialIsAmountEditable: true,
              isAmountEstimated: true,
              currencyRowPadding: EdgeInsets.zero,
              addressRowPadding: EdgeInsets.zero,
              isMoneroWallet: true,
              currencies: buySellViewModel.cryptoCurrencies,
              onCurrencySelected: (currency) =>
                  buySellViewModel.changeCryptoCurrency(currency: currency),
              imageArrow: arrowBottomCakeGreen,
              currencyButtonColor: Colors.transparent,
              addressButtonsColor:
                  Theme.of(context).extension<SendPageTheme>()!.textFieldButtonColor,
              borderColor:
                  Theme.of(context).extension<ExchangePageTheme>()!.textFieldBorderBottomPanelColor,
              currencyValueValidator: (value) {
                return null;
              },
              addressTextFieldValidator: AddressValidator(type: CryptoCurrency.xmr),
              onPushPasteButton: (context) async {},
              onPushAddressBookButton: (context) async {},
            ));

    if (responsiveLayoutUtil.shouldRenderMobileUI) {
      return MobileExchangeCardsSection(
        firstExchangeCard: firstExchangeCard,
        secondExchangeCard: secondExchangeCard,
        isBuySellOption: true,
      );
    }

    return DesktopExchangeCardsSection(
      firstExchangeCard: firstExchangeCard,
      secondExchangeCard: secondExchangeCard,
    );
  }
}
