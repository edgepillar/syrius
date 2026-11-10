import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import '../../harness/app/frame_window.dart';

ui.FrameTiming _frame(int number, int start) => ui.FrameTiming(
  vsyncStart: start - 1000,
  buildStart: start,
  buildFinish: start + 10000,
  rasterStart: start + 11000,
  rasterFinish: start + 16000,
  rasterFinishWallTime: start + 16000,
  frameNumber: number,
);

void main() {
  test('late timings use build time and need a later frame', () async {
    final HarnessFrameWindow window = HarnessFrameWindow(100000);
    window.observe(<ui.FrameTiming>[_frame(2, 90000), _frame(3, 100000)]);
    bool requested = false;
    bool delivered = false;
    final Future<Map<String, Object?>> result = window.finish(
      endUs: 150000,
      requestFrame: () => requested = true,
    );
    unawaited(result.then<void>((_) {
      delivered = true;
    }));
    expect(requested, isTrue);
    window.observe(<ui.FrameTiming>[_frame(4, 149999)]);
    await Future<void>.value();
    expect(delivered, isFalse);

    window.observe(<ui.FrameTiming>[_frame(5, 150000), _frame(6, 160000)]);
    final Map<String, Object?> receipt = await result;
    expect(receipt['windowUs'], 50000);
    expect(receipt['frames'], <List<int>>[
      <int>[0, 0, 10000, 5000, 17000],
      <int>[1, 49999, 10000, 5000, 17000],
    ]);
  });

  test('a later frame alone does not prove a measured interval', () async {
    final HarnessFrameWindow window = HarnessFrameWindow(100000);
    final Future<void> refused = expectLater(
      window.finish(endUs: 150000, requestFrame: () {}),
      throwsStateError,
    );
    window.observe(<ui.FrameTiming>[_frame(1, 150000)]);
    await refused;
  });

  test('a reversed frame number refuses the original interval', () async {
    final HarnessFrameWindow window = HarnessFrameWindow(100000);
    window.observe(<ui.FrameTiming>[_frame(3, 100000), _frame(2, 110000)]);
    await expectLater(
      window.finish(
        endUs: 150000,
        requestFrame: () => fail('unexpected frame'),
      ),
      throwsStateError,
    );
  });

  test('a frame beyond the proposed end refuses that clock', () async {
    final HarnessFrameWindow window = HarnessFrameWindow(100000);
    window.observe(<ui.FrameTiming>[_frame(1, 150001)]);
    await expectLater(
      window.finish(
        endUs: 150000,
        requestFrame: () => fail('unexpected frame'),
      ),
      throwsStateError,
    );
  });

  test('the sample cap refuses rather than dropping retained frames', () async {
    final HarnessFrameWindow window = HarnessFrameWindow(100000);
    window.observe(<ui.FrameTiming>[
      for (int i = 0; i <= HarnessFrameWindow.maxFrames; i++)
        _frame(i + 1, 100000 + i * 30000),
    ]);
    await expectLater(
      window.finish(
        endUs: 20000000,
        requestFrame: () => fail('unexpected frame'),
      ),
      throwsStateError,
    );
  });
}
