import 'dart:convert';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_bitcoin/bitcoin_unspent.dart';
import 'package:cw_bitcoin/electrum_balance.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_type.dart';

class ElectrumWalletSnapshot {
  ElectrumWalletSnapshot({
    required this.name,
    required this.type,
    required this.password,
    required this.mnemonic,
    required this.xpub,
    required this.addresses,
    required this.balance,
    required this.regularAddressIndex,
    required this.changeAddressIndex,
    required this.addressPageType,
    required this.silentAddresses,
    required this.silentAddressIndex,
    required this.mwebAddresses,
    required this.alwaysScan,
    required this.unspentCoins,
    this.passphrase,
    this.derivationType,
    this.derivationPath,
  });

  final String name;
  final String password;
  final WalletType type;
  final String? addressPageType;
  List<BitcoinUnspent> unspentCoins;

  @deprecated
  String? mnemonic;

  @deprecated
  String? xpub;

  @deprecated
  String? passphrase;

  List<BitcoinAddressRecord> addresses;
  List<BitcoinSilentPaymentAddressRecord> silentAddresses;
  List<LitecoinMWEBAddressRecord> mwebAddresses;
  bool alwaysScan;

  ElectrumBalance balance;
  Map<String, int> regularAddressIndex;
  Map<String, int> changeAddressIndex;
  int silentAddressIndex;
  DerivationType? derivationType;
  String? derivationPath;

  static Future<ElectrumWalletSnapshot> load(EncryptionFileUtils encryptionFileUtils, String name,
      WalletType type, String password, BasedUtxoNetwork network) async {
    final path = await pathForWallet(name: name, type: type);
    final jsonSource = await encryptionFileUtils.read(path: path, password: password);
    final data = json.decode(jsonSource) as Map;
    final mnemonic = data['mnemonic'] as String?;
    final xpub = data['xpub'] as String?;
    final passphrase = data['passphrase'] as String? ?? '';

    final addressesTmp = data['addresses'] as List? ?? <Object>[];
    final addresses = addressesTmp
        .whereType<String>()
        .map((addr) => BitcoinAddressRecord.fromJSON(addr))
        .toList();

    final silentAddressesTmp = data['silent_addresses'] as List? ?? <Object>[];
    final silentAddresses = silentAddressesTmp.whereType<String>().map((j) {
      final decoded = json.decode(jsonSource) as Map;
      if (decoded['tweak'] != null || decoded['silent_payment_tweak'] != null) {
        return BitcoinReceivedSPAddressRecord.fromJSON(j);
      } else {
        return BitcoinSilentPaymentAddressRecord.fromJSON(j);
      }
    }).toList();

    final mwebAddressTmp = data['mweb_addresses'] as List? ?? <Object>[];
    final mwebAddresses = mwebAddressTmp
        .whereType<String>()
        .map((addr) => LitecoinMWEBAddressRecord.fromJSON(addr))
        .toList();

    final alwaysScan = data['alwaysScan'] as bool? ?? false;

    final balance = ElectrumBalance.fromJSON(data['balance'] as String?) ??
        ElectrumBalance(confirmed: 0, unconfirmed: 0, frozen: 0);
    var regularAddressIndexByType = {SegwitAddressType.p2wpkh.toString(): 0};
    var changeAddressIndexByType = {SegwitAddressType.p2wpkh.toString(): 0};
    var silentAddressIndex = 0;

    final derivationType = DerivationType
        .values[(data['derivationTypeIndex'] as int?) ?? DerivationType.electrum.index];
    final derivationPath = data['derivationPath'] as String? ?? ELECTRUM_PATH;

    try {
      regularAddressIndexByType = {
        SegwitAddressType.p2wpkh.toString(): int.parse(data['account_index'] as String? ?? '0')
      };
      changeAddressIndexByType = {
        SegwitAddressType.p2wpkh.toString():
            int.parse(data['change_address_index'] as String? ?? '0')
      };
      silentAddressIndex = int.parse(data['silent_address_index'] as String? ?? '0');
    } catch (_) {
      try {
        regularAddressIndexByType = data["account_index"] as Map<String, int>? ?? {};
        changeAddressIndexByType = data["change_address_index"] as Map<String, int>? ?? {};
      } catch (_) {}
    }

    return ElectrumWalletSnapshot(
      name: name,
      type: type,
      password: password,
      passphrase: passphrase,
      mnemonic: mnemonic,
      xpub: xpub,
      addresses: addresses,
      balance: balance,
      regularAddressIndex: regularAddressIndexByType,
      changeAddressIndex: changeAddressIndexByType,
      addressPageType: data['address_page_type'] as String?,
      derivationType: derivationType,
      derivationPath: derivationPath,
      silentAddresses: silentAddresses,
      silentAddressIndex: silentAddressIndex,
      mwebAddresses: mwebAddresses,
      alwaysScan: alwaysScan,
      unspentCoins: (data['unspent_coins'] as List)
          .map((e) => BitcoinUnspent.fromJSON(null, e as Map<String, dynamic>))
          .toList(),
    );
  }
}
