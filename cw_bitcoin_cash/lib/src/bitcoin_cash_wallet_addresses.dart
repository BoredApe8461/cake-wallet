import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:cw_bitcoin/electrum_wallet_addresses.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:mobx/mobx.dart';

part 'bitcoin_cash_wallet_addresses.g.dart';

class BitcoinCashWalletAddresses = BitcoinCashWalletAddressesBase with _$BitcoinCashWalletAddresses;

abstract class BitcoinCashWalletAddressesBase extends ElectrumWalletAddresses with Store {
  BitcoinCashWalletAddressesBase(
    WalletInfo walletInfo, {
    required super.bip32,
    required super.network,
    required super.isHardwareWallet,
    super.initialAddresses,
    super.initialRegularAddressIndex,
    super.initialChangeAddressIndex,
    super.initialAddressPageType,
  }) : super(walletInfo);

  @override
  BitcoinBaseAddress generateAddress({
    required int account,
    required int index,
    required Bip32Slip10Secp256k1 hd,
    required BitcoinAddressType addressType,
  }) =>
      P2pkhAddress.fromBip32(account: account, bip32: hd, index: index);
}
