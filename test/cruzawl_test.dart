// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import '../cruzawl/test/cruz_test.dart' as cruzTest;
import '../cruzawl/test/sembast_test.dart' as sembastTest;
import '../cruzawl/test/wallet_test.dart' as walletTest;

void main() async {
  await cruzTest.main();
  await sembastTest.main();
  await walletTest.main();
}
