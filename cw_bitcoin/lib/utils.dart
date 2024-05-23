import 'dart:typed_data';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:flutter/foundation.dart';
import 'package:bitcoin_flutter/bitcoin_flutter.dart' as bitcoin;
import 'package:bitcoin_flutter/src/payments/index.dart' show PaymentData;
import 'package:hex/hex.dart';

bitcoin.PaymentData generatePaymentData({required bitcoin.HDWallet hd, int? index}) {
  final pubKey = index != null ? hd.derive(index).pubKey! : hd.pubKey!;
  return PaymentData(pubkey: Uint8List.fromList(HEX.decode(pubKey)));
}

ECPrivate generateECPrivate(
    {required bitcoin.HDWallet hd, required BasedUtxoNetwork network, int? index}) {
  final wif = index != null ? hd.derive(index).wif! : hd.wif!;
  return ECPrivate.fromWif(wif, netVersion: network.wifNetVer);
}

String generateP2WPKHAddress({
  required bitcoin.HDWallet hd,
  required BasedUtxoNetwork network,
  int? index,
}) {
  final pubKey = index != null ? hd.derive(index).pubKey! : hd.pubKey!;
  return ECPublic.fromHex(pubKey).toP2wpkhAddress().toAddress(network);
}

String generateP2SHAddress({
  required bitcoin.HDWallet hd,
  required BasedUtxoNetwork network,
  int? index,
}) {
  final pubKey = index != null ? hd.derive(index).pubKey! : hd.pubKey!;
  return ECPublic.fromHex(pubKey).toP2wpkhInP2sh().toAddress(network);
}

String generateP2WSHAddress({
  required bitcoin.HDWallet hd,
  required BasedUtxoNetwork network,
  int? index,
}) {
  final pubKey = index != null ? hd.derive(index).pubKey! : hd.pubKey!;
  return ECPublic.fromHex(pubKey).toP2wshAddress().toAddress(network);
}

String generateP2PKHAddress({
  required bitcoin.HDWallet hd,
  required BasedUtxoNetwork network,
  int? index,
}) {
  final pubKey = index != null ? hd.derive(index).pubKey! : hd.pubKey!;
  return ECPublic.fromHex(pubKey).toP2pkhAddress().toAddress(network);
}

String generateP2TRAddress({
  required bitcoin.HDWallet hd,
  required BasedUtxoNetwork network,
  int? index,
}) {
  final pubKey = index != null ? hd.derive(index).pubKey! : hd.pubKey!;
  return ECPublic.fromHex(pubKey).toTaprootAddress().toAddress(network);
}
