import 'dart:io';
import 'package:cw_core/node.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:hive/hive.dart';
import 'package:cw_bitcoin/bitcoin_mnemonic.dart';
import 'package:cw_bitcoin/bitcoin_mnemonic_is_incorrect_exception.dart';
import 'package:cw_bitcoin/bitcoin_wallet_creation_credentials.dart';
import 'package:cw_bitcoin/litecoin_wallet.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:collection/collection.dart';

class LitecoinWalletService extends WalletService<
    BitcoinNewWalletCredentials,
    BitcoinRestoreWalletFromSeedCredentials,
    BitcoinRestoreWalletFromWIFCredentials> {
  LitecoinWalletService(this.walletInfoSource, this.unspentCoinsInfoSource);

  final Box<WalletInfo> walletInfoSource;
  final Box<UnspentCoinsInfo> unspentCoinsInfoSource;

  @override
  WalletType getType() => WalletType.litecoin;

  @override
  Future<LitecoinWallet> create(BitcoinNewWalletCredentials credentials) async {
    final wallet = await LitecoinWalletBase.create(
        mnemonic: await generateMnemonic(),
        password: credentials.password!,
        walletInfo: credentials.walletInfo!,
        unspentCoinsInfo: unspentCoinsInfoSource);
    await wallet.save();
    await wallet.init();

    return wallet;
  }

  @override
  Future<bool> isWalletExit(String name) async =>
      File(await pathForWallet(name: name, type: getType())).existsSync();

  @override
  Future<LitecoinWallet> openWallet(String name, String password) async {
    final walletInfo = walletInfoSource.values.firstWhereOrNull(
        (info) => info.id == WalletBase.idFor(name, getType()))!;
    final wallet = await LitecoinWalletBase.open(
        password: password, name: name, walletInfo: walletInfo,
        unspentCoinsInfo: unspentCoinsInfoSource);
    await wallet.init();
    return wallet;
  }

  @override
  Future<void> remove(String wallet) async =>
      File(await pathForWalletDir(name: wallet, type: getType()))
          .delete(recursive: true);

  @override
  Future<LitecoinWallet> restoreFromKeys(
          BitcoinRestoreWalletFromWIFCredentials credentials) async =>
      throw UnimplementedError();

  @override
  Future<LitecoinWallet> restoreFromSeed(
      BitcoinRestoreWalletFromSeedCredentials credentials) async {
    if (!validateMnemonic(credentials.mnemonic)) {
      throw BitcoinMnemonicIsIncorrectException();
    }

    final wallet = await LitecoinWalletBase.create(
        password: credentials.password!,
        mnemonic: credentials.mnemonic,
        walletInfo: credentials.walletInfo!,
        unspentCoinsInfo: unspentCoinsInfoSource);
    await wallet.save();
    await wallet.init();
    return wallet;
  }

  @override
  Future<Map<String, dynamic>> sweepAllFunds(Node node, String address, String paymentId) {
    // TODO: implement sweepAllFunds
    throw UnimplementedError();
  }
}
