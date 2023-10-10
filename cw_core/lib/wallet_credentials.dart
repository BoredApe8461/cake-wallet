import 'package:cw_core/wallet_info.dart';

abstract class WalletCredentials {
  WalletCredentials({
    required this.name,
    this.height,
    this.walletInfo,
    this.password,
    DerivationInfo? derivationInfo,
  }) {
    if (this.walletInfo != null && derivationInfo != null) {
      this.walletInfo!.derivationInfo = derivationInfo;
    }
  }

  final String name;
  final int? height;
  String? password;
  WalletInfo? walletInfo;
}
