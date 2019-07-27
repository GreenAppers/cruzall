// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:scoped_model/scoped_model.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/wallet.dart';

import 'package:cruzall/cruzawl-ui/localizations.dart';
import 'package:cruzall/cruzawl-ui/model.dart';
import 'package:cruzall/cruzawl-ui/transaction.dart';
import 'package:cruzall/wallet.dart';

class WalletBalanceWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations locale = AppLocalizations.of(context);
    final Cruzawl appState = ScopedModel.of<Cruzawl>(context);
    final Wallet wallet =
        ScopedModel.of<WalletModel>(context, rebuildOnChange: true).wallet;
    final Currency currency = wallet.currency;
    final int numTransactions = wallet.transactions.data.length;
    final bool hasPeer =
        currency.network != null ? currency.network.hasPeer : false;
    final TextStyle linkStyle = TextStyle(color: appState.theme.linkColor);

    final List<Widget> ret = <Widget>[
      Container(
        padding: EdgeInsets.only(top: 32),
        child: RichText(
          text: !hasPeer
              ? TextSpan(
                  text: locale.currentBalanceIs,
                  style: appState.theme.labelStyle)
              : AppLocalizations.parseTextSpan(
                  locale.balanceAtHeightIs(currency.network.tipHeight),
                  style: appState.theme.labelStyle,
                  tags: <String, TextSpan>{
                    'a': TextSpan(
                      style: linkStyle,
                      text: '${currency.network.tipHeight}',
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => appState.navigateToHeight(
                            context, currency.network.tipHeight),
                    ),
                  },
                ),
        ),
      ),
      Container(
        padding: EdgeInsets.only(bottom: 32),
        child: Text(
          currency.format(wallet.balance),
          style: theme.textTheme.display1,
        ),
      ),
    ];

    if (wallet.maturesBalance > 0) {
      ret.add(Text(locale.balanceMaturingByHeightIs(wallet.maturesHeight),
          style: appState.theme.labelStyle));
      ret.add(
        Container(
          padding: EdgeInsets.only(bottom: 32),
          child: Text(
            currency.format(wallet.maturesBalance),
            style: theme.textTheme.display1,
          ),
        ),
      );
    }

    if (numTransactions > 0) {
      ret.add(Text(locale.recentHistory, style: appState.theme.labelStyle));
      ret.add(
        Expanded(
          child: ListView.builder(
              itemCount: wallet.transactions.data.length,
              itemBuilder: (BuildContext context, int index) {
                Transaction tx = wallet.transactions.data[index];
                return TransactionListTile(
                  wallet.currency,
                  tx,
                  WalletTransactionInfo(wallet, tx),
                  onToTap: (tx) =>
                      appState.navigateToAddressText(context, tx.toText),
                  onFromTap: (tx) =>
                      appState.navigateToAddressText(context, tx.fromText),
                  onTap: (tx) => appState.navigateToTransaction(context, tx),
                );
              }),
        ),
      );
    }

    return Column(
      children: ret,
      mainAxisAlignment: MainAxisAlignment.center,
    );
  }
}
