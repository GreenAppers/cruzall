// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import '../cruzawl/test/cruz_test.dart' as cruz_test;
import '../cruzawl/test/sembast_test.dart' as sembast_test;
import '../cruzawl/test/wallet_test.dart' as wallet_test;

void main() async {
  await cruz_test.main();
  await sembast_test.main();
  await wallet_test.main();
}
