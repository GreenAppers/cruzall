// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

import 'package:gradient_app_bar/gradient_app_bar.dart';
import 'package:scoped_model/scoped_model.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzall/cruzawl-ui/ui.dart';
import 'package:cruzall/balance.dart';
import 'package:cruzall/model/cruzall.dart';
import 'package:cruzall/model/wallet.dart';
import 'package:cruzall/receive.dart';
import 'package:cruzall/send.dart';

class CruzallWidget extends StatelessWidget {
  final Wallet wallet;
  final Cruzall appState;
  CruzallWidget(this.wallet, this.appState);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Currency currency = wallet.currency;

    return DefaultTabController(
      length: 3,
      initialIndex: 1,
      child: Scaffold(
        appBar: GradientAppBar(
          centerTitle: true,
          title: Text(
            currency.ticker + ' +' + currency.format(wallet.balance),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'MartelSans',
            ),
          ),
          backgroundColorStart: theme.primaryColor,
          backgroundColorEnd: theme.accentColor,
          leading: buildWalletsMenu(context),
          actions: <Widget>[
            (PopupMenuBuilder()
                  ..addItem(
                    icon: Icon(Icons.settings),
                    text: 'Settings',
                    onSelected: () =>
                        Navigator.of(context).pushNamed('/settings'),
                  )
                  ..addItem(
                    icon: Icon(Icons.vpn_lock),
                    text: 'Network',
                    onSelected: () =>
                        Navigator.of(context).pushNamed('/network'),
                  ))
                .build(
              icon: Icon(Icons.more_vert),
            ),
          ],
          bottom: TabBar(
            tabs: <Widget>[
              Tab(
                icon: Icon(Icons.attach_money),
                text: 'Receive',
              ),
              Tab(
                icon: Icon(Icons.receipt),
                text: 'Balance',
              ),
              Tab(
                icon: Icon(Icons.send),
                text: 'Send',
              ),
            ],
          ),
        ),
        body: appState.walletsLoading > 0
            ? (appState.fatal != null
                ? ErrorWidget.builder(appState.fatal)
                : Center(child: CircularProgressIndicator()))
            : TabBarView(
                children: <Widget>[
                  WalletReceiveWidget(),
                  WalletBalanceWidget(),
                  WalletSendWidget(wallet),
                ],
              ),
      ),
    );
  }

  Widget buildWalletsMenu(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final PopupMenuBuilder walletsMenu = PopupMenuBuilder();
    for (Wallet x in appState.wallets) {
      bool activeWallet = x.name == wallet.name;
      walletsMenu.addItem(
        text: x.name,
        icon: Icon(
            activeWallet ? Icons.check_box : Icons.check_box_outline_blank),
        onSelected: activeWallet
            ? () => Navigator.of(context).pushNamed('/wallet')
            : () => appState.changeActiveWallet(x),
      );
    }
    walletsMenu.addItem(
      icon: Icon(Icons.add),
      text: 'Add Wallet',
      onSelected: () => Navigator.of(context).pushNamed('/addWallet'),
    );

    return !appState.preferences.walletNameInTitle
        ? walletsMenu.build(
            child: Icon(
            Icons.menu,
            color: theme.primaryTextTheme.title.color,
          ))
        : OverflowBox(
            maxWidth: 200,
            alignment: Alignment.centerLeft,
            child: walletsMenu.build(
              padding: const EdgeInsets.all(0.0),
              child: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 10, 5, 10),
                    child: Icon(
                      Icons.menu,
                      color: theme.primaryTextTheme.title.color,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      wallet.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.primaryTextTheme.title.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
    final Cruzall appState = ScopedModel.of<Cruzall>(context);

    return Form(
      key: formKey,
      child: ListView(children: <Widget>[
        ListTile(
          subtitle: TextFormField(
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Password',
            ),
            validator: (value) {
              if (!(value.length > 0)) return "Password can't be empty.";
              return null;
            },
            onSaved: (val) => password = val,
          ),
        ),
        RaisedGradientButton(
          labelText: 'Unlock',
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
    );
  }
}
