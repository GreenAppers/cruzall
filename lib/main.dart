// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:package_info/package_info.dart' as packageinfo;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:trust_fall/trust_fall.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/preferences.dart';
import 'package:cruzawl/wallet.dart';

import 'package:cruzall/address.dart';
import 'package:cruzall/cruzall.dart';
import 'package:cruzall/cruzawl-ui/address.dart';
import 'package:cruzall/cruzawl-ui/block.dart';
import 'package:cruzall/cruzawl-ui/cruzbase.dart';
import 'package:cruzall/cruzawl-ui/model.dart';
import 'package:cruzall/cruzawl-ui/network.dart';
import 'package:cruzall/cruzawl-ui/transaction.dart';
import 'package:cruzall/cruzawl-ui/ui.dart';
import 'package:cruzall/send.dart';
import 'package:cruzall/settings.dart';
import 'package:cruzall/wallet.dart';

void setClipboardText(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text)).then((result) =>
      Scaffold.of(context).showSnackBar(SnackBar(content: Text('Copied.'))));
}

void main() async {
  bool isTrustFall = await TrustFall.isTrustFall;
  packageinfo.PackageInfo info = await packageinfo.PackageInfo.fromPlatform();
  Directory dataDir = await getApplicationDocumentsDirectory();
  debugPrint('main trustFall=${isTrustFall}, dataDir=${dataDir.path}');
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

class CruzallApp extends StatefulWidget {
  final Cruzawl appState;
  CruzallApp(this.appState);

  @override
  CruzallAppState createState() => CruzallAppState();
}

class CruzallAppState extends State<CruzallApp> {
  @override
  void initState() {
    super.initState();
    widget.appState.runQuickTestVector();

    if (!widget.appState.preferences.walletsEncrypted)
      widget.appState.openWallets();

    for (Currency currency in currencies)
      widget.appState.connectPeers(currency);
  }

  @override
  Widget build(BuildContext context) {
    final Cruzawl appState =
        ScopedModel.of<Cruzawl>(context, rebuildOnChange: true);

    if (appState.wallets.length == 0) {
      if (appState.fatal != null)
        return MaterialApp(
          title: 'cruzall',
          theme: appState.theme.data,
          home: SimpleScaffold(ErrorWidget.builder(appState.fatal),
              title: 'Cruzall'),
        );

      if (appState.preferences.walletsEncrypted)
        return MaterialApp(
          title: 'cruzall',
          theme: appState.theme.data,
          home: SimpleScaffold(
            UnlockCruzallWidget(),
            title: 'Unlock Cruzall',
          ),
        );

      return MaterialApp(
        title: 'cruzall',
        theme: appState.theme.data,
        home: SimpleScaffold(
          Column(
            children: <Widget>[
              Container(
                padding: EdgeInsets.only(top: 32),
                child: Text('To begin, create a wallet:'),
              ),
              Expanded(
                child: AddWalletWidget(appState, welcome: true),
              ),
            ],
          ),
          title: 'Welcome to Cruzall',
        ),
      );
    }

    final Wallet wallet = appState.wallet.wallet;
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'cruzall',
        theme: appState.theme.data,
        home: ScopedModel(
          model: appState.wallet,
          child: CruzallWidget(wallet, appState),
        ),
        routes: <String, WidgetBuilder>{
          '/settings': (BuildContext context) =>
              SimpleScaffold(CruzallSettings(), title: 'Settings'),
          '/network': (BuildContext context) => ScopedModel(
              model: appState.wallet,
              child: ScopedModelDescendant<WalletModel>(
                  builder: (context, child, model) => SimpleScaffold(
                      CruzawlNetworkSettings(),
                      title: wallet.currency.ticker + ' Network'))),
          '/wallet': (BuildContext context) =>
              SimpleScaffold(WalletWidget(wallet), title: wallet.name),
          '/addWallet': (BuildContext context) =>
              SimpleScaffold(AddWalletWidget(appState), title: 'New Wallet'),
          '/addPeer': (BuildContext context) =>
              SimpleScaffold(AddPeerWidget(), title: 'New Peer'),
          '/sendFrom': (BuildContext context) =>
              SimpleScaffold(SendFromWidget(wallet), title: 'From'),
          '/enableEncryption': (BuildContext context) =>
              SimpleScaffold(EnableEncryptionWidget(), title: 'Encryption'),
        },
        onGenerateRoute: (settings) {
          final String name = settings.name;
          const String address = '/address/',
              block = '/block/',
              height = '/height/',
              transaction = '/transaction/';

          if (name.startsWith(address)) {
            String addressText = name.substring(address.length);
            return MaterialPageRoute(
                settings: settings,
                builder: (context) {
                  if (addressText == 'cruzbase')
                    return CruzbaseWidget(
                        wallet.currency, wallet.currency.network.tip);

                  Address address = wallet.addresses[addressText];
                  return address != null
                      ? SimpleScaffold(AddressWidget(wallet, address),
                          title: 'Address')
                      : ScopedModel(
                          model: appState.wallet,
                          child: ScopedModelDescendant<WalletModel>(
                              builder: (context, child, model) =>
                                  ExternalAddressWidget(
                                      wallet.currency, addressText,
                                      title: 'External Address')));
                });
          } else if (name.startsWith(block))
            return MaterialPageRoute(
              settings: settings,
              builder: (context) => ScopedModel(
                model: appState.wallet,
                child: ScopedModelDescendant<WalletModel>(
                  builder: (context, child, model) => BlockWidget(
                      wallet.currency,
                      blockId: name.substring(block.length)),
                ),
              ),
            );
          else if (name.startsWith(height))
            return MaterialPageRoute(
              settings: settings,
              builder: (context) => ScopedModel(
                model: appState.wallet,
                child: ScopedModelDescendant<WalletModel>(
                  builder: (context, child, model) => BlockWidget(
                      wallet.currency,
                      blockHeight: int.parse(name.substring(height.length))),
                ),
              ),
            );
          else if (name.startsWith(transaction)) {
            String transactionIdText = name.substring(transaction.length);
            return MaterialPageRoute(
              settings: settings,
              builder: (context) => ScopedModel(
                model: appState.wallet,
                child: ScopedModelDescendant<WalletModel>(
                    builder: (context, child, model) {
                  Transaction transaction =
                      wallet.transactionIds[transactionIdText];
                  return transaction != null
                      ? TransactionWidget(wallet.currency,
                          WalletTransactionInfo(wallet, transaction),
                          transaction: transaction)
                      : TransactionWidget(wallet.currency, TransactionInfo(),
                          transactionIdText: transactionIdText,
                          onHeightTap: (tx) => Navigator.of(context)
                              .pushNamed('/height/' + tx.height.toString()));
                }),
              ),
            );
          }

          return null;
        });
  }
}
