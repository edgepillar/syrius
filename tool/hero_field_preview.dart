// A window that shows only the hero field, in both themes, and photographs
// itself.
//
//   flutter build windows --no-pub -t tool/hero_field_preview.dart
//   FIELD_OUT=<dir> build/windows/x64/runner/Release/syrius.exe
//
// Like tool/glow_preview.dart it opens no wallet file and exits by itself,
// after writing field_<ms>.png into FIELD_OUT at a few moments. Stop any
// running Syrius first: the Windows runner allows one instance.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/hero_field.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/plasma_meter.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/motion_binding.dart';

final GlobalKey _shot = GlobalKey();
final Stopwatch _elapsed = Stopwatch()..start();

Future<void> main() async {
  MotionBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  runApp(const _Preview());
  await windowManager.show();
  final String out = Platform.environment['FIELD_OUT'] ?? '.';
  for (final int ms in <int>[800, 6000, 14000]) {
    await Future<void>.delayed(Duration(milliseconds: ms) - _elapsed.elapsed);
    final RenderRepaintBoundary boundary =
        _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/field_$ms.png').writeAsBytesSync(data!.buffer.asUint8List());
  }
  exit(0);
}

class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: RepaintBoundary(
        key: _shot,
        child: Column(
          children: <Widget>[
            Expanded(child: _Sample(theme: AppTheme.darkTheme)),
            Expanded(child: _Sample(theme: AppTheme.lightTheme)),
          ],
        ),
      ),
    );
  }
}

/// A card the size of the Home hero, with a balance over the field, so the
/// field is judged with text in front of it and not as a picture.
class _Sample extends StatelessWidget {
  const _Sample({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: theme,
      child: Builder(
        builder: (BuildContext context) {
          final ThemeData theme = Theme.of(context);
          return ColoredBox(
            color: theme.scaffoldBackgroundColor,
            child: Center(
              child: SizedBox(
                width: 1030,
                height: 148,
                child: Material(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(
                    AppTokens.of(context).cardRadius,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: <Widget>[
                      const Positioned.fill(child: HeroField()),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              'ADDRESS 4  z1qp3y…ej3e',
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '49,998.5 ZNN',
                              style: theme.textTheme.headlineSmall!.copyWith(
                                fontSize: 32,
                              ),
                            ),
                            Text(
                              '499,970 QSR',
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                      // The plasma meter at its real size, at three levels,
                      // and once enlarged so the light in it can be judged.
                      PositionedDirectional(
                        end: 24,
                        top: 22,
                        width: 420,
                        child: Column(
                          children: <Widget>[
                            for (final double level in <double>[1, 0.55, 0.2])
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: SizedBox(
                                  width: 210,
                                  child: PlasmaMeter(
                                    value: level,
                                    trackColor: theme.dividerTheme.color!,
                                  ),
                                ),
                              ),
                            PlasmaMeter(
                              value: 0.7,
                              height: 28,
                              trackColor: theme.dividerTheme.color!,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
