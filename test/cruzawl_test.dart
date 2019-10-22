// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import '../cruzawl/test/btc_test.dart' as btc_test;
import '../cruzawl/test/cruz_test.dart' as cruz_test;
import '../cruzawl/test/cruz_wallet_test.dart' as cruz_wallet_test;
import '../cruzawl/test/eth_test.dart' as eth_test;
import '../cruzawl/test/sembast_test.dart' as sembast_test;

void main() async {
  await btc_test.main();
  await cruz_test.main();
  await cruz_wallet_test.main();
  await eth_test.main();
  await sembast_test.main();
}
