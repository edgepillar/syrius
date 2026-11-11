import 'dart:convert';

import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/latest_transactions/model/activity_entry.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// A preview cannot supply or replace its original selected-address history.
class ActivityMessagePreviewRefused implements Exception {
  /// Supplies no raw history, wallet or owner diagnostic.
  const ActivityMessagePreviewRefused();
}

/// Attaches explicit presentation metadata to one existing history block.
/// No block, message, receipt or financial operation is manufactured.
final class ActivityMessagePreview {
  ActivityMessagePreview._(
    this._source, this._readSource, this._readBlocks, this._requireOwner,
    this._block, this._original, this.entry,
  );

  /// Selects one existing block without changing the source or its data.
  factory ActivityMessagePreview.capture({
    required Object source,
    required Object Function() readSource,
    required List<AccountBlock> Function() readBlocks,
    required void Function() requireOwner,
    required String owner,
  }) {
    requireOwner();
    if (!identical(source, readSource())) {
      throw const ActivityMessagePreviewRefused();
    }
    final List<AccountBlock> blocks = readBlocks();
    if (blocks.length > 512) throw const ActivityMessagePreviewRefused();
    final List<AccountBlock> eligible = blocks.where((AccountBlock block) =>
      block.chainIdentifier == 321 && block.address.toString() == owner &&
      block.height > 0 && RegExp(r'^[0-9a-f]{64}$')
          .hasMatch(block.hash.toString()) && block.hash != emptyHash,
    ).toList();
    if (eligible.isEmpty) throw const ActivityMessagePreviewRefused();
    final AccountBlock block = eligible.first;
    if (blocks.where((AccountBlock item) => item.hash == block.hash).length !=
        1) {
      throw const ActivityMessagePreviewRefused();
    }
    final ActivityMessagePreview preview = ActivityMessagePreview._(
      source, readSource, readBlocks, requireOwner, block,
      jsonEncode(block.toJson()), ActivityEntry.fromBlock(block,
        zapPreview: const ActivityZapPreview()),
    )..requireCurrent();
    return preview;
  }

  final Object _source;
  final Object Function() _readSource;
  final List<AccountBlock> Function() _readBlocks;
  final void Function() _requireOwner;
  final AccountBlock _block;
  final String _original;
  bool _held = false;

  /// Retains the exact original hash and movement with explicit preview kind.
  final ActivityEntry entry;

  /// Source or data loss holds this preview even if later restored.
  void requireCurrent() {
    if (_held) throw const ActivityMessagePreviewRefused();
    try {
      _requireOwner();
      final List<AccountBlock> blocks = _readBlocks();
      if (!identical(_source, _readSource()) || blocks.length > 512 ||
          blocks.where((AccountBlock item) => item.hash == _block.hash)
              .length != 1 ||
          !blocks.any((AccountBlock item) => identical(item, _block)) ||
          jsonEncode(_block.toJson()) != _original) {
        throw const ActivityMessagePreviewRefused();
      }
      _requireOwner();
    } on Object {
      _held = true;
      rethrow;
    }
  }
}
