import 'dart:io';

import 'package:cw_core/balance.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_ethereum/ethereum_wallet.dart';
import 'package:cw_ethereum/ethereum_wallet_creation_credentials.dart';
import 'package:ed25519_hd_key/ed25519_hd_key.dart';
import 'package:hive/hive.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:hex/hex.dart';

class EthereumWalletService extends WalletService<EthereumNewWalletCredentials,
    EthereumRestoreWalletFromSeedCredentials, EthereumRestoreWalletFromWIFCredentials> {
  EthereumWalletService(this.walletInfoSource);

  final Box<WalletInfo> walletInfoSource;

  @override
  Future<EthereumWallet> create(EthereumNewWalletCredentials credentials) async {
    final mnemonic = bip39.generateMnemonic();
    final privateKey = await getPrivateKey(mnemonic, credentials.password!);
    final wallet = EthereumWallet(
      walletInfo: credentials.walletInfo!,
      mnemonic: mnemonic,
      privateKey: privateKey,
      password: credentials.password!,
    );
    await wallet.save();

    return wallet;
  }

  @override
  WalletType getType() => WalletType.ethereum;

  @override
  Future<bool> isWalletExit(String name) async =>
      File(await pathForWallet(name: name, type: getType())).existsSync();

  @override
  Future<WalletBase<Balance, TransactionHistoryBase<TransactionInfo>, TransactionInfo>> openWallet(
      String name, String password) {
    // TODO: implement openWallet
    throw UnimplementedError();
  }

  @override
  Future<void> remove(String wallet) async =>
      File(await pathForWalletDir(name: wallet, type: getType())).delete(recursive: true);

  @override
  Future<WalletBase<Balance, TransactionHistoryBase<TransactionInfo>, TransactionInfo>>
      restoreFromKeys(credentials) {
    throw UnimplementedError();
  }

  @override
  Future<WalletBase<Balance, TransactionHistoryBase<TransactionInfo>, TransactionInfo>>
      restoreFromSeed(credentials) {
    // TODO: implement restoreFromSeed
    throw UnimplementedError();
  }

  Future<String> getPrivateKey(String mnemonic, String password) async {
    final seed = bip39.mnemonicToSeedHex(mnemonic);
    final master = await ED25519_HD_KEY.getMasterKeyFromSeed(HEX.decode(seed),
        masterSecret: password);
    final privateKey = HEX.encode(master.key);
    return privateKey;
  }
}
