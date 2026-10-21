import 'dart:io';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/app_lottie.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class ReceiveQrImage extends StatelessWidget {
  const ReceiveQrImage({
    required String data,
    required double size,
    required TokenStandard tokenStandard,
    super.key,
  })  : _data = data,
        _size = size,
        _tokenStandard = tokenStandard;

  final String _data;
  final double _size;
  final TokenStandard _tokenStandard;

  // The last code made, kept: the card rebuilds on every keystroke in the
  // form beside it and on every visit to the page, and laying out the
  // modules again each time took about 5 ms of each of those frames.
  static String? _lastData;
  static QrImage? _lastImage;

  static QrImage _imageFor(String data) {
    if (_lastData == data && _lastImage != null) return _lastImage!;
    final QrImage image = QrImage(
      QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M),
    );
    _lastData = data;
    _lastImage = image;
    return image;
  }

  PrettyQrDecorationImage get _decorationImage => PrettyQrDecorationImage(
        colorFilter: ColorFilter.mode(
          ColorUtils.getTokenColor(_tokenStandard),
          BlendMode.srcIn,
        ),
        image: const AssetImage(
          'assets/images/qr_code_child_image_znn_cut.png',
        ),
        fit: BoxFit.contain,
      );

  @override
  Widget build(BuildContext context) {
    late Widget qrWidget;
    PrettyQrDecoration? qrDecoration;
    QrImage? qrImage;

    // onSurface is a color that ensures a strong contrast
    final Color qrCodeColor = Theme.of(context).colorScheme.onSurface;

    try {
      qrImage = _imageFor(_data);

      qrDecoration = PrettyQrDecoration(
        shape: PrettyQrSmoothSymbol(
          color: qrCodeColor,
          roundFactor: 0,
        ),
        image: _decorationImage,
      );

      qrWidget = RepaintBoundary(
        child: PrettyQrView(
          qrImage: qrImage,
          decoration: qrDecoration,
        ),
      );
    } on Exception catch (e) {
      qrWidget = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const AppLottie(AppLottieAsset.noData, size: 32),
          Tooltip(
            message: e.toString(),
            child: Text(
              context.l10n.receiveQrFailedError,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );
    }

    return Column(
      children: <Widget>[
        Tooltip(
          message: _data,
          child: SizedBox.square(
            dimension: _size,
            child: qrWidget,
          ),
        ),
        kVerticalGap16,
        if (qrDecoration != null && qrImage != null)
          Row(
            children: <Widget>[
              IconButton(
                tooltip: context.l10n.shareQr,
                onPressed: () => _shareQR(
                  qrDecoration: qrDecoration!,
                  qrImage: qrImage!,
                ),
                icon: const Icon(
                  Icons.share_rounded,
                  color: AppColors.znnColor,
                ),
              ),
              kHorizontalGap16,
              IconButton(
                tooltip: context.l10n.saveQr,
                onPressed: () => _saveQR(
                  qrDecoration: qrDecoration!,
                  qrImage: qrImage!,
                ),
                icon: const Icon(
                  Icons.save_alt_rounded,
                  color: AppColors.znnColor,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<Uint8List?> _getQRImageData({
    required PrettyQrDecoration qrDecoration,
    required QrImage qrImage,
  }) async {
    final ByteData? b = await qrImage.toImageAsBytes(
      size: _size.toInt(),
      decoration: qrDecoration,
    );

    if (b != null) return b.buffer.asUint8List();
    return null;
  }

  Future<void> _saveQR({
    required PrettyQrDecoration qrDecoration,
    required QrImage qrImage,
  }) async {
    final Uint8List? imageData = await _getQRImageData(
      qrDecoration: qrDecoration,
      qrImage: qrImage,
    );
    if (imageData != null) {
      final String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final File imagePath = await File(
        '${znnDefaultPaths.cache.path}${path.separator}$fileName.png',
      ).create();
      await imagePath.writeAsBytes(imageData);
      await OpenFilex.open(imagePath.path);
    }
  }

  Future<void> _shareQR({
    required PrettyQrDecoration qrDecoration,
    required QrImage qrImage,
  }) async {
    final Uint8List? imageData = await _getQRImageData(
      qrDecoration: qrDecoration,
      qrImage: qrImage,
    );
    if (imageData != null) {
      final String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final File imagePath = await File(
        '${znnDefaultPaths.cache.path}${path.separator}$fileName.png',
      ).create();
      await imagePath.writeAsBytes(imageData);
      await Share.shareXFiles(<XFile>[XFile(imagePath.path)]);
    }
  }
}
