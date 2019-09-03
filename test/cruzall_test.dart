// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:cruzawl/http.dart';
import 'package:cruzawl/preferences.dart';
import 'package:cruzawl/test.dart';
import 'package:cruzawl/util.dart';
import 'package:cruzawl/wallet.dart';

import 'package:cruzall/app.dart';
import 'package:cruzall/cruzawl-ui/lib/localization.dart';
import 'package:cruzall/cruzawl-ui/lib/model.dart';
import 'package:cruzall/cruzawl-ui/lib/ui.dart';
import 'package:cruzall/cruzawl-ui/lib/wallet/settings.dart';

void main() async {
  CruzawlPreferences preferences = CruzawlPreferences(
      await databaseFactoryMemoryFs.openDatabase('settings.db'), () => 'USD');
  await preferences.load();
  preferences.networkEnabled = false;
  preferences.minimumReserveAddress = 3;
  SetClipboardText stringCallback = (BuildContext c, String x) {};
  TestHttpClient httpClient = TestHttpClient();
  Cruzawl appState = Cruzawl((String x) => x, stringCallback, stringCallback,
      null, databaseFactoryMemoryFs, preferences, '/', NullFileSystem(),
      httpClient: httpClient);

  testWidgets('CruzallApp Init', (WidgetTester tester) async {
    expect(appState.wallets.length, 0);
    CruzallApp app = CruzallApp(appState);
    await tester.pumpWidget(ScopedModel(model: appState, child: app));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(RaisedGradientButton));
    await tester.pump(Duration(seconds: 1));
    await tester.pump(Duration(seconds: 2));
    expect(appState.wallets.length, 1);
    expect(appState.wallet.wallet.addresses.length,
        preferences.minimumReserveAddress);
  });

  testWidgets('WalletSettingsWidget Verify', (WidgetTester tester) async {
    Wallet wallet = appState.wallet.wallet;
    await tester.pumpWidget(ScopedModel(
        model: appState,
        child: MaterialApp(
            localizationsDelegates: <LocalizationsDelegate>[
              LocalizationDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate
            ],
            supportedLocales: <Locale>[
              Locale("en")
            ],
            home: SimpleScaffold(WalletSettingsWidget(wallet),
                title: wallet.name))));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Addresses'), Offset(0.0, -400));
    await tester.pump();
    await tester.tap(find.widgetWithText(RaisedGradientButton, 'Verify'));
    await tester.pump(Duration(seconds: 1));
    await tester.pump(Duration(seconds: 2));
    expect(find.text('Verified 3/3 addresses and 11/11 tests succeeded'),
        findsOneWidget);
  });
}
