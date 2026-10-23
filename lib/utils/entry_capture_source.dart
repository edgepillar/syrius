import 'package:material_ui/material_ui.dart';

/// The observed result of an original owner Future, with no deadline or retry.
enum EntryCaptureStatus {
  /// The original operation has not completed.
  pending,

  /// The original operation completed positively.
  succeeded,

  /// The original operation returned its retained error.
  failed,
}

/// Retains the exact Future and its error without changing its caller's result.
class EntryCaptureCompletion {
  /// Observes an already reserved original operation.
  EntryCaptureCompletion(this.original) {
    completion = original.then<void>(
      (_) {
        _status = EntryCaptureStatus.succeeded;
      },
      onError: (Object error, StackTrace stack) {
        _error = error;
        _stack = stack;
        _status = EntryCaptureStatus.failed;
      },
    );
  }

  /// The original Future from route.completed or Navigator.push.
  final Future<dynamic> original;

  /// Settles after observation; inspect [status] for the actual outcome.
  late final Future<void> completion;
  EntryCaptureStatus _status = EntryCaptureStatus.pending;
  Object? _error;
  StackTrace? _stack;

  /// Pending and failed originals remain distinguishable forever.
  EntryCaptureStatus get status => _status;

  /// Positive completion alone admits a dependent capture.
  bool get succeeded => _status == EntryCaptureStatus.succeeded;

  /// Private diagnostic identity. Never include the raw error in a public log.
  Object? get error => _error;

  /// The original failure stack, retained without rendering private paths.
  StackTrace? get stackTrace => _stack;
}

/// One genuine Splash owner, reserved before calling its initialization.
class EntryStartupReceipt {
  EntryStartupReceipt._({
    required this.owner,
    required this.source,
    required this.route,
    required this.startupOwner,
    required Future<void> detached,
    required Future<void> cleanup,
    required this._current,
    required this._registry,
  }) : detached = EntryCaptureCompletion(detached),
       cleanup = EntryCaptureCompletion(cleanup);

  /// The actual Splash State.
  final Object owner;

  /// The original Splash source generation.
  final Object source;

  /// The actual route that mounted Splash.
  final ModalRoute<dynamic> route;

  /// The original launch session, retained across Splash disposal.
  final Object startupOwner;
  final bool Function() _current;
  final EntryCaptureRegistry _registry;

  /// Two actual detach frames, separate from decoder and image cleanup.
  final EntryCaptureCompletion detached;

  /// Detach and the original launch decoder's resource cleanup.
  final EntryCaptureCompletion cleanup;
  EntryCaptureCompletion? _initialization;
  EntryCaptureCompletion? _splashOperation;
  Object? _initializationError;
  StackTrace? _initializationStack;
  bool _initializationStarted = false;
  bool _welcomeRequested = false;
  bool _welcomeAttached = false;

  /// Remains the same operation after Splash has left the route stack.
  EntryCaptureCompletion? get initialization => _initialization;

  /// The original outer Splash operation, distinct from its inner initializer.
  EntryCaptureCompletion? get splashOperation => _splashOperation;

  /// Reserved before calling the initializer, including synchronous failure.
  bool get initializationStarted => _initializationStarted;

  /// The original initialization failure; no raw error enters public snapshots.
  Object? get initializationError =>
      _initializationError ?? _initialization?.error;

  /// The original private diagnostic stack, including a synchronous failure.
  StackTrace? get initializationStackTrace =>
      _initializationStack ?? _initialization?.stackTrace;

  /// Live ownership is distinct from completed initialization and cleanup.
  bool get isCurrent => _current();

  /// Reserves the invocation before any synchronous initialization effects.
  void beginInitialization() {
    if (_initializationStarted) _registry._hold();
    _initializationStarted = true;
  }

  /// Retains InitUtils.initApp's returned Future before it is awaited.
  void initializing(Future<void> original) {
    if (!_initializationStarted) _registry._hold();
    if (_initialization != null) {
      if (!identical(_initialization!.original, original)) _registry._hold();
      return;
    }
    _initialization = EntryCaptureCompletion(original);
  }

  /// An invocation failure without a returned Future remains explicit.
  void initializationFailed(Object error, StackTrace stack) {
    _initializationError ??= error;
    _initializationStack ??= stack;
  }

  /// The actual outer startup operation never substitutes for initApp's result.
  void retainSplashOperation(Future<void> original) {
    if (_splashOperation != null) {
      if (!identical(_splashOperation!.original, original)) _registry._hold();
      return;
    }
    _splashOperation = EntryCaptureCompletion(original);
  }

  /// Reserves only the existing no-wallet navigation, before its push.
  void requestingWelcome() {
    if (_welcomeRequested || _initialization == null) _registry._hold();
    _welcomeRequested = true;
  }

  /// A visible destination cannot substitute for either original completion.
  bool get ready =>
      !_registry.held &&
      _welcomeRequested &&
      _welcomeAttached &&
      _initializationStarted &&
      _initializationError == null &&
      (_initialization?.succeeded ?? false) &&
      (_splashOperation?.succeeded ?? false) &&
      detached.succeeded &&
      cleanup.succeeded;
}

/// The genuine Welcome State and the source that drew its three actions.
class EntryWelcomeReceipt {
  EntryWelcomeReceipt._({
    required this.owner,
    required this.source,
    required this.route,
    required this.startup,
    required Future<void> disposed,
    required this._attached,
    required this._current,
    required this._registry,
  }) : disposed = EntryCaptureCompletion(disposed);

  /// The original Welcome State, never serialized by the registry.
  final Object owner;

  /// The source that drew this State's entry actions.
  final Object source;

  /// The actual route retaining this Welcome State during an Import visit.
  final ModalRoute<dynamic> route;

  /// Only the receipt supplied by the original Splash navigation.
  final EntryStartupReceipt? startup;

  /// Positive disposal of this actual Welcome State.
  final EntryCaptureCompletion disposed;
  final bool Function() _attached;
  final bool Function() _current;
  final EntryCaptureRegistry _registry;

  /// Remains true while this owner's own Import covers its original route.
  bool get isAttached => _attached();

  /// Reads the same mounted/current-route guard used by the genuine owner.
  bool get isCurrent => isAttached && _current() && entryRouteReady(route);

  /// A direct Welcome mount has no startup proof and remains unqualified.
  bool get ready => !_registry.held && isCurrent && (startup?.ready ?? false);

  /// Requires the same original owner after its exact Import route is gone.
  bool restoredAfter(EntryImportReceipt imported) =>
      !_registry.held &&
      identical(imported.welcome, this) &&
      imported.cleaned &&
      isCurrent;
}

/// A genuine Welcome action's original route, navigation and Import State.
class EntryImportReceipt {
  EntryImportReceipt._(this.welcome, this.route, this._registry)
    : routeCompleted = EntryCaptureCompletion(route.completed);

  /// The original Welcome owner that admitted this Import visit.
  final EntryWelcomeReceipt welcome;

  /// The actual MaterialPageRoute used by ordinary Welcome navigation.
  final MaterialPageRoute<void> route;
  final EntryCaptureRegistry _registry;

  /// The retained route.completed Future, after its reverse transition.
  final EntryCaptureCompletion routeCompleted;
  EntryCaptureCompletion? _navigation;
  Object? _navigationError;
  StackTrace? _navigationStack;
  Object? _owner;
  Object? _source;
  Object? _controllerOwner;
  EntryCaptureCompletion? _controllerDisposed;
  bool Function()? _current;
  bool Function()? _empty;
  bool Function()? _unoffered;
  bool Function()? _pickerUntouched;

  /// The actual Import State, retained after disposal.
  Object? get owner => _owner;

  /// The first Import source. An edit cannot replace this identity.
  Object? get source => _source;

  /// Identity of the original controller, without copying its private text.
  Object? get controllerOwner => _controllerOwner;

  /// The actual Navigator.push result, separate from route.completed.
  EntryCaptureCompletion? get navigation => _navigation;

  /// Positive disposal of the original controller and its owning State.
  EntryCaptureCompletion? get controllerDisposed => _controllerDisposed;

  /// Exact private error when a push throws before returning its Future.
  Object? get navigationError => _navigationError;

  /// Original private stack for a synchronous push failure.
  StackTrace? get navigationStackTrace => _navigationStack;

  /// The original Navigator.push Future is retained before awaiting anything.
  void navigating(Future<dynamic> original) {
    if (_navigation != null) {
      if (!identical(_navigation!.original, original)) _registry._hold();
      return;
    }
    _navigation = EntryCaptureCompletion(original);
  }

  /// A synchronous push failure has no returned Future to invent or replace.
  void navigationFailed(Object error, StackTrace stack) {
    _navigationError ??= error;
    _navigationStack ??= stack;
    _registry._hold();
  }

  /// Coverage, source replacement and disposal revoke the captured owner.
  bool get isCurrent => (_current?.call() ?? false) && entryRouteReady(route);

  /// Booleans only; mnemonic text and file data stay with the owner.
  bool get empty => _empty?.call() ?? false;

  /// No file offer or selection has touched this original owner.
  bool get noOfferedFile => _unoffered?.call() ?? false;

  /// Any picker request or file probe permanently revokes this proof.
  bool get noPendingPickerOrProbe => _pickerUntouched?.call() ?? false;

  /// The first source must still be the untouched empty source on this route.
  bool get ready =>
      !_registry.held &&
      isCurrent &&
      empty &&
      noOfferedFile &&
      noPendingPickerOrProbe &&
      (welcome.startup?.ready ?? false) &&
      _navigation?.status == EntryCaptureStatus.pending;

  /// A pop result is insufficient until the actual route and controller end.
  bool get cleaned =>
      (_navigation?.succeeded ?? false) &&
      routeCompleted.succeeded &&
      (_controllerDisposed?.succeeded ?? false);
}

/// Reads the retained route's own entrance/return clocks without moving them.
bool entryRouteReady(ModalRoute<dynamic> route) =>
    route.isCurrent &&
    (route.animation?.status ?? AnimationStatus.completed) ==
        AnimationStatus.completed &&
    (route.secondaryAnimation?.status ?? AnimationStatus.dismissed) ==
        AnimationStatus.dismissed;

/// Harness-only observation of the process's first ordinary entry lineage.
///
/// Replacements and capacity exhaustion hold capture only. They never prevent
/// ordinary startup, navigation, file selection or disposal from proceeding.
/// Production entry visits record a boolean without retaining owner objects.
class EntryCaptureRegistry {
  EntryCaptureRegistry._();

  /// The harness opts in before app startup; ordinary builds retain no owners.
  static final EntryCaptureRegistry instance = EntryCaptureRegistry._();

  /// Every retained route fits in a finite process-local receipt set.
  static const int maxImports = 32;
  EntryStartupReceipt? _startup;
  EntryWelcomeReceipt? _welcome;
  final List<EntryImportReceipt> _imports = <EntryImportReceipt>[];
  bool _held = false;
  bool _observingHarnessEntry = false;
  bool _unobservedEntrySeen = false;

  /// Enables collection only before the first genuine entry owner is seen.
  ///
  /// Repeated calls cannot clear a hold or adopt an already running app. This
  /// is called only by the native capture harness before the app's main entry.
  void observeHarnessEntry() {
    if (_observingHarnessEntry) return;
    if (_unobservedEntrySeen) {
      _hold();
      return;
    }
    _observingHarnessEntry = true;
  }

  /// Whether explicit harness observation began before genuine app startup.
  bool get observingHarnessEntry => _observingHarnessEntry;

  bool _observeEntry() {
    if (_observingHarnessEntry) return true;
    _unobservedEntrySeen = true;
    return false;
  }

  /// The first actual Splash owner; a replacement cannot overwrite it.
  EntryStartupReceipt? get startup => _startup;

  /// The first actual Welcome owner, retained across temporary route coverage.
  EntryWelcomeReceipt? get welcome => _welcome;

  /// An immutable view of the bounded original Import visits.
  List<EntryImportReceipt> get imports =>
      List<EntryImportReceipt>.unmodifiable(_imports);

  /// The last reserved original route, including an uncertain pending visit.
  EntryImportReceipt? get latestImport => _imports.lastOrNull;

  /// Sticky uncertainty cannot be cleared by mounting a replacement owner.
  bool get held => _held;
  void _hold() => _held = true;

  /// Reserves the original Splash before InitUtils can produce reentrant work.
  EntryStartupReceipt? attachStartup({
    required Object owner,
    required Object source,
    required ModalRoute<dynamic> route,
    required Object startupOwner,
    required Future<void> detached,
    required Future<void> cleanup,
    required bool Function() current,
  }) {
    if (!_observeEntry()) return null;
    final EntryStartupReceipt? original = _startup;
    if (original != null) {
      if (!identical(original.owner, owner) ||
          !identical(original.source, source) ||
          !identical(original.route, route) ||
          !identical(original.startupOwner, startupOwner) ||
          !identical(original.detached.original, detached) ||
          !identical(original.cleanup.original, cleanup)) {
        _hold();
        return null;
      }
      return original;
    }
    return _startup = EntryStartupReceipt._(
      owner: owner,
      source: source,
      route: route,
      startupOwner: startupOwner,
      detached: detached,
      cleanup: cleanup,
      current: current,
      registry: this,
    );
  }

  /// Accepts only the original startup argument, never a latest-owner lookup.
  EntryWelcomeReceipt? attachWelcome({
    required Object owner,
    required Object source,
    required ModalRoute<dynamic> route,
    required Future<void> disposed,
    required bool Function() attached,
    required bool Function() current,
  }) {
    if (!_observeEntry()) return null;
    final EntryWelcomeReceipt? original = _welcome;
    if (original != null) {
      if (!identical(original.owner, owner) ||
          !identical(original.source, source) ||
          !identical(original.route, route)) {
        _hold();
        return null;
      }
      return original;
    }
    final Object? argument = route.settings.arguments;
    EntryStartupReceipt? startup;
    if (argument is EntryStartupReceipt &&
        identical(argument, _startup) &&
        argument._welcomeRequested &&
        !argument._welcomeAttached) {
      startup = argument;
      argument._welcomeAttached = true;
    }
    return _welcome = EntryWelcomeReceipt._(
      owner: owner,
      source: source,
      route: route,
      startup: startup,
      disposed: disposed,
      attached: attached,
      current: current,
      registry: this,
    );
  }

  /// Reserves a route before Navigator.push can mount its genuine importer.
  EntryImportReceipt? openingImport({
    required EntryWelcomeReceipt? welcome,
    required MaterialPageRoute<void> route,
  }) {
    if (!_observeEntry()) return null;
    if (welcome == null ||
        !identical(welcome, _welcome) ||
        _imports.length >= maxImports) {
      _hold();
      return null;
    }
    if (_imports.isNotEmpty && !welcome.restoredAfter(_imports.last)) _hold();
    final EntryImportReceipt receipt = EntryImportReceipt._(
      welcome,
      route,
      this,
    );
    _imports.add(receipt);
    return receipt;
  }

  /// Binds the actual State only to the exact route reserved by Welcome.
  EntryImportReceipt? attachImport({
    required Object owner,
    required Object source,
    required ModalRoute<dynamic> route,
    required Object controllerOwner,
    required Future<void> controllerDisposed,
    required bool Function() current,
    required bool Function() empty,
    required bool Function() noOfferedFile,
    required bool Function() noPendingPickerOrProbe,
  }) {
    if (!_observeEntry()) return null;
    final EntryImportReceipt? receipt = _imports
        .where((EntryImportReceipt value) => identical(value.route, route))
        .firstOrNull;
    if (receipt == null) return null;
    if (receipt._owner != null) {
      if (!identical(receipt._owner, owner) ||
          !identical(receipt._source, source) ||
          !identical(receipt._controllerOwner, controllerOwner)) {
        _hold();
        return null;
      }
      return receipt;
    }
    receipt
      .._owner = owner
      .._source = source
      .._controllerOwner = controllerOwner
      .._controllerDisposed = EntryCaptureCompletion(controllerDisposed)
      .._current = current
      .._empty = empty
      .._unoffered = noOfferedFile
      .._pickerUntouched = noPendingPickerOrProbe;
    return receipt;
  }
}
