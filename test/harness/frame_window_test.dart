import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
    final HarnessFrameWindow window = HarnessFrameWindow(100000)
      ..observe(<ui.FrameTiming>[_frame(2, 90000), _frame(3, 100000)]);
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
      throwsA(
        isA<HarnessFrameWindowRefused>().having(
          (HarnessFrameWindowRefused error) => error.reason,
          'reason',
          HarnessFrameWindowRefusal.noFrames,
        ),
      ),
    );
    window.observe(<ui.FrameTiming>[_frame(1, 150000)]);
    await refused;
  });

  test('a reversed frame number refuses the original interval', () async {
    final HarnessFrameWindow window = HarnessFrameWindow(100000)
      ..observe(<ui.FrameTiming>[_frame(3, 100000), _frame(2, 110000)]);
    await expectLater(
      window.finish(
        endUs: 150000,
        requestFrame: () => fail('unexpected frame'),
      ),
      throwsA(
        isA<HarnessFrameWindowRefused>().having(
          (HarnessFrameWindowRefused error) => error.reason,
          'reason',
          HarnessFrameWindowRefusal.frameOrder,
        ),
      ),
    );
  });

  test('a frame beyond the proposed end refuses that clock', () async {
    final HarnessFrameWindow window = HarnessFrameWindow(100000)
      ..observe(<ui.FrameTiming>[_frame(1, 150001)]);
    await expectLater(
      window.finish(
        endUs: 150000,
        requestFrame: () => fail('unexpected frame'),
      ),
      throwsA(
        isA<HarnessFrameWindowRefused>().having(
          (HarnessFrameWindowRefused error) => error.reason,
          'reason',
          HarnessFrameWindowRefusal.windowBounds,
        ),
      ),
    );
  });

  test('a packed launch retains each frame through its larger limit', () async {
    const int count = HarnessFrameWindow.maxPackedFrames;
    const int start = 100000;
    const int spacing = 28000;
    const int duration = 120000000;
    const int first = 42;
    final HarnessFrameWindow window = HarnessFrameWindow(start, packed: true)
      ..observe(<ui.FrameTiming>[
        for (int i = 0; i < count; i++)
          _frame(first + i + i ~/ 1000, start + i * spacing),
      ]);
    final Future<Map<String, Object?>> result = window.finish(
      endUs: start + duration,
      requestFrame: () {},
    );
    window.observe(<ui.FrameTiming>[
      _frame(first + count + count ~/ 1000, start + duration),
    ]);
    final Map<String, Object?> receipt = await result;
    expect(
      receipt.keys,
      unorderedEquals(<String>[
        'schema',
        'scope',
        'windowUs',
        'frameCount',
        'packedFrames',
      ]),
    );
    expect(receipt['schema'], 2);
    expect(receipt['scope'], 'harness_frame_window');
    expect(receipt['windowUs'], duration);
    expect(receipt['frameCount'], count);
    final ByteData rows = ByteData.sublistView(
      Uint8List.fromList(
        zlib.decode(base64Decode(receipt['packedFrames']! as String)),
      ),
    );
    expect(rows.lengthInBytes, count * 20);
    for (int i = 0; i < count; i++) {
      expect(
        <int>[
          for (int field = 0; field < 5; field++)
            rows.getUint32(i * 20 + field * 4, Endian.little),
        ],
        <int>[i + i ~/ 1000, i * spacing, 10000, 5000, 17000],
      );
    }
  });

  test('the sample cap refuses rather than dropping retained frames', () async {
    for (final bool packed in <bool>[false, true]) {
      final int limit = packed ? 120000000 : 60000000;
      final HarnessFrameWindow overWindow =
          HarnessFrameWindow(100000, packed: packed)
            ..observe(<ui.FrameTiming>[_frame(1, 100000)]);
      await expectLater(
        overWindow.finish(
          endUs: 100000 + limit + 1,
          requestFrame: () => fail('unexpected frame'),
        ),
        throwsA(
          isA<HarnessFrameWindowRefused>().having(
            (HarnessFrameWindowRefused error) => error.reason,
            'reason',
            HarnessFrameWindowRefusal.windowBounds,
          ),
        ),
      );
    }
    for (final bool packed in <bool>[false, true]) {
      final int count = packed
          ? HarnessFrameWindow.maxPackedFrames
          : HarnessFrameWindow.maxFrames;
      final HarnessFrameWindow window =
          HarnessFrameWindow(100000, packed: packed)..observe(<ui.FrameTiming>[
            for (int i = 0; i <= count; i++) _frame(i + 1, 100000 + i * 12000),
          ]);
      await expectLater(
        window.finish(
          endUs: 60000000,
          requestFrame: () => fail('unexpected frame'),
        ),
        throwsA(
          isA<HarnessFrameWindowRefused>().having(
            (HarnessFrameWindowRefused error) => error.reason,
            'reason',
            HarnessFrameWindowRefusal.frameLimit,
          ),
        ),
      );
    }
  });
}
