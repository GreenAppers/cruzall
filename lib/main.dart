// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:barcode_scan/barcode_scan.dart';
import 'package:package_info/package_info.dart' as packageinfo;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:trust_fall/trust_fall.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cruzawl/preferences.dart';
import 'package:cruzawl/util.dart';

import 'package:cruzall/app.dart';
import 'package:cruzall/cruzawl-ui/lib/localization.dart';
import 'package:cruzall/cruzawl-ui/lib/model.dart';

String assetPath(String asset) => 'assets/$asset';

class IoFileSystem extends FileSystem {
  Future<bool> exists(String filename) async => File(filename).exists();
  Future<void> remove(String filename) async => File(filename).delete();
}

void setClipboardText(BuildContext context, String text) =>
    Clipboard.setData(ClipboardData(text: text)).then((result) =>
        Scaffold.of(context).showSnackBar(
            SnackBar(content: Text(Localization.of(context).copied))));

void launchUrl(BuildContext context, String url) async {
  debugPrint('Launching $url');
  if (await canLaunch(url)) {
    await launch(url);
  } else {
    debugPrint('Could not launch $url');
    setClipboardText(context, url);
  }
}

Future<String> barcodeScan() async {
  try {
    String barcode = await BarcodeScanner.scan();
    debugPrint('barcodeScan success: $barcode');
    return barcode;
  } on PlatformException catch (e) {
    if (e.code == BarcodeScanner.CameraAccessDenied) {
      debugPrint(
          'barcodeScan failed: The user did not grant the camera permission.');
    } else {
      debugPrint('barcodeScan failed: $e');
    }
  } on FormatException {
    debugPrint('barcodeScan aborted: User returned before scanning anything.');
  } catch (e) {
    debugPrint('barcodeScan failed with unknown error: $e');
  }
  return null;
}

/// Adapted from trust_fall.dart
Future<bool> trustFall({bool checkCanMockLocation=true}) async {
  final bool isJailBroken = await TrustFall.isJailBroken;
  final bool isRealDevice = await TrustFall.isRealDevice;
  final bool canMockLocation = checkCanMockLocation && await TrustFall.canMockLocation;
  if (Platform.isAndroid) {
    final bool isOnExternalStorage = await TrustFall.isOnExternalStorage;
    return isJailBroken ||
        canMockLocation ||
        !isRealDevice ||
        isOnExternalStorage;
  } else {
    return isJailBroken || canMockLocation || !isRealDevice;
  }
}

void main() async {
  bool isTrustFall = await trustFall(checkCanMockLocation: false);
  packageinfo.PackageInfo info = await packageinfo.PackageInfo.fromPlatform();
  Directory dataDir = await getApplicationDocumentsDirectory();
  debugPrint('main trustFall=$isTrustFall, dataDir=${dataDir.path}');

  CruzawlPreferences preferences = CruzawlPreferences(await databaseFactoryIo
      .openDatabase(dataDir.path + Platform.pathSeparator + 'settings.db'));
  Cruzawl appState = Cruzawl(
      assetPath,
      launchUrl,
      setClipboardText,
      databaseFactoryIo,
      await preferences.load(),
      dataDir.path + Platform.pathSeparator,
      IoFileSystem(),
      packageInfo: PackageInfo(
          info.appName, info.packageName, info.version, info.buildNumber),
      barcodeScan: barcodeScan,
      isTrustFall: isTrustFall);

  runApp(ScopedModel(
    model: appState,
    child: CruzallApp(appState),
  ));
}
