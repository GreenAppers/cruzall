// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:clippy/server.dart' as clippy;
import 'package:scoped_model/scoped_model.dart';
import 'package:sembast/sembast_io.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cruzawl/preferences.dart';

import 'package:cruzall/app.dart';
import 'package:cruzall/cruzawl-ui/model.dart';

String assetPath(String asset) => 'assets/$asset';

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
  if (homePath != null && homePath.length > 0)
    dataDirPath = homePath + '/.cruzall';
  else if (appDataPath != null && appDataPath.length > 0)
    dataDirPath = appDataPath + '\\Cruzall';
  Directory dataDir = Directory(dataDirPath);
  PackageInfo info =
      PackageInfo('Cruzall', 'com.greenappers.cruzall', '1.0.15', '15');
  debugPrint('main dataDir=${dataDir.path}');

  CruzawlPreferences preferences = CruzawlPreferences(await databaseFactoryIo
      .openDatabase(dataDir.path + Platform.pathSeparator + 'settings.db'));
  Cruzawl appState = Cruzawl(assetPath, launchUrl, setClipboardText,
      databaseFactoryIo, await preferences.load(), dataDir,
      packageInfo: info, isTrustFall: false);

  runApp(ScopedModel(
    model: appState,
    child: CruzallApp(appState),
  ));
}
