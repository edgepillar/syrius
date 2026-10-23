import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/receive/widgets/receive_populated.dart';
import 'package:zenon_syrius_wallet_flutter/utils/zts_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/receive_qr_image.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/page_dismiss.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

import 'receive_test_support.dart';

String get _first => emptyAddress.toString();
String get _second => pillarAddress.toString();

ReceivePopulated _form({
  List<Token>? assets,
  Future<void> Function(String)? copy,
  Future<void> Function(Uint8List)? share,
  Future<void> Function(Uint8List)? save,
  ReceiveQrEncoder? encode,
}) => ReceivePopulated(
  key: const Key('receive_test_form'),
  assets: assets ?? <Token>[kZnnCoin, kQsrCoin],
  addresses: <String>[_first, _second],
  addressLabels: <String, String>{_first: 'Address 1', _second: 'Address 2'},
  initialAddress: _first,
  onCopyAddress: copy ?? (String _) async {},
  onShareImage: share ?? (Uint8List _) async {},
  onSaveImage: save ?? (Uint8List _) async {},
  encodeImage: encode ?? receiveTestEncode,
);

String _payload(WidgetTester tester) => tester
    .widget<Tooltip>(find.byKey(const Key('receive_qr_payload')))
    .message!;

Future<void> _showQr(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('receive_qr_toggle')));
  await receiveTestReveal(tester);
}

Future<void> _toggleRequest(WidgetTester tester) async {
  final Finder toggle = find.byKey(const Key('receive_request_toggle'));
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await receiveTestReveal(tester);
}

void main() {
  for (final bool light in <bool>[false, true]) {
    testWidgets('full address at rest with optional controls closed, $light', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(receiveTestHost(_form(), light: light));
      final SelectableText address = tester.widget<SelectableText>(
        find.byKey(const Key('receive_address')),
      );
      expect(address.data, _first);
      expect(address.textDirection, TextDirection.ltr);
      expect(find.text('Copy address'), findsOneWidget);
      expect(find.text('Show QR'), findsOneWidget);
      expect(find.byType(ReceiveQrImage), findsNothing);
      expect(find.byKey(const Key('receive_amount_field')), findsNothing);
      expect(find.byKey(const Key('receive_share_image')), findsNothing);
      await _showQr(tester);
      expect(find.text('Hide QR'), findsOneWidget);
      expect(
        _payload(tester),
        'znn:$_first?zts=${kZnnCoin.tokenStandard}&amount=0',
      );
      expect(find.text('Share image'), findsOneWidget);
      expect(find.text('Save QR'), findsOneWidget);
      expect(find.text('Copy image'), findsNothing);
      await receiveTestDispose(tester);
    });
  }

  testWidgets('copies the complete selected address without direction marks', (
    WidgetTester tester,
  ) async {
    final List<String> copies = <String>[];
    await tester.pumpWidget(
      receiveTestHost(
        _form(copy: (String value) async => copies.add(value)),
        direction: TextDirection.rtl,
      ),
    );
    await tester.tap(find.byKey(const Key('receive_copy_address')));
    await tester.pump();
    expect(copies, <String>[_first]);
    final DropdownMenu<String> picker = tester.widget<DropdownMenu<String>>(
      find.byKey(const Key('receive_address_picker')),
    );
    picker.onSelected!(_second);
    await tester.pump();
    await tester.tap(find.byKey(const Key('receive_copy_address')));
    await tester.pump();
    expect(copies, <String>[_first, _second]);
    await _showQr(tester);
    expect(
      _payload(tester),
      'znn:$_second?zts=${kZnnCoin.tokenStandard}&amount=0',
    );
    await receiveTestDispose(tester);
  });

  testWidgets('request keeps all base units beyond double precision', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(receiveTestHost(_form()));
    await _toggleRequest(tester);
    await tester.enterText(
      find.byKey(const Key('receive_amount_field')),
      '9007199254740993.00000001',
    );
    await _showQr(tester);
    expect(_payload(tester), endsWith('&amount=900719925474099300000001'));
    await receiveTestDispose(tester);
  });

  testWidgets('QR keeps the full reveal clock and denies closing exports', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(receiveTestHost(_form(), reduced: true));
    await tester.tap(find.byKey(const Key('receive_qr_toggle')));
    await tester.pump();
    final AnimationController motion =
        tester
                .widget<AnimatedBuilder>(
                  find.byKey(const Key('receive_qr_reveal')),
                )
                .animation
            as AnimationController;
    expect(motion.duration, ReceivePopulated.qrRevealDuration);
    expect(motion.animationBehavior, AnimationBehavior.preserve);
    expect(
      tester
          .widget<Transform>(find.byKey(const Key('receive_qr_slide')))
          .transform
          .storage[13],
      -8,
    );
    await tester.pump(const Duration(milliseconds: 239));
    expect(motion.isCompleted, isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    if (!motion.isCompleted) {
      expect(motion.lastElapsedDuration, ReceivePopulated.qrRevealDuration);
    }
    expect(motion.value, closeTo(1, 1e-12));
    // The exact endpoint can round just below one in the ticker's double
    // clock. Settle status at the next quantum without changing its duration.
    await tester.pump(const Duration(microseconds: 1));
    expect(motion.isCompleted, isTrue);
    await tester.tap(find.byKey(const Key('receive_qr_toggle')));
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('receive_share_image')))
          .onPressed,
      isNull,
    );
    await receiveTestReveal(tester);
    expect(find.byType(ReceiveQrImage), findsNothing);
    await receiveTestDispose(tester);
  });

  testWidgets('token changes revalidate without truncating the typed amount', (
    WidgetTester tester,
  ) async {
    final Token whole = Token.fromJson(<String, dynamic>{
      ...kQsrCoin.toJson(),
      'symbol': 'WHOLE',
      'decimals': 0,
    });
    await tester.pumpWidget(
      receiveTestHost(_form(assets: <Token>[kZnnCoin, whole])),
    );
    await _toggleRequest(tester);
    final Finder field = find.byKey(const Key('receive_amount_field'));
    await tester.enterText(field, '1.5');
    await _showQr(tester);
    expect(_payload(tester), endsWith('&amount=150000000'));
    tester
        .widget<DropdownMenu<Token>>(
          find.byKey(const Key('receive_token_picker')),
        )
        .onSelected!(whole);
    await tester.pump();
    expect(tester.widget<TextField>(field).controller!.text, '1.5');
    expect(find.byType(ReceiveQrImage), findsNothing);
    expect(find.byKey(const Key('receive_share_image')), findsNothing);
    tester
        .widget<DropdownMenu<Token>>(
          find.byKey(const Key('receive_token_picker')),
        )
        .onSelected!(kZnnCoin);
    await tester.pump();
    expect(_payload(tester), endsWith('&amount=150000000'));
    await receiveTestDispose(tester);
  });

  testWidgets('invalid amounts expose no image export or zero substitution', (
    WidgetTester tester,
  ) async {
    final List<Uint8List> exports = <Uint8List>[];
    await tester.pumpWidget(
      receiveTestHost(
        _form(
          share: (Uint8List bytes) async => exports.add(bytes),
          save: (Uint8List bytes) async => exports.add(bytes),
        ),
      ),
    );
    await _toggleRequest(tester);
    await _showQr(tester);
    for (final String amount in <String>[
      '0',
      '1.000000001',
      (kBigP255m1 + BigInt.one).toString(),
    ]) {
      await tester.enterText(
        find.byKey(const Key('receive_amount_field')),
        amount,
      );
      await tester.pump();
      expect(find.byType(ReceiveQrImage), findsNothing, reason: amount);
      expect(find.byKey(const Key('receive_share_image')), findsNothing);
      expect(find.byKey(const Key('receive_save_image')), findsNothing);
    }
    expect(exports, isEmpty);
    await receiveTestDispose(tester);
  });

  testWidgets('invalidating a request refuses bytes from its pending encoder', (
    WidgetTester tester,
  ) async {
    final Completer<Uint8List?> encoding = Completer<Uint8List?>();
    final List<Uint8List> exports = <Uint8List>[];
    await tester.pumpWidget(
      receiveTestHost(
        _form(
          encode:
              (
                QrImage image,
                PrettyQrDecoration decoration,
                int size,
              ) => encoding.future,
          share: (Uint8List bytes) async => exports.add(bytes),
        ),
      ),
    );
    await _toggleRequest(tester);
    final Finder amount = find.byKey(const Key('receive_amount_field'));
    await tester.enterText(amount, '1');
    await _showQr(tester);
    await tester.tap(find.byKey(const Key('receive_share_image')));
    await tester.pump();
    await tester.enterText(amount, '1.000000001');
    encoding.complete(Uint8List.fromList(<int>[1]));
    await tester.pump();
    expect(find.byType(ReceiveQrImage), findsNothing);
    expect(exports, isEmpty);
    await receiveTestDispose(tester);
  });

  testWidgets('restoring the same amount does not revive an old export', (
    WidgetTester tester,
  ) async {
    final Completer<Uint8List?> encoding = Completer<Uint8List?>();
    final List<Uint8List> exports = <Uint8List>[];
    await tester.pumpWidget(
      receiveTestHost(
        _form(
          encode:
              (
                QrImage image,
                PrettyQrDecoration decoration,
                int size,
              ) => encoding.future,
          share: (Uint8List bytes) async => exports.add(bytes),
        ),
      ),
    );
    await _toggleRequest(tester);
    final Finder amount = find.byKey(const Key('receive_amount_field'));
    await tester.enterText(amount, '1');
    await _showQr(tester);
    final String originalPayload = _payload(tester);
    final TextEditingController controller = tester
        .widget<TextField>(amount)
        .controller!;
    await tester.tap(find.byKey(const Key('receive_share_image')));
    await tester.pump();
    // Both edits precede the next frame and return to the same wire value.
    controller
      ..text = '1.000000001'
      ..text = '1';
    encoding.complete(Uint8List.fromList(<int>[1]));
    await tester.pump();
    expect(_payload(tester), originalPayload);
    expect(exports, isEmpty);
    await tester.tap(find.byKey(const Key('receive_share_image')));
    await tester.pump();
    expect(exports, <List<int>>[
      <int>[1],
    ]);
    await receiveTestDispose(tester);
  });

  testWidgets('Escape closes request then QR while retaining the draft', (
    WidgetTester tester,
  ) async {
    final PageDismissController dismiss = PageDismissController();
    try {
      await tester.pumpWidget(
        receiveTestHost(
          PageDismissScope(controller: dismiss, child: _form()),
        ),
      );
      await _showQr(tester);
      await _toggleRequest(tester);
      await tester.enterText(
        find.byKey(const Key('receive_amount_field')),
        '12.5',
      );
      expect(dismiss.dismissLatest(), isTrue);
      await receiveTestReveal(tester);
      expect(find.byKey(const Key('receive_amount_field')), findsNothing);
      expect(find.byType(ReceiveQrImage), findsOneWidget);
      expect(dismiss.dismissLatest(), isTrue);
      await receiveTestReveal(tester);
      expect(find.byType(ReceiveQrImage), findsNothing);
      await _toggleRequest(tester);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('receive_amount_field')))
            .controller!
            .text,
        '12.5',
      );
      await receiveTestDispose(tester);
    } finally {
      dismiss.dispose();
    }
  });

  testWidgets('disclosure and QR toggles retain address, token and amount', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(receiveTestHost(_form()));
    await _toggleRequest(tester);
    final Finder field = find.byKey(const Key('receive_amount_field'));
    await tester.enterText(field, '100.5');
    tester
        .widget<DropdownMenu<Token>>(
          find.byKey(const Key('receive_token_picker')),
        )
        .onSelected!(kQsrCoin);
    tester
        .widget<DropdownMenu<String>>(
          find.byKey(const Key('receive_address_picker')),
        )
        .onSelected!(_second);
    await tester.pump();
    await _showQr(tester);
    final String request = _payload(tester);
    expect(
      request,
      'qsr:$_second?zts=${kQsrCoin.tokenStandard}&amount=10050000000',
    );
    await _toggleRequest(tester);
    expect(find.byKey(const Key('receive_amount_field')), findsNothing);
    expect(_payload(tester), request);
    await _showQr(tester);
    await _showQr(tester);
    await _toggleRequest(tester);
    expect(tester.widget<TextField>(field).controller!.text, '100.5');
    expect(_payload(tester), request);
    await receiveTestDispose(tester);
  });

  testWidgets('refreshed precision invalidates a retained request', (
    WidgetTester tester,
  ) async {
    final List<Token> original = <Token>[kQsrCoin, kZnnCoin];
    await tester.pumpWidget(receiveTestHost(_form(assets: original)));
    expect(original, <Token>[kQsrCoin, kZnnCoin]);
    await _toggleRequest(tester);
    await tester.enterText(
      find.byKey(const Key('receive_amount_field')),
      '1.5',
    );
    await _showQr(tester);
    final Token wholeZnn = Token.fromJson(<String, dynamic>{
      ...kZnnCoin.toJson(),
      'decimals': 0,
    });
    await tester.pumpWidget(
      receiveTestHost(_form(assets: <Token>[wholeZnn, kQsrCoin])),
    );
    expect(find.byType(ReceiveQrImage), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('receive_amount_field')))
          .controller!
          .text,
      '1.5',
    );
    await receiveTestDispose(tester);
  });

  testWidgets('narrow RTL and scaled text keep the full address below QR', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      receiveTestHost(
        _form(),
        width: 320,
        scale: 1.5,
        direction: TextDirection.rtl,
      ),
    );
    await _showQr(tester);
    expect(
      tester.getTopLeft(find.byKey(const Key('receive_address'))).dy,
      greaterThan(
        tester.getBottomLeft(find.byKey(const Key('receive_qr_image'))).dy,
      ),
    );
    await _toggleRequest(tester);
    await tester.ensureVisible(find.byKey(const Key('receive_amount_field')));
    await tester.enterText(find.byKey(const Key('receive_amount_field')), '.5');
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('receive_amount_field')))
          .textDirection,
      TextDirection.ltr,
    );
    expect(_payload(tester), endsWith('&amount=50000000'));
    await receiveTestDispose(tester);
  });

  testWidgets('late clipboard completion after disposal stays local', (
    WidgetTester tester,
  ) async {
    final Completer<void> copy = Completer<void>();
    await tester.pumpWidget(
      receiveTestHost(_form(copy: (String _) => copy.future)),
    );
    await tester.tap(find.byKey(const Key('receive_copy_address')));
    await tester.pumpWidget(const SizedBox.shrink());
    copy.completeError(StateError('test clipboard failure'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
