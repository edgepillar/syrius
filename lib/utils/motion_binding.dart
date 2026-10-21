import 'package:flutter/foundation.dart' show BindingBase;
import 'package:flutter/widgets.dart';

/// Every animation runs, always, whatever the system says about reduced
/// motion. The SDK plays an [AnimationController] at a twentieth of its
/// length when the binding reports [disableAnimations], and the implicit
/// widgets and the animation packages give no way to opt out one by one, so
/// the binding answers false for all of them.
///
/// The root [MediaQuery] does not ask the binding: it copies the same flag
/// straight from the platform, and [Image] stops an animated image on it.
/// [wrapWithDefaultView] is the one place under that [MediaQuery] and above
/// everything `runApp` is given, the overlay that sits outside `MaterialApp`
/// included, so the second override goes there and no entry point carries it.
mixin MotionAlwaysBinding on WidgetsBinding {
  @override
  bool get disableAnimations => false;

  @override
  Widget wrapWithDefaultView(Widget rootWidget) =>
      super.wrapWithDefaultView(MotionAlways(child: rootWidget));
}

/// The binding every entry point installs in place of the SDK's.
///
/// It has to be the first binding the process creates. A later
/// `WidgetsFlutterBinding.ensureInitialized()` hands this one back, but an
/// earlier one would leave a plain binding in place with the rule switched
/// off and nothing to show for it; a debug build stops on that with "Binding
/// is already initialized".
class MotionBinding extends WidgetsFlutterBinding with MotionAlwaysBinding {
  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
  }

  /// The binding, once [ensureInitialized] has run.
  static MotionBinding get instance => BindingBase.checkInstance(_instance);
  static MotionBinding? _instance;

  /// Installs the binding if the process has none, and returns it. The shape
  /// is the SDK's own, so it reads the same at every call site.
  // ignore: prefer_constructors_over_static_methods
  static MotionBinding ensureInitialized() {
    if (_instance == null) {
      MotionBinding();
    }
    return _instance!;
  }
}

/// Hands [child] the surrounding [MediaQuery] with `disableAnimations` false.
///
/// [MotionAlwaysBinding] already puts one under the root view. Use it by hand
/// only for a tree that is not started by `runApp`, or that builds a
/// [MediaQuery] of its own from the view.
class MotionAlways extends StatelessWidget {
  /// Creates the override around [child].
  const MotionAlways({required this.child, super.key});

  /// The tree that must never read the platform's flag.
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: false),
    child: child,
  );
}
