// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:scoped_model/scoped_model.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/wallet.dart';

import 'package:cruzall/address.dart';
import 'package:cruzall/cruzall.dart';
import 'package:cruzall/cruzawl-ui/address.dart';
import 'package:cruzall/cruzawl-ui/block.dart';
import 'package:cruzall/cruzawl-ui/cruzbase.dart';
import 'package:cruzall/cruzawl-ui/localization.dart';
import 'package:cruzall/cruzawl-ui/model.dart';
import 'package:cruzall/cruzawl-ui/network.dart';
import 'package:cruzall/cruzawl-ui/transaction.dart';
import 'package:cruzall/cruzawl-ui/ui.dart';
import 'package:cruzall/send.dart';
import 'package:cruzall/settings.dart';
import 'package:cruzall/wallet.dart';

class WelcomeWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Localization locale = Localization.of(context);
    final Cruzawl appState = ScopedModel.of<Cruzawl>(context);
    return SimpleScaffold(
      Column(
        children: <Widget>[
          Container(
            padding: EdgeInsets.only(top: 32),
            child: Text(locale.welcomeDesc),
          ),
          Expanded(
            child: AddWalletWidget(appState, welcome: true),
          ),
        ],
      ),
      title: locale.welcomeTitle,
    );
  }
}

class UnlockWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      UnlockCruzallWidget(),
      title: Localization.of(context).unlockTitle,
    );
  }
}

class FatalWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Cruzawl appState = ScopedModel.of<Cruzawl>(context);
    return SimpleScaffold(ErrorWidget.builder(appState.fatal),
        title: Localization.of(context).title);
  }
}

class CruzallApp extends StatefulWidget {
  final Cruzawl appState;
  CruzallApp(this.appState);

  @override
  CruzallAppState createState() => CruzallAppState();
}

class CruzallAppState extends State<CruzallApp> with WidgetsBindingObserver {
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    final localizationsDelegates = <LocalizationsDelegate>[
      LocalizationDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate
    ];
    final supportedLocales = <Locale>[Locale("en"), Locale("zh")];

    if (appState.wallets.length == 0) {
      if (appState.fatal != null)
        return MaterialApp(
          theme: appState.theme.data,
          debugShowCheckedModeBanner: false,
          supportedLocales: supportedLocales,
          localizationsDelegates: localizationsDelegates,
          onGenerateTitle: (BuildContext context) =>
              Localization.of(context).title,
          home: FatalWidget(),
        );

      if (appState.preferences.walletsEncrypted)
        return MaterialApp(
          theme: appState.theme.data,
          debugShowCheckedModeBanner: false,
          supportedLocales: supportedLocales,
          localizationsDelegates: localizationsDelegates,
          onGenerateTitle: (BuildContext context) =>
              Localization.of(context).title,
          home: UnlockWidget(),
        );

      return MaterialApp(
        theme: appState.theme.data,
        debugShowCheckedModeBanner: false,
        supportedLocales: supportedLocales,
        localizationsDelegates: localizationsDelegates,
        onGenerateTitle: (BuildContext context) =>
            Localization.of(context).title,
        home: WelcomeWidget(),
      );
    }

    final Wallet wallet = appState.wallet.wallet;
    return MaterialApp(
        theme: appState.theme.data,
        debugShowCheckedModeBanner: false,
        supportedLocales: supportedLocales,
        localizationsDelegates: localizationsDelegates,
        onGenerateTitle: (BuildContext context) =>
            Localization.of(context).title,
        home: ScopedModel(
          model: appState.wallet,
          child: CruzallWidget(wallet, appState),
        ),
        routes: <String, WidgetBuilder>{
          '/settings': (BuildContext context) => SimpleScaffold(
              CruzallSettings(),
              title: Localization.of(context).settings),
          '/network': (BuildContext context) => ScopedModel(
              model: appState.wallet,
              child: ScopedModelDescendant<WalletModel>(
                  builder: (context, child, model) => SimpleScaffold(
                      CruzawlNetworkSettings(),
                      title: Localization.of(context)
                          .networkType(wallet.currency.ticker)))),
          '/wallet': (BuildContext context) =>
              SimpleScaffold(WalletWidget(wallet), title: wallet.name),
          '/addWallet': (BuildContext context) => SimpleScaffold(
              AddWalletWidget(appState),
              title: Localization.of(context).newWallet),
          '/addPeer': (BuildContext context) => SimpleScaffold(AddPeerWidget(),
              title: Localization.of(context).newPeer),
          '/sendFrom': (BuildContext context) => SimpleScaffold(
              SendFromWidget(wallet),
              title: Localization.of(context).from),
          '/enableEncryption': (BuildContext context) => SimpleScaffold(
              EnableEncryptionWidget(),
              title: Localization.of(context).encryption),
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
                          title: Localization.of(context).address)
                      : ScopedModel(
                          model: appState.wallet,
                          child: ScopedModelDescendant<WalletModel>(
                              builder: (context, child, model) =>
                                  ExternalAddressWidget(
                                      wallet.currency, addressText,
                                      title: Localization.of(context)
                                          .externalAddress)));
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
                          onHeightTap: (tx) =>
                              appState.navigateToHeight(context, tx.height));
                }),
              ),
            );
          }

          return null;
        });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('didChangeAppLifecycleState $state');
    if (state == AppLifecycleState.paused) {
      // went to Background
    }
    if (state == AppLifecycleState.resumed) {
      // came back to Foreground
    }
  }
}
