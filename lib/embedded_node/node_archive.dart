/// Reads one member out of a `.zip` or a `.tar.gz`, for the node updater.
///
/// Written out here because `package:archive` is only a transitive
/// dependency, which this package may not import. It is the minimum the
/// release archives need: a zip whose member is stored or deflated, and a
/// gzipped ustar with pax and GNU long names.
///
/// The archive is hostile until proven otherwise, so the reader never writes
/// to a path taken from it. The caller names the output file; the archive
/// only decides whether it holds exactly one member of an expected name.
/// A member is matched by the last component of its path, an archive with a
/// path that climbs out (`..`, a leading `/`, a drive letter) anywhere in it
/// is refused whole, and the extracted size is capped while it is written.
///
/// Everything is synchronous `dart:io`: call it from a worker isolate.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:zenon_syrius_wallet_flutter/embedded_node/node_library.dart'
    show Sha256;

/// The two containers go-zenon publishes the library in.
enum NodeArchiveFormat {
  zip,
  tarGz;

  /// By the file's name: `.zip`, `.tar.gz` or `.tgz`. Null for anything
  /// else.
  static NodeArchiveFormat? ofFileName(String name) {
    final String lower = name.toLowerCase();
    if (lower.endsWith('.zip')) {
      return NodeArchiveFormat.zip;
    }
    if (lower.endsWith('.tar.gz') || lower.endsWith('.tgz')) {
      return NodeArchiveFormat.tarGz;
    }
    return null;
  }
}

/// Why an archive was refused.
enum NodeArchiveProblem {
  /// No regular file of an expected name.
  memberMissing,

  /// More than one entry of an expected name.
  memberDuplicated,

  /// An entry's path is absolute or has a `..` component.
  unsafePath,

  /// Not a readable archive of its format, truncated, or failing a checksum.
  corrupt,

  /// A feature this reader does not implement: zip64, encryption, a
  /// compression method other than stored or deflate, a split archive.
  unsupported,

  /// The member, or the unpacked archive, is over the size cap.
  tooLarge,
}

class NodeArchiveException implements Exception {
  NodeArchiveException(this.problem, this.detail);

  final NodeArchiveProblem problem;

  /// For the log. Not for the user.
  final String detail;

  @override
  String toString() => 'NodeArchiveException: ${problem.name}, $detail';
}

/// What [NodeArchive.extractMember] wrote.
class NodeArchiveMember {
  NodeArchiveMember({
    required this.name,
    required this.sha256,
    required this.size,
  });

  /// The last component of the member's path in the archive.
  final String name;

  /// Lower-case hex, of the extracted bytes.
  final String sha256;
  final int size;
}

abstract final class NodeArchive {
  /// Writes the one member of [archivePath] whose file name is in
  /// [memberNames] to [outputPath], and returns its sha256 and size.
  ///
  /// Throws [NodeArchiveException] when there is not exactly one such
  /// member, when any path in the archive is unsafe, when the member is
  /// empty or larger than [maxBytes], and when the archive cannot be read.
  /// [outputPath] may be left half-written then: deleting it is the
  /// caller's job. A [FileSystemException] passes through.
  static NodeArchiveMember extractMember({
    required String archivePath,
    required NodeArchiveFormat format,
    required List<String> memberNames,
    required String outputPath,
    required int maxBytes,
  }) {
    final RandomAccessFile archive = File(archivePath).openSync();
    try {
      final RandomAccessFile output =
          File(outputPath).openSync(mode: FileMode.write);
      try {
        final _MemberSink sink = _MemberSink(
          output,
          maxBytes,
          withCrc: format == NodeArchiveFormat.zip,
        );
        final String name = switch (format) {
          NodeArchiveFormat.zip => _extractZip(archive, memberNames, sink),
          NodeArchiveFormat.tarGz =>
            _extractTarGz(archive, memberNames, sink, maxBytes),
        };
        if (sink.size == 0) {
          throw NodeArchiveException(
            NodeArchiveProblem.corrupt,
            '$name is empty',
          );
        }
        output.flushSync();
        return NodeArchiveMember(
          name: name,
          sha256: sink.sha256(),
          size: sink.size,
        );
      } finally {
        output.closeSync();
      }
    } finally {
      archive.closeSync();
    }
  }

  /// The components of an entry's path, or null when it is one no release
  /// archive holds: empty, absolute, on a drive, or climbing with `..`.
  ///
  /// A backslash counts as a separator, as it would on Windows.
  static List<String>? safeComponents(String entryName) {
    final String normal = entryName.replaceAll(r'\', '/');
    if (normal.isEmpty ||
        normal.startsWith('/') ||
        normal.contains('\u0000') ||
        _drive.hasMatch(normal)) {
      return null;
    }
    final List<String> parts = normal
        .split('/')
        .where((String part) => part.isNotEmpty && part != '.')
        .toList();
    return parts.contains('..') ? null : parts;
  }

  static final RegExp _drive = RegExp('^[A-Za-z]:');

  static const int _chunkSize = 1 << 16;

  // The pax and long-name records that rename the next entry are tiny.
  static const int _maxMetaBytes = 1 << 20;

  // 65535 entries with long names fit several times over.
  static const int _maxCentralDirectoryBytes = 16 << 20;

  static Never _fail(NodeArchiveProblem problem, String detail) =>
      throw NodeArchiveException(problem, detail);

  // ---------------------------------------------------------------- zip --

  static const int _endOfCentralDirectory = 0x06054b50;
  static const int _centralHeader = 0x02014b50;
  static const int _localHeader = 0x04034b50;

  static String _extractZip(
    RandomAccessFile file,
    List<String> memberNames,
    _MemberSink sink,
  ) {
    final int length = file.lengthSync();
    if (length < 22) {
      _fail(NodeArchiveProblem.corrupt, 'too short for a zip');
    }

    // The end record is the last thing in the file, before a comment of at
    // most 65535 bytes. Only a record whose comment ends the file counts,
    // so there is one reading of the archive and not two.
    final int tailLength = length < 22 + 0xFFFF ? length : 22 + 0xFFFF;
    final int tailStart = length - tailLength;
    file.setPositionSync(tailStart);
    final Uint8List tail = _readExactly(file, tailLength);
    final ByteData tailData = ByteData.sublistView(tail);
    int end = -1;
    for (int i = tail.length - 22; i >= 0; i--) {
      if (tailData.getUint32(i, Endian.little) == _endOfCentralDirectory &&
          i + 22 + tailData.getUint16(i + 20, Endian.little) == tail.length) {
        end = i;
        break;
      }
    }
    if (end < 0) {
      _fail(NodeArchiveProblem.corrupt, 'no end of central directory');
    }
    final int entryCount = tailData.getUint16(end + 10, Endian.little);
    final int directorySize = tailData.getUint32(end + 12, Endian.little);
    final int directoryOffset = tailData.getUint32(end + 16, Endian.little);
    if (tailData.getUint16(end + 4, Endian.little) != 0 ||
        tailData.getUint16(end + 6, Endian.little) != 0 ||
        tailData.getUint16(end + 8, Endian.little) != entryCount) {
      _fail(NodeArchiveProblem.unsupported, 'a split zip');
    }
    if (entryCount == 0xFFFF ||
        directorySize == 0xFFFFFFFF ||
        directoryOffset == 0xFFFFFFFF) {
      _fail(NodeArchiveProblem.unsupported, 'zip64');
    }
    if (directorySize > _maxCentralDirectoryBytes) {
      _fail(NodeArchiveProblem.unsupported, 'a central directory too large');
    }
    if (directoryOffset + directorySize > tailStart + end) {
      _fail(NodeArchiveProblem.corrupt, 'the central directory overruns');
    }

    file.setPositionSync(directoryOffset);
    final Uint8List directory = _readExactly(file, directorySize);
    final ByteData data = ByteData.sublistView(directory);
    _ZipEntry? member;
    int matches = 0;
    int position = 0;
    for (int i = 0; i < entryCount; i++) {
      if (position + 46 > directory.length ||
          data.getUint32(position, Endian.little) != _centralHeader) {
        _fail(NodeArchiveProblem.corrupt, 'a bad central directory entry');
      }
      final int nameLength = data.getUint16(position + 28, Endian.little);
      final int next = position +
          46 +
          nameLength +
          data.getUint16(position + 30, Endian.little) +
          data.getUint16(position + 32, Endian.little);
      if (next > directory.length) {
        _fail(NodeArchiveProblem.corrupt, 'a central directory entry overruns');
      }
      final Uint8List rawName = Uint8List.sublistView(
        directory,
        position + 46,
        position + 46 + nameLength,
      );
      final String name = utf8.decode(rawName, allowMalformed: true);
      final List<String>? parts = safeComponents(name);
      if (parts == null) {
        _fail(NodeArchiveProblem.unsafePath, 'the entry "$name"');
      }
      if (parts.isNotEmpty && memberNames.contains(parts.last)) {
        matches++;
        member = _ZipEntry(
          name: parts.last,
          rawName: rawName,
          isDirectory: name.endsWith('/') || name.endsWith(r'\'),
          flags: data.getUint16(position + 8, Endian.little),
          method: data.getUint16(position + 10, Endian.little),
          crc32: data.getUint32(position + 16, Endian.little),
          compressedSize: data.getUint32(position + 20, Endian.little),
          size: data.getUint32(position + 24, Endian.little),
          localOffset: data.getUint32(position + 42, Endian.little),
        );
      }
      position = next;
    }
    if (matches > 1) {
      _fail(NodeArchiveProblem.memberDuplicated, '$matches entries match');
    }
    if (member == null || member.isDirectory) {
      _fail(NodeArchiveProblem.memberMissing, 'no file named $memberNames');
    }
    if (member.flags & 1 != 0) {
      _fail(NodeArchiveProblem.unsupported, 'an encrypted member');
    }
    if (member.method != 0 && member.method != 8) {
      _fail(
        NodeArchiveProblem.unsupported,
        'compression method ${member.method}',
      );
    }
    if (member.size == 0xFFFFFFFF || member.compressedSize == 0xFFFFFFFF) {
      _fail(NodeArchiveProblem.unsupported, 'a zip64 member');
    }
    if (member.size > sink.maxBytes) {
      _fail(NodeArchiveProblem.tooLarge, 'the member is ${member.size} bytes');
    }

    // The sizes and the checksum come from the central directory: the local
    // header may leave them to a trailing descriptor. The name must be the
    // same in both, or the directory describes some other entry's bytes.
    if (member.localOffset + 30 > length) {
      _fail(NodeArchiveProblem.corrupt, 'the local header overruns');
    }
    file.setPositionSync(member.localOffset);
    final Uint8List local = _readExactly(file, 30);
    final ByteData localData = ByteData.sublistView(local);
    if (localData.getUint32(0, Endian.little) != _localHeader) {
      _fail(NodeArchiveProblem.corrupt, 'no local header');
    }
    final int localNameLength = localData.getUint16(26, Endian.little);
    final int dataStart = member.localOffset +
        30 +
        localNameLength +
        localData.getUint16(28, Endian.little);
    if (dataStart + member.compressedSize > length) {
      _fail(NodeArchiveProblem.corrupt, 'the member overruns');
    }
    if (!_sameBytes(_readExactly(file, localNameLength), member.rawName)) {
      _fail(NodeArchiveProblem.corrupt, 'the local header names another file');
    }

    file.setPositionSync(dataStart);
    final Sink<List<int>> input = member.method == 0
        ? sink
        : ZLibDecoder(raw: true).startChunkedConversion(sink);
    try {
      int remaining = member.compressedSize;
      while (remaining > 0) {
        final Uint8List chunk = _readExactly(
          file,
          remaining < _chunkSize ? remaining : _chunkSize,
        );
        input.add(chunk);
        remaining -= chunk.length;
      }
      input.close();
    } on FormatException catch (e) {
      _fail(NodeArchiveProblem.corrupt, 'bad deflate data: ${e.message}');
    }
    if (sink.size != member.size) {
      _fail(
        NodeArchiveProblem.corrupt,
        'the member is ${sink.size} bytes, not the ${member.size} declared',
      );
    }
    if (sink.crc32() != member.crc32) {
      _fail(NodeArchiveProblem.corrupt, 'the member fails its CRC-32');
    }
    return member.name;
  }

  static Uint8List _readExactly(RandomAccessFile file, int count) {
    final Uint8List bytes = file.readSync(count);
    if (bytes.length != count) {
      _fail(NodeArchiveProblem.corrupt, 'the file ends early');
    }
    return bytes;
  }

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  // ------------------------------------------------------------- tar.gz --

  static String _extractTarGz(
    RandomAccessFile file,
    List<String> memberNames,
    _MemberSink sink,
    int maxBytes,
  ) {
    final _TarReader reader = _TarReader(memberNames, sink, maxBytes * 2);
    final Sink<List<int>> input = gzip.decoder.startChunkedConversion(reader);
    try {
      while (true) {
        // A fresh buffer each time: the decoder may keep what it is given.
        final Uint8List chunk = file.readSync(_chunkSize);
        if (chunk.isEmpty) {
          break;
        }
        input.add(chunk);
      }
      input.close();
    } on FormatException catch (e) {
      _fail(NodeArchiveProblem.corrupt, 'bad gzip data: ${e.message}');
    }
    return reader.finish();
  }
}

class _ZipEntry {
  _ZipEntry({
    required this.name,
    required this.rawName,
    required this.isDirectory,
    required this.flags,
    required this.method,
    required this.crc32,
    required this.compressedSize,
    required this.size,
    required this.localOffset,
  });

  final String name;
  final Uint8List rawName;
  final bool isDirectory;
  final int flags;
  final int method;
  final int crc32;
  final int compressedSize;
  final int size;
  final int localOffset;
}

/// Hashes, counts and writes the member as it is unpacked, and stops the
/// unpacking at the cap: a deflate stream can claim one size and hold
/// another.
class _MemberSink implements Sink<List<int>> {
  _MemberSink(this._file, this.maxBytes, {required this.withCrc});

  final RandomAccessFile _file;
  final int maxBytes;

  /// Only a zip has a CRC-32 to hold the member to.
  final bool withCrc;
  final Sha256 _hash = Sha256();
  int size = 0;
  int _crc = 0xFFFFFFFF;

  static final Uint32List _crcTable = _makeCrcTable();

  static Uint32List _makeCrcTable() {
    final Uint32List table = Uint32List(256);
    for (int n = 0; n < 256; n++) {
      int c = n;
      for (int k = 0; k < 8; k++) {
        c = c & 1 != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
      }
      table[n] = c;
    }
    return table;
  }

  @override
  void add(List<int> data) {
    size += data.length;
    if (size > maxBytes) {
      throw NodeArchiveException(
        NodeArchiveProblem.tooLarge,
        'the member is over $maxBytes bytes',
      );
    }
    final Uint8List bytes = data is Uint8List ? data : Uint8List.fromList(data);
    _hash.add(bytes);
    if (withCrc) {
      final Uint32List table = _crcTable;
      int crc = _crc;
      for (int i = 0; i < bytes.length; i++) {
        crc = table[(crc ^ bytes[i]) & 0xFF] ^ (crc >> 8);
      }
      _crc = crc;
    }
    _file.writeFromSync(bytes);
  }

  /// The decoders close their output; the file is the caller's to close.
  @override
  void close() {}

  String sha256() => _hash.close();

  int crc32() => _crc ^ 0xFFFFFFFF;
}

enum _TarMode { skip, member, pax, longName }

/// A ustar stream, fed in pieces of any size.
///
/// Reads the header blocks, follows a pax `path` or `size` record and a GNU
/// long name to the entry they describe, hands the one member's bytes to
/// the sink and skips everything else. Stops at the first zero block, which
/// is where every other tar stops too.
class _TarReader implements Sink<List<int>> {
  _TarReader(this._memberNames, this._sink, this._maxTotal);

  final List<String> _memberNames;
  final _MemberSink _sink;

  /// The cap on the unpacked archive, member and all: what a gzip bomb
  /// would otherwise make this reader chew through.
  final int _maxTotal;

  final Uint8List _header = Uint8List(512);
  int _headerFill = 0;
  int _remaining = 0;
  int _padding = 0;
  _TarMode _mode = _TarMode.skip;
  BytesBuilder _meta = BytesBuilder(copy: false);
  String? _nextPath;
  int? _nextSize;
  int _total = 0;
  int _headers = 0;
  int _matches = 0;
  String? _memberName;
  bool _memberDone = false;
  bool _ended = false;

  @override
  void add(List<int> data) {
    _total += data.length;
    if (_total > _maxTotal) {
      NodeArchive._fail(
        NodeArchiveProblem.tooLarge,
        'the archive unpacks to more than $_maxTotal bytes',
      );
    }
    final Uint8List bytes = data is Uint8List ? data : Uint8List.fromList(data);
    int offset = 0;
    while (offset < bytes.length && !_ended) {
      final int available = bytes.length - offset;
      if (_remaining > 0) {
        final int take = _remaining < available ? _remaining : available;
        final Uint8List piece =
            Uint8List.sublistView(bytes, offset, offset + take);
        switch (_mode) {
          case _TarMode.member:
            _sink.add(piece);
          case _TarMode.pax:
          case _TarMode.longName:
            _meta.add(Uint8List.fromList(piece));
          case _TarMode.skip:
            break;
        }
        _remaining -= take;
        offset += take;
        if (_remaining == 0) {
          _finishEntry();
        }
      } else if (_padding > 0) {
        final int take = _padding < available ? _padding : available;
        _padding -= take;
        offset += take;
      } else {
        final int take =
            512 - _headerFill < available ? 512 - _headerFill : available;
        _header.setRange(_headerFill, _headerFill + take, bytes, offset);
        _headerFill += take;
        offset += take;
        if (_headerFill == 512) {
          _headerFill = 0;
          _readHeader();
        }
      }
    }
  }

  @override
  void close() {}

  /// The member's file name, once the whole stream has been fed.
  String finish() {
    if (_headers == 0 && !_ended) {
      NodeArchive._fail(NodeArchiveProblem.corrupt, 'not a tar archive');
    }
    if (!_ended && (_remaining > 0 || _headerFill > 0)) {
      NodeArchive._fail(NodeArchiveProblem.corrupt, 'the archive ends early');
    }
    final String? name = _memberName;
    if (_matches == 0 || !_memberDone || name == null) {
      NodeArchive._fail(
        NodeArchiveProblem.memberMissing,
        'no file named $_memberNames',
      );
    }
    return name;
  }

  void _readHeader() {
    final Uint8List header = _header;
    if (header.every((int byte) => byte == 0)) {
      _ended = true;
      return;
    }
    _headers++;

    int sum = 0;
    for (int i = 0; i < 512; i++) {
      sum += i >= 148 && i < 156 ? 0x20 : header[i];
    }
    if (_octal(148, 8) != sum) {
      NodeArchive._fail(NodeArchiveProblem.corrupt, 'a bad tar header');
    }

    final int type = header[156];
    int size = _octal(124, 12);
    switch (type) {
      case 0x78: // 'x': pax records for the next entry.
        _startMeta(_TarMode.pax, size);
        return;
      case 0x4C: // 'L': a GNU long name for the next entry.
        _startMeta(_TarMode.longName, size);
        return;
      case 0x67: // 'g': pax records for the whole archive. Nothing we use.
      case 0x4B: // 'K': a GNU long link target.
        _start(_TarMode.skip, size);
        return;
    }

    String name = _text(0, 100);
    // Only the POSIX magic has a prefix; GNU keeps timestamps there.
    if (_text(257, 6) == 'ustar') {
      final String prefix = _text(345, 155);
      if (prefix.isNotEmpty) {
        name = '$prefix/$name';
      }
    }
    name = _nextPath ?? name;
    size = _nextSize ?? size;
    _nextPath = null;
    _nextSize = null;

    final List<String>? parts = NodeArchive.safeComponents(name);
    if (parts == null) {
      NodeArchive._fail(NodeArchiveProblem.unsafePath, 'the entry "$name"');
    }
    // '0', NUL and '7' are files. Links, devices, directories and FIFOs
    // ('1' to '6') carry no data, whatever their size field says.
    final bool isFile = type == 0x30 || type == 0 || type == 0x37;
    if (type >= 0x31 && type <= 0x36) {
      size = 0;
    }
    if (parts.isNotEmpty && _memberNames.contains(parts.last)) {
      _matches++;
      if (_matches > 1) {
        NodeArchive._fail(
          NodeArchiveProblem.memberDuplicated,
          'a second entry named ${parts.last}',
        );
      }
      if (isFile && !name.endsWith('/')) {
        if (size > _sink.maxBytes) {
          NodeArchive._fail(
            NodeArchiveProblem.tooLarge,
            'the member is $size bytes',
          );
        }
        _memberName = parts.last;
        _start(_TarMode.member, size);
        return;
      }
    }
    _start(_TarMode.skip, size);
  }

  void _startMeta(_TarMode mode, int size) {
    if (size > NodeArchive._maxMetaBytes) {
      NodeArchive._fail(
        NodeArchiveProblem.unsupported,
        'an extended header of $size bytes',
      );
    }
    _meta = BytesBuilder(copy: false);
    _start(mode, size);
  }

  void _start(_TarMode mode, int size) {
    _mode = mode;
    _remaining = size;
    _padding = (512 - size % 512) % 512;
    if (size == 0) {
      _finishEntry();
    }
  }

  void _finishEntry() {
    switch (_mode) {
      case _TarMode.member:
        _memberDone = true;
      case _TarMode.longName:
        final Uint8List bytes = _meta.takeBytes();
        final int end = bytes.indexOf(0);
        _nextPath = utf8.decode(
          end < 0 ? bytes : Uint8List.sublistView(bytes, 0, end),
          allowMalformed: true,
        );
      case _TarMode.pax:
        _readPax(_meta.takeBytes());
      case _TarMode.skip:
        break;
    }
    _mode = _TarMode.skip;
  }

  /// Records of the form `<length> <key>=<value>\n`, the length counting
  /// the whole record.
  void _readPax(Uint8List bytes) {
    int position = 0;
    while (position < bytes.length) {
      final int space = bytes.indexOf(0x20, position);
      final int? length = space < 0
          ? null
          : int.tryParse(ascii.decode(
              Uint8List.sublistView(bytes, position, space),
              allowInvalid: true,
            ));
      if (length == null ||
          length <= space - position + 1 ||
          position + length > bytes.length ||
          bytes[position + length - 1] != 0x0A) {
        NodeArchive._fail(NodeArchiveProblem.corrupt, 'a bad pax record');
      }
      final String record = utf8.decode(
        Uint8List.sublistView(bytes, space + 1, position + length - 1),
        allowMalformed: true,
      );
      final int equals = record.indexOf('=');
      if (equals < 0) {
        NodeArchive._fail(NodeArchiveProblem.corrupt, 'a bad pax record');
      }
      final String value = record.substring(equals + 1);
      switch (record.substring(0, equals)) {
        case 'path':
          _nextPath = value;
        case 'size':
          final int? size = int.tryParse(value);
          if (size == null || size < 0) {
            NodeArchive._fail(NodeArchiveProblem.corrupt, 'a bad pax size');
          }
          _nextSize = size;
      }
      position += length;
    }
  }

  String _text(int start, int length) {
    int end = start;
    while (end < start + length && _header[end] != 0) {
      end++;
    }
    return utf8.decode(
      Uint8List.sublistView(_header, start, end),
      allowMalformed: true,
    );
  }

  int _octal(int start, int length) {
    if (_header[start] & 0x80 != 0) {
      // GNU's binary form, for numbers octal cannot hold: 8 GiB and up.
      NodeArchive._fail(NodeArchiveProblem.tooLarge, 'a binary tar number');
    }
    int value = 0;
    bool digits = false;
    for (int i = start; i < start + length; i++) {
      final int byte = _header[i];
      if (byte == 0 || (byte == 0x20 && digits)) {
        break;
      }
      if (byte == 0x20) {
        continue;
      }
      if (byte < 0x30 || byte > 0x37) {
        NodeArchive._fail(NodeArchiveProblem.corrupt, 'a bad tar number');
      }
      value = value * 8 + (byte - 0x30);
      digits = true;
    }
    return value;
  }
}
