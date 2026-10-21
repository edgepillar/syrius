import 'dart:io';

import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';

class FileUtils {
  static Future<void> deleteFile(String path) async {
    try {
      final File file = File(path);
      if (file.existsSync()) {
        await file.delete();
      } else {
        throw currentL10n.fileDeleteNoFileError(path);
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> deleteDirectory(String path) async {
    try {
      final Directory directory = Directory(path);
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      } else {
        throw currentL10n.fileDeleteNoDirectoryError(path);
      }
    } catch (e) {
      rethrow;
    }
  }
}
