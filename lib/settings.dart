// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

import 'package:scoped_model/scoped_model.dart';

import 'package:cruzall/cruzawl-ui/ui.dart';
import 'package:cruzall/model/cruzall.dart';
import 'package:cruzall/model/preferences.dart';

class CruzallSettings extends StatefulWidget {
  @override
  _CruzallSettingsState createState() => _CruzallSettingsState();
}

class _CruzallSettingsState extends State<CruzallSettings> {
  @override
  Widget build(BuildContext context) {
    final Cruzall appState =
        ScopedModel.of<Cruzall>(context, rebuildOnChange: true);
    final bool enabled = appState.preferences.walletsEncrypted;
    return ListView(
      children: <Widget>[
        ListTile(
          leading: Icon(enabled ? Icons.lock_outline : Icons.lock_open),
          title: Text('Encryption'),
          trailing: Switch(
            value: enabled,
            onChanged: (bool value) async {
              var password = value
                  ? await Navigator.of(context).pushNamed('/enableEncryption')
                  : null;
              setState(() => appState.preferences.encryptWallets(password));
            },
          ),
        ),
        ListTile(
          leading: Icon(Icons.color_lens),
          title: Text('Theme'),
          trailing: DropdownButton<String>(
            value: appState.preferences.theme,
            onChanged: (String val) {
              appState.preferences.theme = val;
              appState.setState(() {});
            },
            items: buildDropdownMenuItem(themes.keys.toList()),
          ),
        ),
        ListTile(
          title: Text('Show wallet name in title'),
          trailing: Switch(
            value: appState.preferences.walletNameInTitle,
            onChanged: (bool value) {
              appState.preferences.walletNameInTitle = value;
              appState.setState(() {});
            },
          ),
        ),
      ],
    );
  }
}

class EnableEncryptionWidget extends StatefulWidget {
  @override
  _EnableEncryptionWidgetState createState() => _EnableEncryptionWidgetState();
}

class _EnableEncryptionWidgetState extends State<EnableEncryptionWidget> {
  final formKey = GlobalKey<FormState>();
  final passwordKey = GlobalKey<FormFieldState>();
  String password, confirm;

  @override
  Widget build(BuildContext c) {
    return Form(
      key: formKey,
      child: ListView(children: <Widget>[
        ListTile(
          subtitle: TextFormField(
            key: passwordKey,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Password',
            ),
            validator: (value) {
              if (!(value.length > 0)) return "Password can't be empty.";
              return null;
            },
            onSaved: (val) => password = val,
          ),
        ),
        ListTile(
          subtitle: TextFormField(
            obscureText: true,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Confirm password',
            ),
            validator: (value) {
              if (passwordKey.currentState.value != value)
                return "Passwords don't match.";
              return null;
            },
            onSaved: (val) => confirm = val,
          ),
        ),
        RaisedGradientButton(
          labelText: 'Encrypt',
          padding: EdgeInsets.all(32),
          onPressed: () {
            if (!formKey.currentState.validate()) return;
            formKey.currentState.save();
            formKey.currentState.reset();
            Navigator.of(context).pop(password);
          },
        ),
      ]),
    );
  }
}
