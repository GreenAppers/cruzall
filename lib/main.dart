// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:barcode_scan/barcode_scan.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:jdenticon_dart/jdenticon_dart.dart';
import 'package:package_info/package_info.dart' as packageinfo;
import 'package:path_provider/path_provider.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:sembast/sembast_io.dart';
import 'package:trust_fall/trust_fall.dart';
import 'package:uni_links/uni_links.dart';
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

Future<String> getClipboardText() async {
  ClipboardData data = await Clipboard.getData(Clipboard.kTextPlain);
  return data == null ? '' : data.text;
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
    final String barcode = await BarcodeScanner.scan();
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

Future<PackageInfo> getPackageInfo(bool havePackageInfo) async {
  if (havePackageInfo) {
    final packageinfo.PackageInfo info =
        await packageinfo.PackageInfo.fromPlatform();
    return PackageInfo(
        info.appName, info.packageName, info.version, info.buildNumber);
  } else {
    return PackageInfo('Cruzall', 'com.greenappers.cruzall', '1.1.2', '22');
  }
}

Future<Directory> getDataDir(bool isDesktop) async {
  if (isDesktop) {
    String homePath = Platform.environment['HOME'], dataDirPath = '';
    String appDataPath = Platform.environment['LOCALAPPDATA'];
    if (homePath != null && homePath.isNotEmpty) {
      dataDirPath = homePath + '/.cruzall';
    } else if (appDataPath != null && appDataPath.isNotEmpty) {
      dataDirPath = appDataPath + '\\Cruzall';
    }
    return Directory(dataDirPath);
  } else {
    return await getApplicationDocumentsDirectory();
  }
}

void runCruzallApp(PackageInfo packageInfo, Directory dataDir, bool isDesktop,
    bool isTrustFall,
    [CruzawlCallback appCreated]) async {
  debugPrint('runCruzallApp trustFall=$isTrustFall, dataDir=${dataDir.path}');

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
      packageInfo: packageInfo,
      barcodeScan: isDesktop ? null : barcodeScan,
      httpClient: HttpClientImpl(),
      isTrustFall: isTrustFall,
      createIconImage: (x) => SvgPicture.string(Jdenticon.toSvg(x),
          fit: BoxFit.contain, height: 64, width: 64));

  if (appCreated != null) appCreated(appState);

  final List<LocalizationsDelegate> localizationsDelegates =
      <LocalizationsDelegate>[
    LocalizationDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate
  ];

  VoidCallback getInitLink =
      isDesktop ? null : () async => await getInitialLink();
  Stream<String> linksStream = isDesktop ? null : getLinksStream();

  runApp(ScopedModel(
    model: appState,
    child:
        WalletApp(appState, localizationsDelegates, getInitLink, linksStream),
  ));
}

void main() async {
  final bool isDesktop =
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  if (isDesktop) debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  WidgetsFlutterBinding.ensureInitialized();

  final PackageInfo packageInfo = await getPackageInfo(!isDesktop);
  final Directory dataDir = await getDataDir(isDesktop);
  final bool isTrustFall = isDesktop ? false : await TrustFall.isTrustFall;

  await runCruzallApp(packageInfo, dataDir, isDesktop, isTrustFall);
}
