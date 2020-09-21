import 'package:flutter/foundation.dart';
import 'package:bitcoin_flutter/bitcoin_flutter.dart' as bitcoin;
import 'package:bitcoin_flutter/src/payments/index.dart' show PaymentData;
import 'package:cake_wallet/bitcoin/bitcoin_address_record.dart';
import 'package:cake_wallet/bitcoin/bitcoin_amount_format.dart';
import 'package:cake_wallet/entities/transaction_direction.dart';
import 'package:cake_wallet/entities/transaction_info.dart';
import 'package:cake_wallet/entities/format_amount.dart';

class BitcoinTransactionInfo extends TransactionInfo {
  BitcoinTransactionInfo(
      {@required String id,
      @required int height,
      @required int amount,
      @required TransactionDirection direction,
      @required bool isPending,
      @required DateTime date,
      @required int confirmations}) {
    this.id = id;
    this.height = height;
    this.amount = amount;
    this.direction = direction;
    this.date = date;
    this.isPending = isPending;
    this.confirmations = confirmations;
  }

  factory BitcoinTransactionInfo.fromElectrumVerbose(Map<String, Object> obj,
      {@required List<BitcoinAddressRecord> addresses, @required int height}) {
    final addressesSet = addresses.map((addr) => addr.address).toSet();
    final id = obj['txid'] as String;
    final vins = obj['vin'] as List<Object> ?? [];
    final vout = (obj['vout'] as List<Object> ?? []);
    final date = obj['time'] is int
        ? DateTime.fromMillisecondsSinceEpoch((obj['time'] as int) * 1000)
        : DateTime.now();
    final confirmations = obj['confirmations'] as int ?? 0;
    var direction = TransactionDirection.incoming;

    for (dynamic vin in vins) {
      final vout = vin['vout'] as int;
      final out = vin['tx']['vout'][vout] as Map;
      final outAddresses =
          (out['scriptPubKey']['addresses'] as List<Object>)?.toSet();

      if (outAddresses?.intersection(addressesSet)?.isNotEmpty ?? false) {
        direction = TransactionDirection.outgoing;
        break;
      }
    }

    final amount = vout.fold(0, (int acc, dynamic out) {
      final outAddresses =
          out['scriptPubKey']['addresses'] as List<Object> ?? [];
      final ntrs = outAddresses.toSet().intersection(addressesSet);
      var amount = acc;

      if ((direction == TransactionDirection.incoming && ntrs.isNotEmpty) ||
          (direction == TransactionDirection.outgoing && ntrs.isEmpty)) {
        amount += doubleToBitcoinAmount(out['value'] as double ?? 0.0);
      }

      return amount;
    });

    return BitcoinTransactionInfo(
        id: id,
        height: height,
        isPending: false,
        direction: direction,
        amount: amount,
        date: date,
        confirmations: confirmations);
  }

  factory BitcoinTransactionInfo.fromHexAndHeader(String hex,
      {List<String> addresses, int height, int timestamp, int confirmations}) {
    final tx = bitcoin.Transaction.fromHex(hex);
    var exist = false;
    var amount = 0;

    if (addresses != null) {
      tx.outs.forEach((out) {
        try {
          final p2pkh = bitcoin.P2PKH(
              data: PaymentData(output: out.script), network: bitcoin.bitcoin);
          exist = addresses.contains(p2pkh.data.address);

          if (exist) {
            amount += out.value;
          }
        } catch (_) {}
      });
    }

    final date = timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)
        : DateTime.now();

    return BitcoinTransactionInfo(
        id: tx.getId(),
        height: height,
        isPending: false,
        direction: TransactionDirection.incoming,
        amount: amount,
        date: date,
        confirmations: confirmations);
  }

  factory BitcoinTransactionInfo.fromJson(Map<String, dynamic> data) {
    return BitcoinTransactionInfo(
        id: data['id'] as String,
        height: data['height'] as int,
        amount: data['amount'] as int,
        direction: parseTransactionDirectionFromInt(data['direction'] as int),
        date: DateTime.fromMillisecondsSinceEpoch(data['date'] as int),
        isPending: data['isPending'] as bool,
        confirmations: data['confirmations'] as int);
  }

  String _fiatAmount;

  @override
  String amountFormatted() =>
      '${formatAmount(bitcoinAmountToString(amount: amount))} BTC';

  @override
  String fiatAmount() => _fiatAmount ?? '';

  @override
  void changeFiatAmount(String amount) => _fiatAmount = formatAmount(amount);

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    m['id'] = id;
    m['height'] = height;
    m['amount'] = amount;
    m['direction'] = direction.index;
    m['date'] = date.millisecondsSinceEpoch;
    m['isPending'] = isPending;
    m['confirmations'] = confirmations;
    return m;
  }
}
