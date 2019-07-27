// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:math';

import 'package:flutter/material.dart';

import 'package:qr_flutter/qr_flutter.dart';
import 'package:scoped_model/scoped_model.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/wallet.dart';

import 'package:cruzall/cruzawl-ui/localizations.dart';
import 'package:cruzall/cruzawl-ui/model.dart';
import 'package:cruzall/cruzawl-ui/ui.dart';

class WalletReceiveWidget extends StatefulWidget {
  @override
  _WalletReceiveWidgetState createState() => _WalletReceiveWidgetState();
}

class _WalletReceiveWidgetState extends State<WalletReceiveWidget> {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations locale = AppLocalizations.of(context);
    final Cruzawl appState = ScopedModel.of<Cruzawl>(context);
    final Wallet wallet =
        ScopedModel.of<WalletModel>(context, rebuildOnChange: true).wallet;
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
              child: Text(locale.address, style: appState.theme.linkStyle),
            ),
            CopyableText(
              addressText,
              appState.setClipboardText,
              onTap: () => appState.navigateToAddressText(context, addressText),
            ),
            Container(
              padding: EdgeInsets.all(32),
              child: FlatButton.icon(
                icon: Icon(
                  Icons.refresh,
                  color: appState.theme.linkColor,
                ),
                label: Text(
                  locale.generateNewAddress,
                  style: TextStyle(
                    color: appState.theme.linkColor,
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
