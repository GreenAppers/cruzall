// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

import 'package:gradient_app_bar/gradient_app_bar.dart';
import 'package:scoped_model/scoped_model.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/wallet.dart';

import 'package:cruzall/cruzawl-ui/model.dart';
import 'package:cruzall/cruzawl-ui/ui.dart';
import 'package:cruzall/balance.dart';
import 'package:cruzall/receive.dart';
import 'package:cruzall/send.dart';

class CruzallWidget extends StatefulWidget {
  final Wallet wallet;
  final Cruzawl appState;
  CruzallWidget(this.wallet, this.appState);

  @override
  _CruzallWidgetState createState() => _CruzallWidgetState();
}

class _CruzallWidgetState extends State<CruzallWidget> {
  @override
  void initState() {
    super.initState();
    if (widget.appState.isTrustFall &&
        widget.appState.preferences.insecureDeviceWarning)
      Future.delayed(Duration(seconds: 0)).then((_) => showDialog(
          context: context,
          builder: (_) => AlertDialog(
                title: Text('Insecure Device Warning'),
                content: Text(
                    'A rooted or jailbroken device has been detected.\n\nFurther use not recommended.',
                    style: TextStyle(color: Colors.red)),
                actions: <Widget>[
                  FlatButton(
                    child: const Text('Ignore'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(32.0))),
              )));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Currency currency = widget.wallet.currency;

    return DefaultTabController(
      length: 3,
      initialIndex: 1,
      child: Scaffold(
        appBar: GradientAppBar(
          centerTitle: true,
          title: Text(
            currency.ticker + ' +' + currency.format(widget.wallet.balance),
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
        body: widget.appState.fatal != null
            ? ErrorWidget.builder(widget.appState.fatal)
            : (widget.appState.walletsLoading > 0
                ? Center(child: CircularProgressIndicator())
                : TabBarView(
                    children: <Widget>[
                      WalletReceiveWidget(),
                      WalletBalanceWidget(),
                      WalletSendWidget(widget.wallet),
                    ],
                  )),
      ),
    );
  }

  Widget buildWalletsMenu(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final PopupMenuBuilder walletsMenu = PopupMenuBuilder();
    for (WalletModel x in widget.appState.wallets) {
      bool activeWallet = x.wallet.name == widget.wallet.name;
      walletsMenu.addItem(
        text: x.wallet.name,
        icon: Icon(
            activeWallet ? Icons.check_box : Icons.check_box_outline_blank),
        onSelected: activeWallet
            ? () => Navigator.of(context).pushNamed('/wallet')
            : () => widget.appState.changeActiveWallet(x),
      );
    }
    walletsMenu.addItem(
      icon: Icon(Icons.add),
      text: 'Add Wallet',
      onSelected: () => Navigator.of(context).pushNamed('/addWallet'),
    );

    return !widget.appState.preferences.walletNameInTitle
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
                      widget.wallet.name,
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
    final Cruzawl appState = ScopedModel.of<Cruzawl>(context);

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
