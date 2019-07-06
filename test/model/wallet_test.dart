import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/cruz.dart';
import 'package:cruzall/model/wallet.dart';

void main() {
  group('SLIP 0010 Test vector 1 for ed25519', () {
    Wallet wallet = Wallet.fromSeed(
        null,
        'TestVector1',
        cruz,
        Seed(hex.decode(
            'fffcf9f6f3f0edeae7e4e1dedbd8d5d2cfccc9c6c3c0bdbab7b4b1aeaba8a5a29f9c999693908d8a8784817e7b7875726f6c696663605d5a5754514e4b484542')));
    CruzAddress addr1, addr2;

    test("m/0'", () {
      addr1 = wallet.deriveAddressWithPath("m/0'");
      expect(hex.encode(addr1.privateKey.data.buffer.asUint8List(0, 32)),
          '1559eb2bbec5790b0c65d8693e4d0875b1747f4970ae8b650486ed7470845635');
      expect(hex.encode(addr1.publicKey.data),
          '86fab68dcb57aa196c77c5f264f215a112c22a912c10d123b0d03c3c28ef1037');
      expect(hex.encode(addr1.chainCode.data),
          '0b78a3226f915c082bf118f83618a618ab6dec793752624cbeb622acb562862d');
    });

    test("m/0'/2147483647'/1'/2147483646'/2'", () {
      addr2 =
          wallet.deriveAddressWithPath("m/0'/2147483647'/1'/2147483646'/2'");
      expect(hex.encode(addr2.privateKey.data.buffer.asUint8List(0, 32)),
          '551d333177df541ad876a60ea71f00447931c0a9da16f227c11ea080d7391b8d');
      expect(hex.encode(addr2.publicKey.data),
          '47150c75db263559a70d5778bf36abbab30fb061ad69f69ece61a72b0cfa4fc0');
      expect(hex.encode(addr2.chainCode.data),
          '5d70af781f3a37b829f0d060924d5e960bdc02e85423494afc0b1a41bbe196d4');
    });

    test('transaction', () {
      CruzTransaction tx = CruzTransaction(addr1.publicKey, addr2.publicKey,
          50 * CRUZ.cruzbitsPerCruz, 0, 'for lunch', height: 0);
      tx.sign(addr1.privateKey);
      expect(tx.verify(), true);
      tx.sign(addr2.privateKey);
      expect(tx.verify(), false);
    });
  });
}
