// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert' as c;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:intl/intl.dart';

import 'package:cruzawl_ui/localization.dart';
import 'package:cruzawl_ui/model.dart';
import 'package:cruzall/main.dart' as cruzall;

void main() async {
  Cruzawl appState;
  final Completer<Cruzawl> appCreated = Completer<Cruzawl>();
  final DataHandler handler = (String query) async {
    if (appState == null) appState = await appCreated.future;
    switch (query) {
      case 'height':
        return Future.value(appState.network.tipHeight.toString());

      default:
        final locale =
            await Localization.load(Locale(ui.window.locale.languageCode));
        return Future.value(c.jsonEncode({
          'locale': Intl.defaultLocale,
          'blocks': locale.blocks,
          'receive': locale.receive,
          'send': locale.send,
          'payTo': locale.payTo,
          'generateNewAddress': locale.generateNewAddress,
        }));
    }
  };

  // Enable integration testing with the Flutter Driver extension.
  // See https://flutter.io/testing/ for more info.
  enableFlutterDriverExtension(handler: handler);
  WidgetsApp.debugAllowBannerOverride = false;

  await cruzall.runCruzallApp(false, (app) => appCreated.complete(app));
}
