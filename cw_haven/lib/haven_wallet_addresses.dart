import 'package:cw_core/wallet_addresses_with_account.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_monero/account.dart';
import 'package:cw_haven/haven_account_list.dart';
import 'package:cw_haven/haven_subaddress_list.dart';
import 'package:cw_monero/subaddress.dart';
import 'package:mobx/mobx.dart';

part 'haven_wallet_addresses.g.dart';

class HavenWalletAddresses = HavenWalletAddressesBase
    with _$HavenWalletAddresses;

abstract class HavenWalletAddressesBase extends WalletAddressesWithAccount<Account> with Store {
  HavenWalletAddressesBase(WalletInfo walletInfo) : super(walletInfo) {
    accountList = HavenAccountList();
    subaddressList = HavenSubaddressList();
  }

  @override
  @observable
  String address;
  
  @override
  @observable
  Account account;

  @observable
  Subaddress subaddress;

  HavenSubaddressList subaddressList;
  
  HavenAccountList accountList;

  @override
  Future<void> init() async {
    accountList.update();
    account = accountList.accounts.first;
    updateSubaddressList(accountIndex: account.id ?? 0);
    await updateAddressesInBox();
  }

  @override
  Future<void> updateAddressesInBox() async {
    try {
      final _subaddressList = HavenSubaddressList();

      addressesMap.clear();

      accountList.accounts.forEach((account) {
        _subaddressList.update(accountIndex: account.id);
        _subaddressList.subaddresses.forEach((subaddress) {
          addressesMap[subaddress.address] = subaddress.label;
        });
      });

      await saveAddressesInBox();
    } catch (e) {
      print(e.toString());
    }
  }

  bool validate() {
    accountList.update();
    final accountListLength = accountList.accounts?.length ?? 0;

    if (accountListLength <= 0) {
      return false;
    }

    subaddressList.update(accountIndex: accountList.accounts.first.id);
    final subaddressListLength = subaddressList.subaddresses?.length ?? 0;

    if (subaddressListLength <= 0) {
      return false;
    }

    return true;
  }

  void updateSubaddressList({int accountIndex}) {
    subaddressList.update(accountIndex: accountIndex);
    subaddress = subaddressList.subaddresses.first;
    address = subaddress.address;
  }
}