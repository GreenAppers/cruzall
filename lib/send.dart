// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

import 'package:scoped_model/scoped_model.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzall/cruzawl-ui/ui.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzall/address.dart';
import 'package:cruzall/model/wallet.dart';

class WalletSendWidget extends StatefulWidget {
  final Wallet wallet;
  WalletSendWidget(this.wallet);

  @override
  _WalletSendWidgetState createState() => _WalletSendWidgetState();
}

class _WalletSendWidgetState extends State<WalletSendWidget> {
  final formKey = GlobalKey<FormState>();
  final amountKey = GlobalKey<FormFieldState>();
  final TextEditingController fromController = TextEditingController();
  String fromInput, toInput, memoInput;
  num amountInput, feeInput;
  Wallet lastWallet;

  @override
  void dispose() {
    fromController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Wallet wallet =
        ScopedModel.of<Wallet>(context, rebuildOnChange: true);
    final Currency currency = wallet.currency;
    final TextStyle labelTextStyle = TextStyle(fontFamily: 'MartelSans');

    if (lastWallet == null || lastWallet != wallet) {
      lastWallet = wallet;
      fromController.text = widget.wallet.addresses.values
          .toList()
          .reduce(Address.reduceBalance)
          .publicKey
          .toJson();
      fromController.selection = TextSelection(baseOffset: 0, extentOffset: 0);
    }

    return ListView(
      padding: EdgeInsets.all(32.0),
      children: <Widget>[
        Form(
          key: formKey,
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: <int, TableColumnWidth>{
              0: IntrinsicColumnWidth(),
              1: IntrinsicColumnWidth(),
            },
            children: <TableRow>[
              TableRow(
                children: <Widget>[
                  GestureDetector(
                    onTap: chooseAddress,
                    child: const Icon(Icons.person),
                  ),
                  GestureDetector(
                    onTap: chooseAddress,
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text('From', style: labelTextStyle),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: chooseAddress,
                    child: TextFormField(
                      enabled: false,
                      controller: fromController,
                      textAlign: TextAlign.right,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        Address fromAddress = wallet.addresses[value];
                        if (fromAddress == null) return 'Unknown address';
                        return null;
                      },
                      onSaved: (value) => fromInput = value,
                    ),
                  ),
                ],
              ),
              TableRow(
                children: <Widget>[
                  const Icon(Icons.send),
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text('Pay to', style: labelTextStyle),
                  ),
                  TextFormField(
                    textAlign: TextAlign.right,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: '',
                    ),
                    validator: (value) {
                      if (currency.fromPublicAddressJson(value) == null)
                        return 'Invalid address';
                      return null;
                    },
                    onSaved: (value) => toInput = value,
                  ),
                ],
              ),
              TableRow(
                children: <Widget>[
                  const Icon(Icons.edit),
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text('Memo', style: labelTextStyle),
                  ),
                  TextFormField(
                    textAlign: TextAlign.right,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: '',
                    ),
                    validator: (value) {
                      if (value.length > 100)
                        return 'Maximum memo length is 100';
                      return null;
                    },
                    onSaved: (value) => memoInput = value,
                  ),
                ],
              ),
              TableRow(
                children: <Widget>[
                  const Icon(Icons.attach_money),
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text('Amount', style: labelTextStyle),
                  ),
                  TextFormField(
                    key: amountKey,
                    textAlign: TextAlign.right,
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: '0.0',
                      suffixText: ' ' + currency.ticker,
                    ),
                    validator: (value) {
                      num v = currency.parse(value);
                      if (!(v > 0)) return "Value must be positive";
                      Address fromAddress =
                          wallet.addresses[fromController.text];
                      if (fromAddress != null && v > fromAddress.balance)
                        return 'Insufficient funds';
                      if (currency.network.minAmount == null)
                        return 'Network offline';
                      if (v < currency.network.minAmount)
                        return 'Minimum amount is ${currency.network.minAmount}';
                      return null;
                    },
                    onSaved: (value) => amountInput = currency.parse(value),
                  ),
                ],
              ),
              TableRow(
                children: <Widget>[
                  const Icon(Icons.rowing),
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text('Fee', style: labelTextStyle),
                  ),
                  TextFormField(
                    textAlign: TextAlign.right,
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: currency.suggestedFee(null),
                      suffixText: ' ' + currency.ticker,
                    ),
                    validator: (value) {
                      num v = currency.parse(value);
                      if (!(v > 0)) return "Value must be positive";
                      num amount = currency.parse(amountKey.currentState.value);
                      Address fromAddress =
                          wallet.addresses[fromController.text];
                      if (fromAddress != null &&
                          (amount + v) > fromAddress.balance)
                        return 'Insufficient funds';
                      if (currency.network.tipHeight == null ||
                          currency.network.tipHeight == 0 ||
                          currency.network.minFee == null)
                        return 'Network offline';
                      if (v < currency.network.minFee)
                        return 'Minimum fee is ${currency.network.minFee}';
                      return null;
                    },
                    onSaved: (value) => feeInput = currency.parse(value),
                  ),
                ],
              ),
            ],
          ),
        ),
        RaisedGradientButton(
          labelText: 'Send',
          onPressed: () async {
            if (!formKey.currentState.validate()) return;
            formKey.currentState.save();
            formKey.currentState.reset();
            FocusScope.of(context).requestFocus(FocusNode());
            Scaffold.of(context)
                .showSnackBar(SnackBar(content: Text('Sending...')));
            Address fromAddress = wallet.addresses[fromInput];
            Transaction transaction = await wallet.newTransaction(
                currency.signedTransaction(
                    fromAddress,
                    currency.fromPublicAddressJson(toInput),
                    amountInput,
                    feeInput,
                    memoInput,
                    currency.network.tipHeight,
                    expires: currency.network.tipHeight + 3));

            TransactionId transactionId;
            for (int i = 0; transactionId == null && i < 3; i++) {
              Peer peer = await currency.network.getPeer();
              if (peer == null) continue;
              transactionId = await peer.putTransaction(transaction);
            }
            if (transactionId != null)
              Scaffold.of(context).showSnackBar(
                  SnackBar(content: Text('Sent ' + transactionId.toJson())));
            else
              Scaffold.of(context)
                  .showSnackBar(SnackBar(content: Text('Send failed')));
          },
        ),
      ],
    );
  }

  void chooseAddress() async {
    var addr = await Navigator.of(context).pushNamed('/sendFrom');
    if (addr != null) fromController.text = addr;
    fromController.selection = TextSelection(baseOffset: 0, extentOffset: 0);
  }
}

class SendFromWidget extends StatelessWidget {
  final VoidCallback onTap;
  final Wallet wallet;
  final List<Address> addresses;
  SendFromWidget(this.wallet, {this.onTap})
      : addresses = wallet.addresses.values.where((v) => v.balance > 0).toList()
          ..sort(Address.compareBalance);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: addresses.length,
      itemBuilder: (BuildContext context, int index) =>
          AddressListTile(wallet, addresses[index], onTap: onTap),
    );
  }
}
