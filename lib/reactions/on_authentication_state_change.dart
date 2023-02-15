import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/dashboard/desktop_widgets/desktop_dashboard_view.dart';
import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';
import 'package:cake_wallet/entities/load_current_wallet.dart';
import 'package:cake_wallet/store/authentication_store.dart';

ReactionDisposer? _onAuthenticationStateChange;

dynamic loginError;

void startAuthenticationStateChange(AuthenticationStore authenticationStore,
    GlobalKey<NavigatorState> navigatorKey) {
  _onAuthenticationStateChange ??= autorun((_) async {
    final state = authenticationStore.state;

    if (state == AuthenticationState.installed) {
      try {
        await loadCurrentWallet();
      } catch (e) {
        loginError = e;
      }
      return;
    }

    if (state == AuthenticationState.allowed) {
      // Temporary workaround for the issue with desktopKey dispose
      Future.delayed(Duration(milliseconds: 2), () async {
        await navigatorKey.currentState!.pushNamedAndRemoveUntil(Routes.dashboard, (route) => false);
        return;
      });
    }
  });
}
