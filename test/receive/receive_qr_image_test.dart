import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show MethodCall, MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:zenon_syrius_wallet_flutter/utils/zts_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/receive_qr_image.dart';

import 'receive_test_support.dart';

class _SaveTarget implements File {
  final List<List<int>> writes = <List<int>>[];

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async {
    expect(mode, FileMode.write);
    expect(flush, isTrue);
    writes.add(bytes.toList());
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ReceiveQrImage _qr({
  String data = 'request-one',
  ReceiveQrEncoder? encode,
  bool Function()? isRequestCurrent,
  Future<void> Function(Uint8List)? copyImage,
  Future<void> Function(Uint8List)? save,
}) => ReceiveQrImage(
  key: const Key('test_qr'),
  data: data,
  size: 150,
  tokenStandard: kZnnCoin.tokenStandard,
  encodeImage: encode ?? receiveTestEncode,
  isRequestCurrent: isRequestCurrent,
  onCopyImage: copyImage ?? (Uint8List _) async {},
  onSaveImage: save ?? (Uint8List _) async {},
);

void main() {
  testWidgets('Copy sends the encoded image to the platform clipboard', (
    WidgetTester tester,
  ) async {
    const MethodChannel clipboard = MethodChannel(
      'network.zenon.syrius/image_clipboard',
    );
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final List<List<int>> copied = <List<int>>[];
    final List<List<int>> saved = <List<int>>[];
    final List<int> sizes = <int>[];
    messenger.setMockMethodCallHandler(clipboard, (MethodCall call) async {
      expect(call.method, 'writePng');
      copied.add((call.arguments as Uint8List).toList());
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(clipboard, null));
    await tester.pumpWidget(
      receiveTestHost(
        ReceiveQrImage(
          data: 'request-one',
          size: 150,
          tokenStandard: kZnnCoin.tokenStandard,
          encodeImage:
              (
                QrImage image,
                PrettyQrDecoration decoration,
                int size,
              ) async {
                sizes.add(size);
                return Uint8List.fromList(<int>[4, 5, 6]);
              },
          onSaveImage: (Uint8List bytes) async => saved.add(bytes.toList()),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('receive_share_image')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('receive_save_image')));
    await tester.pump();
    expect(sizes, <int>[150, 150]);
    expect(copied, <List<int>>[
      <int>[4, 5, 6],
    ]);
    expect(saved, <List<int>>[
      <int>[4, 5, 6],
    ]);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Copy image'), findsOneWidget);
    await receiveTestDispose(tester);
  });

  testWidgets('Save writes only a current confirmed destination', (
    WidgetTester tester,
  ) async {
    const MethodChannel selector = MethodChannel(
      'plugins.flutter.io/file_selector',
    );
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final _SaveTarget target = _SaveTarget();
    final List<Completer<String?>> choices = <Completer<String?>>[];
    bool current = true;
    int openedFiles = 0;
    messenger.setMockMethodCallHandler(selector, (MethodCall call) {
      expect(call.method, 'getSavePath');
      final Map<Object?, Object?> arguments =
          call.arguments as Map<Object?, Object?>;
      expect(arguments['suggestedName'], 'syrius-receive.png');
      final Completer<String?> choice = Completer<String?>();
      choices.add(choice);
      return choice.future;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(selector, null));

    await IOOverrides.runZoned(
      () async {
        await tester.pumpWidget(
          receiveTestHost(
            ReceiveQrImage(
              data: 'request-one',
              size: 150,
              tokenStandard: kZnnCoin.tokenStandard,
              encodeImage: receiveTestEncode,
              isRequestCurrent: () => current,
            ),
          ),
        );
        final Finder save = find.byKey(const Key('receive_save_image'));
        await tester.tap(save);
        await tester.pump();
        expect(choices, hasLength(1));
        expect(tester.widget<TextButton>(save).onPressed, isNull);
        choices.single.complete(null);
        await tester.pump();
        expect(openedFiles, 0);
        expect(find.text('The QR image could not be exported'), findsNothing);

        await tester.tap(save);
        await tester.pump();
        expect(choices, hasLength(2));
        current = false;
        choices.last.complete('selected-qr.png');
        await tester.pump();
        expect(openedFiles, 0);

        current = true;
        await tester.tap(save);
        await tester.pump();
        expect(choices, hasLength(3));
        choices.last.complete('selected-qr.png');
        await tester.pump();
        expect(openedFiles, 1);
        expect(target.writes.single, <int>[1, 2, 3]);
        expect(tester.widget<TextButton>(save).onPressed, isNotNull);
        await receiveTestDispose(tester);
      },
      createFile: (String path) {
        expect(path, 'selected-qr.png');
        openedFiles++;
        return target;
      },
    );
  });

  testWidgets('a pending encoder disables exports and refuses a replaced QR', (
    WidgetTester tester,
  ) async {
    final Completer<Uint8List?> encoding = Completer<Uint8List?>();
    final List<Uint8List> exports = <Uint8List>[];
    await tester.pumpWidget(
      receiveTestHost(
        _qr(
          encode:
              (
                QrImage image,
                PrettyQrDecoration decoration,
                int size,
              ) => encoding.future,
          copyImage: (Uint8List bytes) async => exports.add(bytes),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('receive_share_image')));
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('receive_share_image')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('receive_save_image')))
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(receiveTestHost(_qr(data: 'request-two')));
    encoding.complete(Uint8List.fromList(<int>[1]));
    await tester.pump();
    expect(exports, isEmpty);
    expect(
      tester
          .widget<Tooltip>(find.byKey(const Key('receive_qr_payload')))
          .message,
      'request-two',
    );
    await receiveTestDispose(tester);
  });

  testWidgets('disposed request never exports a late encoded image', (
    WidgetTester tester,
  ) async {
    final Completer<Uint8List?> encoding = Completer<Uint8List?>();
    final List<Uint8List> exports = <Uint8List>[];
    await tester.pumpWidget(
      receiveTestHost(
        _qr(
          encode:
              (
                QrImage image,
                PrettyQrDecoration decoration,
                int size,
              ) => encoding.future,
          copyImage: (Uint8List bytes) async => exports.add(bytes),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('receive_share_image')));
    await tester.pumpWidget(const SizedBox.shrink());
    encoding.complete(Uint8List.fromList(<int>[1]));
    await tester.pump();
    expect(exports, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('synchronous ownership guards admission and native dispatch', (
    WidgetTester tester,
  ) async {
    final Completer<Uint8List?> encoding = Completer<Uint8List?>();
    final List<Uint8List> exports = <Uint8List>[];
    bool current = false;
    int encodings = 0;
    await tester.pumpWidget(
      receiveTestHost(
        _qr(
          isRequestCurrent: () => current,
          encode:
              (
                QrImage image,
                PrettyQrDecoration decoration,
                int size,
              ) {
                encodings += 1;
                return encoding.future;
              },
          copyImage: (Uint8List bytes) async => exports.add(bytes),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('receive_share_image')));
    await tester.pump();
    expect(encodings, 0);
    current = true;
    await tester.tap(find.byKey(const Key('receive_share_image')));
    await tester.pump();
    expect(encodings, 1);
    current = false;
    encoding.complete(Uint8List.fromList(<int>[1]));
    await tester.pump();
    expect(exports, isEmpty);
    await receiveTestDispose(tester);
  });

  testWidgets('missing encoded bytes fail visibly and can be retried', (
    WidgetTester tester,
  ) async {
    int encodings = 0;
    int exports = 0;
    await tester.pumpWidget(
      receiveTestHost(
        _qr(
          encode:
              (
                QrImage image,
                PrettyQrDecoration decoration,
                int size,
              ) async => ++encodings == 1 ? null : Uint8List.fromList(<int>[8]),
          save: (Uint8List bytes) async {
            exports += 1;
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('receive_save_image')));
    await tester.pump();
    expect(exports, 0);
    expect(find.text('The QR image could not be exported'), findsOneWidget);
    await tester.tap(find.byKey(const Key('receive_save_image')));
    await tester.pump();
    expect(exports, 1);
    expect(find.text('The QR image could not be exported'), findsNothing);
    await receiveTestDispose(tester);
  });

  testWidgets('native export failures expose only the localized remedy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      receiveTestHost(
        _qr(
          copyImage: (Uint8List bytes) async {
            throw StateError('test export internals');
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('receive_share_image')));
    await tester.pump();
    expect(find.text('The QR image could not be exported'), findsOneWidget);
    expect(find.textContaining('test export internals'), findsNothing);
    await receiveTestDispose(tester);
  });

  testWidgets('late native completion leaves disposed state alone', (
    WidgetTester tester,
  ) async {
    final Completer<void> exported = Completer<void>();
    await tester.pumpWidget(
      receiveTestHost(_qr(save: (Uint8List bytes) => exported.future)),
    );
    await tester.tap(find.byKey(const Key('receive_save_image')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    exported.completeError(StateError('test late export failure'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
