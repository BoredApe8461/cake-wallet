import 'dart:async';

import 'package:cake_wallet/view_model/dashboard/payjoin_transaction_list_item.dart';
import 'package:cw_core/payjoin_session.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';

part 'payjoin_transactions_store.g.dart';

class PayjoinTransactionsStore = PayjoinTransactionsStoreBase
    with _$PayjoinTransactionsStore;

abstract class PayjoinTransactionsStoreBase with Store {
  PayjoinTransactionsStoreBase({
    required this.payjoinSessionSource,
  }) : transactions = <PayjoinTransactionListItem>[] {
    payjoinSessionSource.watch().listen((_) => updateTransactionList());
    updateTransactionList();
  }

  Box<PayjoinSession> payjoinSessionSource;

  @observable
  List<PayjoinTransactionListItem> transactions;

  @action
  Future<void> updateTransactionList() async {
    transactions = payjoinSessionSource.values
        .where((session) => [
              PayjoinSessionStatus.inProgress.name,
              PayjoinSessionStatus.success.name,
              PayjoinSessionStatus.unrecoverable.name
            ].contains(session.status) && session.inProgressSince != null)
        .map(
          (session) => PayjoinTransactionListItem(
            session: session,
            key: ValueKey(
                'payjoin_transaction_list_item_${session.inProgressSince!.millisecondsSinceEpoch}_key'),
          ),
        )
        .toList();
  }
}
