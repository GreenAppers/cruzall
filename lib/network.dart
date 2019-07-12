// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

import 'package:scoped_model/scoped_model.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzall/cruzawl-ui/ui.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzall/model/cruzall.dart';

class CruzallNetworkSettings extends StatefulWidget {
  @override
  _CruzallNetworkSettingsState createState() => _CruzallNetworkSettingsState();
}

class _CruzallNetworkSettingsState extends State<CruzallNetworkSettings> {
  List<PeerPreference> peers;
  int selectedPeerIndex;

  @override
  Widget build(BuildContext context) {
    final Cruzall appState =
        ScopedModel.of<Cruzall>(context, rebuildOnChange: true);
    final PeerNetwork network = appState.wallet.currency.network;
    final ThemeData theme = Theme.of(context);

    peers = appState.preferences.peers;

    List<Widget> ret = <Widget>[
      SwitchListTile(
        title: Text('Network'),
        value: appState.preferences.networkEnabled,
        onChanged: (bool value) {
          appState.preferences.networkEnabled = value;
          appState.reconnectPeers(appState.wallet.currency);
          appState.setState(() {});
        },
        secondary: const Icon(Icons.vpn_lock),
      ),
    ];

    for (Peer peer in network.peers)
      ret.add(
        ListTile(
          leading: Icon(Icons.check),
          title: Text(peer.spec.name),
          subtitle: Text(peer.spec.url),
          trailing: IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {},
          ),
        ),
      );

    List<Widget> reorder = <Widget>[];
    for (int i = 0; i < peers.length; i++) {
      PeerPreference peer = peers[i];
      reorder.add(
        Container(
          key: ValueKey(peer),
          margin: EdgeInsets.all(5.0),
          child: ListTile(
            leading: Icon(peer.ignoreBadCert ? Icons.cast : Icons.vpn_lock),
            title: Text(peer.name),
            subtitle: Text(peer.url),
            trailing: Icon(Icons.menu),
            onTap: () => setState(
                () => selectedPeerIndex = i == selectedPeerIndex ? null : i),
          ),
          decoration: i == selectedPeerIndex
              ? BoxDecoration(
                  color: Colors.black38,
                  border: Border.all(color: Colors.black))
              : BoxDecoration(),
        ),
      );
    }

    ret.add(
      Center(
        child: Container(
          padding: EdgeInsets.only(top: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                icon: Icon(Icons.remove),
                color: theme.accentColor,
                onPressed: removeSelectedPeer,
              ),
              Text('Peers'),
              IconButton(
                icon: Icon(Icons.add),
                color: theme.accentColor,
                onPressed: () => Navigator.of(context).pushNamed('/addPeer'),
              ),
            ],
          ),
        ),
      ),
    );

    ret.add(
      Flexible(
        child: ReorderableListView(
          children: reorder,
          onReorder: (int oldIndex, int newIndex) {
            debugPrint('reorder $oldIndex -> $newIndex');
            setState(() {
              PeerPreference peer = peers[oldIndex];
              peers.insert(newIndex, peer);
              peers.removeAt(oldIndex + (newIndex < oldIndex ? 1 : 0));
              appState.preferences.peers = peers;
              if (selectedPeerIndex == oldIndex)
                selectedPeerIndex = newIndex - (newIndex > oldIndex ? 1 : 0);
            });
          },
        ),
      ),
    );

    return Column(children: ret);
  }

  void removeSelectedPeer() {
    if (selectedPeerIndex == null) return;
    final Cruzall appState = ScopedModel.of<Cruzall>(context);
    PeerPreference peer = peers[selectedPeerIndex];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: TitledWidget(
          title: 'Delete Peer',
          content: ListTile(
            leading: Icon(Icons.cast),
            title: Text(peer.name),
            subtitle: Text(peer.url),
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
              setState(() {
                peers.removeAt(selectedPeerIndex);
                appState.preferences.peers = peers;
                appState.reconnectPeers(appState.wallet.currency);
              });
              Navigator.of(context).pop();
            },
          ),
        ],
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(32.0))),
      ),
    );
  }
}

class AddPeerWidget extends StatefulWidget {
  @override
  _AddPeerWidgetState createState() => _AddPeerWidgetState();
}

class _AddPeerWidgetState extends State<AddPeerWidget> {
  final formKey = GlobalKey<FormState>();
  String name, url;
  bool certRequired = true;

  @override
  Widget build(BuildContext c) {
    final Cruzall appState = ScopedModel.of<Cruzall>(context);
    final Currency currency = appState.wallet.currency;
    final PeerNetwork network = currency.network;
    final List<PeerPreference> peers = appState.preferences.peers;

    return Form(
      key: formKey,
      child: ListView(children: <Widget>[
        ListTile(
          subtitle: TextFormField(
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            initialValue: name,
            decoration: InputDecoration(
              labelText: 'Name',
            ),
            validator: (value) {
              if (peers.indexWhere((v) => v.name == value) != -1)
                return 'Name must be unique.';
              return null;
            },
            onSaved: (val) => name = val,
          ),
        ),
        ListTile(
          subtitle: TextFormField(
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'URL',
            ),
            validator: (value) {
              try {
                network.parseUri(value, '');
              } on Exception {
                return 'Invalid URL.';
              }
              return null;
            },
            onSaved: (val) => url = val,
          ),
        ),
        ListTile(
          leading: Icon(certRequired ? Icons.lock_outline : Icons.lock_open),
          title: Text('Require SSL certificate'),
          trailing: Switch(
            value: certRequired,
            onChanged: (bool value) => setState(() => certRequired = value),
          ),
        ),
        RaisedGradientButton(
          labelText: 'Create',
          padding: EdgeInsets.all(32),
          onPressed: () {
            if (!formKey.currentState.validate()) return;
            formKey.currentState.save();
            formKey.currentState.reset();
            Scaffold.of(context)
                .showSnackBar(SnackBar(content: Text('Creating...')));

            String options = PeerPreference.formatOptions(ignoreBadCert: !certRequired);
            peers.add(PeerPreference(name, url, currency.ticker, options));
            appState.preferences.peers = peers;
            if (peers.length == 1) appState.connectPeers(currency);

            appState.setState(() {});
            Navigator.of(context).pop();
          },
        ),
      ]),
    );
  }
}
