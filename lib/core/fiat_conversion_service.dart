import 'dart:io';

import 'package:cake_wallet/entities/fiat_api_mode.dart';
import 'package:cake_wallet/utils/proxy_wrapper.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cake_wallet/entities/fiat_currency.dart';
import 'dart:convert';
import 'package:cake_wallet/.secrets.g.dart' as secrets;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';

const _fiatApiClearNetAuthority = 'fiat-api.cakewallet.com';
const _fiatApiOnionAuthority = 'n4z7bdcmwk2oyddxvzaap3x2peqcplh3pzdy7tpkk5ejz5n4mhfvoxqd.onion';
const _fiatApiPath = '/v2/rates';

Future<double> _fetchPrice(Map<String, dynamic> args) async {
  final crypto = args['crypto'] as String;
  final fiat = args['fiat'] as String;
  final torOnly = args['torOnly'] as bool;
  final onionOnly = args['onionOnly'] as bool;
  final mainThreadProxyPort = args['port'] as int;

  final Map<String, String> queryParams = {
    'interval_count': '1',
    'base': crypto.split(".").first,
    'quote': fiat,
    'key': secrets.fiatApiKey,
  };

  num price = 0.0;

  try {
    final Uri onionUri = Uri.http(_fiatApiOnionAuthority, _fiatApiPath, queryParams);
    final Uri clearnetUri = Uri.https(_fiatApiClearNetAuthority, _fiatApiPath, queryParams);

    HttpClient client = await ProxyWrapper.instance.getProxyInstance(
      portOverride: mainThreadProxyPort,
    );

    late HttpClientResponse httpResponse;
    late String responseBody;
    late int statusCode;

    // we might have tor enabled (no way of knowing), so we try to use it first
    try {
      // connect through onion url first:
      try {
        final request = await client.getUrl(onionUri);
        httpResponse = await request.close();
        responseBody = await utf8.decodeStream(httpResponse);
      } catch (e) {
        // if the onion url fails, try the clearnet url, (still using tor!):
        // only do this if we are not onionOnly, otherwise we will fail
        if (!onionOnly) {
          final request = await client.getUrl(clearnetUri);
          httpResponse = await request.close();
          responseBody = await utf8.decodeStream(httpResponse);
        } else {
          // we failed to connect through onionOnly
          return 0.0;
        }
      }
      statusCode = httpResponse.statusCode;
    } catch (e) {
      if (torOnly) {
        // we failed to connect through torOnly
        return 0.0;
      }

      // connections all failed / tor is not enabled, so we use the clearnet url directly as normal:
      final response = await get(clearnetUri);
      responseBody = response.body;
      statusCode = response.statusCode;
    }
    
    if (statusCode != 200) {
      return 0.0;
    }

    final responseJSON = json.decode(responseBody) as Map<String, dynamic>;
    final results = responseJSON['results'] as Map<String, dynamic>;

    if (results.isNotEmpty) {
      price = results.values.first as num;
    }

    return price.toDouble();
  } catch (e) {
    return price.toDouble();
  }
}

Future<double> _fetchPriceAsync(CryptoCurrency crypto, FiatCurrency fiat, bool torOnly, bool onionOnly) async =>
    compute(_fetchPrice, {
      'fiat': fiat.toString(),
      'crypto': crypto.toString(),
      'torOnly': torOnly,
      'onionOnly': onionOnly,
      'port': ProxyWrapper.port,
      'torEnabled': ProxyWrapper.enabled,
    });

class FiatConversionService {
  static Future<double> fetchPrice({
    required CryptoCurrency crypto,
    required FiatCurrency fiat,
    required bool torOnly,
    required bool onionOnly,
  }) async =>
      await _fetchPriceAsync(crypto, fiat, torOnly, onionOnly);
}
