import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/wallet_file.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/select_file_widget.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

const String _kRefusal = 'Not a Syrius wallet file';

/// Holds the path the way the import screen does: set when a file is
/// accepted, dropped when one is refused, and Continue follows it.
class _Host extends StatefulWidget {
  const _Host({required this.onRefused});

  final VoidCallback onRefused;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String? path;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SelectFileWidget(
          validator: WalletFile.isKeyStoreFile,
          invalidFileMessage: _kRefusal,
          onPathFoundCallback: (String p) => setState(() => path = p),
          onFileRefusedCallback: () {
            widget.onRefused();
            setState(() => path = null);
          },
        ),
        OutlinedButton(
          onPressed: path == null ? null : () {},
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

/// Drops [path] on the zone the way the desktop_drop plugin reports it: the
/// pointer enters over the target, then the drop is performed.
Future<void> _drop(WidgetTester tester, String path) async {
  final Offset at = tester.getCenter(find.byType(SelectFileWidget));
  for (final MethodCall call in <MethodCall>[
    MethodCall('entered', <double>[at.dx, at.dy]),
    MethodCall('performOperation', <String>[path]),
  ]) {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'desktop_drop',
      const StandardMethodCodec().encodeMethodCall(call),
      (ByteData? _) {},
    );
  }
  await tester.pump();
}

void main() {
  late Directory dir;
  late String good;
  late String bad;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('select_file_refusal');
    final EncryptedFile encrypted = await EncryptedFile.encrypt(
      List<int>.filled(32, 7),
      'password',
      metadata: <String, dynamic>{walletTypeKey: keyStoreWalletType},
    );
    good = (File('${dir.path}${Platform.pathSeparator}good.json')
          ..writeAsStringSync(json.encode(encrypted)))
        .path;
    bad = (File('${dir.path}${Platform.pathSeparator}bad.json')
          ..writeAsStringSync('{"a": 1}'))
        .path;
  });

  tearDownAll(() => dir.deleteSync(recursive: true));

  bool continueEnabled(WidgetTester tester) => tester
      .widget<OutlinedButton>(find.byType(OutlinedButton))
      .enabled;

  testWidgets('a refused file drops the path an accepted one left', (
    WidgetTester tester,
  ) async {
    int refusals = 0;
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: _Host(onRefused: () => refusals++)),
      ),
    );
    final _HostState host = tester.state(find.byType(_Host));
    expect(continueEnabled(tester), isFalse);

    await _drop(tester, good);
    expect(host.path, good);
    expect(find.text(good), findsOneWidget);
    expect(refusals, 0);
    expect(continueEnabled(tester), isTrue);

    // The zone now names the refusal, so nothing may still be importable.
    await _drop(tester, bad);
    expect(find.text(_kRefusal), findsOneWidget);
    expect(find.text(good), findsNothing);
    expect(refusals, 1);
    expect(host.path, isNull);
    expect(continueEnabled(tester), isFalse);

    // A good file after a refusal is taken again.
    await _drop(tester, good);
    expect(host.path, good);
    expect(refusals, 1);
    expect(continueEnabled(tester), isTrue);
  });

  testWidgets('a refusal with no callback set only shows the message', (
    WidgetTester tester,
  ) async {
    final List<String> found = <String>[];
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SelectFileWidget(
            validator: WalletFile.isKeyStoreFile,
            invalidFileMessage: _kRefusal,
            onPathFoundCallback: found.add,
          ),
        ),
      ),
    );
    await _drop(tester, bad);
    expect(find.text(_kRefusal), findsOneWidget);
    expect(found, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
