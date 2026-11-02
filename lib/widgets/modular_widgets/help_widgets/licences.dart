import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/disclosure.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';

/// An injectable registry stream, with no package or licence fixture default.
typedef AboutLicenceLoader = Stream<LicenseEntry> Function();

/// The actual licence registry, with one row per package or bundled font.
class Licences extends StatefulWidget {
  /// The owner supplies a bounded height and optional end-of-list content.
  const Licences({
    this.loadLicences,
    this.trailingBuilder,
    this.preserveEndOnReveal = false,
    super.key,
  });

  /// Null uses Flutter's registry, including the startup font registrations.
  final AboutLicenceLoader? loadLicences;

  /// Built after the final licence, following a complete registry read.
  final WidgetBuilder? trailingBuilder;

  /// On the reveal transition, retain a previously reached real list end.
  final bool preserveEndOnReveal;

  @override
  State<Licences> createState() => _LicencesState();
}

class _LicencesState extends State<Licences> {
  final ScrollController _scroll = ScrollController();
  StreamSubscription<LicenseEntry>? _subscription;
  List<_PackageLicence>? _packages;
  int _epoch = 0;
  int _scrollRevision = 0;
  bool _wasAtEnd = false;
  Object? _endRequest;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_scrolled);
    _read();
  }

  @override
  void didUpdateWidget(Licences oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.loadLicences, widget.loadLicences)) {
      _read();
    } else if (widget.preserveEndOnReveal &&
        !oldWidget.preserveEndOnReveal) {
      _keepReachedEnd();
    } else if (!widget.preserveEndOnReveal) {
      _endRequest = null;
    }
  }

  void _rememberEnd() {
    if (!_scroll.hasClients || !_scroll.position.hasContentDimensions) return;
    _wasAtEnd = _scroll.position.extentAfter == 0;
  }

  void _scrolled() {
    _scrollRevision++;
    _rememberEnd();
  }

  void _keepReachedEnd() {
    if (!_scroll.hasClients) return;
    final ScrollPosition position = _scroll.position;
    if (!position.hasContentDimensions ||
        !_wasAtEnd ||
        position.isScrollingNotifier.value) {
      return;
    }
    final int epoch = _epoch;
    final Object request = Object();
    _endRequest = request;
    int revision = _scrollRevision;
    int corrections = 0;
    bool current() => mounted &&
          identical(_endRequest, request) &&
          widget.preserveEndOnReveal &&
          epoch == _epoch &&
          _scroll.hasClients &&
          identical(position, _scroll.position) &&
          _scrollRevision == revision &&
          !position.isScrollingNotifier.value;
    void finish() {
      if (identical(_endRequest, request)) _endRequest = null;
    }
    void restore(Duration _) {
      if (!current()) {
        finish();
        return;
      }
      // Keep the bounded observations: a lazy extent can look final early.
      if (corrections == 4) {
        finish();
        return;
      }
      final double target = position.maxScrollExtent;
      if (!target.isFinite) {
        finish();
        return;
      }
      final int expected = revision + (position.pixels == target ? 0 : 1);
      position.jumpTo(target);
      // Only this jump may advance the lease; a reentrant movement revokes it.
      if (_scrollRevision != expected || position.pixels != target) {
        finish();
        return;
      }
      revision = expected;
      corrections++;
      if (!current()) {
        finish();
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback(restore);
      WidgetsBinding.instance.ensureVisualUpdate();
    }
    WidgetsBinding.instance.addPostFrameCallback(restore);
  }

  void _read() {
    _wasAtEnd = false;
    _endRequest = null;
    final int epoch = ++_epoch;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _packages = null;
    _failed = false;
    final Map<String, List<List<LicenseParagraph>>> collected =
        <String, List<List<LicenseParagraph>>>{};
    void fail(Object _, [StackTrace? _]) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _packages = null;
          _failed = true;
        });
      }
    }

    try {
      final Stream<LicenseEntry> entries =
          widget.loadLicences?.call() ?? LicenseRegistry.licenses;
      _subscription = entries.listen(
        (LicenseEntry entry) {
          if (!mounted || epoch != _epoch || _failed) return;
          try {
            final List<LicenseParagraph> paragraphs =
                List<LicenseParagraph>.unmodifiable(entry.paragraphs);
            final Set<String> packages = entry.packages.toSet();
            // Even an unnamed registry entry keeps its authentic paragraphs.
            for (final String package
                in packages.isEmpty ? const <String>{''} : packages) {
              collected
                  .putIfAbsent(package, () => <List<LicenseParagraph>>[])
                  .add(paragraphs);
            }
          } on Object catch (error, stack) {
            fail(error, stack);
            unawaited(_subscription?.cancel());
          }
        },
        onError: fail,
        onDone: () {
          if (!mounted || epoch != _epoch || _failed) return;
          final List<String> names = collected.keys.toList()
            ..sort(
              (String a, String b) => a.toLowerCase().compareTo(
                b.toLowerCase(),
              ),
            );
          setState(() {
            _packages = <_PackageLicence>[
              for (final String name in names)
                _PackageLicence(
                  name,
                  List<List<LicenseParagraph>>.unmodifiable(collected[name]!),
                ),
            ];
          });
        },
        cancelOnError: true,
      );
    } on Object catch (error, stack) {
      fail(error, stack);
    }
  }

  @override
  void dispose() {
    _epoch++;
    _endRequest = null;
    unawaited(_subscription?.cancel());
    _scroll.removeListener(_scrolled);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final List<_PackageLicence>? packages = _packages;
    if (_failed) {
      return Center(
        child: Padding(
          padding: tokens.cardPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                context.l10n.aboutLicencesFailed,
                key: const Key('about_licences_failure'),
                style: tokens.bodyText,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: tokens.inlineGap),
              SecondaryAction(
                child: OutlinedButton(
                  key: const Key('about_licences_retry'),
                  onPressed: () => setState(_read),
                  child: Text(context.l10n.aboutRetry),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (packages == null) {
      return Center(
        child: Text(
          context.l10n.aboutLicencesLoading,
          key: const Key('about_licences_loading'),
          style: tokens.settingsHintText,
        ),
      );
    }
    if (packages.isEmpty) {
      return QuietNote(
        context.l10n.noItemsFound,
        key: const Key('about_licences_empty'),
      );
    }
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (ScrollMetricsNotification notification) {
        if (notification.depth == 0) _rememberEnd();
        return false;
      },
      child: Scrollbar(
        controller: _scroll,
        thumbVisibility: true,
        child: ListView.builder(
          key: const Key('about_licences_list'),
          controller: _scroll,
          primary: false,
          itemCount: packages.length + 1,
          itemBuilder: (BuildContext context, int index) {
            if (index == packages.length) {
              return KeyedSubtree(
                key: const Key('about_licences_end'),
                child:
                    widget.trailingBuilder?.call(context) ??
                    SizedBox(height: tokens.cardGap),
              );
            }
            final _PackageLicence package = packages[index];
            return _LicenceRow(
              key: ValueKey<String>('about_licence_${package.name}'),
              package: package,
            );
          },
        ),
      ),
    );
  }
}

class _PackageLicence {
  const _PackageLicence(this.name, this.entries);

  final String name;
  final List<List<LicenseParagraph>> entries;
}

class _LicenceRow extends StatelessWidget {
  const _LicenceRow({required this.package, super.key});

  final _PackageLicence package;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.line)),
      ),
      child: Theme(
        data: theme.copyWith(
          textTheme: theme.textTheme.copyWith(headlineSmall: tokens.bodyText),
        ),
        child: Disclosure(
          title: package.name.isEmpty
              ? context.l10n.aboutUnknown
              : package.name,
          keyPrefix: 'about_licence_${package.name}',
          headerMinHeight: tokens.aboutLicenceRowHeight,
          child: Padding(
            padding: tokens.cardPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final List<LicenseParagraph> entry
                    in package.entries) ...<Widget>[
                  for (final LicenseParagraph paragraph in entry)
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                        start:
                            paragraph.indent == LicenseParagraph.centeredIndent
                            ? 0
                            : paragraph.indent > 0
                            ? tokens.cardGap * paragraph.indent
                            : 0,
                        bottom: tokens.inlineGap,
                      ),
                      child: SelectableText(
                        paragraph.text,
                        textAlign:
                            paragraph.indent == LicenseParagraph.centeredIndent
                            ? TextAlign.center
                            : TextAlign.start,
                        style: tokens.bodyText,
                      ),
                    ),
                  SizedBox(height: tokens.cardGap),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
