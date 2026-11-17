import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/shaders/shader_clock.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/motion/rise_switcher.dart';

const MethodChannel _window = MethodChannel('window_manager');

class _ClockSurface extends StatefulWidget {
  const _ClockSurface({
    required this.onReady,
    required this.onDisposed,
    super.key,
  });

  final ValueChanged<ShaderClock> onReady;
  final VoidCallback onDisposed;

  @override
  State<_ClockSurface> createState() => _ClockSurfaceState();
}

class _ClockSurfaceState extends State<_ClockSurface>
    with SingleTickerProviderStateMixin {
  late final ShaderClock clock;

  @override
  void initState() {
    super.initState();
    clock = ShaderClock(vsync: this)..active = true;
    widget.onReady(clock);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    clock.updateVisibility(context);
  }

  @override
  void dispose() {
    clock.dispose();
    widget.onDisposed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_window, (MethodCall call) async {
          if (call.method == 'isFocused') return true;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_window, null);
  });

  testWidgets('only visible page shaders advance during fade through', (
    WidgetTester tester,
  ) async {
    final Map<int, ShaderClock> clocks = <int, ShaderClock>{};
    final Set<int> disposed = <int>{};
    Widget host(int index) => MaterialApp(
      home: RiseSwitcher(
        child: _ClockSurface(
          key: ValueKey<int>(index),
          onReady: (ShaderClock clock) => clocks[index] = clock,
          onDisposed: () => disposed.add(index),
        ),
      ),
    );

    await tester.pumpWidget(host(0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(clocks[0]!.value, closeTo(0.1, 0.000001));

    await tester.pumpWidget(host(1));
    expect(clocks[0]!.isRunning, isTrue);
    expect(clocks[1]!.isRunning, isFalse);
    expect(clocks[1]!.value, 0);
    final double exitStart = clocks[0]!.value;

    await tester.pump(const Duration(milliseconds: 95));
    expect(clocks[0]!.value, closeTo(exitStart + 0.095, 0.000001));
    expect(clocks[1]!.isRunning, isFalse);
    expect(clocks[1]!.value, 0);

    await tester.pump(const Duration(milliseconds: 1));
    expect(clocks[1]!.isRunning, isFalse);
    expect(clocks[1]!.value, 0);

    await tester.pump(const Duration(milliseconds: 1));
    expect(disposed, contains(0));
    expect(clocks[1]!.isRunning, isTrue);
    expect(clocks[1]!.value, 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(clocks[1]!.value, closeTo(0.1, 0.000001));

    await tester.pump(const Duration(milliseconds: 123));
    await tester.pump(const Duration(microseconds: 1));
    expect(tester.binding.transientCallbackCount, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(disposed, containsAll(<int>[0, 1]));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a replaced hidden arrival never advances its shader', (
    WidgetTester tester,
  ) async {
    final Map<int, ShaderClock> clocks = <int, ShaderClock>{};
    final Set<int> disposed = <int>{};
    Widget host(int index) => MaterialApp(
      home: RiseSwitcher(
        child: _ClockSurface(
          key: ValueKey<int>(index),
          onReady: (ShaderClock clock) => clocks[index] = clock,
          onDisposed: () => disposed.add(index),
        ),
      ),
    );

    await tester.pumpWidget(host(0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(host(1));
    await tester.pump(const Duration(milliseconds: 50));
    expect(clocks[1]!.isRunning, isFalse);
    expect(clocks[1]!.value, 0);

    await tester.pumpWidget(host(2));
    expect(disposed, contains(1));
    expect(clocks[1]!.value, 0);
    expect(clocks[2]!.isRunning, isFalse);
    await tester.pump(const Duration(milliseconds: 50));
    expect(disposed, containsAll(<int>[0, 1]));
    expect(clocks[2]!.isRunning, isFalse);
    expect(clocks[2]!.value, 0);

    await tester.pump(const Duration(milliseconds: 47));
    expect(clocks[2]!.isRunning, isTrue);
    expect(clocks[2]!.value, 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(clocks[2]!.value, closeTo(0.1, 0.000001));

    await tester.pumpWidget(const SizedBox.shrink());
    expect(disposed, containsAll(<int>[0, 1, 2]));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
