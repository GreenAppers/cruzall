// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import 'package:bip39/bip39.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:sembast/sembast.dart' hide Transaction;
import 'package:sembast/sembast_io.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl/util.dart';
import 'package:cruzall/model/sembast.dart';

part 'wallet.g.dart';

@JsonSerializable(includeIfNull: false)
class Account {
  int id, nextIndex = 0;

  @JsonKey(ignore: true)
  double balance = 0;

  @JsonKey(ignore: true)
  double maturesBalance = 0;

  @JsonKey(ignore: true)
  int maturesHeight = 0;

  @JsonKey(ignore: true)
  SplayTreeMap<int, Address> reserveAddress = SplayTreeMap<int, Address>();

  Account(this.id);

  factory Account.fromJson(Map<String, dynamic> json) =>
      _$AccountFromJson(json);

  Map<String, dynamic> toJson() => _$AccountToJson(this);

  void clearMatures() {
    maturesBalance = 0;
    maturesHeight = 0;
  }
}

class Seed {
  final Uint8List data;
  static const int size = 64;

  Seed(this.data) {
    assert(data.length == size);
  }

  Seed.fromJson(String x) : this(base64.decode(x));

  String toJson() => base64.encode(data);
}

typedef WalletCallback = void Function(Wallet);

class Wallet extends Model {
  String name, seedPhrase;
  Seed seed;
  Currency currency;
  Database storage;
  num balance = 0, maturesBalance = 0;
  int activeAccountId = 0, pendingCount = 0, maturesHeight = 0;
  Map<int, Account> accounts = <int, Account>{0: Account(0)};
  Map<String, Address> addresses = <String, Address>{};
  PriorityQueue<Transaction> maturing =
      PriorityQueue<Transaction>(Transaction.maturityCompare);
  SortedListSet<Transaction> transactions =
      SortedListSet<Transaction>(Transaction.timeCompare, List<Transaction>());
  Map<String, Transaction> transactionIds = Map<String, Transaction>();
  var walletStore, accountStore, addressStore, pendingStore;
  VoidCallback balanceChanged;
  FlutterErrorDetails fatal;

  Wallet.generate(String filename, String name, Currency currency,
      [WalletCallback loaded])
      : this.fromSeedPhrase(
            filename, name, currency, generateMnemonic(), loaded);

  Wallet.fromSeedPhrase(
      String filename, String name, Currency currency, String seedPhrase,
      [WalletCallback loaded])
      : this.fromSeed(filename, name, currency,
            Seed(mnemonicToSeed(seedPhrase)), seedPhrase, loaded);

  Wallet.fromSeed(String filename, this.name, this.currency, this.seed,
      [this.seedPhrase, WalletCallback loaded]) {
    if (filename != null) openWalletStorage(filename, true, loaded);
  }

  Wallet.fromFile(String filename, this.seed, [WalletCallback loaded])
      : name = 'loading',
        currency = const LoadingCurrency() {
    openWalletStorage(filename, false, loaded);
  }

  Account get account => accounts[activeAccountId];

  Address getNextAddress() {
    if (account.reserveAddress.length > 0)
      return account.reserveAddress.entries.first.value;
    else
      return addNextAddress();
  }

  String bip44Path(int index, int coinType,
      {int bip43Purpose = 44, int accountId = 0, int change = 0}) {
    return "m/$bip43Purpose'/$coinType'/$accountId'/$change'/$index'";
  }

  Address deriveAddressWithPath(String path) =>
      currency.deriveAddress(seed.data, path);

  Address deriveAddress(int index, {int accountId = 0, int change = 0}) =>
      deriveAddressWithPath(bip44Path(index, currency.bip44CoinType,
          accountId: accountId, change: change))
        ..accountId = accountId
        ..chainIndex = index;

  Address addNextAddress({bool load = true, Account account}) {
    if (account == null) account = this.account;
    return addAddress(deriveAddress(account.nextIndex, accountId: account.id),
        load: load);
  }

  Address addAddress(Address x, {bool store = true, bool load = true}) {
    addresses[x.publicKey.toJson()] = x;
    if (store) storeAddress(x);
    if (load) filterNetworkFor(x);
    if (x.state == AddressState.reserve)
      account.reserveAddress[x.chainIndex] = x;
    if (x.chainIndex != null && x.chainIndex >= account.nextIndex) {
      account.nextIndex = x.chainIndex + 1;
      storeAccount(account);
    }
    return x;
  }

  Account addAccount(Account x, {bool store = true}) {
    accounts[x.id] = x;
    activeAccountId = x.id;
    if (store) storeAccount(x);
    return x;
  }

  void openWalletStorage(String filename, bool create,
      [WalletCallback opened]) async {
    try {
      debugPrint((create ? 'Creating' : 'Opening') + ' wallet $filename ...');
      if (create) assert(await File(filename).exists() == false);
      storage = await databaseFactoryIo.openDatabase(
        filename,
        codec: getSalsa20SembastCodec(Uint8List.view(seed.data.buffer, 32)),
      );
      walletStore = StoreRef<String, dynamic>.main();
      accountStore = intMapStoreFactory.store('accounts');
      addressStore = stringMapStoreFactory.store('addresses');
      pendingStore = stringMapStoreFactory.store('pendingTransactions');

      if (create) {
        await storeHeader();
        await storeAccount(account);
      } else {
        await readStoredHeader();
        await readStoredAccounts();
        await readStoredAddresses(load: false);
      }

    } catch (error, stackTrace) {
      fatal = FlutterErrorDetails(exception: error, stack: stackTrace);
      if (opened != null) return opened(this);
      else rethrow;
    }

    for (Account account in accounts.values)
      while (account.reserveAddress.length < 20) {
        addNextAddress(account: account, load: false);
        await Future.delayed(Duration(seconds: 0));
      }

    if (opened != null) opened(this);
    notifyListeners();
    reload();
  }

  Future<void> storeHeader() async {
    await walletStore.record('header').put(
        storage,
        jsonDecode(jsonEncode(<String, dynamic>{
          'name': name,
          'seed': seed,
          'seedPhrase': seedPhrase,
          'currency': currency,
        })));
  }

  Future<void> readStoredHeader() async {
    var header = await walletStore.record('header').get(storage);
    name = header['name'] as String;
    seed = Seed.fromJson(header['seed']);
    seedPhrase = header['seedPhrase'] as String;
    currency = Currency.fromJson(header['currency']);
  }

  Future<void> storeAccount(Account x) async {
    await accountStore.record(x.id).put(storage, x.toJson());
  }

  Future<void> readStoredAccounts() async {
    var finder = Finder(sortOrders: [SortOrder('id')]);
    var records = await accountStore.find(storage, finder: finder);
    for (var record in records)
      addAccount(Account.fromJson(record.value), store: false);
  }

  Future<void> storeAddress(Address x) async {
    await addressStore
        .record(x.publicKey.toJson())
        .put(storage, jsonDecode(jsonEncode(x)));
  }

  Future<void> readStoredAddresses({bool load = true}) async {
    var finder = Finder(sortOrders: [SortOrder('id')]);
    var records = await addressStore.find(storage, finder: finder);
    for (var record in records) {
      Address x = addAddress(currency.fromAddressJson(record.value),
          store: false, load: load);
      accounts[x.accountId].balance += x.balance;
      balance += x.balance;
    }
  }

  Future<void> removePendingTransaction(String id) async =>
      pendingStore.record(id).delete(storage);

  Future<void> storePendingTransaction(Transaction tx) async {
    String id = tx.id().toJson();
    await pendingStore.record(id).put(storage, jsonDecode(jsonEncode(tx)));
  }

  Future<void> readPendingTransactions() async {
    var finder = Finder(sortOrders: [SortOrder('id')]);
    var records = await pendingStore.find(storage, finder: finder);
    for (var record in records) {
      updateTransaction(currency.fromTransactionJson(record.value),
          newTransaction: false);
      pendingCount++;
    }
  }

  void expirePendingTransactions(int height) async {
    var finder = Finder(
      filter: Filter.lessThan('expires', height),
      sortOrders: [SortOrder('expires')],
    );
    var records = await pendingStore.find(storage, finder: finder);
    for (var record in records) {
      Transaction transaction =
          transactions.find(currency.fromTransactionJson(record.value));
      if (transaction != null &&
          (transaction.height == null || transaction.height == 0))
        updateBalance(addresses[transaction.from.toJson()],
            transaction.amount + transaction.fee);
      removePendingTransaction(record.key);
      pendingCount--;
    }
  }

  void completeMaturingTransactions(int height) {
    while (maturing.length > 0 && maturing.first.maturity <= height) {
      Transaction transaction = maturing.removeFirst();
      Address to = addresses[transaction.to.toJson()];
      applyMaturesBalanceDelta(to, -transaction.amount);
      updateBalance(to, transaction.amount);
    }
  }

  void clearMatures() {
    maturesBalance = maturesHeight = 0;
    for (Account account in accounts.values) account.clearMatures();
  }

  void reload() async {
    // XXX let's see. clearMatures();
    pendingCount = 0;
    transactions.clear();
    readPendingTransactions();

    List<Address> reloadAddresses = addresses.values.toList();
    for (Address address in reloadAddresses) filterNetworkFor(address);

    if (currency.network.hasPeer)
      (await currency.network.getPeer()).filterTransactionQueue();
  }

  void filterNetworkFor(Address x) async {
    if (!currency.network.hasPeer) return;
    Peer peer = await currency.network.getPeer();
    if (peer == null) return;

    x.newBalance = x.newMaturesBalance = 0;
    bool filtering = await peer.filterAdd(x.publicKey, updateTransaction);
    if (filtering == null) return;
    assert(filtering == true);

    num newBalance = await peer.getBalance(x.publicKey);
    if (newBalance == null) return;

    x.loadedHeight = x.loadedIndex = null;
    x.newBalance += newBalance;
    do {
      // Load most recent 100 blocks worth of transactions
      if (await getNextTransactions(peer, x) == null) return;
    } while (x.loadedHeight > max(0, peer.tip.height - 100));

    /// [Address] [newBalance] and [newMatureBalance] account for possibly
    /// receiving new transactions for [x] as we're loading
    applyMaturesBalanceDelta(x, -x.maturesBalance + x.newMaturesBalance);
    updateBalance(x, -x.balance + x.newBalance);
    x.newBalance = x.newMaturesBalance = null;
    notifyListeners();
  }

  Future<TransactionIteratorResults> getNextTransactions(
      Peer peer, Address x) async {
    TransactionIteratorResults results = await peer.getTransactions(
      x.publicKey,
      startHeight: x.loadedHeight,
      startIndex: x.loadedIndex,
      endHeight: x.loadedHeight != null ? 0 : null,
    );
    if (results == null) return null;
    for (Transaction transaction in results.transactions)
      updateTransaction(transaction, newTransaction: false);

    if (results.height == x.loadedHeight && results.index == x.loadedIndex) {
      x.loadedHeight = x.loadedIndex = 0;
    } else {
      x.loadedHeight = results.height;
      x.loadedIndex = results.index;
    }
    return results;
  }

  Future<Transaction> newTransaction(Transaction transaction) async {
    pendingCount++;
    await storePendingTransaction(transaction);
    return transaction;
  }

  void updateTransaction(Transaction transaction,
      {bool newTransaction = true}) {
    bool undo = transaction.height < 0, transactionsChanged;
    if (undo) {
      transactionsChanged = transactions.remove(transaction);
      transactionIds.remove(transaction.id().toJson());
    } else {
      transactionsChanged = transactions.add(transaction);
      transactionIds[transaction.id().toJson()] = transaction;
    }
    bool balanceChanged = transactionsChanged && (newTransaction || undo);
    bool mature = transaction.maturity <= currency.network.tipHeight;

    Address from =
        transaction.from == null ? null : addresses[transaction.from.toJson()];
    Address to = addresses[transaction.to.toJson()];
    if (from != null) {
      if (transaction.height > 0) from.updateSeenHeight(transaction.height);
      updateAddressState(from, AddressState.used, store: !balanceChanged);
    }
    if (to != null) {
      if (transaction.height > 0) to.updateSeenHeight(transaction.height);
      updateAddressState(to, AddressState.used, store: !balanceChanged);
    }

    if (balanceChanged) {
      if (from != null) {
        num cost = transaction.amount + transaction.fee;
        updateBalance(from, undo ? cost : -cost);
      }
      if (to != null && mature)
        updateBalance(to, undo ? -transaction.amount : transaction.amount);
    }

    if (to != null && !mature && transactionsChanged)
      applyMaturesBalanceDelta(
          to, undo ? -transaction.amount : transaction.amount, transaction);
  }

  void updateBalance(Address x, num delta) {
    if (x == null || delta == 0) return;
    applyBalanceDelta(x, delta);
    storeAddress(x);
    notifyListeners();
    if (balanceChanged != null) balanceChanged();
  }

  void updateAddressState(Address x, AddressState newState,
      {bool store = true}) {
    if (x.state == newState) return;
    bool wasReserve = x.state == AddressState.reserve;
    if (wasReserve) accounts[x.accountId].reserveAddress.remove(x.chainIndex);
    x.state = newState;
    if (store) {
      storeAddress(x);
      notifyListeners();
    }
    if (wasReserve) addNextAddress(account: accounts[x.accountId]);
  }

  void updateTip() {
    assert(currency.network.tipHeight != null);
    expirePendingTransactions(currency.network.tipHeight);
    completeMaturingTransactions(currency.network.tipHeight);
    notifyListeners();
  }

  void applyBalanceDelta(Address x, num delta) {
    x.balance += delta;
    if (x.newBalance != null) x.newBalance += delta;
    accounts[x.accountId].balance += delta;
    balance += delta;
  }

  void applyMaturesBalanceDelta(Address x, num delta,
      [Transaction transaction]) {
    x.maturesBalance += delta;
    if (x.newMaturesBalance != null) x.newMaturesBalance += delta;
    Account account = accounts[x.accountId];
    account.maturesBalance += delta;
    maturesBalance += delta;

    if (transaction == null) return;
    int maturity = transaction.maturity;
    x.maturesHeight = max(x.maturesHeight, maturity);
    account.maturesHeight = max(account.maturesHeight, maturity);
    maturesHeight = max(maturesHeight, maturity);

    if (delta > 0)
      maturing.add(transaction);
    else
      maturing.remove(transaction);
  }
}
