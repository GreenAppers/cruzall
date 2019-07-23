// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:package_info/package_info.dart' as packageinfo;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:trust_fall/trust_fall.dart';

import 'package:cruzawl/preferences.dart';

import 'package:cruzall/app.dart';
import 'package:cruzall/cruzawl-ui/model.dart';

void main() async {
  bool isMobile;
  SetClipboardText setClipboardText;
  try {
    isMobile = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  } catch (e) {
    isMobile = false;
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  }
  if (isMobile) {
    setClipboardText = (BuildContext context, String text) {
      Clipboard.setData(ClipboardData(text: text)).then((result) =>
          Scaffold.of(context)
              .showSnackBar(SnackBar(content: Text('Copied.'))));
    };
  } else {
  }

  bool isTrustFall = isMobile && await TrustFall.isTrustFall;
  packageinfo.PackageInfo info =
      isMobile ? await packageinfo.PackageInfo.fromPlatform() : null;
  Directory dataDir = isMobile
      ? await getApplicationDocumentsDirectory()
      : Directory(Platform.environment['HOME'] + '/.cruzall');
  debugPrint('main trustFall=$isTrustFall, dataDir=${dataDir.path}');
  CruzawlPreferences preferences = CruzawlPreferences(await databaseFactoryIo
      .openDatabase(dataDir.path + Platform.pathSeparator + 'settings.db'));
  Cruzawl appState = Cruzawl(
      setClipboardText, databaseFactoryIo, await preferences.load(), dataDir,
      packageInfo: info != null
          ? PackageInfo(
              info.appName, info.packageName, info.version, info.buildNumber)
          : PackageInfo('Cruzall', 'com.greenappers.cruzall', '1.0.13', '13'),
      isTrustFall: isTrustFall);
  runApp(ScopedModel(
    model: appState,
    child: CruzallApp(appState),
  ));
}
