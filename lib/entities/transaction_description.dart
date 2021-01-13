import 'package:hive/hive.dart';

part 'transaction_description.g.dart';

@HiveType(typeId: 2)
class TransactionDescription extends HiveObject {
  TransactionDescription({this.id, this.recipientAddress, this.transactionNote});

  static const boxName = 'TransactionDescriptions';
  static const boxKey = 'transactionDescriptionsBoxKey';

  @HiveField(0)
  String id;

  @HiveField(1)
  String recipientAddress;

  @HiveField(2)
  String transactionNote;

  String get note => transactionNote ?? '';
}
