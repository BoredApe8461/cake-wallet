import 'package:bitcoin_flutter/bitcoin_flutter.dart' as bitcoin;
import 'package:bitbox/bitbox.dart' as bitbox;
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_bitcoin/electrum_transaction_history.dart';
import 'package:cw_core/wallet_addresses.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:mobx/mobx.dart';

part 'electrum_wallet_addresses.g.dart';

class ElectrumWalletAddresses = ElectrumWalletAddressesBase with _$ElectrumWalletAddresses;

abstract class ElectrumWalletAddressesBase extends WalletAddresses with Store {
  ElectrumWalletAddressesBase(
    WalletInfo walletInfo, {
    required this.mainHd,
    required this.sideHd,
    required this.transactionHistory,
    required this.networkType,
    List<BitcoinAddressRecord>? initialAddresses,
    List<BitcoinAddressRecord>? initialSilentAddresses,
    int initialRegularAddressIndex = 0,
    int initialChangeAddressIndex = 0,
    int initialSilentAddressIndex = 0,
    bitcoin.SilentPaymentReceiver? silentAddress,
  })  : addresses = ObservableList<BitcoinAddressRecord>.of((initialAddresses ?? []).toSet()),
        primarySilentAddress = silentAddress,
        receiveAddresses = ObservableList<BitcoinAddressRecord>.of((initialAddresses ?? [])
            .where((addressRecord) => !addressRecord.isHidden && !addressRecord.isUsed)
            .toSet()),
        changeAddresses = ObservableList<BitcoinAddressRecord>.of((initialAddresses ?? [])
            .where((addressRecord) => addressRecord.isHidden && !addressRecord.isUsed)
            .toSet()),
        silentAddresses = ObservableList<BitcoinAddressRecord>.of((initialSilentAddresses ?? [])
            .where((addressRecord) =>
                addressRecord.silentAddressLabel != null &&
                addressRecord.silentPaymentTweak != null)
            .toSet()),
        currentReceiveAddressIndex = initialRegularAddressIndex,
        currentChangeAddressIndex = initialChangeAddressIndex,
        currentSilentAddressIndex = initialSilentAddressIndex,
        super(walletInfo);

  static const defaultReceiveAddressesCount = 22;
  static const defaultChangeAddressesCount = 17;
  static const gap = 20;

  static String toCashAddr(String address) => bitbox.Address.toCashAddress(address);

  final ObservableList<BitcoinAddressRecord> addresses;
  final ObservableList<BitcoinAddressRecord> receiveAddresses;
  final ObservableList<BitcoinAddressRecord> changeAddresses;
  final ObservableList<BitcoinAddressRecord> silentAddresses;
  final ElectrumTransactionHistory transactionHistory;
  final bitcoin.NetworkType networkType;
  final bitcoin.HDWallet mainHd;
  final bitcoin.HDWallet sideHd;

  final bitcoin.SilentPaymentReceiver? primarySilentAddress;

  @observable
  // ignore: prefer_final_fields
  dynamic _addressPageType = bitcoin.AddressType.p2wpkh;
  @computed
  dynamic get addressPageType => _addressPageType;

  @observable
  String? activeSilentAddress;

  @computed
  String get receiveAddress {
    if (receiveAddresses.isEmpty) {
      final address = generateNewAddress().address;
      return walletInfo.type == WalletType.bitcoinCash ? toCashAddr(address) : address;
    }
    final receiveAddress = receiveAddresses.first.address;

    return walletInfo.type == WalletType.bitcoinCash ? toCashAddr(receiveAddress) : receiveAddress;
  }

  @override
  @computed
  String get address {
    if (addressPageType == bitcoin.AddressType.p2sp) {
      if (activeSilentAddress != null) {
        return activeSilentAddress!;
      }

      return primarySilentAddress!.toString();
    }

    if (receiveAddresses.isEmpty) {
      return generateNewAddress().address;
    }

    try {
      return receiveAddresses
          .firstWhere((address) => addressPageType == bitcoin.AddressType.p2wpkh
              ? address.type == null || address.type == addressPageType
              : address.type == addressPageType)
          .address;
    } catch (_) {}

    return receiveAddresses.first.address;
  }

  @override
  set address(String addr) => activeSilentAddress = addr;

  int currentReceiveAddressIndex;
  int currentChangeAddressIndex;
  int currentSilentAddressIndex;

  @computed
  int get totalCountOfReceiveAddresses => addresses.fold(0, (acc, addressRecord) {
        if (!addressRecord.isHidden) {
          return acc + 1;
        }
        return acc;
      });

  @computed
  int get totalCountOfChangeAddresses => addresses.fold(0, (acc, addressRecord) {
        if (addressRecord.isHidden) {
          return acc + 1;
        }
        return acc;
      });

  Future<void> discoverAddresses() async {
    await _discoverAddresses(mainHd, false);
    await _discoverAddresses(sideHd, true);
    await updateAddressesInBox();
  }

  @override
  Future<void> init() async {
    await _generateInitialAddresses();
    updateReceiveAddresses();
    updateChangeAddresses();
    await updateAddressesInBox();

    if (currentReceiveAddressIndex >= receiveAddresses.length) {
      currentReceiveAddressIndex = 0;
    }

    if (currentChangeAddressIndex >= changeAddresses.length) {
      currentChangeAddressIndex = 0;
    }
  }

  @action
  Future<String> getChangeAddress() async {
    updateChangeAddresses();

    if (changeAddresses.isEmpty) {
      final newAddresses = await _createNewAddresses(gap,
          hd: sideHd,
          startIndex: totalCountOfChangeAddresses > 0 ? totalCountOfChangeAddresses - 1 : 0,
          isHidden: true);
      addAddresses(newAddresses);
    }

    if (currentChangeAddressIndex >= changeAddresses.length) {
      currentChangeAddressIndex = 0;
    }

    updateChangeAddresses();
    final address = changeAddresses[currentChangeAddressIndex].address;
    currentChangeAddressIndex += 1;
    return address;
  }

  Map<String, String> get labels {
    final labels = <String, String>{};
    for (int i = 0; i < silentAddresses.length; i++) {
      final silentAddressRecord = silentAddresses[i];
      final silentAddress =
          bitcoin.SilentPaymentDestination.fromAddress(silentAddressRecord.address, 0)
              .spendPubkey
              .toCompressedHex();

      if (silentAddressRecord.silentPaymentTweak != null)
        labels[silentAddress] = silentAddressRecord.silentPaymentTweak!;
    }
    return labels;
  }

  @action
  BitcoinAddressRecord generateNewAddress(
      {bitcoin.HDWallet? hd, bool isHidden = false, String? label}) {
    if (label != null && primarySilentAddress != null) {
      currentSilentAddressIndex += 1;

      final tweak = currentSilentAddressIndex.toString();

      final address = BitcoinAddressRecord(
        bitcoin.SilentPaymentAddress.createLabeledSilentPaymentAddress(
                primarySilentAddress!.scanPubkey, primarySilentAddress!.spendPubkey, tweak.fromHex,
                hrp: primarySilentAddress!.hrp, version: primarySilentAddress!.version)
            .toString(),
        index: currentSilentAddressIndex,
        isHidden: isHidden,
        silentAddressLabel: label,
        silentPaymentTweak: tweak,
      );

      silentAddresses.add(address);

      return address;
    }

    // FIX-ME: Check logic for whichi HD should be used here  ???
    final address = BitcoinAddressRecord(
        getAddress(
          index: currentReceiveAddressIndex,
          hd: hd ?? sideHd,
          addressType: addressPageType as bitcoin.AddressType,
        ),
        index: currentReceiveAddressIndex,
        isHidden: isHidden);
    addresses.add(address);
    return address;

    currentReceiveAddressIndex += 1;
  }

  String getAddress(
          {required int index, required bitcoin.HDWallet hd, bitcoin.AddressType? addressType}) =>
      '';

  @override
  Future<void> updateAddressesInBox() async {
    try {
      addressesMap.clear();
      addressesMap[address] = '';
      await saveAddressesInBox();
    } catch (e) {
      print(e.toString());
    }
  }

  @action
  void updateReceiveAddresses() {
    receiveAddresses.removeRange(0, receiveAddresses.length);
    final newAdresses =
        addresses.where((addressRecord) => !addressRecord.isHidden && !addressRecord.isUsed);
    receiveAddresses.addAll(newAdresses);
  }

  @action
  void updateChangeAddresses() {
    changeAddresses.removeRange(0, changeAddresses.length);
    final newAdresses =
        addresses.where((addressRecord) => addressRecord.isHidden && !addressRecord.isUsed);
    changeAddresses.addAll(newAdresses);
  }

  @action
  Future<void> _discoverAddresses(bitcoin.HDWallet hd, bool isHidden,
      {bitcoin.AddressType? addressType}) async {
    var hasAddrUse = true;
    List<BitcoinAddressRecord> addrs;

    if (addresses.where((addr) => addr.type == addressPageType).isNotEmpty) {
      addrs = addresses.where((addr) => addr.isHidden == isHidden).toList();
    } else {
      addrs = await _createNewAddresses(
          isHidden ? defaultChangeAddressesCount : defaultReceiveAddressesCount,
          startIndex: 0,
          hd: hd,
          isHidden: isHidden,
          addressType: addressType);
    }

    while (hasAddrUse) {
      final addr = addrs.last.address;
      hasAddrUse = await _hasAddressUsed(addr);

      if (!hasAddrUse) {
        break;
      }

      final start = addrs.length;
      final count = start + gap;
      final batch = await _createNewAddresses(count,
          startIndex: start, hd: hd, isHidden: isHidden, addressType: addressType);
      addrs.addAll(batch);
    }

    if (addresses.length < addrs.length || addressPageType != null) {
      addAddresses(addrs);
    }
  }

  Future<void> _generateInitialAddresses() async {
    var countOfReceiveAddresses = 0;
    var countOfHiddenAddresses = 0;

    addresses.forEach((addr) {
      if (addr.isHidden) {
        countOfHiddenAddresses += 1;
        return;
      }

      countOfReceiveAddresses += 1;
    });

    if (countOfReceiveAddresses < defaultReceiveAddressesCount) {
      final addressesCount = defaultReceiveAddressesCount - countOfReceiveAddresses;
      final newAddresses = await _createNewAddresses(addressesCount,
          startIndex: countOfReceiveAddresses, hd: mainHd, isHidden: false);
      addresses.addAll(newAddresses);
    }

    if (countOfHiddenAddresses < defaultChangeAddressesCount) {
      final addressesCount = defaultChangeAddressesCount - countOfHiddenAddresses;
      final newAddresses = await _createNewAddresses(addressesCount,
          startIndex: countOfHiddenAddresses, hd: sideHd, isHidden: true);
      addresses.addAll(newAddresses);
    }
  }

  Future<List<BitcoinAddressRecord>> _createNewAddresses(int count,
      {required bitcoin.HDWallet hd,
      int startIndex = 0,
      bool isHidden = false,
      bitcoin.AddressType? addressType}) async {
    final list = <BitcoinAddressRecord>[];

    for (var i = startIndex; i < count + startIndex; i++) {
      final address = BitcoinAddressRecord(getAddress(index: i, hd: hd, addressType: addressType),
          index: i, isHidden: isHidden, type: addressType);
      list.add(address);
    }

    return list;
  }

  @action
  void addAddresses(Iterable<BitcoinAddressRecord> addresses) {
    final addressesSet = this.addresses.toSet();
    addressesSet.addAll(addresses);
    this.addresses.removeRange(0, this.addresses.length);
    this.addresses.addAll(addressesSet);
  }

  Future<bool> _hasAddressUsed(String address) async {
    return transactionHistory.transactions.values.any((txInfo) => txInfo.to == address);
  }

  @override
  @action
  Future<void> setAddressType(dynamic type) async {
    _addressPageType = type as bitcoin.AddressType;

    if (addressPageType != bitcoin.AddressType.p2sp) {
      await _discoverAddresses(mainHd, false, addressType: addressPageType as bitcoin.AddressType);
      updateReceiveAddresses();
    }
  }
}
