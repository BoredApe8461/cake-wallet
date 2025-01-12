import 'dart:convert';

import 'package:bip39/bip39.dart' as bip39;
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_bitcoin/bitcoin_mnemonic.dart';
import 'package:cw_bitcoin/bitcoin_unspent.dart';
import 'package:cw_bitcoin/pending_bitcoin_transaction.dart';
import 'package:cw_bitcoin/psbt_finalizer_v0.dart';
import 'package:cw_bitcoin/psbt_signer.dart';
import 'package:cw_bitcoin/psbt_transaction_builder.dart';
import 'package:cw_bitcoin/psbt_v0_deserialize.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_bitcoin/bitcoin_transaction_credentials.dart';
import 'package:cw_bitcoin/bitcoin_wallet_addresses.dart';
import 'package:cw_bitcoin/electrum_balance.dart';
import 'package:cw_bitcoin/electrum_derivations.dart';
import 'package:cw_bitcoin/electrum_wallet.dart';
import 'package:cw_bitcoin/electrum_wallet_snapshot.dart';
import 'package:cw_bitcoin/exceptions.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_keys_file.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:ledger_bitcoin/ledger_bitcoin.dart';
import 'package:ledger_bitcoin/psbt.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';
import 'package:mobx/mobx.dart';

part 'bitcoin_wallet.g.dart';

class BitcoinWallet = BitcoinWalletBase with _$BitcoinWallet;

abstract class BitcoinWalletBase extends ElectrumWallet with Store {
  BitcoinWalletBase({
    required String password,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required EncryptionFileUtils encryptionFileUtils,
    Uint8List? seedBytes,
    String? mnemonic,
    String? xpub,
    String? addressPageType,
    BasedUtxoNetwork? networkParam,
    List<BitcoinAddressRecord>? initialAddresses,
    ElectrumBalance? initialBalance,
    Map<String, int>? initialRegularAddressIndex,
    Map<String, int>? initialChangeAddressIndex,
    String? passphrase,
    List<BitcoinSilentPaymentAddressRecord>? initialSilentAddresses,
    int initialSilentAddressIndex = 0,
    bool? alwaysScan,
  }) : super(
          mnemonic: mnemonic,
          passphrase: passphrase,
          xpub: xpub,
          password: password,
          walletInfo: walletInfo,
          unspentCoinsInfo: unspentCoinsInfo,
          network: networkParam == null
              ? BitcoinNetwork.mainnet
              : networkParam == BitcoinNetwork.mainnet
                  ? BitcoinNetwork.mainnet
                  : BitcoinNetwork.testnet,
          initialAddresses: initialAddresses,
          initialBalance: initialBalance,
          seedBytes: seedBytes,
          encryptionFileUtils: encryptionFileUtils,
          currency: networkParam == BitcoinNetwork.testnet
              ? CryptoCurrency.tbtc
              : CryptoCurrency.btc,
          alwaysScan: alwaysScan,
        ) {
    // in a standard BIP44 wallet, mainHd derivation path = m/84'/0'/0'/0 (account 0, index unspecified here)
    // the sideHd derivation path = m/84'/0'/0'/1 (account 1, index unspecified here)
    // String derivationPath = walletInfo.derivationInfo!.derivationPath!;
    // String sideDerivationPath = derivationPath.substring(0, derivationPath.length - 1) + "1";
    // final hd = bitcoin.HDWallet.fromSeed(seedBytes, network: networkType);
    walletAddresses = BitcoinWalletAddresses(
      walletInfo,
      initialAddresses: initialAddresses,
      initialRegularAddressIndex: initialRegularAddressIndex,
      initialChangeAddressIndex: initialChangeAddressIndex,
      initialSilentAddresses: initialSilentAddresses,
      initialSilentAddressIndex: initialSilentAddressIndex,
      mainHd: hd,
      sideHd: accountHD.childKey(Bip32KeyIndex(1)),
      network: networkParam ?? network,
      masterHd:
          seedBytes != null ? Bip32Slip10Secp256k1.fromSeed(seedBytes) : null,
      isHardwareWallet: walletInfo.isHardwareWallet,
    );

    autorun((_) {
      this.walletAddresses.isEnabledAutoGenerateSubaddress =
          this.isEnabledAutoGenerateSubaddress;
    });
  }

  static Future<BitcoinWallet> create({
    required String mnemonic,
    required String password,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required EncryptionFileUtils encryptionFileUtils,
    String? passphrase,
    String? addressPageType,
    BasedUtxoNetwork? network,
    List<BitcoinAddressRecord>? initialAddresses,
    List<BitcoinSilentPaymentAddressRecord>? initialSilentAddresses,
    ElectrumBalance? initialBalance,
    Map<String, int>? initialRegularAddressIndex,
    Map<String, int>? initialChangeAddressIndex,
    int initialSilentAddressIndex = 0,
  }) async {
    late Uint8List seedBytes;

    switch (walletInfo.derivationInfo?.derivationType) {
      case DerivationType.bip39:
        seedBytes = await bip39.mnemonicToSeed(
          mnemonic,
          passphrase: passphrase ?? "",
        );
        break;
      case DerivationType.electrum:
      default:
        seedBytes =
            await mnemonicToSeedBytes(mnemonic, passphrase: passphrase ?? "");
        break;
    }
    return BitcoinWallet(
      mnemonic: mnemonic,
      passphrase: passphrase ?? "",
      password: password,
      walletInfo: walletInfo,
      unspentCoinsInfo: unspentCoinsInfo,
      initialAddresses: initialAddresses,
      initialSilentAddresses: initialSilentAddresses,
      initialSilentAddressIndex: initialSilentAddressIndex,
      initialBalance: initialBalance,
      encryptionFileUtils: encryptionFileUtils,
      seedBytes: seedBytes,
      initialRegularAddressIndex: initialRegularAddressIndex,
      initialChangeAddressIndex: initialChangeAddressIndex,
      addressPageType: addressPageType,
      networkParam: network,
    );
  }

  static Future<BitcoinWallet> open({
    required String name,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required String password,
    required EncryptionFileUtils encryptionFileUtils,
    required bool alwaysScan,
  }) async {
    final network = walletInfo.network != null
        ? BasedUtxoNetwork.fromName(walletInfo.network!)
        : BitcoinNetwork.mainnet;

    final hasKeysFile = await WalletKeysFile.hasKeysFile(name, walletInfo.type);

    ElectrumWalletSnapshot? snp = null;

    try {
      snp = await ElectrumWalletSnapshot.load(
        encryptionFileUtils,
        name,
        walletInfo.type,
        password,
        network,
      );
    } catch (e) {
      if (!hasKeysFile) rethrow;
    }

    final WalletKeysData keysData;
    // Migrate wallet from the old scheme to then new .keys file scheme
    if (!hasKeysFile) {
      keysData = WalletKeysData(
        mnemonic: snp!.mnemonic,
        xPub: snp.xpub,
        passphrase: snp.passphrase,
      );
    } else {
      keysData = await WalletKeysFile.readKeysFile(
        name,
        walletInfo.type,
        password,
        encryptionFileUtils,
      );
    }

    walletInfo.derivationInfo ??= DerivationInfo();

    // set the default if not present:
    walletInfo.derivationInfo!.derivationPath ??=
        snp?.derivationPath ?? electrum_path;
    walletInfo.derivationInfo!.derivationType ??=
        snp?.derivationType ?? DerivationType.electrum;

    Uint8List? seedBytes = null;
    final mnemonic = keysData.mnemonic;
    final passphrase = keysData.passphrase;

    if (mnemonic != null) {
      switch (walletInfo.derivationInfo!.derivationType) {
        case DerivationType.electrum:
          seedBytes =
              await mnemonicToSeedBytes(mnemonic, passphrase: passphrase ?? "");
          break;
        case DerivationType.bip39:
        default:
          seedBytes = await bip39.mnemonicToSeed(
            mnemonic,
            passphrase: passphrase ?? '',
          );
          break;
      }
    }

    return BitcoinWallet(
      mnemonic: mnemonic,
      xpub: keysData.xPub,
      password: password,
      passphrase: passphrase,
      walletInfo: walletInfo,
      unspentCoinsInfo: unspentCoinsInfo,
      initialAddresses: snp?.addresses,
      initialSilentAddresses: snp?.silentAddresses,
      initialSilentAddressIndex: snp?.silentAddressIndex ?? 0,
      initialBalance: snp?.balance,
      encryptionFileUtils: encryptionFileUtils,
      seedBytes: seedBytes,
      initialRegularAddressIndex: snp?.regularAddressIndex,
      initialChangeAddressIndex: snp?.changeAddressIndex,
      addressPageType: snp?.addressPageType,
      networkParam: network,
      alwaysScan: alwaysScan,
    );
  }

  LedgerConnection? _ledgerConnection;
  BitcoinLedgerApp? _bitcoinLedgerApp;

  @override
  void setLedgerConnection(LedgerConnection connection) {
    _ledgerConnection = connection;
    _bitcoinLedgerApp = BitcoinLedgerApp(_ledgerConnection!,
        derivationPath: walletInfo.derivationInfo!.derivationPath!);
  }

  Future<PSBTTransactionBuild> buildPayjoinTransaction({
    required List<BitcoinBaseOutput> outputs,
    required BigInt fee,
    required BasedUtxoNetwork network,
    required List<UtxoWithAddress> utxos,
    required Map<String, PublicKeyWithDerivationPath> publicKeys,
    String? memo,
    bool enableRBF = false,
    BitcoinOrdering inputOrdering = BitcoinOrdering.bip69,
    BitcoinOrdering outputOrdering = BitcoinOrdering.bip69,
  }) async {
    final psbtReadyInputs = <PSBTReadyUtxoWithAddress>[];
    for (final UtxoWithAddress utxo in utxos) {
      debugPrint('[+] BITCOINWALLET => UTXO.utxo - ${utxo.utxo.toString()}');
      final rawTx =
      await electrumClient.getTransactionHex(hash: utxo.utxo.txHash);
      final publicKeyAndDerivationPath =
      publicKeys[utxo.ownerDetails.address.pubKeyHash()]!;

      psbtReadyInputs.add(PSBTReadyUtxoWithAddress(
        utxo: utxo.utxo,
        rawTx: rawTx,
        ownerDetails: utxo.ownerDetails,
        ownerDerivationPath: publicKeyAndDerivationPath.derivationPath,
        ownerMasterFingerprint: Uint8List(0),
        ownerPublicKey: publicKeyAndDerivationPath.publicKey,
      ));
    }

    final psbt = PSBTTransactionBuild(
        inputs: psbtReadyInputs, outputs: outputs, enableRBF: enableRBF);

    return psbt;
  }

  @override
  Future<BtcTransaction> buildHardwareWalletTransaction({
    required List<BitcoinBaseOutput> outputs,
    required BigInt fee,
    required BasedUtxoNetwork network,
    required List<UtxoWithAddress> utxos,
    required Map<String, PublicKeyWithDerivationPath> publicKeys,
    String? memo,
    bool enableRBF = false,
    BitcoinOrdering inputOrdering = BitcoinOrdering.bip69,
    BitcoinOrdering outputOrdering = BitcoinOrdering.bip69,
  }) async {
    final masterFingerprint = await _bitcoinLedgerApp!.getMasterFingerprint();

    final psbtReadyInputs = <PSBTReadyUtxoWithAddress>[];
    for (final utxo in utxos) {
      final rawTx =
          await electrumClient.getTransactionHex(hash: utxo.utxo.txHash);
      final publicKeyAndDerivationPath =
          publicKeys[utxo.ownerDetails.address.pubKeyHash()]!;

      psbtReadyInputs.add(PSBTReadyUtxoWithAddress(
        utxo: utxo.utxo,
        rawTx: rawTx,
        ownerDetails: utxo.ownerDetails,
        ownerDerivationPath: publicKeyAndDerivationPath.derivationPath,
        ownerMasterFingerprint: masterFingerprint,
        ownerPublicKey: publicKeyAndDerivationPath.publicKey,
      ));
    }

    final psbt = PSBTTransactionBuild(
        inputs: psbtReadyInputs, outputs: outputs, enableRBF: enableRBF);

    final rawHex = await _bitcoinLedgerApp!.signPsbt(psbt: psbt.psbt);
    return BtcTransaction.fromRaw(BytesUtils.toHexString(rawHex));
  }

  Future<PsbtV2> createPayjoinTransaction(BitcoinTransactionCredentials credentials) async {
    try {
      final outputs = <BitcoinOutput>[];
      final hasMultiDestination = credentials.outputs.length > 1;
      final sendAll =
          !hasMultiDestination && credentials.outputs.first.sendAll;
      final memo = credentials.outputs.first.memo;

      int credentialsAmount = 0;
      bool hasSilentPayment = false;

      for (final out in credentials.outputs) {
        final outputAmount = out.formattedCryptoAmount!;

        if (!sendAll && outputAmount <= 546) {
          throw BitcoinTransactionNoDustException();
        }

        if (hasMultiDestination) {
          if (out.sendAll) {
            throw BitcoinTransactionWrongBalanceException();
          }
        }

        credentialsAmount += outputAmount;

        final addressStr = out.isParsedAddress ? out.extractedAddress! : out.address;

        print('[+] ElectrumWallet || createTx => addressStr: $addressStr');

        final address = RegexUtils.addressTypeFromStr(addressStr, network);

        if (address is SilentPaymentAddress) {
          hasSilentPayment = true;
        }
        print('[+] ElectrumWallet => createTransaction() Running here');

        if (sendAll) {
          // The value will be changed after estimating the Tx size and deducting the fee from the total to be sent
          outputs.add(BitcoinOutput(address: address, value: BigInt.from(0)));
        } else {
          outputs.add(BitcoinOutput(
              address: address, value: BigInt.from(outputAmount)));
        }
      }

      final feeRateInt = credentials.feeRate != null
          ? credentials.feeRate!
          : feeRate(credentials.priority!);

      EstimatedTxResult estimatedTx;
      final updatedOutputs = outputs
          .map((e) => BitcoinOutput(
        address: e.address,
        value: e.value,
        isSilentPayment: e.isSilentPayment,
        isChange: e.isChange,
      ))
          .toList();
      if (sendAll) {
        estimatedTx = await estimateSendAllTx(
          outputs,
          feeRateInt,
          memo: memo,
          hasSilentPayment: hasSilentPayment,
        );
      } else {
        estimatedTx = await estimateTxForAmount(
          credentialsAmount,
          outputs,
          updatedOutputs,
          feeRateInt,
          memo: memo,
          hasSilentPayment: hasSilentPayment,
        );
      }

      final transaction = await buildPayjoinTransaction(
        utxos: estimatedTx.utxos,
        outputs: outputs,
        fee: BigInt.from(estimatedTx.fee),
        network: network,
        memo: estimatedTx.memo,
        outputOrdering: BitcoinOrdering.none,
        enableRBF: true,
        publicKeys: estimatedTx.publicKeys,
      );

      transaction.psbt.signWithUTXO(
          estimatedTx.utxos
              .map((e) =>
                  UtxoWithPrivateKey.fromUtxo(e, estimatedTx.inputPrivKeyInfos))
              .toList(), (txDigest, utxo, key, sighash) {
        if (utxo.utxo.isP2tr()) {
          return key.signTapRoot(
            txDigest,
            sighash: sighash,
            tweak: utxo.utxo.isSilentPayment != true,
          );
        } else {
          return key.signInput(txDigest, sigHash: sighash);
        }
      });

      return transaction.psbt;
    } catch (e, st) {
      print('[!] ElectrumWallet || e: $e and st: $st');
      throw e;
    }
  }

  Future<PendingBitcoinTransaction> psbtToPendingTx(String preProcessedPsbt, Object credentials) async {
    final unspent = unspentCoins.where((e) => (e.isSending || !e.isFrozen));

    List<UtxoWithPrivateKey> utxos = [];

    for (BitcoinUnspent input in unspent) {
      utxos.add(UtxoWithPrivateKey.fromUnspent(input, this));
    }

    final psbt = PsbtV2()..deserializeV0(base64.decode(preProcessedPsbt));

    final inputCount = psbt.getGlobalInputCount();

    final unsignedTx = [];
    for (var i = 0; i < inputCount; i++) {
      if (psbt.getInputFinalScriptsig(i) == null) {
        try {
          psbt.getInputFinalScriptwitness(i);
        } catch (_) {
          unsignedTx.add(BytesUtils.toHexString(psbt.getInputPreviousTxid(i).reversed.toList()));
        }
      }
    }

    psbt.signWithUTXO(utxos.where((e) => unsignedTx.contains(e.utxo.txHash)).toList(), (txDigest, utxo, key, sighash) {
      if (utxo.utxo.isP2tr()) {
        return key.signTapRoot(
          txDigest,
          sighash: sighash,
          tweak: utxo.utxo.isSilentPayment != true,
        );
      } else {
        return key.signInput(txDigest, sigHash: sighash);
      }
    });

    psbt.finalizeV0();

    final btcTx = BtcTransaction.fromRaw(BytesUtils.toHexString(psbt.extract()));

    return PendingBitcoinTransaction(
      btcTx,
      type,
      electrumClient: electrumClient,
      amount: psbt.getOutputAmount(0), // ToDo
      fee: 0,// ToDo
      feeRate: "Payjoin", // ToDo
      network: network,
      hasChange: true,
      isSendAll: true,
      hasTaprootInputs: false, // ToDo: (Konsti) Support Taproot
    )..addListener(
          (transaction) async {
        transactionHistory.addOne(transaction);
        await updateBalance();
      },
    );
  }

  Future<String> signPsbt(String preProcessedPsbt, List<UtxoWithPrivateKey> utxos) async {
    final psbt = PsbtV2()..deserializeV0(base64Decode(preProcessedPsbt));

    psbt.signWithUTXO(utxos,(txDigest, utxo, key, sighash) {
        return utxo.utxo.isP2tr() ? key.signTapRoot(
          txDigest,
          sighash: sighash,
          tweak: utxo.utxo.isSilentPayment != true,
        ) : key.signInput(txDigest, sigHash: sighash);
    });

    psbt.finalizeV0();
    return base64Encode(psbt.asPsbtV0());
  }

  @override
  Future<String> signMessage(String message, {String? address = null}) async {
    if (walletInfo.isHardwareWallet) {
      final addressEntry = address != null
          ? walletAddresses.allAddresses
              .firstWhere((element) => element.address == address)
          : null;
      final index = addressEntry?.index ?? 0;
      final isChange = addressEntry?.isHidden == true ? 1 : 0;
      final accountPath = walletInfo.derivationInfo?.derivationPath;
      final derivationPath =
          accountPath != null ? "$accountPath/$isChange/$index" : null;

      final signature = await _bitcoinLedgerApp!.signMessage(
          message: ascii.encode(message), signDerivationPath: derivationPath);
      return base64Encode(signature);
    }

    return super.signMessage(message, address: address);
  }
}
