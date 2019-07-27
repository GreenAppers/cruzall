// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:math';

import 'package:flutter/material.dart';

import 'package:qr_flutter/qr_flutter.dart';
import 'package:scoped_model/scoped_model.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl/util.dart';
import 'package:cruzawl/wallet.dart';

import 'package:cruzall/cruzawl-ui/localizations.dart';
import 'package:cruzall/cruzawl-ui/model.dart';
import 'package:cruzall/cruzawl-ui/transaction.dart';
import 'package:cruzall/cruzawl-ui/ui.dart';
import 'package:cruzall/wallet.dart';

class AddressWidget extends StatefulWidget {
  final Wallet wallet;
  final Address address;
  AddressWidget(this.wallet, this.address);

  @override
  _AddressWidgetState createState() => _AddressWidgetState();
}

class _AddressWidgetState extends State<AddressWidget> {
  List<Widget> header;
  SortedListSet<Transaction> transactions;

  void loadTransactions() {
    String addressText = widget.address.publicKey.toJson();
    transactions = SortedListSet(
        Transaction.timeCompare,
        widget.wallet.transactions.data
            .where((v) => v.fromText == addressText || v.toText == addressText)
            .toList());
  }

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    final Address address = widget.address;
    final String addressText = address.publicKey.toJson();
    final AppLocalizations locale = AppLocalizations.of(context);
    final Cruzawl appState = ScopedModel.of<Cruzawl>(context);
    final Size screenSize = MediaQuery.of(context).size;
    final TextStyle labelTextStyle = appState.theme.labelStyle;
    final bool fullyLoaded =
        address.loadedHeight == 0 && address.loadedIndex == 0;

    final List<Widget> top = <Widget>[
      Center(
        child: QrImage(
          data: addressText,
          size: min(screenSize.width, screenSize.height) * 2 / 3.0,
        ),
      ),
      Container(
        padding: const EdgeInsets.only(top: 16),
        child: Text(locale.address, style: labelTextStyle),
      ),
      Container(
        padding: EdgeInsets.only(right: 32),
        child: CopyableText(addressText, appState.setClipboardText),
      ),
    ];

    if (address.chainCode != null)
      top.add(HideableWidget(
        title: locale.chainCode,
        child:
            CopyableText(address.chainCode.toJson(), appState.setClipboardText),
      ));

    if (address.privateKey != null)
      top.add(
        HideableWidget(
          title: locale.privateKey,
          child: CopyableText(
              address.privateKey.toJson(), appState.setClipboardText),
        ),
      );

    header = <Widget>[
      Container(
        padding: EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: top,
        ),
      ),
    ];

    header.add(
      ListTile(
        title: Text(locale.account, style: labelTextStyle),
        trailing: Text(address.accountId.toString()),
      ),
    );
    if (address.chainIndex != null)
      header.add(
        ListTile(
          title: Text(locale.chainIndex, style: labelTextStyle),
          trailing: Text(address.chainIndex.toString()),
        ),
      );
    header.add(
      ListTile(
        title: Text(locale.state, style: labelTextStyle),
        trailing: Text(address.state.toString().split('.')[1]),
      ),
    );
    header.add(
      ListTile(
        title: Text(locale.balance, style: labelTextStyle),
        trailing: Text(widget.wallet.currency.format(address.balance)),
      ),
    );
    header.add(
      ListTile(
        title: Text(locale.transactions, style: labelTextStyle),
        trailing:
            Text((transactions != null ? transactions.length : 0).toString()),
      ),
    );
    if (address.earliestSeen != null)
      header.add(
        ListTile(
          title: Text(locale.earliestSeen, style: labelTextStyle),
          trailing: Text(address.earliestSeen.toString()),
        ),
      );
    if (address.latestSeen != null)
      header.add(
        ListTile(
          title: Text(locale.latestSeen, style: labelTextStyle),
          trailing: Text(address.latestSeen.toString()),
        ),
      );

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 16.0),
      itemCount: header.length +
          (transactions.length > 0
              ? (transactions.length + (fullyLoaded ? 1 : 2))
              : 0),
      itemBuilder: itemBuilder,
    );
  }

  Widget itemBuilder(BuildContext context, int index) {
    if (index < header.length) return header[index];
    if (index == header.length) {
      final AppLocalizations locale = AppLocalizations.of(context);
      final Cruzawl appState = ScopedModel.of<Cruzawl>(context);
      final TextStyle labelTextStyle = appState.theme.labelStyle;
      return Center(child: Text(locale.transactions, style: labelTextStyle));
    }

    int transactionIndex = index - header.length - 1;
    if (transactionIndex < transactions.length) {
      final Cruzawl appState = ScopedModel.of<Cruzawl>(context);
      Transaction tx = transactions.data[transactionIndex];
      return TransactionListTile(
          widget.wallet.currency, tx, WalletTransactionInfo(widget.wallet, tx),
          onTap: (tx) => appState.navigateToTransaction(context, tx));
    }

    assert(
        !(widget.address.loadedHeight == 0 && widget.address.loadedIndex == 0));

    if (widget.wallet.currency.network.hasPeer)
      widget.wallet.currency.network.getPeer().then((Peer peer) {
        if (peer != null)
          widget.wallet
              .getNextTransactions(peer, widget.address)
              .then((results) {
            if (mounted) setState(() => loadTransactions());
          });
      });

    return Center(child: CircularProgressIndicator());
  }
}

class AddressListTile extends StatelessWidget {
  final Wallet wallet;
  final Address address;
  final VoidCallback onTap;
  AddressListTile(this.wallet, this.address, {this.onTap});

  @override
  Widget build(BuildContext context) {
    final String addressText = address.publicKey.toJson();
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: ListTile(
        title: Text(addressText),
        leading: QrImage(data: addressText),
        trailing: Text(
          wallet.currency.format(address.balance),
          style: address.balance > 0 ? TextStyle(color: Colors.green) : null,
        ),
        onTap: onTap ?? () => Navigator.of(context).pop(addressText),
      ),
    );
  }
}
