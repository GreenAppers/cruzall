// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:package_info/package_info.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:trust_fall/trust_fall.dart';

import 'package:cruzall/address.dart';
import 'package:cruzawl/currency.dart';
import 'package:cruzall/cruzall.dart';
import 'package:cruzall/cruzawl-ui/address.dart';
import 'package:cruzall/cruzawl-ui/block.dart';
import 'package:cruzall/cruzawl-ui/cruzbase.dart';
import 'package:cruzall/cruzawl-ui/transaction.dart';
import 'package:cruzall/cruzawl-ui/ui.dart';
import 'package:cruzall/model/cruzall.dart';
import 'package:cruzall/model/preferences.dart';
import 'package:cruzall/model/wallet.dart';
import 'package:cruzall/network.dart';
import 'package:cruzall/send.dart';
import 'package:cruzall/settings.dart';
import 'package:cruzall/wallet.dart';

void main() async {
  bool isTrustFall = await TrustFall.isTrustFall;
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  Directory dataDir = await getApplicationDocumentsDirectory();
  debugPrint('main trustFall=${isTrustFall}, dataDir=${dataDir.path}');
  CruzallPreferences preferences = CruzallPreferences(await databaseFactoryIo
      .openDatabase(dataDir.path + Platform.pathSeparator + 'settings.db'));
  Cruzall appState = Cruzall(await preferences.load(), dataDir,
      packageInfo: packageInfo, isTrustFall: isTrustFall);
  runApp(ScopedModel(
    model: appState,
    child: CruzallApp(appState),
  ));
}

class CruzallApp extends StatefulWidget {
  final Cruzall appState;
  CruzallApp(this.appState);

  @override
  CruzallAppState createState() => CruzallAppState();
}

class CruzallAppState extends State<CruzallApp> {
  @override
  void initState() {
    super.initState();

    if (!widget.appState.preferences.walletsEncrypted)
      widget.appState.openWallets();

    for (Currency currency in currencies)
      widget.appState.connectPeers(currency);
  }

  @override
  Widget build(BuildContext context) {
    final Cruzall appState =
        ScopedModel.of<Cruzall>(context, rebuildOnChange: true);
    final ThemeData theme =
        themes[appState.preferences.theme] ?? themes['deepOrange'];

    if (appState.wallets.length == 0) {
      if (appState.preferences.walletsEncrypted)
        return MaterialApp(
          title: 'cruzall',
          theme: theme,
          home: SimpleScaffold(
            'Unlock Cruzall',
            UnlockCruzallWidget(),
          ),
        );

      return MaterialApp(
        title: 'cruzall',
        theme: theme,
        home: SimpleScaffold(
          'Welcome to Cruzall',
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
        ),
      );
    }

    final Wallet wallet = appState.wallet;
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'cruzall',
        theme: theme,
        home: ScopedModel(
          model: appState.wallet,
          child: CruzallWidget(wallet, appState),
        ),
        routes: <String, WidgetBuilder>{
          '/settings': (BuildContext context) =>
              SimpleScaffold('Settings', CruzallSettings()),
          '/network': (BuildContext context) => SimpleScaffold(
              wallet.currency.ticker + ' Network', CruzallNetworkSettings()),
          '/wallet': (BuildContext context) =>
              SimpleScaffold(wallet.name, WalletWidget(wallet)),
          '/addWallet': (BuildContext context) =>
              SimpleScaffold('New Wallet', AddWalletWidget(appState)),
          '/addPeer': (BuildContext context) =>
              SimpleScaffold('New Peer', AddPeerWidget()),
          '/sendFrom': (BuildContext context) =>
              SimpleScaffold('From', SendFromWidget(wallet)),
          '/enableEncryption': (BuildContext context) =>
              SimpleScaffold('Encryption', EnableEncryptionWidget()),
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
                      ? SimpleScaffold(
                          'Address', AddressWidget(wallet, address))
                      : ScopedModel(
                          model: wallet,
                          child: ScopedModelDescendant<Wallet>(
                              builder: (context, child, model) =>
                                  ExternalAddressWidget(
                                      wallet.currency, addressText,
                                      title: 'External Address')));
                });
          } else if (name.startsWith(block))
            return MaterialPageRoute(
              settings: settings,
              builder: (context) => ScopedModel(
                model: wallet,
                child: ScopedModelDescendant<Wallet>(
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
                model: wallet,
                child: ScopedModelDescendant<Wallet>(
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
                model: wallet,
                child: ScopedModelDescendant<Wallet>(
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
