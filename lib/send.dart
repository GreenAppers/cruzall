// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:barcode_scan/barcode_scan.dart';
import 'package:scoped_model/scoped_model.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl/wallet.dart';

import 'package:cruzall/address.dart';
import 'package:cruzall/cruzawl-ui/localization.dart';
import 'package:cruzall/cruzawl-ui/model.dart';
import 'package:cruzall/cruzawl-ui/ui.dart';

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
  final TextEditingController toController = TextEditingController();
  String fromInput, toInput, memoInput;
  num amountInput, feeInput;
  Wallet lastWallet;

  @override
  void dispose() {
    fromController.dispose();
    toController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Localization locale = Localization.of(context);
    final Cruzawl appState = ScopedModel.of<Cruzawl>(context);
    final TextStyle labelTextStyle = appState.theme.titleStyle;
    final Wallet wallet =
        ScopedModel.of<WalletModel>(context, rebuildOnChange: true).wallet;
    final Currency currency = wallet.currency;

    if (lastWallet == null || lastWallet != wallet) {
      lastWallet = wallet;
      fromController.text = widget.wallet.addresses.values
          .toList()
          .reduce(Address.reduceBalance)
          .publicKey
          .toJson();
      fromController.selection = TextSelection(baseOffset: 0, extentOffset: 0);
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
      child: ListView(
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
                        child: Text(locale.from, style: labelTextStyle),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: chooseAddress,
                      child: TextFormField(
                        enabled: false,
                        maxLines: null,
                        controller: fromController,
                        textAlign: TextAlign.right,
                        keyboardType: TextInputType.multiline,
                        validator: (value) {
                          Address fromAddress = wallet.addresses[value];
                          if (fromAddress == null) return locale.unknownAddress;
                          if (fromAddress.privateKey == null)
                            return locale.watchOnlyWallet;
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
                      child: Text(locale.payTo, style: labelTextStyle),
                    ),
                    TextFormField(
                      maxLines: null,
                      controller: toController,
                      textAlign: TextAlign.right,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        suffixIcon: IconButton(
                          icon: Icon(Icons.camera_alt),
                          onPressed: scan,
                        ),
                        hintText: '',
                      ),
                      validator: (value) {
                        if (currency.fromPublicAddressJson(value) == null)
                          return locale.invalidAddress;
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
                      child: Text(locale.memo, style: labelTextStyle),
                    ),
                    TextFormField(
                      maxLines: null,
                      textAlign: TextAlign.right,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: '',
                      ),
                      validator: (value) {
                        if (value.length > 100) return locale.maxMemoLength;
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
                      child: Text(locale.amount, style: labelTextStyle),
                    ),
                    TextFormField(
                      key: amountKey,
                      textAlign: TextAlign.right,
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: '0.0',
                        suffixText: ' ' + locale.ticker(currency.ticker),
                      ),
                      validator: (value) {
                        num v = currency.parse(value);
                        if (!(v > 0)) return locale.valueMustBePositive;
                        Address fromAddress =
                            wallet.addresses[fromController.text];
                        if (fromAddress != null) {
                          if (fromAddress.privateKey == null)
                            return locale.watchOnlyWallet;
                          if (v > fromAddress.balance)
                            return locale.insufficientFunds;
                        }
                        if (currency.network.minAmount == null)
                          return locale.networkOffline;
                        if (v < currency.network.minAmount)
                          return locale.minAmount(currency.network.minAmount);
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
                      child: Text(locale.fee, style: labelTextStyle),
                    ),
                    TextFormField(
                      initialValue: currency.suggestedFee(null),
                      textAlign: TextAlign.right,
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: currency.suggestedFee(null),
                        suffixText: ' ' + locale.ticker(currency.ticker),
                      ),
                      validator: (value) {
                        num v = currency.parse(value);
                        if (!(v > 0)) return locale.valueMustBePositive;
                        num amount =
                            currency.parse(amountKey.currentState.value);
                        Address fromAddress =
                            wallet.addresses[fromController.text];
                        if (fromAddress != null &&
                            (amount + v) > fromAddress.balance)
                          return locale.insufficientFunds;
                        if (currency.network.tipHeight == null ||
                            currency.network.tipHeight == 0 ||
                            currency.network.minFee == null)
                          return locale.networkOffline;
                        if (v < currency.network.minFee)
                          return locale.minFee(currency.network.minFee);
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
            labelText: locale.send,
            onPressed: () async {
              if (!formKey.currentState.validate()) return;
              formKey.currentState.save();
              formKey.currentState.reset();
              FocusScope.of(context).requestFocus(FocusNode());
              Scaffold.of(context)
                  .showSnackBar(SnackBar(content: Text(locale.sending)));
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
                Scaffold.of(context).showSnackBar(SnackBar(
                    content: Text(
                        locale.sentTransactionId(transactionId.toJson()))));
              else
                Scaffold.of(context)
                    .showSnackBar(SnackBar(content: Text(locale.sendFailed)));
            },
          ),
        ],
      ),
    );
  }

  void chooseAddress() async {
    var addr = await Navigator.of(context).pushNamed('/sendFrom');
    if (addr != null) fromController.text = addr;
    fromController.selection = TextSelection(baseOffset: 0, extentOffset: 0);
  }

  Future scan() async {
    try {
      String barcode = await BarcodeScanner.scan();
      debugPrint('scan: $barcode');
      setState(() => toController.text = barcode);
    } on PlatformException catch (e) {
      if (e.code == BarcodeScanner.CameraAccessDenied) {
        debugPrint(
            'scan failed: The user did not grant the camera permission.');
      } else {
        debugPrint('scan failed: $e');
      }
    } on FormatException {
      debugPrint(
          'scan aborted: User returned using the "back"-button before scanning anything.');
    } catch (e) {
      debugPrint('scan failed with unknown error: $e');
    }
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
