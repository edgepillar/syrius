import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:material_ui/material_ui.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/services/windows_image_clipboard.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/color_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/rail.dart'
    show ShellSymbol;
import 'package:znn_sdk_dart/znn_sdk_dart.dart' show TokenStandard;

const MethodChannel _imageClipboard = MethodChannel(
  'network.zenon.syrius/image_clipboard',
);

/// Rasterizes one exact QR request for the existing image exports.
typedef ReceiveQrEncoder =
    Future<Uint8List?> Function(
      QrImage image,
      PrettyQrDecoration decoration,
      int size,
    );

/// A request QR with Copy image and Save operations.
class ReceiveQrImage extends StatefulWidget {
  /// Creates the image. Tests may replace rasterization and native exports.
  const ReceiveQrImage({
    required this.data,
    required this.size,
    required this.tokenStandard,
    this.enabled = true,
    this.isRequestCurrent,
    this.onCopyImage,
    this.onSaveImage,
    this.encodeImage,
    super.key,
  });

  /// The exact legacy request encoded in the image.
  final String data;

  /// The square image's logical size before its surrounding controls.
  final double size;

  /// Selects the existing native-coin mark's token color.
  final TokenStandard tokenStandard;

  /// A closing panel keeps its paint while refusing further exports.
  final bool enabled;

  /// Synchronously checks ownership at admission and native dispatch.
  /// An edited form can revoke this image before its next widget rebuild.
  final bool Function()? isRequestCurrent;

  /// Replaces the native clipboard write of the generated PNG bytes.
  final Future<void> Function(Uint8List)? onCopyImage;

  /// Replaces saving the generated PNG to a selected file.
  final Future<void> Function(Uint8List)? onSaveImage;

  /// Replaces image encoding without replacing the QR payload.
  final ReceiveQrEncoder? encodeImage;

  @override
  State<ReceiveQrImage> createState() => _ReceiveQrImageState();
}

class _ReceiveQrImageState extends State<ReceiveQrImage> {
  String? _cachedData;
  QrImage? _cachedImage;
  bool _exporting = false;
  bool _exportFailed = false;
  int _attempt = 0;

  QrImage _imageFor(String data) {
    if (_cachedData == data && _cachedImage != null) return _cachedImage!;
    final QrImage image = QrImage(
      QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M),
    );
    _cachedData = data;
    _cachedImage = image;
    return image;
  }

  @override
  void didUpdateWidget(ReceiveQrImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool dataChanged = oldWidget.data != widget.data;
    if (dataChanged || oldWidget.enabled != widget.enabled) {
      // An encoder may finish after an edited request has replaced its
      // image. Such bytes must never reach a native export callback.
      _attempt += 1;
      _exporting = false;
      _exportFailed = false;
      if (dataChanged) {
        _cachedData = null;
        _cachedImage = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Future<void> Function(Uint8List) copyImage =
        widget.onCopyImage ?? _copyImage;
    final Future<void> Function(Uint8List)? saveImage = widget.onSaveImage;
    final AppTokens tokens = AppTokens.of(context);
    QrImage? image;
    PrettyQrDecoration? decoration;
    try {
      image = _imageFor(widget.data);
      decoration = PrettyQrDecoration(
        shape: PrettyQrSmoothSymbol(color: tokens.foreground, roundFactor: 0),
        image: PrettyQrDecorationImage(
          colorFilter: ColorFilter.mode(
            ColorUtils.getTokenColor(widget.tokenStandard),
            BlendMode.srcIn,
          ),
          image: const AssetImage(
            'assets/images/qr_code_child_image_znn_cut.png',
          ),
          fit: BoxFit.contain,
        ),
      );
    } on Object catch (_) {
      image = null;
    }
    final QrImage? qrImage = image;
    final PrettyQrDecoration? qrDecoration = decoration;
    final ButtonStyle actionStyle = TextButton.styleFrom(
      foregroundColor: tokens.dim,
      backgroundColor: Colors.transparent,
      textStyle: tokens.captionText.copyWith(fontWeight: FontWeight.w500),
      minimumSize: Size(0, tokens.smallButtonHeight),
      visualDensity: VisualDensity.standard,
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: tokens.receiveQrActionInset,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Tooltip(
          key: const Key('receive_qr_payload'),
          message: widget.data,
          child: SizedBox.square(
            dimension: widget.size,
            child: qrImage == null || qrDecoration == null
                ? _buildError(context.l10n.receiveQrFailedError, tokens)
                : RepaintBoundary(
                    child: PrettyQrView(
                      qrImage: qrImage,
                      decoration: qrDecoration,
                    ),
                  ),
          ),
        ),
        if (qrImage != null && qrDecoration != null) ...<Widget>[
          SizedBox(height: tokens.receiveFieldGap),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: tokens.receiveMicroGap,
            runSpacing: tokens.receiveMicroGap,
            children: <Widget>[
              TextButton.icon(
                // Preserve the existing capture key for this image action.
                key: const Key('receive_share_image'),
                style: actionStyle,
                onPressed: _exporting || !widget.enabled
                    ? null
                    : () => unawaited(
                        _export(
                          image: qrImage,
                          decoration: qrDecoration,
                          action: (Uint8List bytes, _) => copyImage(bytes),
                        ),
                      ),
                icon: ShellSymbol('copy', size: tokens.inlineGlyphSize),
                label: Text(context.l10n.receiveCopyImage),
              ),
              TextButton.icon(
                key: const Key('receive_save_image'),
                style: actionStyle,
                onPressed: _exporting || !widget.enabled
                    ? null
                    : () => unawaited(
                        _export(
                          image: qrImage,
                          decoration: qrDecoration,
                          action: (Uint8List bytes, bool Function() current) =>
                              saveImage?.call(bytes) ??
                              _saveImage(bytes, current),
                        ),
                      ),
                icon: ShellSymbol('dl', size: tokens.inlineGlyphSize),
                label: Text(context.l10n.commonSave),
              ),
            ],
          ),
        ],
        if (_exportFailed) ...<Widget>[
          SizedBox(height: tokens.receiveMicroGap),
          _buildError(context.l10n.receiveExportFailed, tokens),
        ],
      ],
    );
  }

  Widget _buildError(String message, AppTokens tokens) => Semantics(
    liveRegion: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(Icons.error_outline_rounded, color: tokens.error),
        SizedBox(height: tokens.receiveMicroGap),
        Text(
          message,
          textAlign: TextAlign.center,
          style: tokens.captionText.copyWith(color: tokens.error),
        ),
      ],
    ),
  );

  Future<void> _export({
    required QrImage image,
    required PrettyQrDecoration decoration,
    required Future<void> Function(Uint8List, bool Function()) action,
  }) async {
    final bool Function()? isCurrent = widget.isRequestCurrent;
    if (_exporting || !widget.enabled || !(isCurrent?.call() ?? true)) return;
    final int attempt = ++_attempt;
    bool current() =>
        mounted &&
        widget.enabled &&
        attempt == _attempt &&
        (isCurrent?.call() ?? true);
    setState(() {
      _exporting = true;
      _exportFailed = false;
    });
    try {
      // A saved or pasted PNG has no themed surface behind it.
      final PrettyQrDecoration exportDecoration = decoration.copyWith(
        background: AppColors.lightCard2,
        shape: const PrettyQrSmoothSymbol(
          color: AppColors.foregroundLight,
          roundFactor: 0,
        ),
        quietZone: PrettyQrQuietZone.standard,
      );
      final Uint8List? bytes = await (widget.encodeImage ?? _encodeImage)(
        image,
        exportDecoration,
        widget.size.toInt(),
      );
      if (!current()) return;
      if (bytes == null || bytes.isEmpty) {
        setState(() => _exportFailed = true);
        return;
      }
      await action(bytes, current);
    } on Object catch (_) {
      if (mounted && attempt == _attempt && (isCurrent?.call() ?? true)) {
        setState(() => _exportFailed = true);
      }
    } finally {
      if (mounted && attempt == _attempt) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<Uint8List?> _encodeImage(
    QrImage image,
    PrettyQrDecoration decoration,
    int size,
  ) async {
    final ui.Image raster = await image.toImage(
      size: size,
      decoration: decoration,
      configuration: createLocalImageConfiguration(context),
    );
    try {
      final ByteData? data = await raster.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return data?.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      raster.dispose();
    }
  }

  static Future<void> _saveImage(
    Uint8List bytes,
    bool Function() current,
  ) async {
    final FileSaveLocation? location = await getSaveLocation(
      suggestedName: 'syrius-receive.png',
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(
          label: 'PNG',
          extensions: <String>['png'],
          mimeTypes: <String>['image/png'],
          uniformTypeIdentifiers: <String>['public.png'],
        ),
      ],
    );
    if (location == null || !current()) return;
    await File(location.path).writeAsBytes(bytes, flush: true);
  }

  static Future<void> _copyImage(Uint8List bytes) async {
    if (Platform.isWindows && defaultTargetPlatform == TargetPlatform.windows) {
      writeWindowsClipboardImage(bytes);
      return;
    }
    await _imageClipboard.invokeMethod<void>('writePng', bytes);
  }
}
