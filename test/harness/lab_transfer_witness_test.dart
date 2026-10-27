import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/send/bloc/send_transaction/send_transaction_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/send/model/send_intent.dart';
import 'package:zenon_syrius_wallet_flutter/utils/account_block_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/address_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/zts_utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

import '../../harness/app/fixtures/lab_transfer_witness.dart';
import '../../harness/app/fixtures/seed_policy.dart';
import '../helpers/hydrated_bloc.dart';
import '../settings_addresses_redesign/support.dart';

class _Publish extends Mock implements AccountBlockUtils {}
class _Addresses extends Mock implements ZenonAddressUtils {}

class _Sender extends SendTransactionBloc {
  _Sender(_Publish publish, _Addresses addresses) : super(
    accountBlockUtilsHelper: publish,
    zenonAddressUtils: addresses,
    recordRecipient: (String from, String to) async {},
  );

  void offer(SendTransactionState value) => emit(value);
}

class _Fixture {
  _Fixture() {
    when(() => addresses.refreshBalance()).thenAnswer((_) {});
    when(() => publish.createAccountBlock(
      any(), any(), address: any(named: 'address'),
      waitForRequiredPlasma: any(named: 'waitForRequiredPlasma'),
    )).thenAnswer((_) {
      calls++;
      return answer.future;
    });
    sender = _Sender(publish, addresses);
    addTearDown(() async {
      if (!answer.isCompleted) answer.complete(response());
      await sender.close();
    });
  }

  final _Publish publish = _Publish();
  final _Addresses addresses = _Addresses();
  final Completer<AccountBlockTemplate> answer =
      Completer<AccountBlockTemplate>();
  late final _Sender sender;
  bool current = true;
  int calls = 0;
  final SendIntent intent = SendIntent.capture(
    fromAddress: fixtureAddress(2), recipient: fixtureAddress(1),
    amount: '1', token: kZnnCoin,
  );

  AccountBlockTemplate response({int id = 9}) => AccountBlockTemplate.send(
    Address.parse(intent.toAddress), znnZts, intent.amount,
  )..chainIdentifier = 321
   ..address = Address.parse(intent.fromAddress)
   ..hash = Hash.parse(fixtureHash(id));

  LabTransferWitness witness() {
    final LabTransferWitness value = LabTransferWitness.capture(
      sender: sender, intent: intent,
      owner: intent.fromAddress, recipient: intent.toAddress,
      isCurrent: () => current,
    );
    addTearDown(value.close);
    return value;
  }

  Future<void> emitResult(AccountBlockTemplate value) async {
    sender
      ..offer(SendTransactionState(status: SendTransactionStatus.loading,
        requestId: intent.requestId))
      ..offer(SendTransactionState(status: SendTransactionStatus.success,
        requestId: intent.requestId, data: value));
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  initHydratedStorage();
  setUpAll(() {
    registerFallbackValue(AccountBlockTemplate(blockType: 2));
    registerFallbackValue(Address.parse(fixtureAddress(1)));
  });

  test('the real sender retains the identical confirmed request and result',
      () async {
    final _Fixture fixture = _Fixture();
    final LabTransferWitness witness = fixture.witness();
    final AccountBlockTemplate original = fixture.response();
    witness.requireReady();
    final SendRequestHandle? handle = fixture.sender.trySubmitTransfer(
      fixture.intent.toEvent(), canStart: () => fixture.current,
    );
    expect(handle, isNotNull);
    expect(handle!.requestId, same(fixture.intent.requestId));
    await Future<void>.delayed(Duration.zero);
    expect(fixture.calls, 1);
    expect(witness.started, isTrue);
    expect(witness.settled, isFalse);
    fixture.answer.complete(original);
    expect((await handle.result).block, same(original));
    await Future<void>.delayed(Duration.zero);
    expect(witness.identity, same(handle.requestId));
    expect(witness.result, same(original));
    expect(witness.acceptedHash, fixtureHash(9));
    expect(witness.settled, isTrue);
    expect(witness.failed, isFalse);
  });

  test('a matching-looking automatic receive has a different identity',
      () async {
    final _Fixture fixture = _Fixture();
    final LabTransferWitness witness = fixture.witness();
    fixture.sender.offer(SendTransactionState(
      status: SendTransactionStatus.success, requestId: Object(),
      origin: SendTransactionOrigin.collection, data: fixture.response(),
    ));
    await Future<void>.delayed(Duration.zero);
    expect(witness.started, isFalse);
    expect(witness.settled, isFalse);
    expect(witness.acceptedHash, isNull);
    final AccountBlockTemplate original = fixture.response();
    await fixture.emitResult(original);
    expect(witness.result, same(original));
    expect(witness.failed, isFalse);
  });

  test('capture refuses an already observed original request', () async {
    final _Fixture fixture = _Fixture();
    fixture.sender.offer(SendTransactionState(
      status: SendTransactionStatus.success,
      requestId: fixture.intent.requestId, data: fixture.response(),
    ));
    await Future<void>.delayed(Duration.zero);
    expect(fixture.witness, throwsA(isA<SeedRefused>()));
    expect(fixture.calls, 0);
  });

  test('an actual original publication failure cannot become a success',
      () async {
    final _Fixture fixture = _Fixture();
    final LabTransferWitness witness = fixture.witness();
    final SendRequestHandle handle = fixture.sender.trySubmitTransfer(
      fixture.intent.toEvent(),
    )!;
    await Future<void>.delayed(Duration.zero);
    fixture.answer.completeError(StateError('synthetic publication failure'));
    expect((await handle.result).accepted, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(witness.settled, isTrue);
    expect(witness.failed, isTrue);
    expect(witness.error, isNotNull);
    expect(witness.acceptedHash, isNull);
    expect(witness.requireReady, throwsA(isA<SeedRefused>()));
    expect(fixture.calls, 1);
  });

  test('a changed terminal answer cannot overwrite the original hash',
      () async {
    final _Fixture fixture = _Fixture();
    final LabTransferWitness witness = fixture.witness();
    final AccountBlockTemplate original = fixture.response();
    await fixture.emitResult(original);
    fixture.sender.offer(SendTransactionState(
      status: SendTransactionStatus.success,
      requestId: fixture.intent.requestId, data: fixture.response(id: 10),
    ));
    await Future<void>.delayed(Duration.zero);
    expect(witness.result, same(original));
    expect(witness.acceptedHash, fixtureHash(9));
    expect(witness.failed, isTrue);
  });

  test('revocation retains the late original answer without rearming',
      () async {
    final _Fixture fixture = _Fixture();
    final LabTransferWitness witness = fixture.witness();
    fixture.current = false;
    expect(witness.isCurrent, isFalse);
    fixture.current = true;
    final AccountBlockTemplate original = fixture.response();
    await fixture.emitResult(original);
    expect(witness.result, same(original));
    expect(witness.acceptedHash, fixtureHash(9));
    expect(witness.isCurrent, isFalse);
    expect(witness.failed, isTrue);
    expect(witness.requireReady, throwsA(isA<SeedRefused>()));
  });

  test('mutating the SDK answer cannot change its retained accepted hash',
      () async {
    final _Fixture fixture = _Fixture();
    final LabTransferWitness witness = fixture.witness();
    final AccountBlockTemplate original = fixture.response();
    await fixture.emitResult(original);
    original
      ..hash = Hash.parse(fixtureHash(10))
      ..amount = BigInt.one;
    expect(witness.result, same(original));
    expect(witness.acceptedHash, fixtureHash(9));
    expect(witness.failed, isTrue);
  });

  test('a closed original stream with no answer remains unknown', () async {
    final _Fixture fixture = _Fixture();
    final LabTransferWitness witness = fixture.witness();
    await fixture.sender.close();
    await Future<void>.delayed(Duration.zero);
    expect(witness.settled, isTrue);
    expect(witness.failed, isTrue);
    expect(witness.result, isNull);
    expect(witness.acceptedHash, isNull);
    expect(fixture.calls, 0);
  });

  test('exact owner, chain, recipient, asset, amount and data stay mandatory',
      () async {
    for (final String change in <String>[
      'owner', 'chain', 'recipient', 'asset', 'amount', 'data', 'type',
    ]) {
      final _Fixture fixture = _Fixture();
      final LabTransferWitness witness = fixture.witness();
      final AccountBlockTemplate original = fixture.response();
      switch (change) {
        case 'owner': original.address = Address.parse(fixtureAddress(8));
        case 'chain': original.chainIdentifier = 1;
        case 'recipient': original.toAddress = Address.parse(fixtureAddress(8));
        case 'asset': original.tokenStandard = qsrZts;
        case 'amount': original.amount = BigInt.one;
        case 'data': original.data = <int>[1];
        case 'type': original.blockType = BlockTypeEnum.userReceive.index;
      }
      await fixture.emitResult(original);
      expect(witness.result, same(original));
      expect(witness.acceptedHash, fixtureHash(9));
      expect(witness.failed, isTrue, reason: change);
      expect(fixture.calls, 0);
    }
  });

  test('detaching the witness does not cancel the original publication',
      () async {
    final _Fixture fixture = _Fixture();
    final LabTransferWitness witness = fixture.witness();
    final SendRequestHandle handle = fixture.sender.trySubmitTransfer(
      fixture.intent.toEvent(),
    )!;
    await Future<void>.delayed(Duration.zero);
    expect(fixture.calls, 1);
    await witness.close();
    final AccountBlockTemplate original = fixture.response();
    fixture.answer.complete(original);
    expect((await handle.result).block, same(original));
    expect(witness.failed, isTrue);
    expect(witness.result, isNull);
    expect(fixture.calls, 1);
  });
}
