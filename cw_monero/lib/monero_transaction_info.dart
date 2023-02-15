import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/monero_amount_format.dart';
import 'package:cw_monero/api/structs/transaction_info_row.dart';
import 'package:cw_core/parseBoolFromString.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/format_amount.dart';
import 'package:cw_monero/api/transaction_history.dart';
import 'package:intl/intl.dart';

class MoneroTransactionInfo extends TransactionInfo {
  MoneroTransactionInfo(this.id, this.height, this.direction, this.date,
      this.isPending, this.amount, this.accountIndex, this.addressIndex, this.fee, this.unlockTime,
      this.confirmations);

  MoneroTransactionInfo.fromRow(TransactionInfoRow row)
      : id = row.getHash(),
        height = row.blockHeight,
        direction = TransactionDirection.parseFromInt(row.direction),
        date = DateTime.fromMillisecondsSinceEpoch(row.getDatetime() * 1000),
        isPending = row.isPending != 0,
        amount = row.getAmount(),
        accountIndex = row.subaddrAccount,
        addressIndex = row.subaddrIndex,
        unlockTime = row.unlockTime,
        confirmations = row.confirmations,
        key = getTxKey(row.getHash()),
        fee = row.fee {
    additionalInfo = <String, dynamic>{
      'key': key,
      'accountIndex': accountIndex,
      'addressIndex': addressIndex
    };
  }

  final String id;
  final int height;
  final TransactionDirection direction;
  final DateTime date;
  final int accountIndex;
  final bool isPending;
  final int amount;
  final int fee;
  final int addressIndex;
  final int unlockTime;
  final int confirmations;
  String? recipientAddress;
  String? key;
  String? _fiatAmount;

  @override
  String amountFormatted() =>
      '${formatAmount(moneroAmountToString(amount: amount))} XMR';

  @override
  String fiatAmount() => _fiatAmount ?? '';

  @override
  void changeFiatAmount(String amount) => _fiatAmount = formatAmount(amount);

  @override
  String feeFormatted() =>
      '${formatAmount(moneroAmountToString(amount: fee))} XMR';

  @override
  String? unlockTimeFormatted() {
    if (direction == TransactionDirection.outgoing || unlockTime < (height + 10)) {
      return null;
    }

    if (unlockTime < 500000000) {
      return (unlockTime - height) * 2 > 500000
          ? '>1 year'
          : '~${(unlockTime - height) * 2} minutes';
    }

    var locked = DateTime.fromMillisecondsSinceEpoch(unlockTime).compareTo(DateTime.now());
    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final String formattedUnlockTime =
    formatter.format(DateTime.fromMillisecondsSinceEpoch(unlockTime));

    return locked >= 0 ? '$formattedUnlockTime' : null;
  }
}
