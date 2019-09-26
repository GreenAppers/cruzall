// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:intl/intl.dart';

import 'package:cruzall/main.dart' as cruzall;
import 'package:cruzawl/currency.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl_ui/localization.dart';
import 'package:cruzawl_ui/model.dart';

void main() async {
  Currency currency = cruz;
  Cruzawl appState;
  final Completer<Cruzawl> appCreated = Completer<Cruzawl>();
  final DataHandler handler = (String query) async {
    if (appState == null) appState = await appCreated.future;
    switch (query) {
      case 'height':
        PeerNetwork network =
            findPeerNetworkForCurrency(appState.networks, currency);
        Peer peer = await network.getPeer();
        return Future.value(network.tipHeight.toString());

      default:
        final l10n =
            await Localization.load(Locale(ui.window.locale.languageCode));
        return Future.value(jsonEncode({
          'balance': l10n.balance,
          'blocks': l10n.blocks,
          'currency': currency.toJson(),
          'locale': Intl.defaultLocale,
          'generateNewAddress': l10n.generateNewAddress,
          'payTo': l10n.payTo,
          'receive': l10n.receive,
          'send': l10n.send,
        }));
    }
  };

  // Enable integration testing with the Flutter Driver extension.
  // See https://flutter.io/testing/ for more info.
  enableFlutterDriverExtension(handler: handler);
  WidgetsApp.debugAllowBannerOverride = false;

  final PackageInfo packageInfo = await cruzall.getPackageInfo(false);
  final Directory dataDir = await cruzall.getDataDir(false);
  final bool isTrustFall = false;

  await cruzall.runCruzallApp(packageInfo, dataDir, false, isTrustFall,
      (app) => appCreated.complete(app));
}
