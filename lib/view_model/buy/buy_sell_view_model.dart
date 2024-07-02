import 'dart:async';

import 'package:cake_wallet/buy/buy_provider.dart';
import 'package:cake_wallet/buy/buy_quote.dart';
import 'package:cake_wallet/buy/payment_method.dart';
import 'package:cake_wallet/core/selectable_option.dart';
import 'package:cake_wallet/core/wallet_change_listener_view_model.dart';
import 'package:cake_wallet/entities/exchange_api_mode.dart';
import 'package:cake_wallet/entities/fiat_currency.dart';
import 'package:cake_wallet/entities/provider_types.dart';
import 'package:cake_wallet/exchange/exchange_trade_state.dart';
import 'package:cake_wallet/exchange/limits.dart';
import 'package:cake_wallet/exchange/limits_state.dart';
import 'package:cake_wallet/exchange/trade.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cake_wallet/store/dashboard/trades_store.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/store/templates/exchange_template_store.dart';
import 'package:cake_wallet/view_model/contact_list/contact_list_view_model.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'buy_sell_view_model.g.dart';

class BuySellViewModel = BuySellViewModelBase with _$BuySellViewModel;

abstract class BuySellViewModelBase extends WalletChangeListenerViewModel with Store {
  BuySellViewModelBase(
    AppStore appStore,
    this.trades,
    this._exchangeTemplateStore,
    this.tradesStore,
    this._settingsStore,
    this.sharedPreferences,
    this.contactListViewModel,
  )   : _cryptoNumberFormat = NumberFormat(),
        isSendAllEnabled = false,
        isCryptoAmountEntered = false,
        cryptoAmount = '',
        fiatAmount = '',
        receiveAddress = '',
        depositAddress = '',
        isDepositAddressEnabled = false,
        isReceiveAmountEditable = false,
        _useTorOnly = false,
        cryptoCurrencies = <CryptoCurrency>[],
        fiatCurrencies = <FiatCurrency>[],
        limits = Limits(min: 0, max: 0),
        tradeState = ExchangeTradeStateInitial(),
        limitsState = LimitsInitialState(),
        cryptoCurrency = appStore.wallet!.currency,
        fiatCurrency = _settingsStore.fiatCurrency,
        providerList = [],
        sortedAvailableQuotes = ObservableList<Quote>(),
        paymentMethods = ObservableList<PaymentMethod>(),
        super(appStore: appStore) {
    _useTorOnly = _settingsStore.exchangeStatus == ExchangeApiMode.torOnly;

    const excludeFiatCurrencies = [];
    const excludeCryptoCurrencies = [
      CryptoCurrency.xlm,
      CryptoCurrency.xrp,
      CryptoCurrency.bnb,
      CryptoCurrency.btt
    ];

    fiatCurrencies =
        FiatCurrency.all.where((currency) => !excludeFiatCurrencies.contains(currency)).toList();
    cryptoCurrencies = CryptoCurrency.all
        .where((currency) => !excludeCryptoCurrencies.contains(currency))
        .toList();
    _initialize();
  }

  @observable
  List<CryptoCurrency> cryptoCurrencies;

  @observable
  List<FiatCurrency> fiatCurrencies;

  final NumberFormat _cryptoNumberFormat;
  final SettingsStore _settingsStore;
  final ContactListViewModel contactListViewModel;
  late Timer bestRateSync;
  bool _useTorOnly;
  final Box<Trade> trades;
  final ExchangeTemplateStore _exchangeTemplateStore;
  final TradesStore tradesStore;
  final SharedPreferences sharedPreferences;

  List<BuyProvider> get availableBuyProviders {
    final providerTypes = ProvidersHelper.getAvailableBuyProviderTypes(wallet.type);
    return providerTypes
        .map((type) => ProvidersHelper.getProviderByType(type))
        .where((provider) => provider != null)
        .cast<BuyProvider>()
        .toList();
  }

  List<BuyProvider> get availableSellProviders {
    final providerTypes = ProvidersHelper.getAvailableSellProviderTypes(wallet.type);
    return providerTypes
        .map((type) => ProvidersHelper.getProviderByType(type))
        .where((provider) => provider != null)
        .cast<BuyProvider>()
        .toList();
  }

  @observable
  bool isBuyAction = true;

  @observable
  List<BuyProvider> providerList;

  @observable
  ObservableList<Quote> sortedAvailableQuotes;

  @observable
  ObservableList<PaymentMethod> paymentMethods;

  @observable
  FiatCurrency fiatCurrency;

  @observable
  CryptoCurrency cryptoCurrency;

  @observable
  LimitsState limitsState;

  @observable
  ExchangeTradeState tradeState;

  @observable
  String cryptoAmount;

  @observable
  String  fiatAmount;

  @observable
  String depositAddress;

  @observable
  String receiveAddress;

  @observable
  bool isDepositAddressEnabled;

  @observable
  bool isCryptoAmountEntered;

  @observable
  bool isReceiveAmountEditable;

  @observable
  bool isSendAllEnabled;

  @observable
  Limits limits;

  @observable
  Quote? bestRateQuote;

  @observable
  Quote? selectedQuote;

  @observable
  PaymentMethod? selectedPaymentMethod;

  @override
  void onWalletChange(wallet) {
    cryptoCurrency = wallet.currency;
  }

  @action
  void changeFiatCurrency({required FiatCurrency currency}) {
    fiatCurrency = currency;
    _onPairChange();
  }

  @action
  void changeCryptoCurrency({required CryptoCurrency currency}) {
    cryptoCurrency = currency;
    _onPairChange();
  }

  @action
  Future<void> changeFiatAmount({required String amount}) async {
    fiatAmount = amount;

    if (amount.isEmpty) {
      fiatAmount = '';
      cryptoAmount = '';
      return;
    }

    final _enteredAmount = double.tryParse(amount.replaceAll(',', '.')) ?? 0;

    /// in case the best rate was not calculated yet
    if (bestRateQuote == null) {
      cryptoAmount = S.current.fetching;

      await _calculateBestRate();
    }
    _cryptoNumberFormat.maximumFractionDigits = cryptoCurrency.decimals;

    cryptoAmount = _cryptoNumberFormat
        .format(_enteredAmount / bestRateQuote!.rate)
        .toString()
        .replaceAll(RegExp('\\,'), '');
  }

  @action
  void changeOption(SelectableOption option) {
    if (option is Quote) {
      sortedAvailableQuotes.forEach((element) => element.isSelected = false);
      option.isSelected = true;
      selectedQuote = option;
    } else if (option is PaymentMethod) {
      paymentMethods.forEach((element) => element.isSelected = false);
      option.isSelected = true;
      selectedPaymentMethod = option;
      _calculateBestRate();
    } else {
      throw ArgumentError('Unknown option type');
    }
  }

  void _onPairChange() {
    cryptoAmount = '';
    fiatAmount = '';
    _initialize();
  }

  void _setProviders() {
    providerList = isBuyAction ? availableBuyProviders : availableSellProviders;
  }

  Future<void> _initialize() async {
    _setProviders();
    await _getAvailablePaymentTypes();
    if (selectedPaymentMethod != null) {
      await _calculateBestRate();
    }
  }

  @action
  Future<void> _calculateBestRate() async {
    final amount = double.tryParse(isBuyAction ? fiatAmount : cryptoAmount) ?? 100;
    final result = await Future.wait<Quote?>(providerList.map((element) => element.fetchQuote(
          sourceCurrency: isBuyAction ? fiatCurrency.title : cryptoCurrency.title,
          destinationCurrency: isBuyAction ? cryptoCurrency.title : fiatCurrency.title,
          amount: amount.toInt(),
          paymentType: selectedPaymentMethod!.paymentMethodType!,
          type: isBuyAction ? 'buy' : 'sell',
          walletAddress: wallet.walletAddresses.address,
        )));

    final validQuotes = result.where((quote) => quote != null).cast<Quote>().toList();
    if (validQuotes.isEmpty) return;
    validQuotes.sort((a, b) => a.rate.compareTo(b.rate));
    validQuotes.first
      ..isBestRate = true
      ..isSelected = true;
    sortedAvailableQuotes
      ..clear()
      ..addAll(validQuotes);
    bestRateQuote = validQuotes.first;
    selectedQuote = validQuotes.first;
  }

  Future<void> _getAvailablePaymentTypes() async {
    final result = await Future.wait(providerList.map((element) =>
        element.getAvailablePaymentTypes(fiatCurrency.title, isBuyAction ? 'buy' : 'sell')));

    final Map<PaymentType, PaymentMethod> uniquePaymentMethods = {};
    for (var methods in result) {
      for (var method in methods) {
        uniquePaymentMethods[method.paymentMethodType] = method;
      }
    }

    paymentMethods = ObservableList<PaymentMethod>.of(uniquePaymentMethods.values);
    if (paymentMethods.isNotEmpty) {
      selectedPaymentMethod = paymentMethods.first;
      selectedPaymentMethod!.isSelected = true;
    }
  }
}
