// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:scoped_model/scoped_model.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/wallet.dart';

import 'package:cruzall/cruzawl-ui/model.dart';
import 'package:cruzall/cruzawl-ui/transaction.dart';
import 'package:cruzall/wallet.dart';

class WalletBalanceWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Wallet wallet =
        ScopedModel.of<WalletModel>(context, rebuildOnChange: true).wallet;
    final Currency currency = wallet.currency;
    final int numTransactions = wallet.transactions.data.length;
    final bool hasPeer =
        currency.network != null ? currency.network.hasPeer : false;
    final ThemeData theme = Theme.of(context);
    final TextStyle labelStyle =
        TextStyle(fontFamily: 'MartelSans', color: Colors.grey);
    final TextStyle linkStyle = TextStyle(
      color: theme.accentColor,
    );

    final List<Widget> ret = <Widget>[
      Container(
        padding: EdgeInsets.only(top: 32),
        child: RichText(
          text: !hasPeer
              ? TextSpan(text: 'Your current balance is:', style: labelStyle)
              : TextSpan(
                  style: labelStyle,
                  text: 'Your balance at block height ',
                  children: <TextSpan>[
                    TextSpan(
                      style: linkStyle,
                      text: '${currency.network.tipHeight}',
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => Navigator.of(context)
                            .pushNamed('/height/${currency.network.tipHeight}'),
                    ),
                    TextSpan(text: ' is:'),
                  ],
                ),
        ),
      ),
      Container(
        padding: EdgeInsets.only(bottom: 32),
        child: Text(
          currency.format(wallet.balance),
          style: Theme.of(context).textTheme.display1,
        ),
      ),
    ];

    if (wallet.maturesBalance > 0) {
      ret.add(Text(
          'Your balance maturing by height ${wallet.maturesHeight} is:',
          style: labelStyle));
      ret.add(
        Container(
          padding: EdgeInsets.only(bottom: 32),
          child: Text(
            currency.format(wallet.maturesBalance),
            style: Theme.of(context).textTheme.display1,
          ),
        ),
      );
    }

    if (numTransactions > 0) {
      ret.add(
        Text(
          'Recent History',
          style: labelStyle,
        ),
      );

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
                      Navigator.of(context).pushNamed('/address/${tx.toText}'),
                  onFromTap: (tx) => Navigator.of(context)
                      .pushNamed('/address/${tx.fromText}'),
                  onTap: (tx) => Navigator.of(context)
                      .pushNamed('/transaction/' + tx.id().toJson()),
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
