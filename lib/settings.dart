// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

import 'package:scoped_model/scoped_model.dart';

import 'package:cruzall/cruzawl-ui/model.dart';
import 'package:cruzall/cruzawl-ui/ui.dart';
import 'package:cruzawl/preferences.dart';

class CruzallSettings extends StatefulWidget {
  @override
  _CruzallSettingsState createState() => _CruzallSettingsState();
}

class _CruzallSettingsState extends State<CruzallSettings> {
  @override
  Widget build(BuildContext context) {
    final Cruzawl appState =
        ScopedModel.of<Cruzawl>(context, rebuildOnChange: true);
    final bool encryptionEnabled = appState.preferences.walletsEncrypted;
    final bool warningEnabled = appState.preferences.insecureDeviceWarning;
    final bool unitTestBeforeCreating =
        appState.preferences.unitTestBeforeCreating;
    final bool verifyAddressEveryLoad =
        appState.preferences.verifyAddressEveryLoad;
    final TextStyle labelStyle = TextStyle(
      fontFamily: 'MartelSans',
      color: Colors.grey);

    final List<Widget> ret = <Widget>[
      Container(
        height: 200,
        child: Image.asset('assets/cruzbit.png'),
      ),
      ListTile(
        leading: Container(
            padding: EdgeInsets.all(10),
            child: Image.asset('assets/icon.png')),
        title: Text('Version'),
        trailing: Text(appState.packageInfo == null
            ? 'Unknown'
            : appState.packageInfo.version),
      ),
      ListTile(
        leading: Icon(Icons.color_lens),
        title: Text('Theme'),
        trailing: DropdownButton<String>(
          value: appState.preferences.theme,
          onChanged: (String val) {
            appState.preferences.theme = val;
            appState.setState(() => appState.setTheme());
          },
          items: buildDropdownMenuItem(themes.keys.toList()),
        ),
      ),
      ListTile(
        leading:
            Icon(encryptionEnabled ? Icons.lock_outline : Icons.lock_open),
        title: Text('Encryption'),
        trailing: Switch(
          value: encryptionEnabled,
          onChanged: (bool value) async {
            var password = value
                ? await Navigator.of(context).pushNamed('/enableEncryption')
                : null;
            setState(() => appState.preferences.encryptWallets(password));
          },
        ),
      ),
      ListTile(
        leading: Icon(warningEnabled ? Icons.lock_outline : Icons.lock_open),
        title: Text('Insecure device warning'),
        trailing: Switch(
          value: warningEnabled,
          onChanged: (bool value) => setState(
              () => appState.preferences.insecureDeviceWarning = value),
        ),
      ),
      ListTile(
        leading: Icon(
            verifyAddressEveryLoad ? Icons.lock_outline : Icons.lock_open),
        title: Text('Verify key pairs every load'),
        trailing: Switch(
          value: verifyAddressEveryLoad,
          onChanged: (bool value) => setState(
              () => appState.preferences.verifyAddressEveryLoad = value),
        ),
      ),
      ListTile(
        leading: Icon(
            unitTestBeforeCreating ? Icons.lock_outline : Icons.lock_open),
        title: Text('Unit test before creating wallets'),
        trailing: Switch(
          value: unitTestBeforeCreating,
          onChanged: (bool value) => setState(
              () => appState.preferences.unitTestBeforeCreating = value),
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
      ListTile(
        title: Text('Debug log'),
        trailing: Switch(
          value: appState.preferences.debugLog,
          onChanged: (bool value) {
            appState.preferences.debugLog = value;
            appState.setState(() => appState.debugLog = value ? '' : null);
          },
        ),
      ),
    ];

    if (appState.preferences.debugLog && appState.debugLog != null) {
      ret.add(
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Debug Log ', style: labelStyle),
              IconButton(
                icon: Icon(Icons.content_copy),
                color: appState.theme.linkColor,
                onPressed: () => appState.setClipboardText(context, appState.debugLog),
              ),
            ]),
        ),
      );

      ret.add(
        Container(
          height: 600,
          padding: EdgeInsets.only(left: 32, right: 32),
          child: SingleChildScrollView(
            child: Text(appState.debugLog))
          ),
      );
    }

    return ListView(
      padding: EdgeInsets.only(top: 20),
      children: ret,
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
            FocusScope.of(context).requestFocus(FocusNode());
            Navigator.of(context).pop(password);
          },
        ),
      ]),
    );
  }
}
