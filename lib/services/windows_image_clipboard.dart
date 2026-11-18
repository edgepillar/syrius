import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as image;
import 'package:win32/win32.dart';

const int _bitmapHeaderSize = 124;
const int _maximumQrDimension = 1024;
const int _maximumQrPngBytes = 1024 * 1024;
const int _srgbColorSpace = 0x73524742; // LCS_sRGB
const int _imageColorIntent = 4; // LCS_GM_IMAGES

/// Encodes the generated QR as a top-down 32-bit Windows clipboard bitmap.
Uint8List encodeWindowsClipboardBitmap(Uint8List png) {
  if (png.length > _maximumQrPngBytes) {
    throw const FormatException('Clipboard PNG is too large');
  }
  final image.PngDecoder decoder = image.PngDecoder();
  final image.DecodeInfo? info = decoder.startDecode(png);
  if (info == null ||
      info.width <= 0 ||
      info.height <= 0 ||
      info.width > _maximumQrDimension ||
      info.height > _maximumQrDimension) {
    throw const FormatException('Invalid clipboard PNG dimensions');
  }
  final image.Image? bitmap = decoder.decodeFrame(0);
  if (bitmap == null) throw const FormatException('Invalid clipboard PNG');
  final Uint8List pixels = bitmap
      .convert(format: image.Format.uint8, numChannels: 4)
      .getBytes(order: image.ChannelOrder.bgra);
  // BITMAPV5HEADER layout followed by tightly packed BGRA pixels.
  final ByteData dib = ByteData(_bitmapHeaderSize + pixels.length)
    ..setUint32(0, _bitmapHeaderSize, Endian.little)
    ..setInt32(4, bitmap.width, Endian.little)
    ..setInt32(8, -bitmap.height, Endian.little)
    ..setUint16(12, 1, Endian.little)
    ..setUint16(14, 32, Endian.little)
    ..setUint32(16, BI_BITFIELDS, Endian.little)
    ..setUint32(20, pixels.length, Endian.little)
    ..setUint32(40, 0x00ff0000, Endian.little)
    ..setUint32(44, 0x0000ff00, Endian.little)
    ..setUint32(48, 0x000000ff, Endian.little)
    ..setUint32(52, 0xff000000, Endian.little)
    ..setUint32(56, _srgbColorSpace, Endian.little)
    ..setUint32(108, _imageColorIntent, Endian.little);
  return dib.buffer.asUint8List()
    ..setRange(_bitmapHeaderSize, dib.lengthInBytes, pixels);
}

/// Copies the generated PNG to the foreground Syrius window's clipboard.
void writeWindowsClipboardImage(Uint8List png) {
  final Uint8List bitmap = encodeWindowsClipboardBitmap(png);
  final int window = GetForegroundWindow();
  final Pointer<Uint32> windowProcess = calloc<Uint32>();
  try {
    // The Flutter isolate may run on a different thread from the window.
    if (window == 0 ||
        GetWindowThreadProcessId(window, windowProcess) == 0 ||
        windowProcess.value != GetCurrentProcessId()) {
      throw StateError('No foreground application window');
    }
  } finally {
    calloc.free(windowProcess);
  }

  final Pointer<Void> memory = GlobalAlloc(GMEM_MOVEABLE, bitmap.length).cast();
  if (memory == nullptr) throw StateError('Could not allocate clipboard image');
  bool transferred = false;
  try {
    final Pointer<Uint8> pixels = GlobalLock(memory).cast();
    if (pixels == nullptr) throw StateError('Could not lock clipboard image');
    try {
      pixels.asTypedList(bitmap.length).setAll(0, bitmap);
    } finally {
      GlobalUnlock(memory);
    }

    if (OpenClipboard(window) == 0) {
      throw StateError('Could not open clipboard');
    }
    try {
      if (EmptyClipboard() == 0 ||
          SetClipboardData(CF_DIBV5, memory.address) == 0) {
        throw StateError('Could not write clipboard image');
      }
      transferred = true;
    } finally {
      CloseClipboard();
    }
  } finally {
    if (!transferred) GlobalFree(memory);
  }
}
