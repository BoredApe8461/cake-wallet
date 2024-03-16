import 'package:cw_core/format_amount.dart';
import 'package:cw_core/monero_amount_format.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_zano/api/model/transfer.dart';

class ZanoTransactionInfo extends TransactionInfo {
  ZanoTransactionInfo({
    required this.id,
    required this.height,
    required this.direction,
    required this.date,
    required this.isPending,
    required this.amount,
    required this.accountIndex,
    required this.addressIndex,
    required this.fee,
    required this.assetId,
    required this.confirmations,
    required this.tokenSymbol,
  });

  ZanoTransactionInfo.fromTransfer(Transfer transfer, this.tokenSymbol)
      : id = transfer.txHash,
        height = transfer.height,
        direction = transfer.subtransfers.first.isIncome ? TransactionDirection.incoming : TransactionDirection.outgoing,
        date = DateTime.fromMillisecondsSinceEpoch(transfer.timestamp * 1000),
        isPending = false,
        amount = transfer.subtransfers.first.amount,
        accountIndex = 0,
        addressIndex = 0,
        fee = transfer.fee,
        confirmations = 1,
        assetId = transfer.subtransfers.first.assetId,
        recipientAddress = transfer.remoteAddresses.isNotEmpty ? transfer.remoteAddresses.first : '';

  final String id;
  final int height;
  final TransactionDirection direction;
  final DateTime date;
  final int accountIndex;
  final bool isPending;
  final int amount;
  final int fee;
  final int addressIndex;
  final int confirmations;
  late String recipientAddress;
  final String tokenSymbol;
  late String assetId;
  String? _fiatAmount;
  String? key;

  @override
  String amountFormatted() => '${formatAmount(moneroAmountToString(amount: amount))} $tokenSymbol';

  @override
  String fiatAmount() => _fiatAmount ?? '';

  @override
  void changeFiatAmount(String amount) => _fiatAmount = formatAmount(amount);

  @override
  String feeFormatted() => '${formatAmount(moneroAmountToString(amount: fee))} $feeCurrency';

  String get feeCurrency => 'ZANO';
}
