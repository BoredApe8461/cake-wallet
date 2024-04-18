import 'package:flutter/services.dart';
import 'package:flutter_local_authentication/flutter_local_authentication.dart';

class BiometricAuth {
  final _flutterLocalAuthenticationPlugin = FlutterLocalAuthentication();

  Future<bool> isAuthenticated() async {
    try {
      final authenticated = await _flutterLocalAuthenticationPlugin.authenticate();
      return authenticated;
    } catch (e) {
      print(e);
    }
    return false;
  }

  Future<bool> canCheckBiometrics() async {
    bool canAuthenticate;
    try {
      canAuthenticate = await _flutterLocalAuthenticationPlugin.canAuthenticate();
      // Setup TouchID Allowable Reuse duration
      await _flutterLocalAuthenticationPlugin.setTouchIDAuthenticationAllowableReuseDuration(2);
    } catch (error) {
      print("Exception checking support. $error");
      canAuthenticate = false;
    }

    return canAuthenticate;
  }
}
