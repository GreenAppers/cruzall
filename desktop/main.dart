// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:clippy/server.dart' as clippy;
import 'package:sembast/sembast_io.dart';
import 'package:scoped_model/scoped_model.dart';

import 'package:cruzawl/preferences.dart';

import 'package:cruzall/app.dart';
import 'package:cruzall/cruzawl-ui/model.dart';

void main() async {
  debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  Directory dataDir = Directory(Platform.environment['HOME'] + '/.cruzall');
  PackageInfo info =
      PackageInfo('Cruzall', 'com.greenappers.cruzall', '1.0.13', '13');
  debugPrint('main dataDir=${dataDir.path}');

  SetClipboardText setClipboardText =
      (BuildContext context, String text) async => await clippy.write(text);
  CruzawlPreferences preferences = CruzawlPreferences(await databaseFactoryIo
      .openDatabase(dataDir.path + Platform.pathSeparator + 'settings.db'));
  Cruzawl appState = Cruzawl(
      setClipboardText, databaseFactoryIo, await preferences.load(), dataDir,
      packageInfo: info, isTrustFall: false);

  runApp(ScopedModel(
    model: appState,
    child: CruzallApp(appState),
  ));
}
