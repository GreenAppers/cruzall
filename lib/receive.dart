// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:math';

import 'package:flutter/material.dart';

import 'package:qr_flutter/qr_flutter.dart';
import 'package:scoped_model/scoped_model.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzall/cruzawl-ui/ui.dart';
import 'package:cruzall/model/wallet.dart';

class WalletReceiveWidget extends StatefulWidget {
  @override
  _WalletReceiveWidgetState createState() => _WalletReceiveWidgetState();
}

class _WalletReceiveWidgetState extends State<WalletReceiveWidget> {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Wallet wallet =
        ScopedModel.of<Wallet>(context, rebuildOnChange: true);
    final Address address = wallet.getNextAddress();
    final Size screenSize = MediaQuery.of(context).size;
    final String addressText = address.publicKey.toJson();
    return ListView(
      padding: EdgeInsets.symmetric(vertical: 16.0),
      children: <Widget>[
        Center(
          child: QrImage(
            data: addressText,
            size: min(screenSize.width, screenSize.height) * 2 / 3.0,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Address:',
                style: TextStyle(
                  fontFamily: 'MartelSans',
                  color: Colors.grey,
                ),
              ),
            ),
            CopyableText(
              addressText,
              onTap: () =>
                  Navigator.of(context).pushNamed('/address/${addressText}'),
            ),
            Container(
              padding: EdgeInsets.all(32),
              child: FlatButton.icon(
                icon: Icon(
                  Icons.refresh,
                  color: theme.accentColor,
                ),
                label: Text(
                  'Generate new address',
                  style: TextStyle(
                    color: theme.accentColor,
                  ),
                ),
                onPressed: () => setState(() =>
                    wallet.updateAddressState(address, AddressState.open)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
