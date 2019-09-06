import 'dart:async';
import 'dart:convert' as c;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:intl/intl.dart';

import 'package:cruzall/cruzawl-ui/lib/localization.dart';
import 'package:cruzall/main.dart' as cruzall;

void main() async {
  final DataHandler handler = (_) async {
    final localizations =
        await Localization.load(Locale(ui.window.locale.languageCode));
    final response = {
      'title': localizations.title,
      'locale': Intl.defaultLocale
    };
    return Future.value(c.jsonEncode(response));
  };

  // Enable integration testing with the Flutter Driver extension.
  // See https://flutter.io/testing/ for more info.
  enableFlutterDriverExtension(handler: handler);
  WidgetsApp.debugAllowBannerOverride = false; // remove debug banner

  await cruzall.main();
}
