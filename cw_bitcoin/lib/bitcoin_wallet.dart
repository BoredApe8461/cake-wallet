import 'dart:async';
import 'dart:convert';

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_bitcoin/bitcoin_transaction_credentials.dart';
import 'package:cw_bitcoin/electrum_worker/methods/methods.dart';
import 'package:cw_bitcoin/exceptions.dart';
import 'package:cw_bitcoin/pending_bitcoin_transaction.dart';
import 'package:cw_bitcoin/psbt_transaction_builder.dart';
import 'package:cw_bitcoin/bitcoin_unspent.dart';
import 'package:cw_bitcoin/electrum_transaction_info.dart';
import 'package:cw_bitcoin/electrum_wallet_addresses.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_bitcoin/electrum_derivations.dart';
import 'package:cw_bitcoin/bitcoin_wallet_addresses.dart';
import 'package:cw_bitcoin/electrum_balance.dart';
import 'package:cw_bitcoin/electrum_wallet.dart';
import 'package:cw_bitcoin/electrum_wallet_snapshot.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_keys_file.dart';
import 'package:hive/hive.dart';
import 'package:ledger_bitcoin/ledger_bitcoin.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';
import 'package:mobx/mobx.dart';

part 'bitcoin_wallet.g.dart';

class BitcoinWallet = BitcoinWalletBase with _$BitcoinWallet;

abstract class BitcoinWalletBase extends ElectrumWallet with Store {
  @observable
  bool nodeSupportsSilentPayments = true;
  @observable
  bool silentPaymentsScanningActive = false;
  @observable
  bool allowedToSwitchNodesForScanning = false;

  BitcoinWalletBase({
    required String password,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required EncryptionFileUtils encryptionFileUtils,
    List<int>? seedBytes,
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
    required bool mempoolAPIEnabled,
    super.hdWallets,
    super.initialUnspentCoins,
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
          currency:
              networkParam == BitcoinNetwork.testnet ? CryptoCurrency.tbtc : CryptoCurrency.btc,
          alwaysScan: alwaysScan,
          mempoolAPIEnabled: mempoolAPIEnabled,
        ) {
    walletAddresses = BitcoinWalletAddresses(
      walletInfo,
      initialAddresses: initialAddresses,
      initialSilentAddresses: initialSilentAddresses,
      network: networkParam ?? network,
      isHardwareWallet: walletInfo.isHardwareWallet,
      hdWallets: hdWallets,
    );

    autorun((_) {
      this.walletAddresses.isEnabledAutoGenerateSubaddress = this.isEnabledAutoGenerateSubaddress;
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
    required bool mempoolAPIEnabled,
  }) async {
    final walletSeedBytes = await WalletSeedBytes.getSeedBytes(walletInfo, mnemonic, passphrase);

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
      seedBytes: walletSeedBytes.seedBytes,
      hdWallets: walletSeedBytes.hdWallets,
      initialRegularAddressIndex: initialRegularAddressIndex,
      initialChangeAddressIndex: initialChangeAddressIndex,
      addressPageType: addressPageType,
      networkParam: network,
      mempoolAPIEnabled: mempoolAPIEnabled,
    );
  }

  static Future<BitcoinWallet> open({
    required String name,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required String password,
    required EncryptionFileUtils encryptionFileUtils,
    required bool alwaysScan,
    required bool mempoolAPIEnabled,
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
    walletInfo.derivationInfo!.derivationPath ??= snp?.derivationPath ?? electrum_path;
    walletInfo.derivationInfo!.derivationType ??= snp?.derivationType ?? DerivationType.electrum;

    List<int>? seedBytes = null;
    final Map<CWBitcoinDerivationType, Bip32Slip10Secp256k1> hdWallets = {};
    final mnemonic = keysData.mnemonic;
    final passphrase = keysData.passphrase;

    if (mnemonic != null) {
      final walletSeedBytes = await WalletSeedBytes.getSeedBytes(walletInfo, mnemonic, passphrase);
      seedBytes = walletSeedBytes.seedBytes;
      hdWallets.addAll(walletSeedBytes.hdWallets);
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
      mempoolAPIEnabled: mempoolAPIEnabled,
      hdWallets: hdWallets,
      initialUnspentCoins: snp?.unspentCoins,
    );
  }

  Future<bool> getNodeIsElectrs() async {
    if (node?.isElectrs != null) {
      return node!.isElectrs!;
    }

    final isNamedElectrs = node?.uri.host.contains("electrs") ?? false;
    if (isNamedElectrs) {
      node!.isElectrs = true;
    }

    final isNamedFulcrum = node!.uri.host.contains("fulcrum");
    if (isNamedFulcrum) {
      node!.isElectrs = false;
    }

    if (node!.isElectrs == null) {
      final version = await sendWorker(ElectrumWorkerGetVersionRequest());

      if (version is List<String> && version.isNotEmpty) {
        final server = version[0];

        if (server.toLowerCase().contains('electrs')) {
          node!.isElectrs = true;
        }
      } else if (version is String && version.toLowerCase().contains('electrs')) {
        node!.isElectrs = true;
      } else {
        node!.isElectrs = false;
      }
    }

    node!.save();
    return node!.isElectrs!;
  }

  Future<bool> getNodeSupportsSilentPayments() async {
    if (node?.supportsSilentPayments != null) {
      return node!.supportsSilentPayments!;
    }

    // As of today (august 2024), only ElectrumRS supports silent payments
    final isElectrs = await getNodeIsElectrs();
    if (!isElectrs) {
      node!.supportsSilentPayments = false;
    }

    if (node!.supportsSilentPayments == null) {
      try {
        final workerResponse = (await sendWorker(ElectrumWorkerCheckTweaksRequest())) as String;
        final tweaksResponse = ElectrumWorkerCheckTweaksResponse.fromJson(
          json.decode(workerResponse) as Map<String, dynamic>,
        );
        final supportsScanning = tweaksResponse.result == true;

        if (supportsScanning) {
          node!.supportsSilentPayments = true;
        } else {
          node!.supportsSilentPayments = false;
        }
      } catch (_) {
        node!.supportsSilentPayments = false;
      }
    }
    node!.save();
    return node!.supportsSilentPayments!;
  }

  LedgerConnection? _ledgerConnection;
  BitcoinLedgerApp? _bitcoinLedgerApp;

  @override
  void setLedgerConnection(LedgerConnection connection) {
    _ledgerConnection = connection;
    _bitcoinLedgerApp = BitcoinLedgerApp(_ledgerConnection!,
        derivationPath: walletInfo.derivationInfo!.derivationPath!);
  }

  @override
  Future<BtcTransaction> buildHardwareWalletTransaction({
    required List<BitcoinBaseOutput> outputs,
    required BigInt fee,
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
          (await getTransactionExpanded(hash: utxo.utxo.txHash)).originalTransaction.toHex();
      final publicKeyAndDerivationPath = publicKeys[utxo.ownerDetails.address.pubKeyHash()]!;

      psbtReadyInputs.add(PSBTReadyUtxoWithAddress(
        utxo: utxo.utxo,
        rawTx: rawTx,
        ownerDetails: utxo.ownerDetails,
        ownerDerivationPath: publicKeyAndDerivationPath.derivationPath,
        ownerMasterFingerprint: masterFingerprint,
        ownerPublicKey: publicKeyAndDerivationPath.publicKey,
      ));
    }

    final psbt =
        PSBTTransactionBuild(inputs: psbtReadyInputs, outputs: outputs, enableRBF: enableRBF);

    final rawHex = await _bitcoinLedgerApp!.signPsbt(psbt: psbt.psbt);
    return BtcTransaction.fromRaw(BytesUtils.toHexString(rawHex));
  }

  @override
  Future<String> signMessage(String message, {String? address = null}) async {
    if (walletInfo.isHardwareWallet) {
      final addressEntry = address != null
          ? walletAddresses.allAddresses.firstWhere((element) => element.address == address)
          : null;
      final index = addressEntry?.index ?? 0;
      final isChange = addressEntry?.isChange == true ? 1 : 0;
      final accountPath = walletInfo.derivationInfo?.derivationPath;
      final derivationPath = accountPath != null ? "$accountPath/$isChange/$index" : null;

      final signature = await _bitcoinLedgerApp!
          .signMessage(message: ascii.encode(message), signDerivationPath: derivationPath);
      return base64Encode(signature);
    }

    return super.signMessage(message, address: address);
  }

  @action
  Future<void> setSilentPaymentsScanning(bool active) async {
    silentPaymentsScanningActive = active;
    final nodeSupportsSilentPayments = await getNodeSupportsSilentPayments();
    final isAllowedToScan = nodeSupportsSilentPayments || allowedToSwitchNodesForScanning;

    if (active && isAllowedToScan) {
      syncStatus = AttemptingScanSyncStatus();

      final tip = currentChainTip!;

      if (tip == walletInfo.restoreHeight) {
        syncStatus = SyncedTipSyncStatus(tip);
        return;
      }

      if (tip > walletInfo.restoreHeight) {
        _setListeners(walletInfo.restoreHeight);
      }
    } else if (syncStatus is! SyncedSyncStatus) {
      await sendWorker(ElectrumWorkerStopScanningRequest());
      await startSync();
    }
  }

  @override
  @action
  Future<void> updateAllUnspents() async {
    List<BitcoinUnspent> updatedUnspentCoins = [];

    unspentCoins.addAll(updatedUnspentCoins);

    await super.updateAllUnspents();

    final walletAddresses = this.walletAddresses as BitcoinWalletAddresses;

    walletAddresses.silentPaymentAddresses.forEach((addressRecord) {
      addressRecord.txCount = 0;
      addressRecord.balance = 0;
    });
    walletAddresses.receivedSPAddresses.forEach((addressRecord) {
      addressRecord.txCount = 0;
      addressRecord.balance = 0;
    });

    final silentPaymentWallet = walletAddresses.silentPaymentWallet;

    unspentCoins.forEach((unspent) {
      if (unspent.bitcoinAddressRecord is BitcoinReceivedSPAddressRecord) {
        _updateSilentAddressRecord(unspent);

        final receiveAddressRecord = unspent.bitcoinAddressRecord as BitcoinReceivedSPAddressRecord;
        final silentPaymentAddress = SilentPaymentAddress(
          version: silentPaymentWallet!.version,
          B_scan: silentPaymentWallet.B_scan,
          B_spend: receiveAddressRecord.labelHex != null
              ? silentPaymentWallet.B_spend.tweakAdd(
                  BigintUtils.fromBytes(
                    BytesUtils.fromHexString(receiveAddressRecord.labelHex!),
                  ),
                )
              : silentPaymentWallet.B_spend,
        );

        walletAddresses.silentPaymentAddresses.forEach((addressRecord) {
          if (addressRecord.address == silentPaymentAddress.toAddress(network)) {
            addressRecord.txCount += 1;
            addressRecord.balance += unspent.value;
          }
        });
        walletAddresses.receivedSPAddresses.forEach((addressRecord) {
          if (addressRecord.address == receiveAddressRecord.address) {
            addressRecord.txCount += 1;
            addressRecord.balance += unspent.value;
          }
        });
      }
    });

    await walletAddresses.updateAddressesInBox();
  }

  @override
  void updateCoin(BitcoinUnspent coin) {
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
      addCoinInfo(coin);
    }
  }

  @action
  @override
  Future<void> startSync() async {
    await _setInitialScanHeight();

    await super.startSync();

    if (alwaysScan == true) {
      _setListeners(walletInfo.restoreHeight);
    }
  }

  @action
  @override
  Future<void> rescan({required int height, bool? doSingleScan}) async {
    silentPaymentsScanningActive = true;
    _setListeners(height, doSingleScan: doSingleScan);
  }

  // @action
  // Future<void> registerSilentPaymentsKey(bool register) async {
  //   silentPaymentsScanningActive = active;

  //   if (active) {
  //     syncStatus = AttemptingScanSyncStatus();

  //     final tip = await getUpdatedChainTip();

  //     if (tip == walletInfo.restoreHeight) {
  //       syncStatus = SyncedTipSyncStatus(tip);
  //       return;
  //     }

  //     if (tip > walletInfo.restoreHeight) {
  //       _setListeners(walletInfo.restoreHeight, chainTipParam: _currentChainTip);
  //     }
  //   } else {
  //     alwaysScan = false;

  //     _isolate?.then((value) => value.kill(priority: Isolate.immediate));

  //     if (electrumClient.isConnected) {
  //       syncStatus = SyncedSyncStatus();
  //     } else {
  //       syncStatus = NotConnectedSyncStatus();
  //     }
  //   }
  // }

  @action
  Future<void> registerSilentPaymentsKey() async {
    // final registered = await electrumClient.tweaksRegister(
    //   secViewKey: walletAddresses.silentAddress!.b_scan.toHex(),
    //   pubSpendKey: walletAddresses.silentAddress!.B_spend.toHex(),
    //   labels: walletAddresses.silentAddresses
    //       .where((addr) => addr.type == SilentPaymentsAddresType.p2sp && addr.labelIndex >= 1)
    //       .map((addr) => addr.labelIndex)
    //       .toList(),
    // );

    // printV("registered: $registered");
  }

  @action
  void _updateSilentAddressRecord(BitcoinUnspent unspent) {
    final walletAddresses = this.walletAddresses as BitcoinWalletAddresses;
    walletAddresses.addReceivedSPAddresses(
      [unspent.bitcoinAddressRecord as BitcoinReceivedSPAddressRecord],
    );
  }

  @override
  @action
  Future<void> handleWorkerResponse(dynamic message) async {
    super.handleWorkerResponse(message);

    Map<String, dynamic> messageJson;
    if (message is String) {
      messageJson = jsonDecode(message) as Map<String, dynamic>;
    } else {
      messageJson = message as Map<String, dynamic>;
    }
    final workerMethod = messageJson['method'] as String;
    final workerError = messageJson['error'] as String?;

    switch (workerMethod) {
      case ElectrumRequestMethods.tweaksSubscribeMethod:
        if (workerError != null) {
          printV(messageJson);
          // _onConnectionStatusChange(ConnectionStatus.failed);
          break;
        }

        final response = ElectrumWorkerTweaksSubscribeResponse.fromJson(messageJson);
        onTweaksSyncResponse(response.result);
        break;
    }
  }

  @action
  Future<void> onTweaksSyncResponse(TweaksSyncResponse result) async {
    if (result.transactions?.isNotEmpty == true) {
      (walletAddresses as BitcoinWalletAddresses).silentPaymentAddresses.forEach((addressRecord) {
        addressRecord.txCount = 0;
        addressRecord.balance = 0;
      });
      (walletAddresses as BitcoinWalletAddresses).receivedSPAddresses.forEach((addressRecord) {
        addressRecord.txCount = 0;
        addressRecord.balance = 0;
      });

      for (final map in result.transactions!.entries) {
        final txid = map.key;
        final data = map.value;
        final tx = data.txInfo;
        final unspents = data.unspents;

        if (unspents.isNotEmpty) {
          final existingTxInfo = transactionHistory.transactions[txid];
          final txAlreadyExisted = existingTxInfo != null;

          // Updating tx after re-scanned
          if (txAlreadyExisted) {
            existingTxInfo.amount = tx.amount;
            existingTxInfo.confirmations = tx.confirmations;
            existingTxInfo.height = tx.height;

            final newUnspents = unspents
                .where(
                  (unspent) => !unspentCoins.any((element) =>
                      element.hash.contains(unspent.hash) &&
                      element.vout == unspent.vout &&
                      element.value == unspent.value),
                )
                .toList();

            if (newUnspents.isNotEmpty) {
              newUnspents.forEach(_updateSilentAddressRecord);

              unspentCoins.addAll(newUnspents);
              unspentCoins.forEach(updateCoin);

              await refreshUnspentCoinsInfo();

              final newAmount = newUnspents.length > 1
                  ? newUnspents.map((e) => e.value).reduce((value, unspent) => value + unspent)
                  : newUnspents[0].value;

              if (existingTxInfo.direction == TransactionDirection.incoming) {
                existingTxInfo.amount += newAmount;
              }

              // Updates existing TX
              transactionHistory.addOne(existingTxInfo);
              // Update balance record
              balance[currency]!.confirmed += newAmount;
            }
          } else {
            // else: First time seeing this TX after scanning
            unspentCoins.forEach(_updateSilentAddressRecord);

            transactionHistory.addOne(tx);
            balance[currency]!.confirmed += tx.amount;
          }

          await updateAllUnspents();
        }
      }
    }

    final newSyncStatus = result.syncStatus;

    if (newSyncStatus != null) {
      if (newSyncStatus is UnsupportedSyncStatus) {
        nodeSupportsSilentPayments = false;
      }

      if (newSyncStatus is SyncingSyncStatus) {
        syncStatus = SyncingSyncStatus(newSyncStatus.blocksLeft, newSyncStatus.ptc);
      } else {
        syncStatus = newSyncStatus;

        if (newSyncStatus is SyncedSyncStatus) {
          silentPaymentsScanningActive = false;
        }
      }

      final height = result.height;
      if (height != null) {
        await walletInfo.updateRestoreHeight(height);
      }
    }
  }

  @action
  Future<void> _setListeners(int height, {bool? doSingleScan}) async {
    if (currentChainTip == null) {
      throw Exception("currentChainTip is null");
    }

    final chainTip = currentChainTip!;

    if (chainTip == height) {
      syncStatus = SyncedSyncStatus();
      return;
    }

    syncStatus = AttemptingScanSyncStatus();

    final walletAddresses = this.walletAddresses as BitcoinWalletAddresses;
    workerSendPort!.send(
      ElectrumWorkerTweaksSubscribeRequest(
        scanData: ScanData(
          silentPaymentsWallets: walletAddresses.silentPaymentWallets,
          network: network,
          height: height,
          chainTip: chainTip,
          transactionHistoryIds: transactionHistory.transactions.keys.toList(),
          labels: walletAddresses.labels,
          labelIndexes: walletAddresses.silentPaymentAddresses
              .where((addr) => addr.type == SilentPaymentsAddresType.p2sp && addr.labelIndex >= 1)
              .map((addr) => addr.labelIndex)
              .toList(),
          isSingleScan: doSingleScan ?? false,
          shouldSwitchNodes:
              !(await getNodeSupportsSilentPayments()) && allowedToSwitchNodesForScanning,
        ),
      ).toJson(),
    );
  }

  @override
  @action
  Future<Map<String, ElectrumTransactionInfo>> fetchTransactions() async {
    throw UnimplementedError();
    // try {
    //   final Map<String, ElectrumTransactionInfo> historiesWithDetails = {};

    //   await Future.wait(
    //     BITCOIN_ADDRESS_TYPES.map(
    //       (type) => fetchTransactionsForAddressType(historiesWithDetails, type),
    //     ),
    //   );

    //   transactionHistory.transactions.values.forEach((tx) async {
    //     final isPendingSilentPaymentUtxo =
    //         (tx.isPending || tx.confirmations == 0) && historiesWithDetails[tx.id] == null;

    //     if (isPendingSilentPaymentUtxo) {
    //       final info = await fetchTransactionInfo(hash: tx.id, height: tx.height);

    //       if (info != null) {
    //         tx.confirmations = info.confirmations;
    //         tx.isPending = tx.confirmations == 0;
    //         transactionHistory.addOne(tx);
    //         await transactionHistory.save();
    //       }
    //     }
    //   });

    //   return historiesWithDetails;
    // } catch (e) {
    //   printV("fetchTransactions $e");
    //   return {};
    // }
  }

  @override
  int get dustAmount => network == BitcoinNetwork.testnet ? 0 : 546;

  @override
  @action
  Future<void> updateTransactions([List<BitcoinAddressRecord>? addresses]) async {
    super.updateTransactions();

    // transactionHistory.transactions.values.forEach((tx) {
    //   if (tx.unspents != null &&
    //       tx.unspents!.isNotEmpty &&
    //       tx.height != null &&
    //       tx.height! > 0 &&
    //       (currentChainTip ?? 0) > 0) {
    //     tx.confirmations = currentChainTip! - tx.height! + 1;
    //   }
    // });
  }

  // @action
  // Future<ElectrumBalance> fetchBalances() async {
  //   final balance = await super.fetchBalances();

  //   int totalFrozen = balance.frozen;
  //   int totalConfirmed = balance.confirmed;

  //   // Add values from unspent coins that are not fetched by the address list
  //   // i.e. scanned silent payments
  //   transactionHistory.transactions.values.forEach((tx) {
  //     if (tx.unspents != null) {
  //       tx.unspents!.forEach((unspent) {
  //         if (unspent.bitcoinAddressRecord is BitcoinSilentPaymentAddressRecord) {
  //           if (unspent.isFrozen) totalFrozen += unspent.value;
  //           totalConfirmed += unspent.value;
  //         }
  //       });
  //     }
  //   });

  //   return ElectrumBalance(
  //     confirmed: totalConfirmed,
  //     unconfirmed: balance.unconfirmed,
  //     frozen: totalFrozen,
  //   );
  // }

  @override
  @action
  Future<void> onHeadersResponse(ElectrumHeaderResponse response) async {
    super.onHeadersResponse(response);

    _setInitialScanHeight();

    // New headers received, start scanning
    if (alwaysScan == true && syncStatus is SyncedSyncStatus) {
      _setListeners(walletInfo.restoreHeight);
    }
  }

  Future<void> _setInitialScanHeight() async {
    final validChainTip = currentChainTip != null && currentChainTip != 0;
    if (validChainTip && walletInfo.restoreHeight == 0) {
      await walletInfo.updateRestoreHeight(currentChainTip!);
    }
  }

  @override
  @action
  void syncStatusReaction(SyncStatus syncStatus) {
    switch (syncStatus.runtimeType) {
      case SyncingSyncStatus:
        return;
      case SyncedTipSyncStatus:
        silentPaymentsScanningActive = false;

        // Message is shown on the UI for 3 seconds, then reverted to synced
        Timer(Duration(seconds: 3), () {
          if (this.syncStatus is SyncedTipSyncStatus) this.syncStatus = SyncedSyncStatus();
        });
        break;
      default:
        super.syncStatusReaction(syncStatus);
    }
  }

  @override
  int calcFee({
    required List<UtxoWithAddress> utxos,
    required List<BitcoinBaseOutput> outputs,
    String? memo,
    required int feeRate,
    List<ECPrivateInfo>? inputPrivKeyInfos,
    List<Outpoint>? vinOutpoints,
  }) =>
      feeRate *
      BitcoinTransactionBuilder.estimateTransactionSize(
        utxos: utxos,
        outputs: outputs,
        network: network,
        memo: memo,
        inputPrivKeyInfos: inputPrivKeyInfos,
        vinOutpoints: vinOutpoints,
      );

  @override
  TxCreateUtxoDetails createUTXOS({
    required bool sendAll,
    bool paysToSilentPayment = false,
    int credentialsAmount = 0,
    int? inputsCount,
  }) {
    List<UtxoWithAddress> utxos = [];
    List<Outpoint> vinOutpoints = [];
    List<ECPrivateInfo> inputPrivKeyInfos = [];
    final publicKeys = <String, PublicKeyWithDerivationPath>{};
    int allInputsAmount = 0;
    bool spendsSilentPayment = false;
    bool spendsUnconfirmedTX = false;

    int leftAmount = credentialsAmount;
    var availableInputs = unspentCoins.where((utx) {
      // TODO: unspent coin isSending not toggled
      if (!utx.isSending || utx.isFrozen) {
        return false;
      }
      return true;
    }).toList();
    final unconfirmedCoins = availableInputs.where((utx) => utx.confirmations == 0).toList();

    for (int i = 0; i < availableInputs.length; i++) {
      final utx = availableInputs[i];
      if (!spendsUnconfirmedTX) spendsUnconfirmedTX = utx.confirmations == 0;

      if (paysToSilentPayment) {
        // Check inputs for shared secret derivation
        if (utx.bitcoinAddressRecord.type == SegwitAddresType.p2wsh) {
          throw BitcoinTransactionSilentPaymentsNotSupported();
        }
      }

      allInputsAmount += utx.value;
      leftAmount = leftAmount - utx.value;

      final address = RegexUtils.addressTypeFromStr(utx.address, network);
      ECPrivate? privkey;
      bool? isSilentPayment = false;

      if (utx.bitcoinAddressRecord is BitcoinSilentPaymentAddressRecord) {
        privkey = (utx.bitcoinAddressRecord as BitcoinReceivedSPAddressRecord).getSpendKey(
          (walletAddresses as BitcoinWalletAddresses).silentPaymentWallets,
          network,
        );
        spendsSilentPayment = true;
        isSilentPayment = true;
      } else if (!isHardwareWallet) {
        final addressRecord = (utx.bitcoinAddressRecord as BitcoinAddressRecord);
        final path = addressRecord.derivationInfo.derivationPath
            .addElem(Bip32KeyIndex(
              BitcoinAddressUtils.getAccountFromChange(addressRecord.isChange),
            ))
            .addElem(Bip32KeyIndex(addressRecord.index));

        privkey = ECPrivate.fromBip32(bip32: bip32.derive(path));
      }

      vinOutpoints.add(Outpoint(txid: utx.hash, index: utx.vout));
      String pubKeyHex;

      if (privkey != null) {
        inputPrivKeyInfos.add(ECPrivateInfo(
          privkey,
          address.type == SegwitAddresType.p2tr,
          tweak: !isSilentPayment,
        ));

        pubKeyHex = privkey.getPublic().toHex();
      } else {
        pubKeyHex = walletAddresses.hdWallet
            .childKey(Bip32KeyIndex(utx.bitcoinAddressRecord.index))
            .publicKey
            .toHex();
      }

      if (utx.bitcoinAddressRecord is BitcoinAddressRecord) {
        final derivationPath = (utx.bitcoinAddressRecord as BitcoinAddressRecord)
            .derivationInfo
            .derivationPath
            .toString();
        publicKeys[address.pubKeyHash()] = PublicKeyWithDerivationPath(pubKeyHex, derivationPath);
      }

      utxos.add(
        UtxoWithAddress(
          utxo: BitcoinUtxo(
            txHash: utx.hash,
            value: BigInt.from(utx.value),
            vout: utx.vout,
            scriptType: BitcoinAddressUtils.getScriptType(address),
            isSilentPayment: isSilentPayment,
          ),
          ownerDetails: UtxoAddressDetails(
            publicKey: pubKeyHex,
            address: address,
          ),
        ),
      );

      // sendAll continues for all inputs
      if (!sendAll) {
        bool amountIsAcquired = leftAmount <= 0;
        if ((inputsCount == null && amountIsAcquired) || inputsCount == i + 1) {
          break;
        }
      }
    }

    if (utxos.isEmpty) {
      throw BitcoinTransactionNoInputsException();
    }

    return TxCreateUtxoDetails(
      availableInputs: availableInputs,
      unconfirmedCoins: unconfirmedCoins,
      utxos: utxos,
      vinOutpoints: vinOutpoints,
      inputPrivKeyInfos: inputPrivKeyInfos,
      publicKeys: publicKeys,
      allInputsAmount: allInputsAmount,
      spendsSilentPayment: spendsSilentPayment,
      spendsUnconfirmedTX: spendsUnconfirmedTX,
    );
  }

  @override
  Future<EstimatedTxResult> estimateSendAllTx(
    List<BitcoinOutput> outputs,
    int feeRate, {
    String? memo,
    bool hasSilentPayment = false,
  }) async {
    final utxoDetails = createUTXOS(sendAll: true, paysToSilentPayment: hasSilentPayment);

    int fee = await calcFee(
      utxos: utxoDetails.utxos,
      outputs: outputs,
      memo: memo,
      feeRate: feeRate,
      inputPrivKeyInfos: utxoDetails.inputPrivKeyInfos,
      vinOutpoints: utxoDetails.vinOutpoints,
    );

    if (fee == 0) {
      throw BitcoinTransactionNoFeeException();
    }

    // Here, when sending all, the output amount equals to the input value - fee to fully spend every input on the transaction and have no amount left for change
    int amount = utxoDetails.allInputsAmount - fee;

    if (amount <= 0) {
      throw BitcoinTransactionWrongBalanceException(amount: utxoDetails.allInputsAmount + fee);
    }

    // Attempting to send less than the dust limit
    if (isBelowDust(amount)) {
      throw BitcoinTransactionNoDustException();
    }

    if (outputs.length == 1) {
      outputs[0] = BitcoinOutput(address: outputs.last.address, value: BigInt.from(amount));
    }

    return EstimatedTxResult(
      utxos: utxoDetails.utxos,
      inputPrivKeyInfos: utxoDetails.inputPrivKeyInfos,
      publicKeys: utxoDetails.publicKeys,
      fee: fee,
      amount: amount,
      isSendAll: true,
      hasChange: false,
      memo: memo,
      spendsUnconfirmedTX: utxoDetails.spendsUnconfirmedTX,
      spendsSilentPayment: utxoDetails.spendsSilentPayment,
    );
  }

  @override
  Future<EstimatedTxResult> estimateTxForAmount(
    int credentialsAmount,
    List<BitcoinOutput> outputs,
    int feeRate, {
    List<BitcoinOutput>? updatedOutputs,
    int? inputsCount,
    String? memo,
    bool? useUnconfirmed,
    bool hasSilentPayment = false,
    bool isFakeTx = false,
  }) async {
    if (updatedOutputs == null) {
      updatedOutputs = outputs.map((output) => output).toList();
    }

    // Attempting to send less than the dust limit
    if (!isFakeTx && isBelowDust(credentialsAmount)) {
      throw BitcoinTransactionNoDustException();
    }

    final utxoDetails = createUTXOS(
      sendAll: false,
      credentialsAmount: credentialsAmount,
      inputsCount: inputsCount,
      paysToSilentPayment: hasSilentPayment,
    );

    final spendingAllCoins = utxoDetails.availableInputs.length == utxoDetails.utxos.length;
    final spendingAllConfirmedCoins = !utxoDetails.spendsUnconfirmedTX &&
        utxoDetails.utxos.length ==
            utxoDetails.availableInputs.length - utxoDetails.unconfirmedCoins.length;

    // How much is being spent - how much is being sent
    int amountLeftForChangeAndFee = utxoDetails.allInputsAmount - credentialsAmount;

    if (amountLeftForChangeAndFee <= 0) {
      if (!spendingAllCoins) {
        return estimateTxForAmount(
          credentialsAmount,
          outputs,
          feeRate,
          updatedOutputs: updatedOutputs,
          inputsCount: utxoDetails.utxos.length + 1,
          memo: memo,
          hasSilentPayment: hasSilentPayment,
          isFakeTx: isFakeTx,
        );
      }

      throw BitcoinTransactionWrongBalanceException();
    }

    final changeAddress = await walletAddresses.getChangeAddress(
      inputs: utxoDetails.availableInputs,
      outputs: updatedOutputs,
    );
    final address = RegexUtils.addressTypeFromStr(changeAddress.address, network);
    updatedOutputs.add(BitcoinOutput(
      address: address,
      value: BigInt.from(amountLeftForChangeAndFee),
      isChange: true,
    ));
    outputs.add(BitcoinOutput(
      address: address,
      value: BigInt.from(amountLeftForChangeAndFee),
      isChange: true,
    ));

    // Get Derivation path for change Address since it is needed in Litecoin and BitcoinCash hardware Wallets
    final changeDerivationPath =
        (changeAddress as BitcoinAddressRecord).derivationInfo.derivationPath.toString();
    utxoDetails.publicKeys[address.pubKeyHash()] =
        PublicKeyWithDerivationPath('', changeDerivationPath);

    // calcFee updates the silent payment outputs to calculate the tx size accounting
    // for taproot addresses, but if more inputs are needed to make up for fees,
    // the silent payment outputs need to be recalculated for the new inputs
    var temp = outputs.map((output) => output).toList();
    int fee = calcFee(
      utxos: utxoDetails.utxos,
      // Always take only not updated bitcoin outputs here so for every estimation
      // the SP outputs are re-generated to the proper taproot addresses
      outputs: temp,
      memo: memo,
      feeRate: feeRate,
      inputPrivKeyInfos: utxoDetails.inputPrivKeyInfos,
      vinOutpoints: utxoDetails.vinOutpoints,
    );

    updatedOutputs.clear();
    updatedOutputs.addAll(temp);

    if (fee == 0) {
      throw BitcoinTransactionNoFeeException();
    }

    int amount = credentialsAmount;
    final lastOutput = updatedOutputs.last;
    final amountLeftForChange = amountLeftForChangeAndFee - fee;

    if (!isFakeTx && isBelowDust(amountLeftForChange)) {
      // If has change that is lower than dust, will end up with tx rejected by network rules
      // so remove the change amount
      updatedOutputs.removeLast();
      outputs.removeLast();

      if (amountLeftForChange < 0) {
        if (!spendingAllCoins) {
          return estimateTxForAmount(
            credentialsAmount,
            outputs,
            feeRate,
            updatedOutputs: updatedOutputs,
            inputsCount: utxoDetails.utxos.length + 1,
            memo: memo,
            useUnconfirmed: useUnconfirmed ?? spendingAllConfirmedCoins,
            hasSilentPayment: hasSilentPayment,
            isFakeTx: isFakeTx,
          );
        } else {
          throw BitcoinTransactionWrongBalanceException();
        }
      }

      return EstimatedTxResult(
        utxos: utxoDetails.utxos,
        inputPrivKeyInfos: utxoDetails.inputPrivKeyInfos,
        publicKeys: utxoDetails.publicKeys,
        fee: fee,
        amount: amount,
        hasChange: false,
        isSendAll: spendingAllCoins,
        memo: memo,
        spendsUnconfirmedTX: utxoDetails.spendsUnconfirmedTX,
        spendsSilentPayment: utxoDetails.spendsSilentPayment,
      );
    } else {
      // Here, lastOutput already is change, return the amount left without the fee to the user's address.
      updatedOutputs[updatedOutputs.length - 1] = BitcoinOutput(
        address: lastOutput.address,
        value: BigInt.from(amountLeftForChange),
        isSilentPayment: lastOutput.isSilentPayment,
        isChange: true,
      );
      outputs[outputs.length - 1] = BitcoinOutput(
        address: lastOutput.address,
        value: BigInt.from(amountLeftForChange),
        isSilentPayment: lastOutput.isSilentPayment,
        isChange: true,
      );

      return EstimatedTxResult(
        utxos: utxoDetails.utxos,
        inputPrivKeyInfos: utxoDetails.inputPrivKeyInfos,
        publicKeys: utxoDetails.publicKeys,
        fee: fee,
        amount: amount,
        hasChange: true,
        isSendAll: spendingAllCoins,
        memo: memo,
        spendsUnconfirmedTX: utxoDetails.spendsUnconfirmedTX,
        spendsSilentPayment: utxoDetails.spendsSilentPayment,
      );
    }
  }

  @override
  Future<PendingTransaction> createTransaction(Object credentials) async {
    try {
      final outputs = <BitcoinOutput>[];
      final transactionCredentials = credentials as BitcoinTransactionCredentials;
      final hasMultiDestination = transactionCredentials.outputs.length > 1;
      final sendAll = !hasMultiDestination && transactionCredentials.outputs.first.sendAll;
      final memo = transactionCredentials.outputs.first.memo;

      int credentialsAmount = 0;
      bool hasSilentPayment = false;

      for (final out in transactionCredentials.outputs) {
        final outputAmount = out.formattedCryptoAmount!;

        if (!sendAll && isBelowDust(outputAmount)) {
          throw BitcoinTransactionNoDustException();
        }

        if (hasMultiDestination) {
          if (out.sendAll) {
            throw BitcoinTransactionWrongBalanceException();
          }
        }

        credentialsAmount += outputAmount;

        final address = RegexUtils.addressTypeFromStr(
            out.isParsedAddress ? out.extractedAddress! : out.address, network);
        final isSilentPayment = address is SilentPaymentAddress;

        if (isSilentPayment) {
          hasSilentPayment = true;
        }

        if (sendAll) {
          // The value will be changed after estimating the Tx size and deducting the fee from the total to be sent
          outputs.add(BitcoinOutput(
            address: address,
            value: BigInt.from(0),
            isSilentPayment: isSilentPayment,
          ));
        } else {
          outputs.add(BitcoinOutput(
            address: address,
            value: BigInt.from(outputAmount),
            isSilentPayment: isSilentPayment,
          ));
        }
      }

      final feeRateInt = transactionCredentials.feeRate != null
          ? transactionCredentials.feeRate!
          : feeRate(transactionCredentials.priority!);

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
          updatedOutputs,
          feeRateInt,
          memo: memo,
          hasSilentPayment: hasSilentPayment,
        );
      } else {
        estimatedTx = await estimateTxForAmount(
          credentialsAmount,
          outputs,
          feeRateInt,
          updatedOutputs: updatedOutputs,
          memo: memo,
          hasSilentPayment: hasSilentPayment,
        );
      }

      if (walletInfo.isHardwareWallet) {
        final transaction = await buildHardwareWalletTransaction(
          utxos: estimatedTx.utxos,
          outputs: updatedOutputs,
          publicKeys: estimatedTx.publicKeys,
          fee: BigInt.from(estimatedTx.fee),
          memo: estimatedTx.memo,
          outputOrdering: BitcoinOrdering.none,
          enableRBF: true,
        );

        return PendingBitcoinTransaction(
          transaction,
          type,
          sendWorker: sendWorker,
          amount: estimatedTx.amount,
          fee: estimatedTx.fee,
          feeRate: feeRateInt.toString(),
          hasChange: estimatedTx.hasChange,
          isSendAll: estimatedTx.isSendAll,
          hasTaprootInputs: false, // ToDo: (Konsti) Support Taproot
        )..addListener((transaction) async {
            transactionHistory.addOne(transaction);
            await updateBalance();
          });
      }

      final txb = BitcoinTransactionBuilder(
        utxos: estimatedTx.utxos,
        outputs: updatedOutputs,
        fee: BigInt.from(estimatedTx.fee),
        network: network,
        memo: estimatedTx.memo,
        outputOrdering: BitcoinOrdering.none,
        enableRBF: !estimatedTx.spendsUnconfirmedTX,
      );

      bool hasTaprootInputs = false;

      final transaction = txb.buildTransaction((txDigest, utxo, publicKey, sighash) {
        String error = "Cannot find private key.";

        ECPrivateInfo? key;

        if (estimatedTx.inputPrivKeyInfos.isEmpty) {
          error += "\nNo private keys generated.";
        } else {
          error += "\nAddress: ${utxo.ownerDetails.address.toAddress(network)}";

          try {
            key = estimatedTx.inputPrivKeyInfos.firstWhere((element) {
              final elemPubkey = element.privkey.getPublic().toHex();
              if (elemPubkey == publicKey) {
                return true;
              } else {
                error += "\nExpected: $publicKey";
                error += "\nPubkey: $elemPubkey";
                return false;
              }
            });
          } catch (_) {
            throw Exception(error);
          }
        }

        if (key == null) {
          throw Exception(error);
        }

        if (utxo.utxo.isP2tr()) {
          hasTaprootInputs = true;
          return key.privkey.signTapRoot(
            txDigest,
            sighash: sighash,
            tweak: utxo.utxo.isSilentPayment != true,
          );
        } else {
          return key.privkey.signInput(txDigest, sigHash: sighash);
        }
      });

      return PendingBitcoinTransaction(
        transaction,
        type,
        sendWorker: sendWorker,
        amount: estimatedTx.amount,
        fee: estimatedTx.fee,
        feeRate: feeRateInt.toString(),
        hasChange: estimatedTx.hasChange,
        isSendAll: estimatedTx.isSendAll,
        hasTaprootInputs: hasTaprootInputs,
        utxos: estimatedTx.utxos,
        hasSilentPayment: hasSilentPayment,
      )..addListener((transaction) async {
          transactionHistory.addOne(transaction);
          if (estimatedTx.spendsSilentPayment) {
            transactionHistory.transactions.values.forEach((tx) {
              // tx.unspents?.removeWhere(
              //     (unspent) => estimatedTx.utxos.any((e) => e.utxo.txHash == unspent.hash));
              transactionHistory.addOne(tx);
            });
          }

          unspentCoins
              .removeWhere((utxo) => estimatedTx.utxos.any((e) => e.utxo.txHash == utxo.hash));

          await updateBalance();
        });
    } catch (e) {
      throw e;
    }
  }
}

class WalletSeedBytes {
  final List<int> seedBytes;
  final Map<CWBitcoinDerivationType, Bip32Slip10Secp256k1> hdWallets;

  WalletSeedBytes({required this.seedBytes, required this.hdWallets});

  static Future<WalletSeedBytes> getSeedBytes(
    WalletInfo walletInfo,
    String mnemonic, [
    String? passphrase,
  ]) async {
    List<int>? seedBytes = null;
    final Map<CWBitcoinDerivationType, Bip32Slip10Secp256k1> hdWallets = {};

    if (walletInfo.isRecovery) {
      for (final derivation in walletInfo.derivations ?? <DerivationInfo>[]) {
        if (derivation.derivationType == DerivationType.bip39) {
          try {
            seedBytes = Bip39SeedGenerator.generateFromString(mnemonic, passphrase);
            hdWallets[CWBitcoinDerivationType.bip39] = Bip32Slip10Secp256k1.fromSeed(seedBytes);
          } catch (e) {
            printV("bip39 seed error: $e");
          }

          continue;
        }

        if (derivation.derivationType == DerivationType.electrum) {
          try {
            seedBytes = ElectrumV2SeedGenerator.generateFromString(mnemonic, passphrase);
            hdWallets[CWBitcoinDerivationType.electrum] = Bip32Slip10Secp256k1.fromSeed(seedBytes);
          } catch (e) {
            printV("electrum_v2 seed error: $e");

            try {
              seedBytes = ElectrumV1SeedGenerator(mnemonic).generate();
              hdWallets[CWBitcoinDerivationType.electrum] =
                  Bip32Slip10Secp256k1.fromSeed(seedBytes);
            } catch (e) {
              printV("electrum_v1 seed error: $e");
            }
          }
        }
      }

      if (hdWallets[CWBitcoinDerivationType.bip39] != null) {
        hdWallets[CWBitcoinDerivationType.old_bip39] = hdWallets[CWBitcoinDerivationType.bip39]!;
      }
      if (hdWallets[CWBitcoinDerivationType.electrum] != null) {
        hdWallets[CWBitcoinDerivationType.old_electrum] =
            hdWallets[CWBitcoinDerivationType.electrum]!;
      }
    }

    switch (walletInfo.derivationInfo?.derivationType) {
      case DerivationType.bip39:
        seedBytes = await Bip39SeedGenerator.generateFromString(mnemonic, passphrase);
        hdWallets[CWBitcoinDerivationType.bip39] = Bip32Slip10Secp256k1.fromSeed(seedBytes);
        break;
      case DerivationType.electrum:
      default:
        seedBytes = await ElectrumV2SeedGenerator.generateFromString(mnemonic, passphrase);
        hdWallets[CWBitcoinDerivationType.electrum] = Bip32Slip10Secp256k1.fromSeed(seedBytes);
        break;
    }

    return WalletSeedBytes(seedBytes: seedBytes, hdWallets: hdWallets);
  }
}
