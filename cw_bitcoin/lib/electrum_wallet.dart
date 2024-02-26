import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:bitcoin_flutter/bitcoin_flutter.dart' as bitcoin;
import 'package:bitcoin_base/bitcoin_base.dart' as bitcoin_base;
import 'package:collection/collection.dart';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_bitcoin/bitcoin_transaction_credentials.dart';
import 'package:cw_bitcoin/bitcoin_transaction_no_inputs_exception.dart';
import 'package:cw_bitcoin/bitcoin_transaction_priority.dart';
import 'package:cw_bitcoin/bitcoin_transaction_wrong_balance_exception.dart';
import 'package:cw_bitcoin/bitcoin_unspent.dart';
import 'package:cw_bitcoin/bitcoin_wallet_keys.dart';
import 'package:cw_bitcoin/electrum.dart';
import 'package:cw_bitcoin/electrum_balance.dart';
import 'package:cw_bitcoin/electrum_transaction_history.dart';
import 'package:cw_bitcoin/electrum_transaction_info.dart';
import 'package:cw_bitcoin/electrum_wallet_addresses.dart';
import 'package:cw_bitcoin/litecoin_network.dart';
import 'package:cw_bitcoin/pending_bitcoin_transaction.dart';
import 'package:cw_bitcoin/script_hash.dart';
import 'package:cw_bitcoin/utils.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cw_core/utils/file.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:flutter/foundation.dart';
import 'package:hex/hex.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:rxdart/subjects.dart';
import 'package:http/http.dart' as http;

part 'electrum_wallet.g.dart';

class ElectrumWallet = ElectrumWalletBase with _$ElectrumWallet;

abstract class ElectrumWalletBase
    extends WalletBase<ElectrumBalance, ElectrumTransactionHistory, ElectrumTransactionInfo>
    with Store {
  ElectrumWalletBase(
      {required String password,
      required WalletInfo walletInfo,
      required Box<UnspentCoinsInfo> unspentCoinsInfo,
      required this.networkType,
      required this.mnemonic,
      required Uint8List seedBytes,
      List<BitcoinAddressRecord>? initialAddresses,
      ElectrumClient? electrumClient,
      ElectrumBalance? initialBalance,
      CryptoCurrency? currency})
      : hd = currency == CryptoCurrency.bch
            ? bitcoinCashHDWallet(seedBytes)
            : bitcoin.HDWallet.fromSeed(seedBytes, network: networkType).derivePath("m/0'/0"),
        syncStatus = NotConnectedSyncStatus(),
        _password = password,
        _feeRates = <int>[],
        _isTransactionUpdating = false,
        isEnabledAutoGenerateSubaddress = true,
        unspentCoins = [],
        _scripthashesUpdateSubject = {},
        balance = ObservableMap<CryptoCurrency, ElectrumBalance>.of(currency != null
            ? {
                currency:
                    initialBalance ?? const ElectrumBalance(confirmed: 0, unconfirmed: 0, frozen: 0)
              }
            : {}),
        this.unspentCoinsInfo = unspentCoinsInfo,
        this.network = networkType == bitcoin.bitcoin
            ? BitcoinNetwork.mainnet
            : networkType == litecoinNetwork
                ? LitecoinNetwork.mainnet
                : BitcoinNetwork.testnet,
        this.isTestnet = networkType == bitcoin.testnet,
        super(walletInfo) {
    this.electrumClient = electrumClient ?? ElectrumClient();
    this.walletInfo = walletInfo;
    transactionHistory = ElectrumTransactionHistory(walletInfo: walletInfo, password: password);
  }

  static bitcoin.HDWallet bitcoinCashHDWallet(Uint8List seedBytes) =>
      bitcoin.HDWallet.fromSeed(seedBytes).derivePath("m/44'/145'/0'/0");

  static int estimatedTransactionSize(int inputsCount, int outputsCounts) =>
      inputsCount * 68 + outputsCounts * 34 + 10;

  final bitcoin.HDWallet hd;
  final String mnemonic;

  @override
  @observable
  bool isEnabledAutoGenerateSubaddress;

  late ElectrumClient electrumClient;
  Box<UnspentCoinsInfo> unspentCoinsInfo;

  @override
  late ElectrumWalletAddresses walletAddresses;

  @override
  @observable
  late ObservableMap<CryptoCurrency, ElectrumBalance> balance;

  @override
  @observable
  SyncStatus syncStatus;

  List<String> get scriptHashes => walletAddresses.addressesByReceiveType
      .map((addr) => scriptHash(addr.address, network: network))
      .toList();

  List<String> get publicScriptHashes => walletAddresses.allAddresses
      .where((addr) => !addr.isHidden)
      .map((addr) => scriptHash(addr.address, network: network))
      .toList();

  String get xpub => hd.base58!;

  @override
  String get seed => mnemonic;

  bitcoin.NetworkType networkType;
  BasedUtxoNetwork network;

  @override
  bool? isTestnet;

  @override
  BitcoinWalletKeys get keys =>
      BitcoinWalletKeys(wif: hd.wif!, privateKey: hd.privKey!, publicKey: hd.pubKey!);

  String _password;
  List<BitcoinUnspent> unspentCoins;
  List<int> _feeRates;
  Map<String, BehaviorSubject<Object>?> _scripthashesUpdateSubject;
  BehaviorSubject<Object>? _chainTipUpdateSubject;
  bool _isTransactionUpdating;
  // Future<Isolate>? _isolate;

  void Function(FlutterErrorDetails)? _onError;
  Timer? _autoSaveTimer;
  static const int _autoSaveInterval = 30;

  Future<void> init() async {
    await walletAddresses.init();
    await transactionHistory.init();

    _autoSaveTimer =
        Timer.periodic(Duration(seconds: _autoSaveInterval), (_) async => await save());
  }

  // @action
  // Future<void> _setListeners(int height, {int? chainTip}) async {
  //   final currentChainTip = chainTip ?? await electrumClient.getCurrentBlockChainTip() ?? 0;
  //   syncStatus = AttemptingSyncStatus();

  //   if (_isolate != null) {
  //     final runningIsolate = await _isolate!;
  //     runningIsolate.kill(priority: Isolate.immediate);
  //   }

  //   final receivePort = ReceivePort();
  //   _isolate = Isolate.spawn(
  //       startRefresh,
  //       ScanData(
  //         sendPort: receivePort.sendPort,
  //         primarySilentAddress: walletAddresses.primarySilentAddress!,
  //         networkType: networkType,
  //         height: height,
  //         chainTip: currentChainTip,
  //         electrumClient: ElectrumClient(),
  //         transactionHistoryIds: transactionHistory.transactions.keys.toList(),
  //         node: electrumClient.uri.toString(),
  //         labels: walletAddresses.labels,
  //       ));

  //   await for (var message in receivePort) {
  //     if (message is BitcoinUnspent) {
  //       if (!unspentCoins.any((utx) =>
  //           utx.hash.contains(message.hash) &&
  //           utx.vout == message.vout &&
  //           utx.address.contains(message.address))) {
  //         unspentCoins.add(message);

  //         if (unspentCoinsInfo.values.any((element) =>
  //             element.walletId.contains(id) &&
  //             element.hash.contains(message.hash) &&
  //             element.address.contains(message.address))) {
  //           _addCoinInfo(message);

  //           await walletInfo.save();
  //           await save();
  //         }

  //         balance[currency] = await _fetchBalances();
  //       }
  //     }

  //     if (message is Map<String, ElectrumTransactionInfo>) {
  //       transactionHistory.addMany(message);
  //       await transactionHistory.save();
  //     }

  //     // check if is a SyncStatus type since "is SyncStatus" doesn't work here
  //     if (message is SyncResponse) {
  //       syncStatus = message.syncStatus;
  //       walletInfo.restoreHeight = message.height;
  //       await walletInfo.save();
  //     }
  //   }
  // }

  @action
  @override
  Future<void> startSync() async {
    try {
      await _setInitialHeight();
    } catch (_) {}

    try {
      rescan(height: walletInfo.restoreHeight);

      await updateTransactions();
      _subscribeForUpdates();
      await updateUnspent();
      await updateBalance();
      _feeRates = await electrumClient.feeRates(network: network);

      Timer.periodic(
          const Duration(minutes: 1), (timer) async => _feeRates = await electrumClient.feeRates());

      syncStatus = SyncedSyncStatus();
    } catch (e, stacktrace) {
      print(stacktrace);
      print(e.toString());
      syncStatus = FailedSyncStatus();
    }
  }

  @action
  @override
  Future<void> connectToNode({required Node node}) async {
    try {
      syncStatus = ConnectingSyncStatus();
      await electrumClient.connectToUri(node.uri);
      electrumClient.onConnectionStatusChange = (bool isConnected) {
        if (!isConnected) {
          syncStatus = LostConnectionSyncStatus();
        }
      };
      syncStatus = ConnectedSyncStatus();

      // final currentChainTip = await electrumClient.getCurrentBlockChainTip();

      // if ((currentChainTip ?? 0) > walletInfo.restoreHeight) {
      //   _setListeners(walletInfo.restoreHeight, chainTip: currentChainTip);
      // }
    } catch (e) {
      print(e.toString());
      syncStatus = FailedSyncStatus();
    }
  }

  Future<EstimatedTxResult> _estimateTxFeeAndInputsToUse(
      int credentialsAmount,
      bool sendAll,
      List<BitcoinBaseAddress> outputAddresses,
      List<BitcoinOutput> outputs,
      BitcoinTransactionCredentials transactionCredentials,
      {int? inputsCount}) async {
    final utxos = <UtxoWithAddress>[];
    List<ECPrivate> privateKeys = [];

    var leftAmount = credentialsAmount;
    var allInputsAmount = 0;

    for (int i = 0; i < unspentCoins.length; i++) {
      final utx = unspentCoins[i];

      if (utx.isSending) {
        allInputsAmount += utx.value;
        leftAmount = leftAmount - utx.value;

        if (utx.bitcoinAddressRecord.silentPaymentTweak != null) {
          // final d = ECPrivate.fromHex(walletAddresses.primarySilentAddress!.spendPrivkey.toHex())
          //     .tweakAdd(utx.bitcoinAddressRecord.silentPaymentTweak!)!;

          // inputPrivKeys.add(bitcoin.PrivateKeyInfo(d, true));
          // address = bitcoin.P2trAddress(address: utx.address, networkType: networkType);
          // keyPairs.add(bitcoin.ECPair.fromPrivateKey(d.toCompressedHex().fromHex,
          //     compressed: true, network: networkType));
          // scriptType = bitcoin.AddressType.p2tr;
          // script = bitcoin.P2trAddress(pubkey: d.publicKey.toHex(), networkType: networkType)
          //     .scriptPubkey
          //     .toBytes();
        }

        final address = _addressTypeFromStr(utx.address, network);
        final privkey = generateECPrivate(
            hd: utx.bitcoinAddressRecord.isHidden ? walletAddresses.sideHd : walletAddresses.mainHd,
            index: utx.bitcoinAddressRecord.index,
            network: network);

        privateKeys.add(privkey);

        utxos.add(
          UtxoWithAddress(
            utxo: BitcoinUtxo(
              txHash: utx.hash,
              value: BigInt.from(utx.value),
              vout: utx.vout,
              scriptType: _getScriptType(address),
            ),
            ownerDetails:
                UtxoAddressDetails(publicKey: privkey.getPublic().toHex(), address: address),
          ),
        );

        bool amountIsAcquired = !sendAll && leftAmount <= 0;
        if ((inputsCount == null && amountIsAcquired) || inputsCount == i + 1) {
          break;
        }
      }
    }

    if (inputs.isEmpty) {
      throw BitcoinTransactionNoInputsException();
    }

    final allAmountFee = transactionCredentials.feeRate != null
        ? feeAmountWithFeeRate(transactionCredentials.feeRate!, inputs.length, outputs.length)
        : feeAmountForPriority(transactionCredentials.priority!, inputs.length, outputs.length);

    final allAmount = allInputsAmount - allAmountFee;

    var credentialsAmount = 0;
    var amount = 0;
    var fee = 0;

    if (hasMultiDestination) {
      if (outputs.any((item) => item.sendAll || item.formattedCryptoAmount! <= 0)) {
        throw BitcoinTransactionWrongBalanceException(currency);
      }

      credentialsAmount = outputs.fold(0, (acc, value) => acc + value.formattedCryptoAmount!);

      if (allAmount - credentialsAmount < minAmount) {
        throw BitcoinTransactionWrongBalanceException(currency);
      }

      amount = credentialsAmount;

      if (transactionCredentials.feeRate != null) {
        fee = calculateEstimatedFeeWithFeeRate(transactionCredentials.feeRate!, amount,
            outputsCount: outputs.length + 1);
      } else {
        fee = calculateEstimatedFee(transactionCredentials.priority, amount,
            outputsCount: outputs.length + 1);
      }
    } else {
      final output = outputs.first;
      credentialsAmount = !output.sendAll ? output.formattedCryptoAmount! : 0;

      if (credentialsAmount > allAmount) {
        throw BitcoinTransactionWrongBalanceException(currency);
      }

      amount = output.sendAll || allAmount - credentialsAmount < minAmount
          ? allAmount
          : credentialsAmount;

      if (output.sendAll || amount == allAmount) {
        fee = allAmountFee;
      } else if (transactionCredentials.feeRate != null) {
        fee = calculateEstimatedFeeWithFeeRate(transactionCredentials.feeRate!, amount);
      } else {
        fee = calculateEstimatedFee(transactionCredentials.priority, amount);
      }
    }

    if (fee == 0) {
      throw BitcoinTransactionWrongBalanceException(currency);
    }

    final totalAmount = amount + fee;

    if (totalAmount > balance[currency]!.confirmed || totalAmount > allInputsAmount) {
      throw BitcoinTransactionWrongBalanceException(currency);
    }

    final txb = bitcoin.TransactionBuilder(network: networkType);
    final changeAddress = await walletAddresses.getChangeAddress();
    var leftAmount = totalAmount;
    var totalInputAmount = 0;

    inputs.clear();

    for (final utx in unspentCoins) {
      if (utx.isSending) {
        leftAmount = leftAmount - utx.value;

        final address = _addressTypeFromStr(utx.address, network);
        final privkey = generateECPrivate(
            hd: utx.bitcoinAddressRecord.isHidden ? walletAddresses.sideHd : walletAddresses.mainHd,
            index: utx.bitcoinAddressRecord.index,
            network: network);

        privateKeys.add(privkey);

        utxos.add(
          UtxoWithAddress(
            utxo: BitcoinUtxo(
              txHash: utx.hash,
              value: BigInt.from(utx.value),
              vout: utx.vout,
              scriptType: _getScriptType(address),
            ),
            ownerDetails:
                UtxoAddressDetails(publicKey: privkey.getPublic().toHex(), address: address),
          ),
        );

        bool amountIsAcquired = !sendAll && leftAmount <= 0;
        if ((inputsCount == null && amountIsAcquired) || inputsCount == i + 1) {
          break;
        }
      }
    }

    if (utxos.isEmpty) {
      throw BitcoinTransactionNoInputsException();
    }

    var changeValue = allInputsAmount - credentialsAmount;

    if (!sendAll) {
      if (changeValue > 0) {
        final changeAddress = await walletAddresses.getChangeAddress();
        final address = _addressTypeFromStr(changeAddress, network);
        outputAddresses.add(address);
        outputs.add(BitcoinOutput(address: address, value: BigInt.from(changeValue)));
      }
    }

    final estimatedSize = BitcoinTransactionBuilder.estimateTransactionSize(
        utxos: utxos, outputs: outputs, network: network);

    final fee = transactionCredentials.feeRate != null
        ? feeAmountWithFeeRate(transactionCredentials.feeRate!, 0, 0, size: estimatedSize)
        : feeAmountForPriority(transactionCredentials.priority!, 0, 0, size: estimatedSize);

    if (fee == 0) {
      throw BitcoinTransactionWrongBalanceException(currency);
    }

    var amount = credentialsAmount;

    final lastOutput = outputs.last;
    if (!sendAll) {
      if (changeValue > fee) {
        // Here, lastOutput is change, deduct the fee from it
        outputs[outputs.length - 1] =
            BitcoinOutput(address: lastOutput.address, value: lastOutput.value - BigInt.from(fee));
      }
    } else {
      // Here, if sendAll, the output amount equals to the input value - fee to fully spend every input on the transaction and have no amount for change
      amount = allInputsAmount - fee;
      outputs[outputs.length - 1] =
          BitcoinOutput(address: lastOutput.address, value: BigInt.from(amount));
    }

    final totalAmount = amount + fee;

    if (totalAmount > balance[currency]!.confirmed) {
      throw BitcoinTransactionWrongBalanceException(currency);
    }

    if (totalAmount > allInputsAmount) {
      if (unspentCoins.where((utx) => utx.isSending).length == utxos.length) {
        throw BitcoinTransactionWrongBalanceException(currency);
      } else {
        if (changeValue > fee) {
          outputAddresses.removeLast();
          outputs.removeLast();
        }

        return _estimateTxFeeAndInputsToUse(
            credentialsAmount, sendAll, outputAddresses, outputs, transactionCredentials,
            inputsCount: utxos.length + 1);
      }
    }

        if (SilentPaymentAddress.regex.hasMatch(outputAddress)) {
          // final outpointsHash = SilentPayment.hashOutpoints(outpoints);
          // final generatedOutputs = SilentPayment.generateMultipleRecipientPubkeys(inputPrivKeys,
          //     outpointsHash, SilentPaymentDestination.fromAddress(outputAddress, outputAmount!));

          // generatedOutputs.forEach((recipientSilentAddress, generatedOutput) {
          //   generatedOutput.forEach((output) {
          //     outputs.add(BitcoinOutputDetails(
          //       address: P2trAddress(
          //           program: ECPublic.fromHex(output.$1.toHex()).toTapPoint(),
          //           networkType: networkType),
          //       value: BigInt.from(output.$2),
          //     ));
          //   });
          // });
        }

        outputAddresses.add(address);

        if (hasMultiDestination) {
          if (out.sendAll || out.formattedCryptoAmount! <= 0) {
            throw BitcoinTransactionWrongBalanceException(currency);
          }

          final outputAmount = out.formattedCryptoAmount!;
          credentialsAmount += outputAmount;

          outputs.add(BitcoinOutput(address: address, value: BigInt.from(outputAmount)));
        } else {
          if (!sendAll) {
            final outputAmount = out.formattedCryptoAmount!;
            credentialsAmount += outputAmount;
            outputs.add(BitcoinOutput(address: address, value: BigInt.from(outputAmount)));
          } else {
            // The value will be changed after estimating the Tx size and deducting the fee from the total
            outputs.add(BitcoinOutput(address: address, value: BigInt.from(0)));
          }
        }
      }

      final estimatedTx = await _estimateTxFeeAndInputsToUse(
          credentialsAmount, sendAll, outputAddresses, outputs, transactionCredentials);

      final txb = BitcoinTransactionBuilder(
          utxos: estimatedTx.utxos,
          outputs: outputs,
          fee: BigInt.from(estimatedTx.fee),
          network: network);

      final transaction = txb.buildTransaction((txDigest, utxo, publicKey, sighash) {
        final key = estimatedTx.privateKeys
            .firstWhereOrNull((element) => element.getPublic().toHex() == publicKey);

        if (key == null) {
          throw Exception("Cannot find private key");
        }

        if (utxo.utxo.isP2tr()) {
          return key.signTapRoot(txDigest, sighash: sighash);
        } else {
          return key.signInput(txDigest, sigHash: sighash);
        }
      });

      return PendingBitcoinTransaction(transaction, type,
          electrumClient: electrumClient,
          amount: estimatedTx.amount,
          fee: estimatedTx.fee,
          network: network)
        ..addListener((transaction) async {
          transactionHistory.addOne(transaction);
          await updateBalance();
        });
    } catch (e) {
      throw e;
    }
  }

  String toJSON() => json.encode({
        'mnemonic': mnemonic,
        'account_index': walletAddresses.currentReceiveAddressIndexByType,
        'change_address_index': walletAddresses.currentChangeAddressIndexByType,
        'addresses': walletAddresses.allAddresses.map((addr) => addr.toJSON()).toList(),
        'address_page_type': walletInfo.addressPageType == null
            ? SegwitAddresType.p2wpkh.toString()
            : walletInfo.addressPageType.toString(),
        'balance': balance[currency]?.toJSON(),
        'silent_addresses': walletAddresses.silentAddresses.map((addr) => addr.toJSON()).toList(),
        'silent_address_index': walletAddresses.currentSilentAddressIndex.toString(),
        'network_type': network == BitcoinNetwork.testnet ? 'testnet' : 'mainnet',
      });

  int feeRate(TransactionPriority priority) {
    try {
      if (priority is BitcoinTransactionPriority) {
        return _feeRates[priority.raw];
      }

      return 0;
    } catch (_) {
      return 0;
    }
  }

  int feeAmountForPriority(BitcoinTransactionPriority priority, int inputsCount, int outputsCount,
          {int? size}) =>
      feeRate(priority) * (size ?? estimatedTransactionSize(inputsCount, outputsCount));

  int feeAmountWithFeeRate(int feeRate, int inputsCount, int outputsCount, {int? size}) =>
      feeRate * (size ?? estimatedTransactionSize(inputsCount, outputsCount));

  @override
  int calculateEstimatedFee(TransactionPriority? priority, int? amount,
      {int? outputsCount, int? size}) {
    if (priority is BitcoinTransactionPriority) {
      return calculateEstimatedFeeWithFeeRate(feeRate(priority), amount,
          outputsCount: outputsCount, size: size);
    }

    return 0;
  }

  int calculateEstimatedFeeWithFeeRate(int feeRate, int? amount, {int? outputsCount, int? size}) {
    if (size != null) {
      return feeAmountWithFeeRate(feeRate, 0, 0, size: size);
    }

    int inputsCount = 0;

    if (amount != null) {
      int totalValue = 0;

      for (final input in unspentCoins) {
        if (totalValue >= amount) {
          break;
        }

        if (input.isSending) {
          totalValue += input.value;
          inputsCount += 1;
        }
      }

      if (totalValue < amount) return 0;
    } else {
      for (final input in unspentCoins) {
        if (input.isSending) {
          inputsCount += 1;
        }
      }
    }

    // If send all, then we have no change value
    final _outputsCount = outputsCount ?? (amount != null ? 2 : 1);

    return feeAmountWithFeeRate(feeRate, inputsCount, _outputsCount);
  }

  @override
  Future<void> save() async {
    final path = await makePath();
    await write(path: path, password: _password, data: toJSON());
    await transactionHistory.save();
  }

  @override
  Future<void> renameWalletFiles(String newWalletName) async {
    final currentWalletPath = await pathForWallet(name: walletInfo.name, type: type);
    final currentWalletFile = File(currentWalletPath);

    final currentDirPath = await pathForWalletDir(name: walletInfo.name, type: type);
    final currentTransactionsFile = File('$currentDirPath/$transactionsHistoryFileName');

    // Copies current wallet files into new wallet name's dir and files
    if (currentWalletFile.existsSync()) {
      final newWalletPath = await pathForWallet(name: newWalletName, type: type);
      await currentWalletFile.copy(newWalletPath);
    }
    if (currentTransactionsFile.existsSync()) {
      final newDirPath = await pathForWalletDir(name: newWalletName, type: type);
      await currentTransactionsFile.copy('$newDirPath/$transactionsHistoryFileName');
    }

    // Delete old name's dir and files
    await Directory(currentDirPath).delete(recursive: true);
  }

  @override
  Future<void> changePassword(String password) async {
    _password = password;
    await save();
    await transactionHistory.changePassword(password);
  }

  @override
  Future<void> rescan({required int height, int? chainTip, ScanData? scanData}) async {
    // _setListeners(height);
  }

  @override
  Future<void> close() async {
    try {
      await electrumClient.close();
    } catch (_) {}
    _autoSaveTimer?.cancel();
  }

  Future<String> makePath() async => pathForWallet(name: walletInfo.name, type: walletInfo.type);

  Future<void> updateUnspent() async {
    // Update unspents stored from scanned silent payment transactions
    transactionHistory.transactions.values.forEach((tx) {
      if (tx.unspent != null) {
        if (!unspentCoins
            .any((utx) => utx.hash.contains(tx.unspent!.hash) && utx.vout == tx.unspent!.vout)) {
          unspentCoins.add(tx.unspent!);
        }
      }
    });

    List<BitcoinUnspent> updatedUnspentCoins = [];

    final addressesSet = walletAddresses.allAddresses.map((addr) => addr.address).toSet();

    await Future.wait(walletAddresses.allAddresses.map((address) => electrumClient
        .getListUnspentWithAddress(address.address, network)
        .then((unspent) => Future.forEach<Map<String, dynamic>>(unspent, (unspent) async {
              try {
                final coin = BitcoinUnspent.fromJSON(address, unspent);
                final tx = await fetchTransactionInfo(
                    hash: coin.hash, height: 0, myAddresses: addressesSet);
                coin.isChange = tx?.direction == TransactionDirection.outgoing;
                updatedUnspentCoins.add(coin);
              } catch (_) {}
            }))));

    unspentCoins = updatedUnspentCoins;

    if (unspentCoinsInfo.isEmpty) {
      unspentCoins.forEach((coin) => _addCoinInfo(coin));
      return;
    }

    if (unspentCoins.isNotEmpty) {
      unspentCoins.forEach((coin) {
        final coinInfoList = unspentCoinsInfo.values.where((element) =>
            element.walletId.contains(id) &&
            element.hash.contains(coin.hash) &&
            element.address.contains(coin.address));

        if (coinInfoList.isNotEmpty) {
          final coinInfo = coinInfoList.first;

          coin.isFrozen = coinInfo.isFrozen;
          coin.isSending = coinInfo.isSending;
          coin.note = coinInfo.note;
        } else {
          _addCoinInfo(coin);
        }
      });
    }

    await _refreshUnspentCoinsInfo();
  }

  @action
  Future<void> _addCoinInfo(BitcoinUnspent coin) async {
    final newInfo = UnspentCoinsInfo(
      walletId: id,
      hash: coin.hash,
      isFrozen: coin.isFrozen,
      isSending: coin.isSending,
      noteRaw: coin.note,
      address: coin.bitcoinAddressRecord.address,
      value: coin.value,
      vout: coin.vout,
      isChange: coin.isChange,
    );

    await unspentCoinsInfo.add(newInfo);
  }

  Future<void> _refreshUnspentCoinsInfo() async {
    try {
      final List<dynamic> keys = <dynamic>[];
      final currentWalletUnspentCoins =
          unspentCoinsInfo.values.where((element) => element.walletId.contains(id));

      if (currentWalletUnspentCoins.isNotEmpty) {
        currentWalletUnspentCoins.forEach((element) {
          final existUnspentCoins = unspentCoins
              .where((coin) => element.hash.contains(coin.hash) && element.vout == coin.vout);

          if (existUnspentCoins.isEmpty) {
            keys.add(element.key);
          }
        });
      }

      if (keys.isNotEmpty) {
        await unspentCoinsInfo.deleteAll(keys);
      }
    } catch (e) {
      print(e.toString());
    }
  }

  Future<ElectrumTransactionBundle> getTransactionExpanded(
      {required String hash, required int height}) async {
    String transactionHex;
    int? time;
    int confirmations = 0;
    if (network == BitcoinNetwork.testnet) {
      // Testnet public electrum server does not support verbose transaction fetching
      transactionHex = await electrumClient.getTransactionHex(hash: hash);

      final status = json.decode(
          (await http.get(Uri.parse("https://blockstream.info/testnet/api/tx/$hash/status"))).body);

      time = status["block_time"] as int?;
      final tip = await electrumClient.getCurrentBlockChainTip() ?? 0;
      confirmations = tip - (status["block_height"] as int? ?? 0);
    } else {
      final verboseTransaction = await electrumClient.getTransactionRaw(hash: hash);

      transactionHex = verboseTransaction['hex'] as String;
      time = verboseTransaction['time'] as int?;
      confirmations = verboseTransaction['confirmations'] as int? ?? 0;
    }

    final original = BtcTransaction.fromRaw(transactionHex);
    final ins = <BtcTransaction>[];

    for (final vin in original.inputs) {
      try {
        final id = HEX.encode(HEX.decode(vin.txId).reversed.toList());
        final txHex = await electrumClient.getTransactionHex(hash: id);
        final tx = BtcTransaction.fromRaw(txHex);
        ins.add(tx);
      } catch (_) {
        ins.add(BtcTransaction.fromRaw(await electrumClient.getTransactionHex(hash: vin.txId)));
      }
    }

    return ElectrumTransactionBundle(original,
        ins: ins, time: time, confirmations: confirmations, height: height);
  }

  Future<ElectrumTransactionInfo?> fetchTransactionInfo(
      {required String hash,
      required int height,
      required Set<String> myAddresses,
      bool? retryOnFailure}) async {
    try {
      return ElectrumTransactionInfo.fromElectrumBundle(
          await getTransactionExpanded(hash: hash, height: height), walletInfo.type, network,
          addresses: myAddresses, height: height);
    } catch (e) {
      if (e is FormatException && retryOnFailure == true) {
        await Future.delayed(const Duration(seconds: 2));
        return fetchTransactionInfo(hash: hash, height: height, myAddresses: myAddresses);
      }
      return null;
    }
  }

  @override
  Future<Map<String, ElectrumTransactionInfo>> fetchTransactions() async {
    try {
      final Map<String, ElectrumTransactionInfo> historiesWithDetails = {};
      final addressesSet = walletAddresses.allAddresses.map((addr) => addr.address).toSet();
      final currentHeight = await electrumClient.getCurrentBlockChainTip() ?? 0;

      await Future.wait(ADDRESS_TYPES.map((type) {
        final addressesByType = walletAddresses.allAddresses.where((addr) => addr.type == type);

        return Future.wait(addressesByType.map((addressRecord) async {
          final history = await _fetchAddressHistory(addressRecord, addressesSet, currentHeight);

          if (history.isNotEmpty) {
            addressRecord.txCount = history.length;
            historiesWithDetails.addAll(history);

            final matchedAddresses =
                addressesByType.where((addr) => addr.isHidden == addressRecord.isHidden);

            final isLastUsedAddress =
                history.isNotEmpty && addressRecord.address == matchedAddresses.last.address;

            if (isLastUsedAddress) {
              await walletAddresses.discoverAddresses(
                  matchedAddresses.toList(),
                  addressRecord.isHidden,
                  (address, addressesSet) =>
                      _fetchAddressHistory(address, addressesSet, currentHeight)
                          .then((history) => history.isNotEmpty ? address.address : null),
                  type: type);
            }
          }
        }));
      }));

      return historiesWithDetails;
    } catch (e) {
      print(e.toString());
      return {};
    }
  }

  Future<Map<String, ElectrumTransactionInfo>> _fetchAddressHistory(
      BitcoinAddressRecord addressRecord, Set<String> addressesSet, int currentHeight) async {
    try {
      final Map<String, ElectrumTransactionInfo> historiesWithDetails = {};

      final history = await electrumClient
          .getHistory(addressRecord.scriptHash ?? addressRecord.updateScriptHash(network));

      if (history.isNotEmpty) {
        addressRecord.setAsUsed();

        await Future.wait(history.map((transaction) async {
          final txid = transaction['tx_hash'] as String;
          final height = transaction['height'] as int;
          final storedTx = transactionHistory.transactions[txid];

          if (storedTx != null) {
            if (height > 0) {
              storedTx.height = height;
              // the tx's block itself is the first confirmation so add 1
              storedTx.confirmations = currentHeight - height + 1;
              storedTx.isPending = storedTx.confirmations == 0;
            }

            historiesWithDetails[txid] = storedTx;
          } else {
            final tx = await fetchTransactionInfo(
                hash: txid, height: height, myAddresses: addressesSet, retryOnFailure: true);

            if (tx != null) {
              historiesWithDetails[txid] = tx;

              // Got a new transaction fetched, add it to the transaction history
              // instead of waiting all to finish, and next time it will be faster
              transactionHistory.addOne(tx);
              await transactionHistory.save();
            }
          }

          return Future.value(null);
        }));
      }

      return historiesWithDetails;
    } catch (e) {
      print(e.toString());
      return {};
    }
  }

  Future<void> updateTransactions() async {
    try {
      if (_isTransactionUpdating) {
        return;
      }

      _isTransactionUpdating = true;
      await fetchTransactions();
      walletAddresses.updateReceiveAddresses();
      _isTransactionUpdating = false;
    } catch (e, stacktrace) {
      print(stacktrace);
      print(e);
      _isTransactionUpdating = false;
    }
  }

  void _subscribeForUpdates() async {
    scriptHashes.forEach((sh) async {
      await _scripthashesUpdateSubject[sh]?.close();
      _scripthashesUpdateSubject[sh] = electrumClient.scripthashUpdate(sh);
      _scripthashesUpdateSubject[sh]?.listen((event) async {
        try {
          await updateUnspent();
          await updateBalance();
          await updateTransactions();
        } catch (e, s) {
          print(e.toString());
          _onError?.call(FlutterErrorDetails(
            exception: e,
            stack: s,
            library: this.runtimeType.toString(),
          ));
        }
      });
    });

    await _chainTipUpdateSubject?.close();
    _chainTipUpdateSubject = electrumClient.chainTipUpdate();
    _chainTipUpdateSubject?.listen((_) async {
      try {
        final currentHeight = await electrumClient.getCurrentBlockChainTip();
        if (currentHeight != null) walletInfo.restoreHeight = currentHeight;
        // _setListeners(walletInfo.restoreHeight, chainTip: currentHeight);
      } catch (e, s) {
        print(e.toString());
        _onError?.call(FlutterErrorDetails(
          exception: e,
          stack: s,
          library: this.runtimeType.toString(),
        ));
      }
    });
  }

  Future<ElectrumBalance> _fetchBalances() async {
    final addresses = walletAddresses.allAddresses.toList();
    final balanceFutures = <Future<Map<String, dynamic>>>[];
    for (var i = 0; i < addresses.length; i++) {
      final addressRecord = addresses[i];
      final sh = scriptHash(addressRecord.address, network: network);
      final balanceFuture = electrumClient.getBalance(sh);
      balanceFutures.add(balanceFuture);
    }

    var totalFrozen = 0;
    var totalConfirmed = 0;
    var totalUnconfirmed = 0;

    // Add values from unspent coins that are not fetched by the address list
    // i.e. scanned silent payments
    unspentCoinsInfo.values.forEach((info) {
      unspentCoins.forEach((element) {
        if (element.hash == info.hash &&
            element.bitcoinAddressRecord.address == info.address &&
            element.value == info.value) {
          if (info.isFrozen) totalFrozen += element.value;
          if (element.bitcoinAddressRecord.silentPaymentTweak != null) {
            totalConfirmed += element.value;
          }
        }
      });
    });

    final balances = await Future.wait(balanceFutures);

    for (var i = 0; i < balances.length; i++) {
      final addressRecord = addresses[i];
      final balance = balances[i];
      final confirmed = balance['confirmed'] as int? ?? 0;
      final unconfirmed = balance['unconfirmed'] as int? ?? 0;
      totalConfirmed += confirmed;
      totalUnconfirmed += unconfirmed;

      if (confirmed > 0 || unconfirmed > 0) {
        addressRecord.setAsUsed();
      }
    }

    return ElectrumBalance(
        confirmed: totalConfirmed, unconfirmed: totalUnconfirmed, frozen: totalFrozen);
  }

  Future<void> updateBalance() async {
    balance[currency] = await _fetchBalances();
    await save();
  }

  String getChangeAddress() {
    const minCountOfHiddenAddresses = 5;
    final random = Random();
    var addresses = walletAddresses.allAddresses.where((addr) => addr.isHidden).toList();

    if (addresses.length < minCountOfHiddenAddresses) {
      addresses = walletAddresses.allAddresses.toList();
    }

    return addresses[random.nextInt(addresses.length)].address;
  }

  @override
  void setExceptionHandler(void Function(FlutterErrorDetails) onError) => _onError = onError;

  @override
  String signMessage(String message, {String? address = null}) {
    final index = address != null
        ? walletAddresses.allAddresses.firstWhere((element) => element.address == address).index
        : null;
    final HD = index == null ? hd : hd.derive(index);
    return base64Encode(HD.signMessage(message));
  }

  Future<void> _setInitialHeight() async {
    if (walletInfo.isRecovery) {
      return;
    }

    if (walletInfo.restoreHeight == 0) {
      final currentHeight = await electrumClient.getCurrentBlockChainTip();
      if (currentHeight != null) walletInfo.restoreHeight = currentHeight;
    }
  }
}

class ScanData {
  final SendPort sendPort;
  final SilentPaymentReceiver primarySilentAddress;
  final int height;
  final String node;
  final bitcoin.NetworkType networkType;
  final int chainTip;
  final ElectrumClient electrumClient;
  final List<String> transactionHistoryIds;
  final Map<String, String> labels;

  ScanData({
    required this.sendPort,
    required this.primarySilentAddress,
    required this.height,
    required this.node,
    required this.networkType,
    required this.chainTip,
    required this.electrumClient,
    required this.transactionHistoryIds,
    required this.labels,
  });

  factory ScanData.fromHeight(ScanData scanData, int newHeight) {
    return ScanData(
      sendPort: scanData.sendPort,
      primarySilentAddress: scanData.primarySilentAddress,
      height: newHeight,
      node: scanData.node,
      networkType: scanData.networkType,
      chainTip: scanData.chainTip,
      transactionHistoryIds: scanData.transactionHistoryIds,
      electrumClient: scanData.electrumClient,
      labels: scanData.labels,
    );
  }
}

class SyncResponse {
  final int height;
  final SyncStatus syncStatus;

  SyncResponse(this.height, this.syncStatus);
}

// Future<void> startRefresh(ScanData scanData) async {
//   var cachedBlockchainHeight = scanData.chainTip;

//   Future<int> getNodeHeightOrUpdate(int baseHeight) async {
//     if (cachedBlockchainHeight < baseHeight || cachedBlockchainHeight == 0) {
//       final electrumClient = scanData.electrumClient;
//       if (!electrumClient.isConnected) {
//         final node = scanData.node;
//         await electrumClient.connectToUri(Uri.parse(node));
//       }

//       cachedBlockchainHeight =
//           await electrumClient.getCurrentBlockChainTip() ?? cachedBlockchainHeight;
//     }

//     return cachedBlockchainHeight;
//   }

//   var lastKnownBlockHeight = 0;
//   var initialSyncHeight = 0;

//   var syncHeight = scanData.height;
//   var currentChainTip = scanData.chainTip;

//   if (syncHeight <= 0) {
//     syncHeight = currentChainTip;
//   }

//   if (initialSyncHeight <= 0) {
//     initialSyncHeight = syncHeight;
//   }

//   if (lastKnownBlockHeight == syncHeight) {
//     scanData.sendPort.send(SyncResponse(currentChainTip, SyncedSyncStatus()));
//     return;
//   }

//   // Run this until no more blocks left to scan txs. At first this was recursive
//   // i.e. re-calling the startRefresh function but this was easier for the above values to retain
//   // their initial values
//   while (true) {
//     lastKnownBlockHeight = syncHeight;

//     final syncingStatus =
//         SyncingSyncStatus.fromHeightValues(currentChainTip, initialSyncHeight, syncHeight);
//     scanData.sendPort.send(SyncResponse(syncHeight, syncingStatus));

//     if (syncingStatus.blocksLeft <= 0) {
//       scanData.sendPort.send(SyncResponse(currentChainTip, SyncedSyncStatus()));
//       return;
//     }

//     // print(["Scanning from height:", syncHeight]);

//     try {
//       final networkPath =
//           scanData.networkType.network == bitcoin.BtcNetwork.mainnet ? "" : "/testnet";

//       // This endpoint gets up to 10 latest blocks from the given height
//       final tenNewestBlocks =
//           (await http.get(Uri.parse("https://blockstream.info$networkPath/api/blocks/$syncHeight")))
//               .body;
//       var decodedBlocks = json.decode(tenNewestBlocks) as List<dynamic>;

//       decodedBlocks.sort((a, b) => (a["height"] as int).compareTo(b["height"] as int));
//       decodedBlocks =
//           decodedBlocks.where((element) => (element["height"] as int) >= syncHeight).toList();

//       // for each block, get up to 25 txs
//       for (var i = 0; i < decodedBlocks.length; i++) {
//         final blockJson = decodedBlocks[i];
//         final blockHash = blockJson["id"];
//         final txCount = blockJson["tx_count"] as int;

//         // print(["Scanning block index:", i, "with tx count:", txCount]);

//         int startIndex = 0;
//         // go through each tx in block until no more txs are left
//         while (startIndex < txCount) {
//           // This endpoint gets up to 25 txs from the given block hash and start index
//           final twentyFiveTxs = json.decode((await http.get(Uri.parse(
//                   "https://blockstream.info$networkPath/api/block/$blockHash/txs/$startIndex")))
//               .body) as List<dynamic>;

//           // print(["Scanning txs index:", startIndex]);

//           // For each tx, apply silent payment filtering and do shared secret calculation when applied
//           for (var i = 0; i < twentyFiveTxs.length; i++) {
//             try {
//               final tx = twentyFiveTxs[i];
//               final txid = tx["txid"] as String;

//               // print(["Scanning tx:", txid]);

//               // TODO: if tx already scanned & stored skip
//               // if (scanData.transactionHistoryIds.contains(txid)) {
//               //   // already scanned tx, continue to next tx
//               //   pos++;
//               //   continue;
//               // }

//               List<String> pubkeys = [];
//               List<bitcoin.Outpoint> outpoints = [];

//               bool skip = false;

//               for (var i = 0; i < (tx["vin"] as List<dynamic>).length; i++) {
//                 final input = tx["vin"][i];
//                 final prevout = input["prevout"];
//                 final scriptPubkeyType = prevout["scriptpubkey_type"];
//                 String? pubkey;

//                 if (scriptPubkeyType == "v0_p2wpkh" || scriptPubkeyType == "v1_p2tr") {
//                   final witness = input["witness"];
//                   if (witness == null) {
//                     skip = true;
//                     // print("Skipping, no witness");
//                     break;
//                   }

//                   if (witness.length == 2) {
//                     pubkey = witness[1] as String;
//                   } else if (witness.length == 1) {
//                     pubkey = "02" + (prevout["scriptpubkey"] as String).fromHex.sublist(2).hex;
//                   }
//                 }

//                 if (scriptPubkeyType == "p2pkh") {
//                   pubkey = bitcoin.P2pkhAddress(
//                           scriptSig: bitcoin.Script.fromRaw(hexData: input["scriptsig"] as String))
//                       .pubkey;
//                 }

//                 if (pubkey == null) {
//                   skip = true;
//                   // print("Skipping, invalid witness");
//                   break;
//                 }

//                 pubkeys.add(pubkey);
//                 outpoints.add(
//                     bitcoin.Outpoint(txid: input["txid"] as String, index: input["vout"] as int));
//               }

//               if (skip) {
//                 // skipped tx, continue to next tx
//                 continue;
//               }

//               Map<String, bitcoin.Outpoint> outpointsByP2TRpubkey = {};
//               for (var i = 0; i < (tx["vout"] as List<dynamic>).length; i++) {
//                 final output = tx["vout"][i];
//                 if (output["scriptpubkey_type"] != "v1_p2tr") {
//                   // print("Skipping, not a v1_p2tr output");
//                   continue;
//                 }

//                 final script = (output["scriptpubkey"] as String).fromHex;

//                 // final alreadySpentOutput = (await electrumClient.getHistory(
//                 //             scriptHashFromScript(script, networkType: scanData.networkType)))
//                 //         .length >
//                 //     1;

//                 // if (alreadySpentOutput) {
//                 // print("Skipping, invalid witness");
//                 //   break;
//                 // }

//                 final p2tr = bitcoin.P2trAddress(
//                     program: script.sublist(2).hex, networkType: scanData.networkType);
//                 final address = p2tr.address;

//                 print(["Verifying taproot address:", address]);

//                 outpointsByP2TRpubkey[script.sublist(2).hex] =
//                     bitcoin.Outpoint(txid: txid, index: i, value: output["value"] as int);
//               }

//               if (pubkeys.isEmpty || outpoints.isEmpty || outpointsByP2TRpubkey.isEmpty) {
//                 // skipped tx, continue to next tx
//                 continue;
//               }

//               final outpointHash = bitcoin.SilentPayment.hashOutpoints(outpoints);

//               final result = bitcoin.scanOutputs(
//                 scanData.primarySilentAddress.scanPrivkey,
//                 scanData.primarySilentAddress.spendPubkey,
//                 bitcoin.getSumInputPubKeys(pubkeys),
//                 outpointHash,
//                 outpointsByP2TRpubkey.keys.map((e) => e.fromHex).toList(),
//                 labels: scanData.labels,
//               );

//               if (result.isEmpty) {
//                 // no results tx, continue to next tx
//                 continue;
//               }

//               if (result.length > 1) {
//                 print("MULTIPLE UNSPENT COINS FOUND!");
//               } else {
//                 print("UNSPENT COIN FOUND!");
//               }

//               result.forEach((key, value) async {
//                 final outpoint = outpointsByP2TRpubkey[key];

//                 if (outpoint == null) {
//                   return;
//                 }

//                 final tweak = value[0];
//                 String? label;
//                 if (value.length > 1) label = value[1];

//                 final txInfo = ElectrumTransactionInfo(
//                   WalletType.bitcoin,
//                   id: txid,
//                   height: syncHeight,
//                   amount: outpoint.value!,
//                   fee: 0,
//                   direction: TransactionDirection.incoming,
//                   isPending: false,
//                   date: DateTime.fromMillisecondsSinceEpoch((blockJson["timestamp"] as int) * 1000),
//                   confirmations: currentChainTip - syncHeight,
//                   to: bitcoin.SilentPaymentAddress.createLabeledSilentPaymentAddress(
//                           scanData.primarySilentAddress.scanPubkey,
//                           scanData.primarySilentAddress.spendPubkey,
//                           label != null ? label.fromHex : "0".fromHex,
//                           hrp: scanData.primarySilentAddress.hrp,
//                           version: scanData.primarySilentAddress.version)
//                       .toString(),
//                   unspent: null,
//                 );

//                 final status = json.decode((await http
//                         .get(Uri.parse("https://blockstream.info/testnet/api/tx/$txid/outspends")))
//                     .body) as List<dynamic>;

//                 bool spent = false;
//                 for (final s in status) {
//                   if ((s["spent"] as bool) == true) {
//                     spent = true;

//                     scanData.sendPort.send({txid: txInfo});

//                     final sentTxId = s["txid"] as String;
//                     final sentTx = json.decode((await http
//                             .get(Uri.parse("https://blockstream.info/testnet/api/tx/$sentTxId")))
//                         .body);

//                     int amount = 0;
//                     for (final out in (sentTx["vout"] as List<dynamic>)) {
//                       amount += out["value"] as int;
//                     }

//                     final height = s["status"]["block_height"] as int;

//                     scanData.sendPort.send({
//                       sentTxId: ElectrumTransactionInfo(
//                         WalletType.bitcoin,
//                         id: sentTxId,
//                         height: height,
//                         amount: amount,
//                         fee: 0,
//                         direction: TransactionDirection.outgoing,
//                         isPending: false,
//                         date: DateTime.fromMillisecondsSinceEpoch(
//                             (s["status"]["block_time"] as int) * 1000),
//                         confirmations: currentChainTip - height,
//                       )
//                     });
//                   }
//                 }

//                 if (spent) {
//                   return;
//                 }

//                 final unspent = BitcoinUnspent(
//                   BitcoinAddressRecord(
//                     bitcoin.P2trAddress(program: key, networkType: scanData.networkType).address,
//                     index: 0,
//                     isHidden: true,
//                     isUsed: true,
//                     silentAddressLabel: null,
//                     silentPaymentTweak: tweak,
//                     type: bitcoin.AddressType.p2tr,
//                   ),
//                   txid,
//                   outpoint.value!,
//                   outpoint.index,
//                   silentPaymentTweak: tweak,
//                   type: bitcoin.AddressType.p2tr,
//                 );

//                 // found utxo for tx, send unspent coin to main isolate
//                 scanData.sendPort.send(unspent);

//                 // also send tx data for tx history
//                 txInfo.unspent = unspent;
//                 scanData.sendPort.send({txid: txInfo});
//               });
//             } catch (_) {}
//           }

//           // Finished scanning batch of txs in block, add 25 to start index and continue to next block in loop
//           startIndex += 25;
//         }

//         // Finished scanning block, add 1 to height and continue to next block in loop
//         syncHeight += 1;
//         currentChainTip = await getNodeHeightOrUpdate(syncHeight);
//         scanData.sendPort.send(SyncResponse(syncHeight,
//             SyncingSyncStatus.fromHeightValues(currentChainTip, initialSyncHeight, syncHeight)));
//       }
//     } catch (e, stacktrace) {
//       print(stacktrace);
//       print(e.toString());

//       scanData.sendPort.send(SyncResponse(syncHeight, NotConnectedSyncStatus()));
//       break;
//     }
//   }
// }

class EstimatedTxResult {
  EstimatedTxResult(
      {required this.utxos, required this.privateKeys, required this.fee, required this.amount});

  final List<UtxoWithAddress> utxos;
  final List<ECPrivate> privateKeys;
  final int fee;
  final int amount;
}

BitcoinBaseAddress _addressTypeFromStr(String address, BasedUtxoNetwork network) {
  if (P2pkhAddress.regex.hasMatch(address)) {
    return P2pkhAddress.fromAddress(address: address, network: network);
  } else if (P2shAddress.regex.hasMatch(address)) {
    return P2shAddress.fromAddress(address: address, network: network);
  } else if (P2wshAddress.regex.hasMatch(address)) {
    return P2wshAddress.fromAddress(address: address, network: network);
  } else if (P2trAddress.regex.hasMatch(address)) {
    return P2trAddress.fromAddress(address: address, network: network);
  } else {
    return P2wpkhAddress.fromAddress(address: address, network: network);
  }
}

BitcoinAddressType _getScriptType(BitcoinBaseAddress type) {
  if (type is P2pkhAddress) {
    return P2pkhAddressType.p2pkh;
  } else if (type is P2shAddress) {
    return P2shAddressType.p2wpkhInP2sh;
  } else if (type is P2wshAddress) {
    return SegwitAddresType.p2wsh;
  } else if (type is P2trAddress) {
    return SegwitAddresType.p2tr;
  } else {
    return SegwitAddresType.p2wpkh;
  }
}

class EstimateTxParams {
  EstimateTxParams(
      {required this.amount,
      required this.feeRate,
      required this.priority,
      required this.outputsCount,
      required this.size});

  final int amount;
  final int feeRate;
  final TransactionPriority priority;
  final int outputsCount;
  final int size;
}

class EstimatedTxResult {
  EstimatedTxResult(
      {required this.utxos, required this.privateKeys, required this.fee, required this.amount});

  final List<UtxoWithAddress> utxos;
  final List<ECPrivate> privateKeys;
  final int fee;
  final int amount;
}

BitcoinBaseAddress _addressTypeFromStr(String address, BasedUtxoNetwork network) {
  if (P2pkhAddress.regex.hasMatch(address)) {
    return P2pkhAddress.fromAddress(address: address, network: network);
  } else if (P2shAddress.regex.hasMatch(address)) {
    return P2shAddress.fromAddress(address: address, network: network);
  } else if (P2wshAddress.regex.hasMatch(address)) {
    return P2wshAddress.fromAddress(address: address, network: network);
  } else if (P2trAddress.regex.hasMatch(address)) {
    return P2trAddress.fromAddress(address: address, network: network);
  } else {
    return P2wpkhAddress.fromAddress(address: address, network: network);
  }
}

BitcoinAddressType _getScriptType(BitcoinBaseAddress type) {
  if (type is P2pkhAddress) {
    return P2pkhAddressType.p2pkh;
  } else if (type is P2shAddress) {
    return P2shAddressType.p2wpkhInP2sh;
  } else if (type is P2wshAddress) {
    return SegwitAddresType.p2wsh;
  } else if (type is P2trAddress) {
    return SegwitAddresType.p2tr;
  } else {
    return SegwitAddresType.p2wpkh;
  }
}
