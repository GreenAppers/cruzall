// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:scoped_model/scoped_model.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/wallet.dart';

import 'package:cruzall/cruzawl-ui/address.dart';
import 'package:cruzall/cruzawl-ui/block.dart';
import 'package:cruzall/cruzawl-ui/cruzbase.dart';
import 'package:cruzall/cruzawl-ui/localization.dart';
import 'package:cruzall/cruzawl-ui/model.dart';
import 'package:cruzall/cruzawl-ui/network.dart';
import 'package:cruzall/cruzawl-ui/settings.dart';
import 'package:cruzall/cruzawl-ui/transaction.dart';
import 'package:cruzall/cruzawl-ui/ui.dart';
import 'package:cruzall/cruzawl-ui/wallet/add.dart';
import 'package:cruzall/cruzawl-ui/wallet/address.dart';
import 'package:cruzall/cruzawl-ui/wallet/send.dart';
import 'package:cruzall/cruzawl-ui/wallet/settings.dart';
import 'package:cruzall/cruzawl-ui/wallet/wallet.dart';

class WelcomeToCruzallWidget extends StatelessWidget {
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

class UnlockCruzallWidget extends StatefulWidget {
  @override
  _UnlockCruzallWidgetState createState() => _UnlockCruzallWidgetState();
}

class _UnlockCruzallWidgetState extends State<UnlockCruzallWidget> {
  final formKey = GlobalKey<FormState>();
  String password;

  @override
  Widget build(BuildContext c) {
    final Cruzawl appState = ScopedModel.of<Cruzawl>(context);
    final Localization locale = Localization.of(context);

    return SimpleScaffold(
      Form(
        key: formKey,
        child: ListView(children: <Widget>[
          ListTile(
            subtitle: TextFormField(
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: locale.password,
              ),
              validator: (value) {
                if (!(value.length > 0)) return locale.passwordCantBeEmpty;
                return null;
              },
              onSaved: (val) => password = val,
            ),
          ),
          RaisedGradientButton(
            labelText: locale.unlock,
            padding: EdgeInsets.all(32),
            onPressed: () {
              if (!formKey.currentState.validate()) return;
              formKey.currentState.save();
              formKey.currentState.reset();
              if (appState.unlockWallets(password))
                appState.setState(() => appState.openWallets());
            },
          ),
        ]),
      ),
      title: locale.unlockTitle,
    );
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
          home: SimpleScaffold(ErrorWidget.builder(appState.fatal)),
        );

      if (appState.preferences.walletsEncrypted)
        return MaterialApp(
          theme: appState.theme.data,
          debugShowCheckedModeBanner: false,
          supportedLocales: supportedLocales,
          localizationsDelegates: localizationsDelegates,
          onGenerateTitle: (BuildContext context) =>
              Localization.of(context).title,
          home: UnlockCruzallWidget(),
        );

      return MaterialApp(
        theme: appState.theme.data,
        debugShowCheckedModeBanner: false,
        supportedLocales: supportedLocales,
        localizationsDelegates: localizationsDelegates,
        onGenerateTitle: (BuildContext context) =>
            Localization.of(context).title,
        home: WelcomeToCruzallWidget(),
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
          child: WalletWidget(wallet, appState),
        ),
        routes: <String, WidgetBuilder>{
          '/settings': (BuildContext context) => SimpleScaffold(
              CruzallSettings(),
              title: Localization.of(context).settings),
          '/network': (BuildContext context) => ScopedModel(
              model: appState.wallet,
              child: ScopedModelDescendant<WalletModel>(
                  builder: (context, child, model) {
                final Localization locale = Localization.of(context);
                return SimpleScaffold(CruzawlNetworkSettings(),
                    title: locale
                        .networkType(locale.ticker(wallet.currency.ticker)));
              })),
          '/wallet': (BuildContext context) =>
              SimpleScaffold(WalletSettingsWidget(wallet), title: wallet.name),
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
          final PagePath page = parsePagePath(settings.name);
          switch (page.page) {
            case 'address':
              return MaterialPageRoute(
                  settings: settings,
                  builder: (context) {
                    if (page.arg == 'cruzbase')
                      return CruzbaseWidget(
                          wallet.currency, wallet.currency.network.tip);

                    Address address = wallet.addresses[page.arg];
                    return address != null
                        ? SimpleScaffold(AddressWidget(wallet, address),
                            title: Localization.of(context).address)
                        : ScopedModel(
                            model: appState.wallet,
                            child: ScopedModelDescendant<WalletModel>(
                                builder: (context, child, model) =>
                                    ExternalAddressWidget(
                                        wallet.currency, page.arg,
                                        title: Localization.of(context)
                                            .externalAddress)));
                  });

            case 'block':
              return MaterialPageRoute(
                settings: settings,
                builder: (context) => ScopedModel(
                  model: appState.wallet,
                  child: ScopedModelDescendant<WalletModel>(
                    builder: (context, child, model) =>
                        BlockWidget(wallet.currency, blockId: page.arg),
                  ),
                ),
              );
            case 'height':
              return MaterialPageRoute(
                settings: settings,
                builder: (context) => ScopedModel(
                  model: appState.wallet,
                  child: ScopedModelDescendant<WalletModel>(
                    builder: (context, child, model) => BlockWidget(
                        wallet.currency,
                        blockHeight: int.parse(page.arg)),
                  ),
                ),
              );
            case 'tip':
              return MaterialPageRoute(
                settings: settings,
                builder: (context) => ScopedModel(
                  model: appState.wallet,
                  child: ScopedModelDescendant<WalletModel>(
                    builder: (context, child, model) =>
                        BlockWidget(wallet.currency),
                  ),
                ),
              );
            case 'transaction':
              return MaterialPageRoute(
                settings: settings,
                builder: (context) => ScopedModel(
                  model: appState.wallet,
                  child: ScopedModelDescendant<WalletModel>(
                      builder: (context, child, model) {
                    Transaction transaction = wallet.transactionIds[page.arg];
                    return transaction != null
                        ? TransactionWidget(wallet.currency,
                            WalletTransactionInfo(wallet, transaction),
                            transaction: transaction)
                        : TransactionWidget(wallet.currency, TransactionInfo(),
                            transactionIdText: page.arg,
                            onHeightTap: (tx) =>
                                appState.navigateToHeight(context, tx.height));
                  }),
                ),
              );
            default:
              return null;
          }
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
