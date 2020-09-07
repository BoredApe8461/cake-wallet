import 'package:cake_wallet/di.dart';
import 'package:cake_wallet/store/theme_changer_store.dart';
import 'package:cake_wallet/themes.dart';
import 'package:cake_wallet/view_model/settings/version_list_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:mobx/mobx.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/src/domain/common/balance_display_mode.dart';
import 'package:cake_wallet/src/domain/common/fiat_currency.dart';
import 'package:cake_wallet/src/domain/common/node.dart';
import 'package:cake_wallet/src/domain/common/transaction_priority.dart';
import 'package:cake_wallet/src/stores/action_list/action_list_display_mode.dart';
import 'package:cake_wallet/src/screens/auth/auth_page.dart';
import 'package:cake_wallet/view_model/settings/link_list_item.dart';
import 'package:cake_wallet/view_model/settings/picker_list_item.dart';
import 'package:cake_wallet/view_model/settings/regular_list_item.dart';
import 'package:cake_wallet/view_model/settings/settings_list_item.dart';
import 'package:cake_wallet/view_model/settings/switcher_list_item.dart';
import 'package:package_info/package_info.dart';

part 'settings_view_model.g.dart';

class SettingsViewModel = SettingsViewModelBase with _$SettingsViewModel;

abstract class SettingsViewModelBase with Store {
  SettingsViewModelBase(this._settingsStore) : itemHeaders = {} {
    currentVersion = '';
    PackageInfo.fromPlatform().then((PackageInfo packageInfo) => currentVersion = packageInfo.version);

    sections = [
      [
        PickerListItem(
            title: S.current.settings_display_balance_as,
            items: BalanceDisplayMode.all,
            setItem: (dynamic value) => balanceDisplayMode = value as BalanceDisplayMode,
            selectedItem: () => balanceDisplayMode),
        PickerListItem(
            title: S.current.settings_currency,
            items: FiatCurrency.all,
            setItem: (dynamic value) => fiatCurrency = value as FiatCurrency,
            isAlwaysShowScrollThumb: true,
            selectedItem: () => fiatCurrency),
        PickerListItem(
            title: S.current.settings_fee_priority,
            items: TransactionPriority.all,
            setItem: (dynamic value) => transactionPriority = value as TransactionPriority,
            isAlwaysShowScrollThumb: true,
            selectedItem: () => transactionPriority),
        SwitcherListItem(
            title: S.current.settings_save_recipient_address,
            value: () => shouldSaveRecipientAddress,
            onValueChange: (bool value) => shouldSaveRecipientAddress = value)
      ],
      [
        RegularListItem(
            title: S.current.settings_change_pin,
            handler: (BuildContext context) {
              Navigator.of(context).pushNamed(Routes.auth,
                  arguments: (bool isAuthenticatedSuccessfully,
                          AuthPageState auth) =>
                      isAuthenticatedSuccessfully
                          ? Navigator.of(context).popAndPushNamed(
                              Routes.setupPin,
                              arguments:
                                  (BuildContext setupPinContext, String _) =>
                                      Navigator.of(context).pop())
                          : null);
            }),
        RegularListItem(
          title: S.current.settings_change_language,
          handler: (BuildContext context) =>
              Navigator.of(context).pushNamed(Routes.changeLanguage),
        ),
        SwitcherListItem(
            title: S.current.settings_allow_biometrical_authentication,
            value: () => allowBiometricalAuthentication,
            onValueChange: (bool value) =>
                allowBiometricalAuthentication = value),
        SwitcherListItem(
            title: S.current.settings_dark_mode,
            value: () => _settingsStore.isDarkTheme,
            onValueChange: (bool value) {
              _settingsStore.isDarkTheme = value;
              getIt.get<ThemeChangerStore>().themeChanger.setTheme(
                  value ? Themes.darkTheme : Themes.lightTheme);
            })
      ],
      [
        LinkListItem(
            title: 'Email',
            linkTitle: 'support@cakewallet.com',
            link: 'mailto:support@cakewallet.com'),
        LinkListItem(
            title: 'Telegram',
            icon: 'assets/images/Telegram.png',
            linkTitle: 'Cake_Wallet',
            link: 'https:t.me/cakewallet_bot'),
        LinkListItem(
            title: 'Twitter',
            icon: 'assets/images/Twitter.png',
            linkTitle: '@CakeWalletXMR',
            link: 'https:twitter.com/CakewalletXMR'),
        LinkListItem(
            title: 'ChangeNow',
            icon: 'assets/images/change_now.png',
            linkTitle: 'support@changenow.io',
            link: 'mailto:support@changenow.io'),
        LinkListItem(
            title: 'Morph',
            icon: 'assets/images/morph_icon.png',
            linkTitle: 'support@morphtoken.com',
            link: 'mailto:support@morphtoken.com'),
        LinkListItem(
            title: 'XMR.to',
            icon: 'assets/images/xmr_btc.png',
            linkTitle: 'support@xmr.to',
            link: 'mailto:support@xmr.to'),
        RegularListItem(
          title: S.current.settings_terms_and_conditions,
          handler: (BuildContext context) =>
              Navigator.of(context).pushNamed(Routes.disclaimer),
        ),
        RegularListItem(
          title: S.current.faq,
          handler: (BuildContext context) =>
              Navigator.pushNamed(context, Routes.faq),
        )
      ],
      [
        VersionListItem(title: currentVersion)
      ]
    ];
  }

  @observable
  String currentVersion;

  @computed
  Node get node => _settingsStore.node;

  @computed
  FiatCurrency get fiatCurrency => _settingsStore.fiatCurrency;

  @computed
  ObservableList<ActionListDisplayMode> get actionlistDisplayMode =>
      _settingsStore.actionlistDisplayMode;

  @computed
  TransactionPriority get transactionPriority =>
      _settingsStore.transactionPriority;

  @computed
  BalanceDisplayMode get balanceDisplayMode =>
      _settingsStore.balanceDisplayMode;

  @computed
  bool get shouldSaveRecipientAddress =>
      _settingsStore.shouldSaveRecipientAddress;

  @action
  set shouldSaveRecipientAddress(bool value) =>
      _settingsStore.shouldSaveRecipientAddress = value;

  @computed
  bool get allowBiometricalAuthentication =>
      _settingsStore.allowBiometricalAuthentication;

  @action
  set allowBiometricalAuthentication(bool value) =>
      _settingsStore.allowBiometricalAuthentication = value;

  @action
  set balanceDisplayMode(BalanceDisplayMode value) =>
      _settingsStore.balanceDisplayMode = value;

  @action
  set fiatCurrency(FiatCurrency value) =>
      _settingsStore.fiatCurrency = value;

  @action
  set transactionPriority(TransactionPriority value) =>
      _settingsStore.transactionPriority = value;

//  @observable
//  bool isDarkTheme;
//
//  @observable
//  int defaultPinLength;

//  @observable
  final Map<String, String> itemHeaders;
  List<List<SettingsListItem>> sections;
  final SettingsStore _settingsStore;

  @action
  void toggleTransactionsDisplay() =>
      actionlistDisplayMode.contains(ActionListDisplayMode.transactions)
          ? _hideTransaction()
          : _showTransaction();

  @action
  void toggleTradesDisplay() =>
      actionlistDisplayMode.contains(ActionListDisplayMode.trades)
          ? _hideTrades()
          : _showTrades();

  @action
  void _hideTransaction() =>
      actionlistDisplayMode.remove(ActionListDisplayMode.transactions);

  @action
  void _hideTrades() =>
      actionlistDisplayMode.remove(ActionListDisplayMode.trades);

  @action
  void _showTransaction() =>
      actionlistDisplayMode.add(ActionListDisplayMode.transactions);

  @action
  void _showTrades() => actionlistDisplayMode.add(ActionListDisplayMode.trades);
}
