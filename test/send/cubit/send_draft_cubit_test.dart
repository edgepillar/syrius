import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/send/cubit/send_draft_cubit.dart';

void main() {
  group('SendDraftCubit', () {
    test('starts empty', () {
      final SendDraftCubit cubit = SendDraftCubit();
      expect(cubit.state, const SendDraft());
      expect(cubit.state.isEmpty, isTrue);
      cubit.close();
    });

    blocTest<SendDraftCubit, SendDraft>(
      'save keeps the four values of the form',
      build: SendDraftCubit.new,
      act: (SendDraftCubit cubit) => cubit.save(
        fromAddress: 'z1from',
        tokenStandard: 'zts1znn',
        recipient: 'z1to',
        amount: '1.5',
      ),
      expect: () => <SendDraft>[
        const SendDraft(
          fromAddress: 'z1from',
          tokenStandard: 'zts1znn',
          recipient: 'z1to',
          amount: '1.5',
        ),
      ],
      verify: (SendDraftCubit cubit) => expect(cubit.state.isEmpty, isFalse),
    );

    blocTest<SendDraftCubit, SendDraft>(
      'saving the same values again emits nothing',
      build: SendDraftCubit.new,
      seed: () => const SendDraft(
        fromAddress: 'z1from',
        tokenStandard: 'zts1znn',
        recipient: 'z1to',
        amount: '1.5',
      ),
      act: (SendDraftCubit cubit) => cubit.save(
        fromAddress: 'z1from',
        tokenStandard: 'zts1znn',
        recipient: 'z1to',
        amount: '1.5',
      ),
      expect: () => <SendDraft>[],
    );

    blocTest<SendDraftCubit, SendDraft>(
      'clear forgets a draft, as a send and a lock both must',
      build: SendDraftCubit.new,
      seed: () => const SendDraft(
        fromAddress: 'z1from',
        tokenStandard: 'zts1znn',
        recipient: 'z1to',
        amount: '1.5',
      ),
      act: (SendDraftCubit cubit) => cubit.clear(),
      expect: () => <SendDraft>[const SendDraft()],
    );
  });
}
