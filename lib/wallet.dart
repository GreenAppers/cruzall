// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bip39/bip39.dart';
import 'package:scoped_model/scoped_model.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/test.dart';
import 'package:cruzawl/util.dart';
import 'package:cruzawl/wallet.dart';

import 'package:cruzall/address.dart';
import 'package:cruzall/cruzawl-ui/model.dart';
import 'package:cruzall/cruzawl-ui/ui.dart';
import 'package:cruzall/cruzawl-ui/transaction.dart';

class WalletWidget extends StatelessWidget {
  final Wallet wallet;
  final List<Address> addresses;
  WalletWidget(this.wallet)
      : addresses = wallet.addresses.values.toList()
          ..sort(Address.compareBalance);

  @override
  Widget build(BuildContext context) {
    final Cruzawl appState = ScopedModel.of<Cruzawl>(context);
    final TextStyle labelTextStyle = TextStyle(
      fontFamily: 'MartelSans',
      color: Colors.grey,
    );

    List<Widget> header = <Widget>[
      ListTile(
        title: Text('Name', style: labelTextStyle),
        trailing: Text(wallet.name),
      ),
      ListTile(
        title: Text('Accounts', style: labelTextStyle),
        trailing: Text(wallet.accounts.length.toString()),
      ),
      ListTile(
        title: Text('Addresses', style: labelTextStyle),
        trailing: Text(addresses.length.toString()),
      ),
      ListTile(
        title: Text('Balance', style: labelTextStyle),
        trailing: Text(wallet.currency.format(wallet.balance)),
      ),
      ListTile(
        title: Text('Active transactions', style: labelTextStyle),
        trailing: Text(wallet.pendingCount.toString()),
      ),
      ListTile(
        title: Text('Maturing transactions', style: labelTextStyle),
        trailing: Text(wallet.maturing.length.toString()),
      ),
    ];

    if (wallet.hdWallet)
      header.add(
        HideableWidget(
          title: 'Seed phrase',
          child: CopyableText(wallet.seedPhrase, appState.setClipboardText),
        ),
      );

    header.add(
      Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            padding: EdgeInsets.only(top: 32),
            child: Text('Danger Zone', style: labelTextStyle),
          ),
          Container(
            margin: EdgeInsets.only(left: 16, bottom: 48),
            decoration: BoxDecoration(border: Border.all(color: Colors.red)),
            child: ListTile(
              title: Text('Delete this wallet'),
              subtitle: Text(
                  'Once you delete a wallet, there is no going back. Please be certain.'),
              trailing: RaisedButton(
                onPressed: () => deleteWallet(context, appState),
                textColor: Colors.red,
                child: Text('Delete this wallet'),
              ),
            ),
          ),
        ],
      ),
    );

    List<Widget> footer = <Widget>[
      RaisedGradientButton(
        labelText: 'Verify',
        padding: EdgeInsets.all(32),
        onPressed: () async {
          Scaffold.of(context)
              .showSnackBar(SnackBar(content: Text('Verifying...')));
          await Future.delayed(Duration(seconds: 1));

          int verifiedAddresses = 0, ranTests = appState.runUnitTests();
          bool unitTests = ranTests >= 0;
          if (unitTests)
            for (Address address in addresses)
              verifiedAddresses += address.verify() ? 1 : 0;

          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              content: TitledWidget(
                title: 'Verify',
                content: ListTile(
                  leading: Icon(unitTests ? Icons.check : Icons.close),
                  title: Text(unitTests
                      ? 'Verified $verifiedAddresses/${addresses.length} addresses and ${ranTests}/${ranTests} tests succeeded'
                      : 'Unit test failure'),
                ),
              ),
              actions: <Widget>[
                FlatButton(
                  child: const Text('Ok'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(32.0))),
            ),
          );
        },
      ),
      RaisedGradientButton(
        labelText: 'Copy Public Keys',
        padding: EdgeInsets.all(32),
        onPressed: () {
          String publicKeyList = '';
          for (Address address in addresses)
            publicKeyList += '${address.publicKey.toJson()}\n';
          appState.setClipboardText(context, publicKeyList);
          Scaffold.of(context).showSnackBar(SnackBar(content: Text('Copied.')));
        },
      ),
    ];

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(0, 16, 16, 16),
      itemCount: header.length + footer.length + addresses.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index < header.length) return header[index];
        if (index == header.length)
          return Center(child: Text('Addresses', style: labelTextStyle));
        int addressIndex = index - header.length - 1;
        if (addressIndex < addresses.length) {
          Address address = addresses[addressIndex];
          return AddressListTile(
            wallet,
            address,
            onTap: () => Navigator.of(context)
                .pushNamed('/address/${address.publicKey.toJson()}'),
          );
        } else {
          int footerIndex = addressIndex - addresses.length;
          if (footerIndex < footer.length) return footer[footerIndex];
          return null;
        }
      },
    );
  }

  void deleteWallet(BuildContext context, Cruzawl appState) {
    if (appState.wallets.length < 2) {
      Scaffold.of(context).showSnackBar(
          SnackBar(content: Text("Can't delete the only wallet.")));
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: TitledWidget(
          title: 'Delete Wallet',
          content: ListTile(
            leading: Icon(Icons.cast),
            title: Text(wallet.name),
            //subtitle: Text(wallet.seed.toJson()),
            //trailing: Icon(Icons.info_outline),
          ),
        ),
        actions: <Widget>[
          FlatButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          FlatButton(
            child: const Text('Delete'),
            onPressed: () {
              appState.removeWallet();
              appState.setState(() {});
              Navigator.of(context)
                  .popUntil(ModalRoute.withName(Navigator.defaultRouteName));
            },
          ),
        ],
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(32.0))),
      ),
    );
  }
}

class AddWalletWidget extends StatefulWidget {
  final Cruzawl appState;
  final bool welcome;
  AddWalletWidget(this.appState, {this.welcome = false});

  @override
  _AddWalletWidgetState createState() => _AddWalletWidgetState();
}

class _AddWalletWidgetState extends State<AddWalletWidget> {
  final formKey = GlobalKey<FormState>();
  final TextEditingController keyListController = TextEditingController();
  final TextEditingController seedPhraseController =
      TextEditingController(text: generateMnemonic());
  String name = 'My wallet', seedPhrase = '', currency = 'CRUZ';
  bool hdWallet = true, watchOnlyWallet = false;
  List<PrivateKey> keyList;
  List<PublicAddress> publicKeyList;

  @override
  void dispose() {
    seedPhraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    List<Widget> ret = <Widget>[];

    ret.add(
      ListTile(
        subtitle: TextFormField(
          enabled: false,
          initialValue: currency,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Currency',
          ),
          validator: (value) {
            if (Currency.fromJson(value) == null) return 'Unknown address';
            return null;
          },
          onSaved: (value) => currency = value,
        ),
      ),
    );

    ret.add(
      ListTile(
        subtitle: TextFormField(
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          initialValue: name,
          decoration: InputDecoration(
            labelText: 'Name',
          ),
          validator: (value) {
            if (widget.appState.wallets
                    .indexWhere((v) => v.wallet.name == value) !=
                -1) return 'Name must be unique.';
            return null;
          },
          onSaved: (val) => name = val,
        ),
      ),
    );

    ret.add(SwitchListTile(
      title: Text('HD Wallet'),
      value: hdWallet,
      onChanged: (bool value) => setState(() => hdWallet = value),
    ));

    if (!hdWallet)
      ret.add(
        SwitchListTile(
          title: Text('Watch-Only Wallet'),
          value: watchOnlyWallet,
          onChanged: (bool value) => setState(() => watchOnlyWallet = value),
        ),
      );

    if (hdWallet)
      ret.add(ListTile(
        subtitle: TextFormField(
          maxLines: 3,
          controller: seedPhraseController,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            labelText: 'Seed phrase',
            suffixIcon: IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () => seedPhraseController.text = generateMnemonic(),
            ),
          ),
          validator: (value) {
            if (!validateMnemonic(value)) return 'Invalid mnemonic.';
            return null;
          },
          onSaved: (val) => seedPhrase = val,
        ),
      ));
    else if (watchOnlyWallet)
      ret.add(
        ListTile(
            subtitle: TextFormField(
                maxLines: 10,
                controller: keyListController,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: 'Public Key List',
                ),
                validator: (value) {
                  Currency cur = Currency.fromJson(currency);
                  if (cur == null) return 'Invalid currency';
                  try {
                    List<PublicAddress> keys = value
                        .split('\\s+')
                        .map((key) => cur.fromPublicAddressJson(key))
                        .toList();
                    if (keys.length <= 0) return 'No public keys';
                  } catch (error) {
                    return '$error';
                  }
                },
                onSaved: (value) {
                  Currency cur = Currency.fromJson(currency);
                  publicKeyList = cur == null
                      ? null
                      : value
                          .split('\\s+')
                          .map((key) => cur.fromPublicAddressJson(key))
                          .toList();
                })),
      );
    else
      ret.add(
        ListTile(
            subtitle: TextFormField(
                maxLines: 10,
                controller: keyListController,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: 'Private Key List',
                ),
                validator: (value) {
                  Currency cur = Currency.fromJson(currency);
                  if (cur == null) return 'Invalid currency';
                  try {
                    List<PrivateKey> keys = value
                        .split('\\s+')
                        .map((key) => cur.fromPrivateKeyJson(key))
                        .toList();
                    if (keys.length <= 0) return 'No private keys';
                    for (PrivateKey key in keys)
                      if (!cur.fromPrivateKey(key).verify())
                        return 'verify failed: ${key.toJson()}';
                  } catch (error) {
                    return '$error';
                  }
                },
                onSaved: (value) {
                  Currency cur = Currency.fromJson(currency);
                  keyList = cur == null
                      ? null
                      : value
                          .split('\\s+')
                          .map((key) => cur.fromPrivateKeyJson(key))
                          .toList();
                })),
      );

    ret.add(
      RaisedGradientButton(
        labelText: 'Create',
        padding: EdgeInsets.all(32),
        onPressed: () async {
          if (!formKey.currentState.validate()) return;
          formKey.currentState.save();
          FocusScope.of(context).requestFocus(FocusNode());
          String explanation = hdWallet ? ' (PBKDF: 2048 iterations)' : '';
          Scaffold.of(context).showSnackBar(
              SnackBar(content: Text('Creating... $explanation')));
          widget.appState.setState(() => widget.appState.walletsLoading++);
          await Future.delayed(Duration(seconds: 1));

          if (widget.appState.preferences.unitTestBeforeCreating &&
              widget.appState.runUnitTests() < 0) return;

          if (hdWallet) {
            widget.appState.addWallet(Wallet.fromSeedPhrase(
                widget.appState.databaseFactory,
                widget.appState.getWalletFilename(name),
                name,
                Currency.fromJson(currency),
                seedPhrase,
                widget.appState.preferences,
                debugPrint,
                widget.appState.openedWallet));
          } else if (watchOnlyWallet) {
            widget.appState.addWallet(Wallet.fromPublicKeyList(
                widget.appState.databaseFactory,
                widget.appState.getWalletFilename(name),
                name,
                Currency.fromJson(currency),
                Seed(randBytes(64)),
                publicKeyList,
                widget.appState.preferences,
                debugPrint,
                widget.appState.openedWallet));
          } else {
            widget.appState.addWallet(Wallet.fromPrivateKeyList(
                widget.appState.databaseFactory,
                widget.appState.getWalletFilename(name),
                name,
                Currency.fromJson(currency),
                Seed(randBytes(64)),
                keyList,
                widget.appState.preferences,
                debugPrint,
                widget.appState.openedWallet));
          }

          widget.appState.setState(() => widget.appState.walletsLoading--);
          if (!widget.welcome) Navigator.of(context).pop();
        },
      ),
    );

    return Form(key: formKey, child: ListView(children: ret));
  }
}

class WalletTransactionInfo extends TransactionInfo {
  WalletTransactionInfo(Wallet wallet, Transaction tx)
      : super(
            toWallet: wallet.addresses.containsKey(tx.toText),
            fromWallet: wallet.addresses.containsKey(tx.fromText));
}
