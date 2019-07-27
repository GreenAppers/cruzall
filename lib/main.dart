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
import 'package:cruzall/cruzawl-ui/localizations.dart';
import 'package:cruzall/cruzawl-ui/model.dart';

void main() async {
  bool isTrustFall = await TrustFall.isTrustFall;
  packageinfo.PackageInfo info = await packageinfo.PackageInfo.fromPlatform();
  Directory dataDir = await getApplicationDocumentsDirectory();
  debugPrint('main trustFall=$isTrustFall, dataDir=${dataDir.path}');

  SetClipboardText setClipboardText = (BuildContext context, String text) =>
      Clipboard.setData(ClipboardData(text: text)).then((result) =>
          Scaffold.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context).copied))));
  CruzawlPreferences preferences = CruzawlPreferences(await databaseFactoryIo
      .openDatabase(dataDir.path + Platform.pathSeparator + 'settings.db'));
  Cruzawl appState = Cruzawl(
      setClipboardText, databaseFactoryIo, await preferences.load(), dataDir,
      packageInfo: PackageInfo(
          info.appName, info.packageName, info.version, info.buildNumber),
      isTrustFall: isTrustFall);

  runApp(ScopedModel(
    model: appState,
    child: CruzallApp(appState),
  ));
}
