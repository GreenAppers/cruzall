// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:math';

import 'package:flutter/material.dart';

import 'package:qr_flutter/qr_flutter.dart';

import 'package:cruzall/cruzawl-ui/transaction.dart';
import 'package:cruzall/cruzawl-ui/ui.dart';
import 'package:cruzall/wallet.dart';
import 'package:cruzawl/currency.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl/util.dart';
import 'package:cruzawl/wallet.dart';

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
  final TextStyle labelTextStyle = TextStyle(
    fontFamily: 'MartelSans',
    color: Colors.grey,
  );

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
    final Size screenSize = MediaQuery.of(context).size;
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
        child: Text('Address', style: labelTextStyle),
      ),
      Container(
        padding: EdgeInsets.only(right: 32),
        child: CopyableText(addressText),
      ),
    ];

    if (address.chainCode != null)
      top.add(HideableWidget(
        title: 'Chain Code',
        child: CopyableText(address.chainCode.toJson()),
      ));

    top.add(
      HideableWidget(
        title: 'Private Key',
        child: CopyableText(address.privateKey.toJson()),
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
        title: Text('Account', style: labelTextStyle),
        trailing: Text(address.accountId.toString()),
      ),
    );
    if (address.chainIndex != null)
      header.add(
        ListTile(
          title: Text('Chain Index', style: labelTextStyle),
          trailing: Text(address.chainIndex.toString()),
        ),
      );
    header.add(
      ListTile(
        title: Text('State', style: labelTextStyle),
        trailing: Text(address.state.toString().split('.')[1]),
      ),
    );
    header.add(
      ListTile(
        title: Text('Balance', style: labelTextStyle),
        trailing: Text(widget.wallet.currency.format(address.balance)),
      ),
    );
    header.add(
      ListTile(
        title: Text('Transactions', style: labelTextStyle),
        trailing:
            Text((transactions != null ? transactions.length : 0).toString()),
      ),
    );
    if (address.earliestSeen != null)
      header.add(
        ListTile(
          title: Text('Earliest seen', style: labelTextStyle),
          trailing: Text(address.earliestSeen.toString()),
        ),
      );
    if (address.latestSeen != null)
      header.add(
        ListTile(
          title: Text('Latest seen', style: labelTextStyle),
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
    if (index == header.length)
      return Center(child: Text('Transactions', style: labelTextStyle));

    int transactionIndex = index - header.length - 1;
    if (transactionIndex < transactions.length) {
      Transaction tx = transactions.data[transactionIndex];
      return TransactionListTile(
          widget.wallet.currency, tx, WalletTransactionInfo(widget.wallet, tx),
          onTap: (tx) => Navigator.of(context)
              .pushNamed('/transaction/' + tx.id().toJson()));
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
