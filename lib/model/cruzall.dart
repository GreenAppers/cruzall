// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:package_info/package_info.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:tweetnacl/tweetnacl.dart' as tweetnacl;

import 'package:cruzall/cruzawl-ui/preferences.dart';
import 'package:cruzall/model/test.dart';
import 'package:cruzall/model/wallet.dart';
import 'package:cruzawl/currency.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl/test.dart';

class Cruzall extends Model {
  CruzallPreferences preferences;
  FlutterErrorDetails fatal;
  PackageInfo packageInfo;
  bool isTrustFall;
  Directory dataDir;
  Wallet wallet;
  List<Wallet> wallets = <Wallet>[];
  int walletsLoading = 0;
  static String walletSuffix = '.cruzall';
  Cruzall(this.preferences, this.dataDir, {this.packageInfo, this.isTrustFall});

  void setState(VoidCallback stateChangeCb) {
    stateChangeCb();
    notifyListeners();
  }

  bool unlockWallets(String password) {
    try {
      preferences.walletsPassword = password;
      Map<String, String> loadedWallets = preferences.wallets;
      return loadedWallets != null;
    } on Exception {
      return false;
    }
  }

  void openWallets() {
    Map<String, String> loadedWallets = preferences.wallets;
    loadedWallets.forEach((k, v) => addWallet(
        Wallet.fromFile(getWalletFilename(k), Seed(base64.decode(v)),
            preferences, openedWallet),
        store: false));
  }

  void openedWallet(Wallet x) {
    if (x.fatal != null) {
      if (fatal == null) {
        fatal = x.fatal;
        debugPrint(fatal.toString());
      }
    } else {
      walletsLoading--;
    }
    notifyListeners();
  }

  String getWalletFilename(String walletName) =>
      dataDir.path + Platform.pathSeparator + walletName + walletSuffix;

  Wallet addWallet(Wallet x, {bool store = true}) {
    walletsLoading++;
    x.balanceChanged = notifyListeners;
    wallet = x;
    wallets.add(wallet);
    if (store) {
      Map<String, String> loadedWallets = preferences.wallets;
      loadedWallets[x.name] = base64.encode(x.seed.data);
      preferences.wallets = loadedWallets;
    }
    return x;
  }

  void removeWallet({bool store = true}) {
    assert(wallets.length > 1);
    String name = wallet.name;
    wallets.remove(wallet);
    wallet = wallets[0];
    if (store) {
      Map<String, String> loadedWallets = preferences.wallets;
      loadedWallets.remove(name);
      preferences.wallets = loadedWallets;
    }
    File(getWalletFilename(name)).deleteSync();
  }

  void changeActiveWallet(Wallet x) => setState(() => wallet = x);

  void updateWallets(Currency currency) {
    for (Wallet wallet in wallets)
      if (wallet.currency == currency) wallet.updateTip();
  }

  void reloadWallets(Currency currency) {
    for (Wallet wallet in wallets)
      if (wallet.currency == currency) wallet.reload();
    notifyListeners();
  }

  void reconnectPeers(Currency currency) {
    currency.network.reset();
    connectPeers(currency);
  }

  void connectPeers(Currency currency) {
    List<Peer> peers = preferences.peers
        .where((v) => v.currency == currency.ticker)
        .map((v) => addPeer(v))
        .toList();
    if (peers.length > 0 && preferences.networkEnabled) peers[0].connect();
  }

  Peer addPeer(PeerPreference x) {
    Currency currency = Currency.fromJson(x.currency);
    if (currency == null) return null;

    x.debugPrint = debugPrint;
    currency.network.tipChanged = () => updateWallets(currency);
    currency.network.peerChanged = () => reloadWallets(currency);
    return currency.network.addPeerWithSpec(x, currency.genesisBlockId());
  }

  bool runQuickTestVector() {
    Uint8List testVector =
        base64.decode('0JVc4TQg5shsqLNo6UDurejr4YUk8WUvYM+8lFAlAdI=');
    Uint8List publicKey =
        tweetnacl.Signature.keyPair_fromSeed(testVector).publicKey;
    if ((base64.encode(publicKey) !=
        'h6KFAcKAl9pi6cqfRJv5J0f3ffSh292+6MPO7Q92iF0=')) {
      fatal = FlutterErrorDetails(
          exception: FormatException('test vector failure'));
      return false;
    }
    return true;
  }

  int runUnitTests() {
    int tests = 0;
    debugPrint('running unit tests');
    TestCallback testCallback = (n, f) {
      debugPrint('testing $n');
      tests++;
      f();
    };
    ExpectCallback expectCallback = (x, y) {
      if (!(x == y))
        setState(() => fatal = FlutterErrorDetails(
            exception: FormatException('unit test failure')));
    };
    CruzTest(testCallback, testCallback, expectCallback).run();
    WalletTest(testCallback, testCallback, expectCallback).run();
    if (fatal != null) return -1;
    debugPrint('unit tests succeeded');
    return tests;
  }
}
