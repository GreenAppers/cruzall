// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:convert' as c;
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:screenshots/screenshots.dart';
import 'package:test/test.dart';

void main() {
  group('Screenshots', () {
    FlutterDriver driver;
    final config = Config();
    Map locale;

    setUpAll(() async {
      driver = await FlutterDriver.connect();
      locale = c.jsonDecode(await driver.requestData(null));
    });

    tearDownAll(() async {
      if (driver != null) await driver.close();
    });

    test('Driver health', () async {
      Health health = await driver.checkHealth();
      print(health.status);
      sleep(Duration(seconds: 5));
      //await driver.waitUntilFirstFrameRasterized();
    });

    test('Create HD wallet', () async {
      SerializableFinder createWalletButton =
          find.byType('RaisedGradientButton');
      await driver.waitFor(createWalletButton);
      await driver.tap(createWalletButton);
      sleep(Duration(seconds: 5));
    });

    test('Screenshot block chart', () async {
      String height = await driver.requestData('height');
      print('Got height = $height');
      SerializableFinder blockChartButton = find.text(height);
      await driver.waitFor(blockChartButton);
      await driver.tap(blockChartButton);
      sleep(Duration(seconds: 5));
      await screenshot(driver, config, 'screenshot3');
      await driver.tap(find.pageBack());
    });

    test('Screenshot send screen', () async {
      SerializableFinder sendTabButton = find.text(locale['send']);
      await driver.waitFor(sendTabButton);
      await driver.tap(sendTabButton);
      await driver.waitFor(find.text(locale['payTo']));
      await screenshot(driver, config, 'screenshot1');
    });

    test('Screenshot receive screen', () async {
      SerializableFinder receiveTabButton = find.text(locale['receive']);
      await driver.waitFor(receiveTabButton);
      await driver.tap(receiveTabButton);
      await driver.waitFor(find.text(locale['generateNewAddress']));
      await screenshot(driver, config, 'screenshot2');
    });
  });
}
