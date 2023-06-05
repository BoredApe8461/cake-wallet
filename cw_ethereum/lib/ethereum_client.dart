import 'dart:math';

import 'package:cw_core/crypto_currency.dart';
import 'package:cw_ethereum/ethereum_balance.dart';
import 'package:cw_ethereum/pending_ethereum_transaction.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';
import 'package:cw_core/node.dart';
import 'package:cw_ethereum/ethereum_transaction_priority.dart';

class EthereumClient {
  static const Map<CryptoCurrency, String> _erc20Currencies = {
    CryptoCurrency.usdc: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
    CryptoCurrency.usdterc20: "0xdac17f958d2ee523a2206206994597c13d831ec7",
    CryptoCurrency.shib: "0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE",
  };

  Map<CryptoCurrency, String> get erc20Currencies => _erc20Currencies;

  Web3Client? _client;

  bool connect(Node node) {
    try {
      _client = Web3Client(node.uri.toString(), Client());

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<EtherAmount> getBalance(EthereumAddress address) async =>
      await _client!.getBalance(address);

  Future<int> getGasUnitPrice() async {
    final gasPrice = await _client!.getGasPrice();
    return gasPrice.getInWei.toInt();
  }

  Future<List<int>> getEstimatedGasForPriorities() async {
    // TODO: there is no difference, find out why
    // [53000, 53000, 53000]
    final result = await Future.wait(EthereumTransactionPriority.all.map(
      (priority) => _client!.estimateGas(
          // maxPriorityFeePerGas: EtherAmount.fromUnitAndValue(EtherUnit.gwei, priority.tip),
          // maxFeePerGas: EtherAmount.fromUnitAndValue(EtherUnit.gwei, priority.tip),
          ),
    ));

    return result.map((e) => e.toInt()).toList();
  }

  Future<PendingEthereumTransaction> signTransaction({
    required EthPrivateKey privateKey,
    required String toAddress,
    required String amount,
    required int gas,
    required EthereumTransactionPriority priority,
    required CryptoCurrency currency,
  }) async {
    bool _isEthereum = currency == CryptoCurrency.eth;
    final estimatedGas = BigInt.from(_isEthereum ? 21000 : 50000);

    final price = await _client!.getGasPrice();

    final Transaction transaction;

    if (_isEthereum) {
      transaction = Transaction(
        from: privateKey.address,
        to: EthereumAddress.fromHex(toAddress),
        maxGas: gas,
        gasPrice: price,
        value: EtherAmount.inWei(BigInt.parse(amount)),
      );
    } else {
      /// ERC-20 currency
      final String abi = await rootBundle.loadString("assets/abi_json/erc20_abi.json");
      final contractAbi = ContractAbi.fromJson(abi, "ERC20");

      final contract = DeployedContract(
        contractAbi,
        EthereumAddress.fromHex(_erc20Currencies[currency]!),
      );

      final originalAmount = BigInt.parse(amount) / BigInt.from(pow(10, 18));

      int exponent = await _getDecimalPlacesForContract(contract);

      final _amount = BigInt.from(originalAmount * pow(10, exponent));

      final transferFunction = contract.function('transfer');
      final transferData =
          transferFunction.encodeCall([EthereumAddress.fromHex(toAddress), _amount]);

      transaction = Transaction(
        from: privateKey.address,
        to: contract.address,
        maxGas: gas,
        gasPrice: price,
        value: EtherAmount.zero(),
        data: transferData,
      );

      // transaction = Transaction.callContract(
      //   contract: contract,
      //   function: transferFunction,
      //   parameters: [EthereumAddress.fromHex(toAddress), _amount],
      //   from: privateKey.address,
      //   maxGas: gas,
      //   gasPrice: price,
      //   value: EtherAmount.inWei(_amount),
      // );
      print("^^^^^^^^^^^^^^^^^^");
      print(transaction);
      print(transaction.maxGas);
      print(transaction.gasPrice);
      print(transaction.value);
      print("^^^^^^^^^^^^^^^^^^");
      print(exponent);
      print(originalAmount * pow(10, exponent));
      print(_amount);
      print((BigInt.from(transaction.maxGas!) * transaction.gasPrice!.getInWei) +
          transaction.value!.getInWei);

      sendERC20Token(EthereumAddress.fromHex(toAddress), currency, BigInt.parse(amount));
    }

    final signedTransaction = await _client!.signTransaction(privateKey, transaction);

    return PendingEthereumTransaction(
      signedTransaction: signedTransaction,
      amount: amount,
      fee: estimatedGas * price.getInWei,
      sendTransaction: () => sendTransaction(signedTransaction),
    );
  }

  Future<String> sendTransaction(Uint8List signedTransaction) async =>
      await _client!.sendRawTransaction(signedTransaction);

  Future getTransactionDetails(String transactionHash) async {
    // Wait for the transaction receipt to become available
    TransactionReceipt? receipt;
    while (receipt == null) {
      print("&&&&&&&&&&&&&&&&&&&&&&&&&&&&&");
      receipt = await _client!.getTransactionReceipt(transactionHash);
      await Future.delayed(Duration(seconds: 1));
    }

    // Print the receipt information
    print('Transaction Hash: ${receipt.transactionHash}');
    print('Block Hash: ${receipt.blockHash}');
    print('Block Number: ${receipt.blockNumber}');
    print('Gas Used: ${receipt.gasUsed}');

    /*
      Transaction Hash: [112, 244, 4, 238, 89, 199, 171, 191, 210, 236, 110, 42, 185, 202, 220, 21, 27, 132, 123, 221, 137, 90, 77, 13, 23, 43, 12, 230, 93, 63, 221, 116]
I/flutter ( 4474): Block Hash: [149, 44, 250, 119, 111, 104, 82, 98, 17, 89, 30, 190, 25, 44, 218, 118, 127, 189, 241, 35, 213, 106, 25, 95, 195, 37, 55, 131, 185, 180, 246, 200]
I/flutter ( 4474): Block Number: 17120242
I/flutter ( 4474): Gas Used: 21000
       */

    // Wait for the transaction receipt to become available
    TransactionInformation? transactionInformation;
    while (transactionInformation == null) {
      print("********************************");
      transactionInformation = await _client!.getTransactionByHash(transactionHash);
      await Future.delayed(Duration(seconds: 1));
    }
    // Print the receipt information
    print('Transaction Hash: ${transactionInformation.hash}');
    print('Block Hash: ${transactionInformation.blockHash}');
    print('Block Number: ${transactionInformation.blockNumber}');
    print('Gas Used: ${transactionInformation.gas}');

    /*
      Transaction Hash: 0x70f404ee59c7abbfd2ec6e2ab9cadc151b847bdd895a4d0d172b0ce65d3fdd74
I/flutter ( 4474): Block Hash: 0x952cfa776f68526211591ebe192cda767fbdf123d56a195fc3253783b9b4f6c8
I/flutter ( 4474): Block Number: 17120242
I/flutter ( 4474): Gas Used: 53000
       */
  }

// Future<List<Transaction>> fetchTransactions(String address) async {
//   get(Uri.https(
//     "https://api.etherscan.io",
//     "api/",
//     {
//       "module": "account",
//       "action": "txlist",
//       "address": address,
//       "apikey": secrets.,
//     },
//   ));
// }

  Future<Map<CryptoCurrency, ERC20Balance>> fetchERC20Balances(EthereumAddress userAddress) async {
    final String abi = await rootBundle.loadString("assets/abi_json/erc20_abi.json");
    final contractAbi = ContractAbi.fromJson(abi, "ERC20");

    final Map<CryptoCurrency, ERC20Balance> erc20Balances = {};

    for (var currency in _erc20Currencies.keys) {
      final contractAddress = _erc20Currencies[currency]!;

      try {
        final contract = DeployedContract(
          contractAbi,
          EthereumAddress.fromHex(contractAddress),
        );

        final balanceFunction = contract.function('balanceOf');
        final balance = await _client!.call(
          contract: contract,
          function: balanceFunction,
          // test address: 0x1715a3E4A142d8b698131108995174F37aEBA10D
          params: [userAddress],
        );

        BigInt tokenBalance = BigInt.parse(balance.first.toString());
        int exponent = await _getDecimalPlacesForContract(contract);

        erc20Balances[currency] = ERC20Balance(tokenBalance, exponent: exponent);
      } catch (e, s) {
        print(e);
        print(s);
        continue;
      }
    }

    return erc20Balances;
  }

  Future<bool> sendERC20Token(
      EthereumAddress to, CryptoCurrency erc20Currency, BigInt amount) async {
    if (_erc20Currencies[erc20Currency] == null) {
      throw "Unsupported ERC20 token";
    }

    try {
      final String abi = await rootBundle.loadString("assets/abi_json/erc20_abi.json");
      final contractAbi = ContractAbi.fromJson(abi, "ERC20");

      final contract = DeployedContract(
        contractAbi,
        EthereumAddress.fromHex(_erc20Currencies[erc20Currency]!),
      );

      final transferFunction = contract.function('transfer');
      final success = await _client!.call(
        contract: contract,
        function: transferFunction,
        params: [to, amount],
      );

      return success.first as bool;
    } catch (e) {
      return false;
    }
  }

  Future<int> _getDecimalPlacesForContract(DeployedContract contract) async {
    final decimalsFunction = contract.function('decimals');
    final decimals = await _client!.call(
      contract: contract,
      function: decimalsFunction,
      params: [],
    );

    int exponent = int.parse(decimals.first.toString());
    return exponent;
  }
}
