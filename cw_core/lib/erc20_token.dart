import 'package:cw_core/crypto_currency.dart';
import 'package:hive/hive.dart';

part 'erc20_token.g.dart';

@HiveType(typeId: Erc20Token.typeId)
class Erc20Token extends CryptoCurrency with HiveObjectMixin {
  @HiveField(0)
  final String name;
  @HiveField(1)
  final String symbol;
  @HiveField(2)
  final String contractAddress;
  @HiveField(3)
  final int decimal;
  @HiveField(4, defaultValue: false)
  bool _enabled;
  @HiveField(5)
  final String? iconPath;

  bool get enabled => _enabled;

  set enabled(bool value) {
    _enabled = value;
    this.save();
  }

  Erc20Token({
    required this.name,
    required this.symbol,
    required this.contractAddress,
    required this.decimal,
    bool enabled = false,
    this.iconPath,
  })  : _enabled = enabled,
        super(
          name: symbol.toLowerCase(),
          title: symbol.toUpperCase(),
          fullName: name,
          tag: "ETH",
          iconPath: iconPath,
        );

  static const typeId = 12;
  static const boxName = 'Erc20Tokens';

  @override
  bool operator ==(other) => other is Erc20Token && other.contractAddress == contractAddress;

  @override
  int get hashCode => contractAddress.hashCode;
}
