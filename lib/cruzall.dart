// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

import 'package:gradient_app_bar/gradient_app_bar.dart';
import 'package:scoped_model/scoped_model.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/wallet.dart';

import 'package:cruzall/cruzawl-ui/localization.dart';
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
          builder: (context) {
            final Localization locale = Localization.of(context);
            return AlertDialog(
              title: Text(locale.insecureDeviceWarning),
              content: Text(locale.insecureDeviceWarningDescription,
                  style: TextStyle(color: Colors.red)),
              actions: <Widget>[
                FlatButton(
                  child: Text(locale.ignore),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(32.0))),
            );
          }));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Currency currency = widget.wallet.currency;
    final Localization locale = Localization.of(context);

    return DefaultTabController(
      length: 3,
      initialIndex: 1,
      child: Scaffold(
        appBar: GradientAppBar(
          centerTitle: true,
          title: Text(
            locale.balanceTitle(locale.ticker(currency.ticker),
                currency.format(widget.wallet.balance)),
            overflow: TextOverflow.ellipsis,
            style: widget.appState.theme.titleStyle,
          ),
          backgroundColorStart: theme.primaryColor,
          backgroundColorEnd: theme.accentColor,
          leading: buildWalletsMenu(context),
          actions: <Widget>[
            (PopupMenuBuilder()
                  ..addItem(
                    icon: Icon(Icons.settings),
                    text: locale.settings,
                    onSelected: () =>
                        widget.appState.navigateToSettings(context),
                  )
                  ..addItem(
                    icon: Icon(Icons.vpn_lock),
                    text: locale.network,
                    onSelected: () =>
                        widget.appState.navigateToNetwork(context),
                  ))
                .build(
              icon: Icon(Icons.more_vert),
            ),
          ],
          bottom: TabBar(
            tabs: <Widget>[
              Tab(
                icon: Icon(Icons.attach_money),
                text: locale.receive,
              ),
              Tab(
                icon: Icon(Icons.receipt),
                text: locale.balance,
              ),
              Tab(
                icon: Icon(Icons.send),
                text: locale.send,
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
    final Localization locale = Localization.of(context);
    final PopupMenuBuilder walletsMenu = PopupMenuBuilder();

    for (WalletModel x in widget.appState.wallets) {
      bool activeWallet = x.wallet.name == widget.wallet.name;
      walletsMenu.addItem(
        text: x.wallet.name,
        icon: Icon(
            activeWallet ? Icons.check_box : Icons.check_box_outline_blank),
        onSelected: activeWallet
            ? () => widget.appState.navigateToWallet(context)
            : () => widget.appState.changeActiveWallet(x),
      );
    }
    walletsMenu.addItem(
      icon: Icon(Icons.add),
      text: locale.addWallet,
      onSelected: () => widget.appState.navigateToAddWallet(context),
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
    final Localization locale = Localization.of(context);

    return Form(
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
    );
  }
}
