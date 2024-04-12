import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:mobx/mobx.dart';

part 'rescan_view_model.g.dart';

class RescanViewModel = RescanViewModelBase with _$RescanViewModel;

enum RescanWalletState { rescaning, none }

abstract class RescanViewModelBase with Store {
  RescanViewModelBase(this.wallet, this.settingsStore)
      : state = RescanWalletState.none,
        isButtonEnabled = false,
        doSingleScan = false;

  final WalletBase wallet;

  final SettingsStore settingsStore;

  @observable
  RescanWalletState state;

  @observable
  bool isButtonEnabled;

  @observable
  bool doSingleScan;

  @computed
  bool get isSilentPaymentsScan => wallet.type == WalletType.bitcoin;

  @action
  Future<void> rescanCurrentWallet({required int restoreHeight}) async {
    state = RescanWalletState.rescaning;
    if (wallet.type != WalletType.bitcoin) {
      wallet.rescan(height: restoreHeight);
      wallet.transactionHistory.clear();
    } else {
      bitcoin!.rescan(wallet, height: restoreHeight, doSingleScan: doSingleScan);
    }
    state = RescanWalletState.none;
  }
}
