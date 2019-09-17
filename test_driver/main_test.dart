// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:screenshots/screenshots.dart';
import 'package:test/test.dart';

void main() {
  group('Screenshots', () {
    FlutterDriver driver;
    final config = Config();
    Map l10n;

    setUpAll(() async {
      driver = await FlutterDriver.connect();
      l10n = jsonDecode(await driver.requestData(null));
    });

    tearDownAll(() async {
      if (driver != null) await driver.close();
    });

    test('Driver health', () async {
      Health health = await driver.checkHealth();
      print(health.status);
      await driver.waitUntilFirstFrameRasterized();
      await driver.requestData('height');
    });

    test('Create HD wallet', () async {
      SerializableFinder createWalletButton =
          find.byType('RaisedGradientButton');
      await driver.waitFor(createWalletButton);
      await driver.tap(createWalletButton);
      await driver.waitFor(find.text(l10n['balance']));
      await driver.waitFor(find.byValueKey('chartLink'));
    });

    test('Screenshot send screen', () async {
      SerializableFinder sendTabButton = find.text(l10n['send']);
      await driver.tap(sendTabButton);
      await driver.waitFor(find.text(l10n['payTo']));
      await screenshot(driver, config, 'screenshot1');
    });

    test('Screenshot receive screen', () async {
      SerializableFinder receiveTabButton = find.text(l10n['receive']);
      await driver.waitFor(receiveTabButton);
      await driver.tap(receiveTabButton);
      await driver.waitFor(find.text(l10n['generateNewAddress']));
      await screenshot(driver, config, 'screenshot2');
    });

    test('Screenshot block chart', () async {
      SerializableFinder balanceTabButton = find.text(l10n['balance']);
      await driver.waitFor(balanceTabButton);
      await driver.tap(balanceTabButton);
      SerializableFinder blockChartButton = find.byValueKey('chartLink');
      await driver.waitFor(blockChartButton);
      await driver.tap(blockChartButton);
      await driver.waitFor(find.byValueKey('marketCap'));
      await screenshot(driver, config, 'screenshot3');
    }, timeout: Timeout(Duration(seconds: 120)));
  });
}
