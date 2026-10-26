import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/utils/entry_capture_source.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/startup_stage.dart';

import '../../harness/app/agent.dart';
import '../welcome/support.dart';

class _PendingFilm extends CachingAssetBundle {
  final Completer<ByteData> bytes = Completer<ByteData>();

  @override
  Future<ByteData> load(String key) => bytes.future;
}

class _ReceiptHost extends StatefulWidget {
  const _ReceiptHost(this.session);

  final StartupStageSession session;

  @override
  State<_ReceiptHost> createState() => _ReceiptHostState();
}

class _ReceiptHostState extends State<_ReceiptHost> {
  final Object _source = Object();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.session.show(context);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<dynamic> route = ModalRoute.of(context)!;
    EntryCaptureRegistry.instance.attachStartup(
      owner: this,
      source: _source,
      route: route,
      startupOwner: widget.session,
      detached: widget.session.detached,
      cleanup: widget.session.cleanup,
      current: () => mounted && route.isCurrent,
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();

  @override
  void dispose() {
    widget.session.dispose();
    super.dispose();
  }
}

void main() {
  testWidgets('only the registered startup hint shares its original receiver', (
    WidgetTester tester,
  ) async {
    prepareWelcomeViewport(tester);
    EntryCaptureRegistry.instance.observeHarnessEntry();
    final _PendingFilm bundle = _PendingFilm();
    final ByteData bytes = ByteData.sublistView(
      File('test/launch_film/fixtures/film.webp').readAsBytesSync(),
    );
    int done = 0;
    final StartupStageSession session = StartupStageSession(
      bundle: bundle,
      onDone: () => done++,
      authBuilder: (_, StartupStageSession _) => const SizedBox.shrink(),
    );
    addTearDown(() async {
      if (!bundle.bytes.isCompleted) bundle.bytes.complete(bytes);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump();
    });
    final HarnessAgent agent = HarnessAgent.forTest()..booted = true;
    await tester.pumpWidget(welcomeHost(_ReceiptHost(session)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    Future<bool> available() async {
      final Map<String, Object?> view = await agent.commandForTest(
        <String, dynamic>{'cmd': 'wallet-recipe', 'action': 'observe'},
      );
      final List<Map<String, Object?>> controls =
          view['controls']! as List<Map<String, Object?>>;
      return controls.any(
        (Map<String, Object?> row) => row['key'] == 'launch_skip_hint',
      );
    }
    expect(await available(), isTrue);
    expect(done, 0);
    final BuildContext context = tester.element(find.byType(_ReceiptHost));
    final OverlayEntry foreign = OverlayEntry(
      opaque: true,
      builder: (_) => const Focus(
        child: Center(child: Text(
          'Synthetic foreign hint',
          key: ValueKey<String>('launch_skip_hint'),
        )),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(foreign);
    await tester.pump();
    expect(await available(), isFalse);
    expect(done, 0);
    foreign.remove();
    foreign.dispose();
    await tester.pump();
    expect(await available(), isTrue);
    final Map<String, Object?> key = await agent.commandForTest(
      <String, dynamic>{'cmd': 'key', 'key': 'space', 'settleMs': 0},
    );
    expect(key['handled'], isTrue);
    bundle.bytes.complete(bytes);
    for (int frame = 0; frame < 120 && done == 0; frame++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(done, 1);
    expect(session.film.isDone, isTrue);
    expect(await available(), isFalse);
  });
}
