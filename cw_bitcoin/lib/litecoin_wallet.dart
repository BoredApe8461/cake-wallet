import 'dart:async';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:cw_core/cake_hive.dart';
import 'package:cw_core/mweb_utxo.dart';
import 'package:cw_mweb/mwebd.pbgrpc.dart';
import 'package:fixnum/fixnum.dart';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:cw_bitcoin/bitcoin_mnemonic.dart';
import 'package:cw_bitcoin/bitcoin_transaction_priority.dart';
import 'package:cw_bitcoin/bitcoin_unspent.dart';
import 'package:cw_bitcoin/electrum_transaction_info.dart';
import 'package:cw_bitcoin/pending_bitcoin_transaction.dart';
import 'package:cw_bitcoin/utils.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cw_bitcoin/litecoin_wallet_addresses.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_bitcoin/electrum_wallet_snapshot.dart';
import 'package:cw_bitcoin/electrum_wallet.dart';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_bitcoin/electrum_balance.dart';
import 'package:cw_bitcoin/litecoin_network.dart';
import 'package:cw_mweb/cw_mweb.dart';
import 'package:cw_mweb/mwebd.pb.dart';
import 'package:bitcoin_flutter/bitcoin_flutter.dart' as bitcoin;
import 'package:bip39/bip39.dart' as bip39;

part 'litecoin_wallet.g.dart';

class LitecoinWallet = LitecoinWalletBase with _$LitecoinWallet;

abstract class LitecoinWalletBase extends ElectrumWallet with Store {
  LitecoinWalletBase({
    required String mnemonic,
    required String password,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required Uint8List seedBytes,
    String? addressPageType,
    List<BitcoinAddressRecord>? initialAddresses,
    ElectrumBalance? initialBalance,
    Map<String, int>? initialRegularAddressIndex,
    Map<String, int>? initialChangeAddressIndex,
    int? initialMwebHeight,
  })  : mwebHd =
            bitcoin.HDWallet.fromSeed(seedBytes, network: litecoinNetwork).derivePath("m/1000'"),
        super(
          mnemonic: mnemonic,
          password: password,
          walletInfo: walletInfo,
          unspentCoinsInfo: unspentCoinsInfo,
          networkType: litecoinNetwork,
          initialAddresses: initialAddresses,
          initialBalance: initialBalance,
          seedBytes: seedBytes,
          currency: CryptoCurrency.ltc,
        ) {
    walletAddresses = LitecoinWalletAddresses(
      walletInfo,
      initialAddresses: initialAddresses,
      initialRegularAddressIndex: initialRegularAddressIndex,
      initialChangeAddressIndex: initialChangeAddressIndex,
      mainHd: hd,
      sideHd: accountHD.derive(1),
      network: network,
      mwebHd: mwebHd,
    );
    autorun((_) {
      this.walletAddresses.isEnabledAutoGenerateSubaddress = this.isEnabledAutoGenerateSubaddress;
    });
    CwMweb.stub().then((value) {
      _stub = value;
    });
  }

  final bitcoin.HDWallet mwebHd;
  late final Box<MwebUtxo> mwebUtxosBox;
  Timer? _syncTimer;
  int mwebUtxosHeight = 0;
  late RpcClient _stub;

  static Future<LitecoinWallet> create(
      {required String mnemonic,
      required String password,
      required WalletInfo walletInfo,
      required Box<UnspentCoinsInfo> unspentCoinsInfo,
      String? passphrase,
      String? addressPageType,
      List<BitcoinAddressRecord>? initialAddresses,
      ElectrumBalance? initialBalance,
      Map<String, int>? initialRegularAddressIndex,
      Map<String, int>? initialChangeAddressIndex}) async {
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
        seedBytes = await mnemonicToSeedBytes(mnemonic);
        break;
    }
    return LitecoinWallet(
      mnemonic: mnemonic,
      password: password,
      walletInfo: walletInfo,
      unspentCoinsInfo: unspentCoinsInfo,
      initialAddresses: initialAddresses,
      initialBalance: initialBalance,
      seedBytes: seedBytes,
      initialRegularAddressIndex: initialRegularAddressIndex,
      initialChangeAddressIndex: initialChangeAddressIndex,
      addressPageType: addressPageType,
    );
  }

  static Future<LitecoinWallet> open({
    required String name,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required String password,
  }) async {
    final snp =
        await ElectrumWalletSnapshot.load(name, walletInfo.type, password, LitecoinNetwork.mainnet);
    return LitecoinWallet(
      mnemonic: snp.mnemonic!,
      password: password,
      walletInfo: walletInfo,
      unspentCoinsInfo: unspentCoinsInfo,
      initialAddresses: snp.addresses,
      initialBalance: snp.balance,
      seedBytes: await mnemonicToSeedBytes(snp.mnemonic!),
      initialRegularAddressIndex: snp.regularAddressIndex,
      initialChangeAddressIndex: snp.changeAddressIndex,
      addressPageType: snp.addressPageType,
    );
  }

  @action
  @override
  Future<void> startSync() async {
    await super.startSync();
    _stub = await CwMweb.stub();
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      if (syncStatus is FailedSyncStatus) return;
      final height = await electrumClient.getCurrentBlockChainTip() ?? 0;
      final resp = await _stub.status(StatusRequest());
      // print("height: $height");
      // print("resp.blockHeaderHeight: ${resp.blockHeaderHeight}");
      // print("resp.mwebHeaderHeight: ${resp.mwebHeaderHeight}");
      // print("resp.mwebUtxosHeight: ${resp.mwebUtxosHeight}");
      if (resp.blockHeaderHeight < height) {
        int h = resp.blockHeaderHeight;
        syncStatus = SyncingSyncStatus(height - h, h / height);
      } else if (resp.mwebHeaderHeight < height) {
        int h = resp.mwebHeaderHeight;
        syncStatus = SyncingSyncStatus(height - h, h / height);
      } else if (resp.mwebUtxosHeight < height) {
        syncStatus = SyncingSyncStatus(1, 0.999);
      } else {
        // prevent unnecessary reaction triggers:
        if (syncStatus is! SyncedSyncStatus) {
          syncStatus = SyncedSyncStatus();
        }

        if (resp.mwebUtxosHeight > mwebUtxosHeight) {
          mwebUtxosHeight = resp.mwebUtxosHeight;
          await checkMwebUtxosSpent();
          // update the confirmations for each transaction:
          for (final transaction in transactionHistory.transactions.values) {
            if (transaction.isPending) continue;
            final confirmations = mwebUtxosHeight - transaction.height + 1;
            if (transaction.confirmations == confirmations) continue;
            transaction.confirmations = confirmations;
            transactionHistory.addOne(transaction);
          }
          await transactionHistory.save();
        }
      }
    });
    processMwebUtxos();
  }

  @action
  @override
  Future<void> stopSync() async {
    _syncTimer?.cancel();
    await CwMweb.stop();
  }

  Future<void> initMwebUtxosBox() async {
    final boxName = "${walletInfo.name.replaceAll(" ", "_")}_${MwebUtxo.boxName}";

    mwebUtxosBox = await CakeHive.openBox<MwebUtxo>(boxName);
  }

  @action
  @override
  Future<void> rescan({
    required int height,
    int? chainTip,
    ScanData? scanData,
    bool? doSingleScan,
    bool? usingElectrs,
  }) async {
    await mwebUtxosBox.clear();
    transactionHistory.clear();
    mwebUtxosHeight = height;
    await walletInfo.updateRestoreHeight(height);
    print("STARTING SYNC");
    await startSync();
  }

  @override
  Future<void> init() async {
    await super.init();
    await initMwebUtxosBox();
  }

  Future<void> handleIncoming(MwebUtxo utxo, RpcClient stub) async {
    final status = await stub.status(StatusRequest());
    var date = DateTime.now();
    var confirmations = 0;
    if (utxo.height > 0) {
      date = DateTime.fromMillisecondsSinceEpoch(utxo.blockTime * 1000);
      confirmations = status.blockHeaderHeight - utxo.height + 1;
    }
    var tx = transactionHistory.transactions.values
        .firstWhereOrNull((tx) => tx.outputAddresses?.contains(utxo.outputId) ?? false);

    if (tx == null) {
      tx = ElectrumTransactionInfo(
        WalletType.litecoin,
        id: utxo.outputId,
        height: utxo.height,
        amount: utxo.value.toInt(),
        fee: 0,
        direction: TransactionDirection.incoming,
        isPending: utxo.height == 0,
        date: date,
        confirmations: confirmations,
        inputAddresses: [],
        outputAddresses: [utxo.outputId],
      );
    }

    tx.height = utxo.height;
    tx.isPending = utxo.height == 0;
    tx.confirmations = confirmations;
    bool isNew = transactionHistory.transactions[tx.id] == null;

    if (!(tx.outputAddresses?.contains(utxo.address) ?? false)) {
      tx.outputAddresses?.add(utxo.address);
      isNew = true;
    }

    if (isNew) {
      final addressRecord = walletAddresses.allAddresses
          .firstWhereOrNull((addressRecord) => addressRecord.address == utxo.address);
      if (addressRecord == null) {
        return;
      }
      if (!(tx.inputAddresses?.contains(utxo.address) ?? false)) {
        addressRecord.txCount++;
        print("COUNT UPDATED HERE 2!!!!! ${addressRecord.txCount}");
      }
      addressRecord.balance += utxo.value.toInt();
      addressRecord.setAsUsed();

      // update the unconfirmed balance when a new tx is added:
      await updateBalance();
    }
    transactionHistory.addOne(tx);
  }

  Future<void> processMwebUtxos() async {
    final scanSecret = mwebHd.derive(0x80000000).privKey!;
    int restoreHeight = walletInfo.restoreHeight;
    print("SCANNING FROM HEIGHT: $restoreHeight");
    final req = UtxosRequest(scanSecret: hex.decode(scanSecret), fromHeight: restoreHeight);
    bool initDone = false;

    // process old utxos:
    for (final utxo in mwebUtxosBox.values) {
      if (utxo.address.isEmpty) {
        initDone = true;
        continue;
      }

      // if (walletInfo.restoreHeight > utxo.height) {
      //   continue;
      // }

      await handleIncoming(utxo, _stub);

      if (initDone) {
        await updateUnspent();
        await updateBalance();
      }

      if (utxo.height > walletInfo.restoreHeight) {
        walletInfo.updateRestoreHeight(utxo.height);
      }
    }

    // process new utxos as they come in:
    await for (Utxo sUtxo in _stub.utxos(req)) {
      final utxo = MwebUtxo(
        address: sUtxo.address,
        blockTime: sUtxo.blockTime,
        height: sUtxo.height,
        outputId: sUtxo.outputId,
        value: sUtxo.value.toInt(),
      );

      // if (mwebUtxosBox.containsKey(utxo.outputId)) {
      //   // we've already stored this utxo, skip it:
      //   continue;
      // }

      if (utxo.address.isEmpty) {
        await updateUnspent();
        await updateBalance();
        initDone = true;
      }

      final mwebAddrs = (walletAddresses as LitecoinWalletAddresses).mwebAddrs;

      // don't process utxos with addresses that are not in the mwebAddrs list:
      if (utxo.address.isNotEmpty && !mwebAddrs.contains(utxo.address)) {
        continue;
      }

      await mwebUtxosBox.put(utxo.outputId, utxo);

      await handleIncoming(utxo, _stub);
    }
  }

  Future<void> checkMwebUtxosSpent() async {
    while ((await Future.wait(transactionHistory.transactions.values
            .where((tx) => tx.direction == TransactionDirection.outgoing && tx.isPending)
            .map(checkPendingTransaction)))
        .any((x) => x));
    final outputIds =
        mwebUtxosBox.values.where((utxo) => utxo.height > 0).map((utxo) => utxo.outputId).toList();

    final resp = await _stub.spent(SpentRequest(outputId: outputIds));
    final spent = resp.outputId;
    if (spent.isEmpty) return;
    final status = await _stub.status(StatusRequest());
    final height = await electrumClient.getCurrentBlockChainTip();
    if (height == null || status.blockHeaderHeight != height) return;
    if (status.mwebUtxosHeight != height) return;
    int amount = 0;
    Set<String> inputAddresses = {};
    var output = AccumulatorSink<Digest>();
    var input = sha256.startChunkedConversion(output);
    for (final outputId in spent) {
      final utxo = mwebUtxosBox.get(outputId);
      await mwebUtxosBox.delete(outputId);
      if (utxo == null) continue;
      final addressRecord = walletAddresses.allAddresses
          .firstWhere((addressRecord) => addressRecord.address == utxo.address);
      if (!inputAddresses.contains(utxo.address)) {
        addressRecord.txCount++;
        print("COUNT UPDATED HERE 3!!!!! ${addressRecord.address} ${addressRecord.txCount} !!!!!!");
      }
      addressRecord.balance -= utxo.value.toInt();
      amount += utxo.value.toInt();
      inputAddresses.add(utxo.address);
      input.add(hex.decode(outputId));
    }
    if (inputAddresses.isEmpty) return;
    input.close();
    var digest = output.events.single;
    final tx = ElectrumTransactionInfo(
      WalletType.litecoin,
      id: digest.toString(),
      height: height,
      amount: amount,
      fee: 0,
      direction: TransactionDirection.outgoing,
      isPending: false,
      date: DateTime.fromMillisecondsSinceEpoch(status.blockTime * 1000),
      confirmations: 1,
      inputAddresses: inputAddresses.toList(),
      outputAddresses: [],
    );
    print("BEING ADDED HERE@@@@@@@@@@@@@@@@@@@@@@@2");

    transactionHistory.addOne(tx);
    await transactionHistory.save();
  }

  Future<bool> checkPendingTransaction(ElectrumTransactionInfo tx) async {
    if (!tx.isPending) return false;
    final outputId = <String>[], target = <String>{};
    final isHash = RegExp(r'^[a-f0-9]{64}$').hasMatch;
    final spendingOutputIds = tx.inputAddresses?.where(isHash) ?? [];
    final payingToOutputIds = tx.outputAddresses?.where(isHash) ?? [];
    outputId.addAll(spendingOutputIds);
    outputId.addAll(payingToOutputIds);
    target.addAll(spendingOutputIds);
    for (final outputId in payingToOutputIds) {
      final spendingTx = transactionHistory.transactions.values
          .firstWhereOrNull((tx) => tx.inputAddresses?.contains(outputId) ?? false);
      if (spendingTx != null && !spendingTx.isPending) {
        target.add(outputId);
      }
    }
    if (outputId.isEmpty) {
      return false;
    }
    final resp = await _stub.spent(SpentRequest(outputId: outputId));
    if (!setEquals(resp.outputId.toSet(), target)) return false;
    final status = await _stub.status(StatusRequest());
    if (!tx.isPending) return false;
    tx.height = status.mwebUtxosHeight;
    tx.confirmations = 1;
    tx.isPending = false;
    await transactionHistory.save();
    return true;
  }

  @override
  Future<void> updateUnspent() async {
    await super.updateUnspent();
    await checkMwebUtxosSpent();
  }

  @override
  @action
  Future<void> updateAllUnspents() async {
    List<BitcoinUnspent> updatedUnspentCoins = [];

    await Future.wait(walletAddresses.allAddresses.map((address) async {
      updatedUnspentCoins.addAll(await fetchUnspent(address));
    }));

    // update mweb unspents:
    final mwebAddrs = (walletAddresses as LitecoinWalletAddresses).mwebAddrs;
    mwebUtxosBox.keys.forEach((dynamic oId) {
      final String outputId = oId as String;
      final utxo = mwebUtxosBox.get(outputId);
      if (utxo == null) {
        return;
      }
      if (utxo.address.isEmpty) {
        // not sure if a bug or a special case but we definitely ignore these
        return;
      }
      final addressRecord = walletAddresses.allAddresses
          .firstWhereOrNull((addressRecord) => addressRecord.address == utxo.address);

      if (addressRecord == null) {
        print("addressRecord is null! TODO: handle this case2");
        return;
      }
      final unspent = BitcoinUnspent(
        addressRecord,
        outputId,
        utxo.value.toInt(),
        mwebAddrs.indexOf(utxo.address),
      );
      if (unspent.vout == 0) {
        unspent.isChange = true;
      }
      updatedUnspentCoins.add(unspent);
    });

    unspentCoins = updatedUnspentCoins;
  }

  @override
  Future<ElectrumBalance> fetchBalances() async {
    final balance = await super.fetchBalances();
    var confirmed = balance.confirmed;
    var unconfirmed = balance.unconfirmed;
    mwebUtxosBox.values.forEach((utxo) {
      if (utxo.height > 0) {
        confirmed += utxo.value.toInt();
      } else {
        unconfirmed += utxo.value.toInt();
      }
    });

    // update unspent balances:

    // reset coin balances and txCount to 0:
    unspentCoins.forEach((coin) {
      if (coin.bitcoinAddressRecord is! BitcoinSilentPaymentAddressRecord)
        coin.bitcoinAddressRecord.balance = 0;
      coin.bitcoinAddressRecord.txCount = 0;
    });

    unspentCoins.forEach((coin) {
      final coinInfoList = unspentCoinsInfo.values.where(
        (element) =>
            element.walletId.contains(id) &&
            element.hash.contains(coin.hash) &&
            element.vout == coin.vout,
      );

      if (coinInfoList.isNotEmpty) {
        final coinInfo = coinInfoList.first;

        coin.isFrozen = coinInfo.isFrozen;
        coin.isSending = coinInfo.isSending;
        coin.note = coinInfo.note;
        if (coin.bitcoinAddressRecord is! BitcoinSilentPaymentAddressRecord)
          coin.bitcoinAddressRecord.balance += coinInfo.value;
      } else {
        super.addCoinInfo(coin);
      }
    });

    // update the txCount for each address:
    for (var tx in transactionHistory.transactions.values) {
      if (tx.isPending) continue;
      final txAddresses = tx.inputAddresses! + tx.outputAddresses!;
      for (var address in txAddresses) {
        final addressRecord = walletAddresses.allAddresses
            .firstWhereOrNull((addressRecord) => addressRecord.address == address);
        if (addressRecord == null) {
          continue;
        }
        addressRecord.txCount++;
        print("COUNT UPDATED HERE 0!!!!! ${addressRecord.address} ${addressRecord.txCount} !!!!!!");
      }
    }

    return ElectrumBalance(confirmed: confirmed, unconfirmed: unconfirmed, frozen: balance.frozen);
  }

  @override
  int feeRate(TransactionPriority priority) {
    if (priority is LitecoinTransactionPriority) {
      switch (priority) {
        case LitecoinTransactionPriority.slow:
          return 1;
        case LitecoinTransactionPriority.medium:
          return 2;
        case LitecoinTransactionPriority.fast:
          return 3;
      }
    }

    return 0;
  }

  @override
  Future<int> calcFee({
    required List<UtxoWithAddress> utxos,
    required List<BitcoinBaseOutput> outputs,
    required BasedUtxoNetwork network,
    String? memo,
    required int feeRate,
    List<ECPrivateInfo>? inputPrivKeyInfos,
    List<Outpoint>? vinOutpoints,
  }) async {
    final spendsMweb = utxos.any((utxo) => utxo.utxo.scriptType == SegwitAddresType.mweb);
    final paysToMweb = outputs
        .any((output) => output.toOutput.scriptPubKey.getAddressType() == SegwitAddresType.mweb);
    if (!spendsMweb && !paysToMweb) {
      return await super.calcFee(
        utxos: utxos,
        outputs: outputs,
        network: network,
        memo: memo,
        feeRate: feeRate,
        inputPrivKeyInfos: inputPrivKeyInfos,
        vinOutpoints: vinOutpoints,
      );
    }
    if (outputs.length == 1 && outputs[0].toOutput.amount == BigInt.zero) {
      outputs = [
        BitcoinScriptOutput(
            script: outputs[0].toOutput.scriptPubKey, value: utxos.sumOfUtxosValue())
      ];
    }
    final preOutputSum =
        outputs.fold<BigInt>(BigInt.zero, (acc, output) => acc + output.toOutput.amount);
    final fee = utxos.sumOfUtxosValue() - preOutputSum;
    final txb =
        BitcoinTransactionBuilder(utxos: utxos, outputs: outputs, fee: fee, network: network);
    final resp = await _stub.create(CreateRequest(
        rawTx: txb.buildTransaction((a, b, c, d) => '').toBytes(),
        scanSecret: hex.decode(mwebHd.derive(0x80000000).privKey!),
        spendSecret: hex.decode(mwebHd.derive(0x80000001).privKey!),
        feeRatePerKb: Int64(feeRate * 1000),
        dryRun: true));
    final tx = BtcTransaction.fromRaw(hex.encode(resp.rawTx));
    final posUtxos = utxos
        .where((utxo) => tx.inputs
            .any((input) => input.txId == utxo.utxo.txHash && input.txIndex == utxo.utxo.vout))
        .toList();
    final posOutputSum = tx.outputs.fold<int>(0, (acc, output) => acc + output.amount.toInt());
    final mwebInputSum = utxos.sumOfUtxosValue() - posUtxos.sumOfUtxosValue();
    final expectedPegin = max(0, (preOutputSum - mwebInputSum).toInt());
    var feeIncrease = posOutputSum - expectedPegin;
    if (expectedPegin > 0 && fee == BigInt.zero) {
      feeIncrease += await super.calcFee(
              utxos: posUtxos,
              outputs: tx.outputs
                  .map((output) =>
                      BitcoinScriptOutput(script: output.scriptPubKey, value: output.amount))
                  .toList(),
              network: network,
              memo: memo,
              feeRate: feeRate) +
          feeRate * 41;
    }
    return fee.toInt() + feeIncrease;
  }

  @override
  Future<PendingTransaction> createTransaction(Object credentials) async {
    try {
      final tx = await super.createTransaction(credentials) as PendingBitcoinTransaction;

      final resp = await _stub.create(CreateRequest(
        rawTx: hex.decode(tx.hex),
        scanSecret: hex.decode(mwebHd.derive(0x80000000).privKey!),
        spendSecret: hex.decode(mwebHd.derive(0x80000001).privKey!),
        feeRatePerKb: Int64.parseInt(tx.feeRate) * 1000,
      ));
      final tx2 = BtcTransaction.fromRaw(hex.encode(resp.rawTx));
      tx.hexOverride = tx2
          .copyWith(
              witnesses: tx2.inputs.asMap().entries.map((e) {
            final utxo = unspentCoins
                .firstWhere((utxo) => utxo.hash == e.value.txId && utxo.vout == e.value.txIndex);
            final key = generateECPrivate(
                hd: utxo.bitcoinAddressRecord.isHidden
                    ? walletAddresses.sideHd
                    : walletAddresses.mainHd,
                index: utxo.bitcoinAddressRecord.index,
                network: network);
            final digest = tx2.getTransactionSegwitDigit(
              txInIndex: e.key,
              script: key.getPublic().toP2pkhAddress().toScriptPubKey(),
              amount: BigInt.from(utxo.value),
            );
            return TxWitnessInput(stack: [key.signInput(digest), key.getPublic().toHex()]);
          }).toList())
          .toHex();
      tx.outputs = resp.outputId;
      return tx
        ..addListener((transaction) async {
          final addresses = <String>{};
          transaction.inputAddresses?.forEach((id) async {
            final utxo = mwebUtxosBox.get(id);
            await mwebUtxosBox.delete(id);
            if (utxo == null) return;
            if (!addresses.contains(utxo.address)) {
              addresses.add(utxo.address);
            }
          });
          transaction.inputAddresses?.addAll(addresses);

          transactionHistory.addOne(transaction);
          await updateUnspent();
          await updateBalance();
        });
    } catch (e, s) {
      print(e);
      print(s);
      rethrow;
    }
  }

  @override
  Future<void> save() async {
    await super.save();
  }

  @override
  Future<void> close() async {
    await super.close();
    await mwebUtxosBox.close();
    _syncTimer?.cancel();
  }
}
