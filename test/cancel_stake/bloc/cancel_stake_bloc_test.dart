import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/exceptions/exceptions.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

import '../../helpers/hydrated_bloc.dart';

/// Supplies only the injected client's contract APIs.
class MockZenon extends Mock implements Zenon {}

/// Keeps contract construction separate from publication.
class MockEmbedded extends Mock implements EmbeddedApi {}

/// Records the original stake hash without a node.
class MockStakeApi extends Mock implements StakeApi {}

/// Replaces wallet acquisition, signing and network transport.
class MockAccountBlockUtils extends Mock implements AccountBlockUtils {}

/// Counts only the current owner's balance refresh.
class MockZenonAddressUtils extends Mock implements ZenonAddressUtils {}

/// Carries an in-memory original response identity.
class MockAccountBlockTemplate extends Mock implements AccountBlockTemplate {}

void main() {
  initHydratedStorage();

  setUpAll(() {
    registerFallbackValue(AccountBlockTemplate(blockType: 1));
    registerFallbackValue(emptyHash);
    registerFallbackValue(emptyAddress);
  });

  group('CancelStakeBloc', () {
    late MockZenon zenon;
    late MockEmbedded embedded;
    late MockStakeApi stakeApi;
    late MockAccountBlockUtils accountBlockUtils;
    late MockZenonAddressUtils zenonAddressUtils;
    late CancelStakeBloc bloc;
    late AccountBlockTemplate template;

    setUp(() {
      zenon = MockZenon();
      embedded = MockEmbedded();
      stakeApi = MockStakeApi();
      accountBlockUtils = MockAccountBlockUtils();
      zenonAddressUtils = MockZenonAddressUtils();
      template = MockAccountBlockTemplate();

      when(() => zenon.embedded).thenReturn(embedded);
      when(() => embedded.stake).thenReturn(stakeApi);
      when(() => stakeApi.cancel(any())).thenReturn(template);
      when(
        () => accountBlockUtils.createAccountBlock(
          any(),
          any(),
          waitForRequiredPlasma: any(named: 'waitForRequiredPlasma'),
        ),
      ).thenAnswer((_) async => template);
      when(() => zenonAddressUtils.refreshBalance()).thenAnswer((_) {});

      bloc = CancelStakeBloc(
        accountBlockUtils: accountBlockUtils,
        zenon: zenon,
        zenonAddressUtils: zenonAddressUtils,
      );
    });

    test('initial state is correct', () {
      expect(bloc.state, const CancelStakeInitial());
    });

    blocTest<CancelStakeBloc, CancelStakeState>(
      'emits [loading, done] on success',
      build: () => bloc,
      act: (CancelStakeBloc bloc) => bloc.add(
        CancelStakeRequested(stakeHash: emptyHash),
      ),
      verify: (_) {
        verify(() => zenonAddressUtils.refreshBalance()).called(1);
      },
      expect: () => <CancelStakeState>[
        const CancelStakeLoading(),
        const CancelStakeDone(),
      ],
    );

    blocTest<CancelStakeBloc, CancelStakeState>(
      'emits [loading, failure] on SyriusException',
      setUp: () {
        when(() => stakeApi.cancel(any())).thenThrow(FailureException());
      },
      build: () => bloc,
      act: (CancelStakeBloc bloc) => bloc.add(
        CancelStakeRequested(stakeHash: emptyHash),
      ),
      expect: () => <Matcher>[
        isA<CancelStakeLoading>(),
        isA<CancelStakeFailure>().having(
          (CancelStakeFailure s) => s.exception,
          'exception',
          isA<FailureException>(),
        ),
      ],
    );

    test('owned requests keep one exact block, account and guard', () async {
      addTearDown(bloc.close);
      final Completer<AccountBlockTemplate> reply =
          Completer<AccountBlockTemplate>();
      bool current() => true;
      final bool Function() guard = current;
      when(() => accountBlockUtils.createAccountBlock(
        any(), any(), address: any(named: 'address'),
        waitForRequiredPlasma: any(named: 'waitForRequiredPlasma'),
        canPublish: any(named: 'canPublish'),
      )).thenAnswer((Invocation call) {
        expect(call.positionalArguments.first, same(template));
        expect(call.namedArguments[#address], emptyAddress);
        expect(call.namedArguments[#waitForRequiredPlasma], isTrue);
        expect(call.namedArguments[#canPublish], same(guard));
        return reply.future;
      });
      final CancelStakeRequested request = CancelStakeRequested.owned(
        stakeHash: emptyHash, fromAddress: emptyAddress,
        block: template, canPublish: guard,
      );
      final Future<CancelStakeState> loading = bloc.stream.firstWhere(
        (CancelStakeState state) => state is CancelStakeLoading,
      );
      final Future<CancelStakeState> done = bloc.stream.firstWhere(
        (CancelStakeState state) => state is CancelStakeDone,
      );
      bloc..add(request)..add(request);
      await loading;
      await Future<void>.delayed(Duration.zero);
      verify(() => accountBlockUtils.createAccountBlock(
        any(), any(), address: any(named: 'address'),
        waitForRequiredPlasma: any(named: 'waitForRequiredPlasma'),
        canPublish: any(named: 'canPublish'),
      )).called(1);
      verifyNever(() => stakeApi.cancel(any()));
      reply.complete(template);
      await done;
      verify(() => zenonAddressUtils.refreshBalance()).called(1);
    });

    test('a revoked owned request never enters preparation', () async {
      addTearDown(bloc.close);
      final Future<CancelStakeState> idle = bloc.stream.firstWhere(
        (CancelStakeState state) => state is CancelStakeInitial,
      );
      bloc.add(CancelStakeRequested.owned(
        stakeHash: emptyHash, fromAddress: emptyAddress,
        block: template, canPublish: () => false,
      ));
      await idle;
      verifyNever(() => stakeApi.cancel(any()));
      verifyNever(() => accountBlockUtils.createAccountBlock(
        any(), any(), address: any(named: 'address'),
        waitForRequiredPlasma: any(named: 'waitForRequiredPlasma'),
        canPublish: any(named: 'canPublish'),
      ));
      verifyNever(() => zenonAddressUtils.refreshBalance());
    });

    for (final bool rejected in <bool>[false, true]) {
      test('late owned outcome cannot refresh a new context, $rejected',
          () async {
        addTearDown(bloc.close);
        final Completer<AccountBlockTemplate> reply =
            Completer<AccountBlockTemplate>();
        bool current = true;
        when(() => accountBlockUtils.createAccountBlock(
          any(), any(), address: any(named: 'address'),
          waitForRequiredPlasma: any(named: 'waitForRequiredPlasma'),
          canPublish: any(named: 'canPublish'),
        )).thenAnswer((_) => reply.future);
        final Future<CancelStakeState> loading = bloc.stream.firstWhere(
          (CancelStakeState state) => state is CancelStakeLoading,
        );
        final Future<CancelStakeState> idle = bloc.stream.firstWhere(
          (CancelStakeState state) => state is CancelStakeInitial,
        );
        bloc.add(CancelStakeRequested.owned(
          stakeHash: emptyHash, fromAddress: emptyAddress,
          block: template, canPublish: () => current,
        ));
        await loading;
        current = false;
        if (rejected) {
          reply.completeError(FailureException());
        } else {
          reply.complete(template);
        }
        await idle;
        verifyNever(() => stakeApi.cancel(any()));
        verifyNever(() => zenonAddressUtils.refreshBalance());
        expect(bloc.state, const CancelStakeInitial());
      });
    }
  });
}
