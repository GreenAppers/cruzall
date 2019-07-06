// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import "package:pointycastle/digests/sha256.dart";
import 'package:sembast/sembast.dart';

import 'package:cruzawl/network.dart';
import 'package:cruzawl/util.dart';
import 'package:cruzall/model/sembast.dart';

class CruzallPreferences extends SembastPreferences {
  String walletsPassword;
  CruzallPreferences(Database db) : super(db);

  String get theme => data['theme'] ?? 'deepOrange';
  set theme(String value) => setPreference('theme', value);

  bool get networkEnabled => data['networkEnabled'] ?? true;
  set networkEnabled(bool value) => setPreference('networkEnabled', value);

  bool get walletNameInTitle => data['walletNameInTitle'] ?? false;
  set walletNameInTitle(bool value) =>
      setPreference('walletNameInTitle', value);

  bool get walletsEncrypted => data['walletsEncrypted'] ?? false;

  Map<String, String> get wallets {
    if (walletsEncrypted) {
      assert(walletsPassword != null);
      Uint8List password = SHA256Digest().process(utf8.encode(walletsPassword));
      return Map<String, String>.from(
          Salsa20Decoder(password).convert(data['wallets']));
    } else {
      return Map<String, String>.from(data['wallets'] ?? Map<String, String>());
    }
  }

  set wallets(Map<String, String> value) {
    if (walletsEncrypted) {
      assert(walletsPassword != null);
      Uint8List password = SHA256Digest().process(utf8.encode(walletsPassword));
      setPreference('wallets', Salsa20Encoder(password).convert(value));
    } else {
      setPreference('wallets', value);
    }
  }

  List<PeerPreference> get peers {
    var peers = data['peers'];
    if (peers == null)
      return <PeerPreference>[PeerPreference('Localhost', 'wallet.cruzbit.xyz', 'CRUZ')];
    return peers.map<PeerPreference>((v) => PeerPreference.fromJson(v)).toList()
      ..sort(PeerPreference.comparePriority);
  }

  set peers(List<PeerPreference> value) {
    int priority = 10;
    for (int i = value.length - 1; i >= 0; i--, priority += 10)
      value[i].priority = priority;
    setPreference('peers', value.map((v) => v.toJson()).toList());
  }

  void encryptWallets(String password) {
    bool enabled = password != null && password.length > 0;
    if (enabled == walletsEncrypted) return;
    Map<String, String> loadedWallets = wallets;
    setPreference('walletsEncrypted', enabled, store: false);
    walletsPassword = password;
    wallets = loadedWallets;
  }
}

Map<String, ThemeData> themes = <String, ThemeData>{
  'red': ThemeData(primarySwatch: Colors.red, accentColor: Colors.redAccent),
  'pink': ThemeData(primarySwatch: Colors.pink, accentColor: Colors.pinkAccent),
  'purple':
      ThemeData(primarySwatch: Colors.purple, accentColor: Colors.purpleAccent),
  'deepPurple': ThemeData(
      primarySwatch: Colors.deepPurple, accentColor: Colors.deepPurpleAccent),
  'indigo':
      ThemeData(primarySwatch: Colors.indigo, accentColor: Colors.indigoAccent),
  'blue': ThemeData(primarySwatch: Colors.blue, accentColor: Colors.blueAccent),
  'lightBlue': ThemeData(
      primarySwatch: Colors.lightBlue, accentColor: Colors.lightBlueAccent),
  'cyan': ThemeData(primarySwatch: Colors.cyan, accentColor: Colors.cyanAccent),
  'teal': ThemeData(primarySwatch: Colors.teal, accentColor: Colors.tealAccent),
  'green':
      ThemeData(primarySwatch: Colors.green, accentColor: Colors.greenAccent),
  'lightGreen': ThemeData(
      primarySwatch: Colors.lightGreen, accentColor: Colors.lightGreenAccent),
  'lime': ThemeData(primarySwatch: Colors.lime, accentColor: Colors.limeAccent),
  'yellow':
      ThemeData(primarySwatch: Colors.yellow, accentColor: Colors.yellowAccent),
  'amber':
      ThemeData(primarySwatch: Colors.amber, accentColor: Colors.amberAccent),
  'orange':
      ThemeData(primarySwatch: Colors.orange, accentColor: Colors.orangeAccent),
  'deepOrange': ThemeData(
      primarySwatch: Colors.deepOrange, accentColor: Colors.orangeAccent),
  'brown':
      ThemeData(primarySwatch: Colors.brown, accentColor: Colors.brown[100]),
  'blueGrey': ThemeData(
      primarySwatch: Colors.blueGrey, accentColor: Colors.blueGrey[100]),
};
