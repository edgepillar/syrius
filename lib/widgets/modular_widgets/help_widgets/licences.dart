import 'dart:async';
import 'dart:convert';

import 'package:cryptography/dart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:hex/hex.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/disclosure.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';

/// An injectable registry stream, with no package or licence fixture default.
typedef AboutLicenceLoader = Stream<LicenseEntry> Function();

// The normalized length only rules out impossible matches. Every identifier
// requires the SHA-256 of the complete normalized notice.
const Map<int, Map<String, String>>
_reviewedNoticeTypes = <int, Map<String, String>>{
  568: <String, String>{
    // The Apache-2.0 source header bundled alongside the yapf licence.
    '42ebf0d3ee784ee63ffc6baa96301fb701a23db21591bdedc5d836a30cf4fc33':
        'Apache-2.0',
  },
  1082: <String, String>{
    '7a1c6b350f199a0774b3244ec6616af832569ad25d7e8eeb12a944b33d31899f': 'MIT',
    '441207d57c5ad42783aa1a1d0e4d59f7af08d332e3a03ddd2ebbcdf1495f3e53': 'MIT',
    'ee351ea1c070a33d69c3c6e3354606aa765c73e3dbbdf5bbf2804d99d2b8bc2f': 'MIT',
  },
  1091: <String, String>{
    'f6fd12b9fe4c2537d870eb62dd7838f2f30d190d362e13c982d1693c446a4602': 'MIT',
  },
  1096: <String, String>{
    '63ed493e404edc9d6140f12a56495b40a083c108b3d6d090bc246d34795fc082': 'MIT',
  },
  1102: <String, String>{
    '3de266935886bc204b4dc4b12e511bcecd7fd7aff3b6b44ed08b87d7a5d8f9e9': 'MIT',
  },
  1453: <String, String>{
    '1f478d50351c883e515dc1ba2df28b34b6559345e989f7ceb5a4da2ff42fd33e':
        'BSD-3-Clause',
  },
  1467: <String, String>{
    'b2dfea7ab0058a675a30e3bb36d3a7747546565c370128d10be6d883e117a3a2':
        'BSD-3-Clause',
  },
  1473: <String, String>{
    'd52acfb27ee4838e55fee65254d4ad6f10b24538ae58298645e2fb8cb72cbaf9':
        'BSD-3-Clause',
  },
  1477: <String, String>{
    '4b526277a9e26ebb309f6f2ca366c02cc339508a0a5da0b4e7b118d63575ac5f':
        'BSD-3-Clause',
    'ee5cbcfafc145501b2164419c09881dd6855fb26a946e607846adb86355e8128':
        'BSD-3-Clause',
  },
  4379: <String, String>{
    'cf0997ace7773167cefd32109d6b8e652e364f16f114e613b777813556a1b507':
        'OFL-1.1',
  },
  4382: <String, String>{
    '630f3d819cb270483178bad6ae05f5a4975eebc5e3ccdc211c833f607bde7095':
        'OFL-1.1',
  },
  4444: <String, String>{
    'f52331818a1275859e8895c008e7afc4a6030b3c26f37fe1d467c036fa6e4190':
        'OFL-1.1',
  },
  9129: <String, String>{
    '59d8f0ba87ad9a2f1a431123c8d16646e5b89ba53653e818f16d136d77263c99':
        'Apache-2.0',
  },
  10221: <String, String>{
    '0ffddef9e48f8a09aed5caf2d44f7ba1c1be2d9b8e0a6f693b1635b2d5566645':
        'Apache-2.0',
  },
};

final RegExp _noticeWhitespace = RegExp(r'\s+');

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

  /// On reveal, retain a reached list end or already visible trailing area.
  final bool preserveEndOnReveal;

  @override
  State<Licences> createState() => _LicencesState();
}

class _LicencesState extends State<Licences> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  final GlobalKey _trailingKey = GlobalKey();
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

  bool _trailingIsVisible() {
    final RenderObject? viewport =
        _viewportKey.currentContext?.findRenderObject();
    final RenderObject? trailing =
        _trailingKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || trailing is! RenderBox ||
        !viewport.attached || !trailing.attached ||
        !viewport.hasSize || !trailing.hasSize) {
      return false;
    }
    try {
      final Rect viewportBounds = MatrixUtils.transformRect(
        viewport.getTransformTo(null), Offset.zero & viewport.size,
      );
      final Rect trailingBounds = MatrixUtils.transformRect(
        trailing.getTransformTo(null), Offset.zero & trailing.size,
      );
      for (final Rect bounds in <Rect>[viewportBounds, trailingBounds]) {
        if (<double>[bounds.left, bounds.top, bounds.right, bounds.bottom]
            .any((double value) => !value.isFinite)) {
          return false;
        }
      }
      final Rect overlap = viewportBounds.intersect(trailingBounds);
      return overlap.width > 0 && overlap.height > 0;
    } on Object {
      return false;
    }
  }

  void _keepReachedEnd() {
    if (!_scroll.hasClients) return;
    final ScrollPosition position = _scroll.position;
    // The discovery field can be visible before its trailing padding ends.
    if (!position.hasContentDimensions ||
        position.isScrollingNotifier.value ||
        (!_wasAtEnd && !_trailingIsVisible())) {
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
      if (position.pixels != target) {
        final int expected = revision + 1;
        position.jumpTo(target);
        // Only this jump may advance the lease. Other movement revokes it.
        if (_scrollRevision != expected || position.pixels != target) {
          finish();
          return;
        }
        revision = expected;
      }
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
    final Map<String, List<_LicenceText>> collected =
        <String, List<_LicenceText>>{};
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
            final _LicenceText text = _LicenceText(entry);
            final Set<String> packages = entry.packages.toSet();
            // Even an unnamed registry entry keeps its authentic paragraphs.
            for (final String package
                in packages.isEmpty ? const <String>{''} : packages) {
              collected.putIfAbsent(package, () => <_LicenceText>[]).add(text);
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
                  List<_LicenceText>.unmodifiable(collected[name]!),
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
    final double rowHeight = widget.preserveEndOnReveal
        ? tokens.aboutOriginalsLicenceRowHeight
        : tokens.aboutLicenceRowHeight;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (ScrollMetricsNotification notification) {
        if (notification.depth == 0) _rememberEnd();
        return false;
      },
      child: RawScrollbar(
        key: _viewportKey,
        controller: _scroll,
        thumbVisibility: true,
        trackVisibility: true,
        fadeDuration: Duration.zero,
        thumbColor: tokens.faint,
        trackColor: tokens.line,
        trackBorderColor: Colors.transparent,
        thickness: 4,
        radius: const Radius.circular(2),
        trackRadius: const Radius.circular(2),
        // The track consumes the scrollbar margins. Pad the whole track
        // instead so the track stays the same width as its thumb.
        padding: const EdgeInsetsDirectional.only(top: 6, bottom: 6, end: 4),
        minThumbLength: widget.preserveEndOnReveal ? 30 : 46,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: ListView.builder(
            key: const Key('about_licences_list'),
            controller: _scroll,
            primary: false,
            // Opening the panel only prepares a short scroll buffer of rows.
            scrollCacheExtent: ScrollCacheExtent.pixels(2 * rowHeight),
            itemCount: packages.length + 1,
            itemBuilder: (BuildContext context, int index) {
              if (index == packages.length) {
                return KeyedSubtree(
                  key: const Key('about_licences_end'),
                  child: KeyedSubtree(
                    key: _trailingKey,
                    child: widget.trailingBuilder?.call(context) ??
                        SizedBox(height: tokens.cardGap),
                  ),
                );
              }
              final _PackageLicence package = packages[index];
              return _LicenceRow(
                key: ValueKey<String>('about_licence_${package.name}'),
                package: package,
                headerHeight: rowHeight,
                summaryColumnPercent: widget.preserveEndOnReveal
                    ? tokens.aboutOriginalsLicenceSummaryPercent
                    : tokens.aboutLicenceSummaryPercent,
                onReadFailure: () {
                  if (!mounted || !identical(_packages, packages)) return;
                  setState(() {
                    _packages = null;
                    _failed = true;
                  });
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LicenceText {
  _LicenceText(LicenseEntry entry) {
    if (entry is LicenseEntryWithLineBreaks) {
      // Flutter's bundled notices already own an immutable source string.
      _original = entry;
    } else {
      _paragraphs = List<LicenseParagraph>.unmodifiable(entry.paragraphs);
    }
  }

  LicenseEntryWithLineBreaks? _original;
  List<LicenseParagraph>? _paragraphs;
  String? _identifier;
  bool _identifierRead = false;

  String? get identifier {
    if (!_identifierRead) {
      _identifierRead = true;
      final String? text = _original?.text;
      if (text != null && text.length <= 16 * 1024) {
        final String normalized = text.trim().replaceAll(
          _noticeWhitespace,
          ' ',
        );
        final Map<String, String>? matches =
            _reviewedNoticeTypes[normalized.length];
        if (matches != null) {
          final String digest = HEX.encode(
            const DartSha256().hashSync(utf8.encode(normalized)).bytes,
          );
          _identifier = matches[digest];
        }
      }
    }
    return _identifier;
  }

  List<LicenseParagraph> get paragraphs {
    final List<LicenseParagraph> result = _paragraphs ??=
        List<LicenseParagraph>.unmodifiable(_original!.paragraphs);
    _original = null;
    return result;
  }
}

class _PackageLicence {
  _PackageLicence(this.name, this.entries);

  final String name;
  final List<_LicenceText> entries;
  List<List<LicenseParagraph>>? _paragraphs;
  late final String? identifier = _readIdentifier();

  String? _readIdentifier() {
    final Set<String?> values = <String?>{
      for (final _LicenceText entry in entries) entry.identifier,
    };
    if (values.contains(null)) return null;
    final List<String> labels = values.whereType<String>().toList()..sort();
    return labels.join(', ');
  }

  List<List<LicenseParagraph>> get paragraphs =>
      _paragraphs ?? const <List<LicenseParagraph>>[];

  void readParagraphs() {
    _paragraphs ??= <List<LicenseParagraph>>[
      for (final _LicenceText entry in entries) entry.paragraphs,
    ];
  }
}

class _LicenceRow extends StatelessWidget {
  const _LicenceRow({
    required this.package,
    required this.headerHeight,
    required this.summaryColumnPercent,
    required this.onReadFailure,
    super.key,
  });

  final _PackageLicence package;
  final double headerHeight;
  final int summaryColumnPercent;
  final VoidCallback onReadFailure;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.line)),
      ),
      child: Disclosure(
        title: package.name.isEmpty ? context.l10n.aboutUnknown : package.name,
        titleStyle: tokens.bodyText,
        summary: package.identifier,
        summaryColumnPercent: summaryColumnPercent,
        keyPrefix: 'about_licence_${package.name}',
        headerMinHeight: headerHeight,
        headerPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        // The lazy list already isolates each painted row.
        isolateChevronPaint: false,
        onChanged: (bool open) {
          if (open) {
            try {
              package.readParagraphs();
            } on Object {
              onReadFailure();
            }
          }
        },
        child: Builder(builder: (_) => _buildParagraphs(tokens)),
      ),
    );
  }

  Widget _buildParagraphs(AppTokens tokens) => Padding(
    padding: tokens.cardPadding,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final List<LicenseParagraph> entry
            in package.paragraphs) ...<Widget>[
          for (final LicenseParagraph paragraph in entry)
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: paragraph.indent > 0
                    ? tokens.cardGap * paragraph.indent
                    : 0,
                bottom: tokens.inlineGap,
              ),
              child: SelectableText(
                paragraph.text,
                textAlign: paragraph.indent == LicenseParagraph.centeredIndent
                    ? TextAlign.center
                    : TextAlign.start,
                style: tokens.bodyText,
              ),
            ),
          SizedBox(height: tokens.cardGap),
        ],
      ],
    ),
  );
}
