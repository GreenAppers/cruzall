// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:clippy/server.dart' as clippy;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:sembast/sembast_io.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cruzawl/http.dart';
import 'package:cruzawl/preferences.dart';
import 'package:cruzawl/sembast.dart';
import 'package:cruzawl/util.dart';

import 'package:cruzawl_ui/localization.dart';
import 'package:cruzawl_ui/model.dart';
import 'package:cruzawl_ui/wallet/app.dart';

String assetPath(String asset) => 'assets/$asset';

class IoFileSystem extends FileSystem {
  Future<bool> exists(String filename) async => File(filename).exists();
  Future<void> remove(String filename) async => File(filename).delete();
}

Future<String> getClipboardText() async => clippy.read();

void setClipboardText(BuildContext context, String text) async =>
    await clippy.write(text);

void launchUrl(BuildContext context, String url) async {
  debugPrint('Launching $url');
  if (await canLaunch(url)) {
    await launch(url);
  } else {
    debugPrint('Could not launch $url');
    setClipboardText(context, url);
  }
}

void main() async {
  debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  String homePath = Platform.environment['HOME'], dataDirPath = '';
  String appDataPath = Platform.environment['LOCALAPPDATA'];
  if (homePath != null && homePath.isNotEmpty) {
    dataDirPath = homePath + '/.cruzall';
  } else if (appDataPath != null && appDataPath.isNotEmpty) {
    dataDirPath = appDataPath + '\\Cruzall';
  }
  final Directory dataDir = Directory(dataDirPath);
  final PackageInfo info =
      PackageInfo('Cruzall', 'com.greenappers.cruzall', '1.1.1', '20');
  debugPrint('main dataDir=${dataDir.path}');

  final CruzawlPreferences preferences = CruzawlPreferences(
      SembastPreferences(await databaseFactoryIo
          .openDatabase(dataDir.path + Platform.pathSeparator + 'settings.db')),
      () => NumberFormat.currency().currencyName);
  await preferences.storage.load();

  final Cruzawl appState = Cruzawl(
      assetPath,
      launchUrl,
      setClipboardText,
      getClipboardText,
      databaseFactoryIo,
      preferences,
      dataDir.path + Platform.pathSeparator,
      IoFileSystem(),
      packageInfo: info,
      httpClient: HttpClientImpl(),
      isTrustFall: false);

  final List<LocalizationsDelegate> localizationsDelegates =
      <LocalizationsDelegate>[
    LocalizationDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate
  ];

  runApp(ScopedModel(
    model: appState,
    child: WalletApp(appState, localizationsDelegates),
  ));
}
