// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';

import 'package:cruzall/main.dart' as cruzall;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('main test', () {
    expect(cruzall.assetPath('foo.png'), 'assets/foo.png');
    expect(cruzall.getClipboardText(), completion(equals('')));
  });
}
