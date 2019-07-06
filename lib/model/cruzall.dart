// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:scoped_model/scoped_model.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzall/model/preferences.dart';
import 'package:cruzall/model/wallet.dart';

class Cruzall extends Model {
  CruzallPreferences preferences;
  Directory dataDir;
  Wallet wallet;
  List<Wallet> wallets = <Wallet>[];
  static String walletSuffix = '.cruzall';
  Cruzall(this.preferences, this.dataDir);

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
        Wallet.fromFile(
            getWalletFilename(k), Seed(base64.decode(v)), notifyListeners),
        store: false));
  }

  String getWalletFilename(String walletName) =>
      dataDir.path + Platform.pathSeparator + walletName + walletSuffix;

  Wallet addWallet(Wallet x, {bool store = true}) {
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
}
