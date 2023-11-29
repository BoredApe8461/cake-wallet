import 'package:bitcoin_flutter/bitcoin_flutter.dart' as bitcoin;
import 'package:cw_bitcoin/electrum.dart';
import 'package:cw_bitcoin/utils.dart';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_bitcoin/electrum_wallet_addresses.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';

part 'litecoin_wallet_addresses.g.dart';

class LitecoinWalletAddresses = LitecoinWalletAddressesBase
    with _$LitecoinWalletAddresses;

abstract class LitecoinWalletAddressesBase extends ElectrumWalletAddresses
    with Store {
  LitecoinWalletAddressesBase(
      WalletInfo walletInfo,
      {required bitcoin.HDWallet mainHd,
        required bitcoin.HDWallet sideHd,
        required bitcoin.NetworkType networkType,
        required ElectrumClient electrumClient,
        List<BitcoinAddressRecord>? initialAddresses,
        int initialRegularAddressIndex = 0,
        int initialChangeAddressIndex = 0})
      : super(
      walletInfo,
      initialAddresses: initialAddresses,
      initialRegularAddressIndex: initialRegularAddressIndex,
      initialChangeAddressIndex: initialChangeAddressIndex,
      mainHd: mainHd,
      sideHd: sideHd,
      electrumClient: electrumClient,
      networkType: networkType);

  @override
  String getAddress({required int index, required bitcoin.HDWallet hd, bitcoin.AddressType? addressType}) =>
      generateP2WPKHAddress(hd: hd, index: index, networkType: networkType);
}
