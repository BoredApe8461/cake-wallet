import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/hive_type_ids.dart';
import 'package:hive/hive.dart';

part 'wallet_type.g.dart';

const walletTypes = [
  WalletType.monero,
  WalletType.bitcoin,
  WalletType.litecoin,
  WalletType.haven,
  WalletType.ethereum,
  WalletType.zano,
  WalletType.dummy,
];

@HiveType(typeId: WALLET_TYPE_TYPE_ID)
enum WalletType {
  @HiveField(0)
  monero,

  @HiveField(1)
  none,

  @HiveField(2)
  bitcoin,

  @HiveField(3)
  litecoin,

  @HiveField(4)
  haven,

  @HiveField(5)
  ethereum,

  @HiveField(6)
  zano,

  @HiveField(7)
  dummy,
}

int serializeToInt(WalletType type) {
  switch (type) {
    case WalletType.monero:
      return 0;
    case WalletType.bitcoin:
      return 1;
    case WalletType.litecoin:
      return 2;
    case WalletType.haven:
      return 3;
    case WalletType.ethereum:
      return 4;
    case WalletType.zano:
      return 5;
    case WalletType.dummy:
      return 6;
    default:
      return -1;
  }
}

WalletType deserializeFromInt(int raw) {
  switch (raw) {
    case 0:
      return WalletType.monero;
    case 1:
      return WalletType.bitcoin;
    case 2:
      return WalletType.litecoin;
    case 3:
      return WalletType.haven;
    case 4:
      return WalletType.ethereum;
    case 5:
      return WalletType.zano;
    case 6:
      return WalletType.dummy;
    default:
      throw Exception(
          'Unexpected token: $raw for WalletType deserializeFromInt');
  }
}

String walletTypeToString(WalletType type) {
  switch (type) {
    case WalletType.monero:
      return 'Monero';
    case WalletType.bitcoin:
      return 'Bitcoin';
    case WalletType.litecoin:
      return 'Litecoin';
    case WalletType.haven:
      return 'Haven';
    case WalletType.ethereum:
      return 'Ethereum';
    case WalletType.zano:
      return 'Zano';
    case WalletType.dummy:
      return 'Dummy';
    default:
      return '';
  }
}

String walletTypeToDisplayName(WalletType type) {
  switch (type) {
    case WalletType.monero:
      return 'Monero (XMR)';
    case WalletType.bitcoin:
      return 'Bitcoin (BTC)';
    case WalletType.litecoin:
      return 'Litecoin (LTC)';
    case WalletType.haven:
      return 'Haven (XHV)';
    case WalletType.ethereum:
      return 'Ethereum (ETH)';
    case WalletType.zano:
      return 'Zano (ZANO)';
    case WalletType.dummy:
      return 'Dummy (DUMMY)';
    default:
      return '';
  }
}

CryptoCurrency walletTypeToCryptoCurrency(WalletType type) {
  switch (type) {
    case WalletType.monero:
      return CryptoCurrency.xmr;
    case WalletType.bitcoin:
      return CryptoCurrency.btc;
    case WalletType.litecoin:
      return CryptoCurrency.ltc;
    case WalletType.haven:
      return CryptoCurrency.xhv;
    case WalletType.zano:
      return CryptoCurrency.zano;
    case WalletType.ethereum:
      return CryptoCurrency.eth;
    case WalletType.dummy:
      return CryptoCurrency.dummy;
    default:
      throw Exception(
          'Unexpected wallet type: ${type.toString()} for CryptoCurrency walletTypeToCryptoCurrency');
  }
}
