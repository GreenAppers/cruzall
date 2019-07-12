import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl/util.dart';
import 'package:cruzall/model/sembast.dart';

void main() {
  test('Salsa20Codec', () {
    Salsa20Codec codec = Salsa20Codec(randBytes(32));
    PeerPreference peer = PeerPreference('foo', 'bar', 'baz', 'bat');
    Map<String, dynamic> peerJson = peer.toJson();
    String peerText = jsonEncode(peerJson);
    String cipherText = codec.encoder.convert(peerJson);
    Map<String, dynamic> plainJson = codec.decoder.convert(cipherText);
    String plainText = jsonEncode(plainJson);
    expect(plainText, peerText);
  });
}
