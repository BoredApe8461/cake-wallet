import 'dart:typed_data';

import 'package:cw_core/node.dart';
import 'package:cw_ethereum/ethereum_transaction_priority.dart';
import 'package:http/http.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

class EthereumClient {
  Web3Client? _client;

  bool connect(Node node) {
    try {
      _client = Web3Client(node.uri.toString(), Client());

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<EtherAmount> getBalance(EthereumAddress address) async {
    return await _client!.getBalance(address);
  }

  Future<int> getGasUnitPrice() async {
    final gasPrice = await _client!.getGasPrice();
    return gasPrice.getInWei.toInt();
  }

  Future<List<int>> getEstimatedGasForPriorities() async {
    final result = await Future.wait(EthereumTransactionPriority.all.map(
      (priority) => _client!.estimateGas(
          // maxPriorityFeePerGas: EtherAmount.fromUnitAndValue(EtherUnit.gwei, priority.tip),
          // maxFeePerGas: EtherAmount.fromUnitAndValue(EtherUnit.gwei, 100),
          ),
    ));

    return result.map((e) => e.toInt()).toList();
  }

  Future<String> signTransaction(
    EthPrivateKey privateKey,
    String toAddress,
    String amount,
    int fee,
  ) async {
    final transaction = Transaction(
      from: privateKey.address,
      to: EthereumAddress.fromHex(toAddress),
      value: EtherAmount.fromUnitAndValue(EtherUnit.ether, amount),
      // maxPriorityFeePerGas: EtherAmount.inWei(BigInt.from(fee)),
    );

    final Uint8List signedTransaction = await _client!.signTransaction(privateKey, transaction);

    return bytesToHex(signedTransaction);
  }

  Future<String> sendTransaction(EthPrivateKey privateKey, String toAddress, String amount) async {
    final transaction = Transaction(
      from: privateKey.address,
      to: EthereumAddress.fromHex(toAddress),
      value: EtherAmount.fromUnitAndValue(EtherUnit.ether, amount),
    );

    return await _client!.sendTransaction(
      privateKey,
      transaction,
    );
  }
}
