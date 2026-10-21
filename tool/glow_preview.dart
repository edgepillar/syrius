// A window that shows only the plasma glow, and photographs itself.
//
//   flutter build windows --no-pub -t tool/glow_preview.dart
//   GLOW_OUT=<dir> build/windows/x64/runner/Release/syrius.exe
//
// It imports nothing of the wallet but the widget and the binding (which
// imports only the SDK), so it builds while the rest of the tree does not,
// and it opens no wallet file. It writes
// glow_<ms>.png into GLOW_OUT at a few moments and exits. Stop any running
// Syrius first: the Windows runner allows one instance.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/plasma_glow.dart';
import 'package:zenon_syrius_wallet_flutter/utils/motion_binding.dart';

final GlobalKey _shot = GlobalKey();

Future<void> main() async {
  // The wallet's binding, so the glow is photographed at the speed the wallet
  // plays it whatever this machine says about reduced motion.
  MotionBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  runApp(const _Preview());
  await windowManager.show();
  final String out = Platform.environment['GLOW_OUT'] ?? '.';
  for (final int ms in <int>[600, 1500, 3000, 4500, 6000]) {
    await Future<void>.delayed(
      Duration(milliseconds: ms) - _elapsed.elapsed,
    );
    await _capture('$out/glow_$ms.png');
  }
  exit(0);
}

final Stopwatch _elapsed = Stopwatch()..start();

Future<void> _capture(String path) async {
  final RenderRepaintBoundary boundary =
      _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final ui.Image image = await boundary.toImage();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(data!.buffer.asUint8List());
}

class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: _shot,
        child: const ColoredBox(
          color: Color(0xFF1C1C1C),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.bolt, size: 200, color: Colors.white),
                SizedBox(width: 24),
                PlasmaGlow(size: 320),
                SizedBox(width: 24),
                PlasmaGlow(size: 320, active: false),
                SizedBox(width: 24),
                PlasmaGlow(size: 36),
                SizedBox(width: 12),
                PlasmaGlow(size: 36, active: false),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
