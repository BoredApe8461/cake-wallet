import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_core/unspent_transaction_output.dart';

class BitcoinUnspent extends Unspent {
  BitcoinUnspent(BaseBitcoinAddressRecord addressRecord, String hash, int value, int vout,
      {this.silentPaymentTweak, this.type})
      : bitcoinAddressRecord = addressRecord,
        super(addressRecord.address, hash, value, vout, null);

  factory BitcoinUnspent.fromJSON(BaseBitcoinAddressRecord address, Map<String, dynamic> json) =>
      BitcoinUnspent(
        address,
        json['tx_hash'] as String,
        json['value'] as int,
        json['tx_pos'] as int,
        silentPaymentTweak: json['silent_payment_tweak'] as String?,
        type: json['type'] == null
            ? null
            : BitcoinAddressType.values.firstWhere((e) => e.toString() == json['type']),
      );

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'address_record': bitcoinAddressRecord.toJSON(),
      'tx_hash': hash,
      'value': value,
      'tx_pos': vout,
      'silent_payment_tweak': silentPaymentTweak,
      'type': type.toString(),
    };
    return json;
  }

  final BaseBitcoinAddressRecord bitcoinAddressRecord;
  String? silentPaymentTweak;
  BitcoinAddressType? type;
}
