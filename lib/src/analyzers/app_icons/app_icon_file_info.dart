import 'dart:io';
import 'dart:typed_data';

/// The size and transparency of a PNG or ICO icon file, read from its
/// headers without decoding the pixels.
class AppIconFileInfo {
  /// Width in pixels; for an ICO, its largest image's.
  final int width;

  /// Height in pixels; for an ICO, its largest image's.
  final int height;

  /// Whether a PNG has an alpha channel or a transparent color; false for
  /// an ICO.
  final bool hasAlpha;

  /// The square sizes an ICO holds; empty for a PNG.
  final Set<int> icoSizes;

  /// Creates the description of an icon file.
  const AppIconFileInfo({
    required this.width,
    required this.height,
    this.hasAlpha = false,
    this.icoSizes = const {},
  });

  /// The eight bytes every PNG file starts with.
  static const List<int> _pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

  /// Offset of the IHDR chunk's width, past the signature, chunk length
  /// and chunk type.
  static const int _pngWidthOffset = 16;

  /// Offset of the IHDR chunk's height.
  static const int _pngHeightOffset = 20;

  /// Offset of the IHDR chunk's color type.
  static const int _pngColorTypeOffset = 25;

  /// Offset of the first chunk after the signature.
  static const int _pngFirstChunkOffset = 8;

  /// Bytes of a chunk's length field, which its type follows.
  static const int _pngChunkLengthLength = 4;

  /// Bytes of a chunk's length and type fields.
  static const int _pngChunkHeaderLength = 8;

  /// Bytes of a chunk's trailing CRC.
  static const int _pngChunkCrcLength = 4;

  /// PNG color types carrying an alpha channel: gray + alpha, RGBA.
  static const Set<int> _pngAlphaColorTypes = {4, 6};

  /// The chunk declaring a transparent color.
  static const String _pngTransparencyChunk = 'tRNS';

  /// The chunk where pixel data starts; transparency is declared before.
  static const String _pngDataChunk = 'IDAT';

  /// ICO header: reserved zero, type one (icon), image count.
  static const int _icoHeaderLength = 6;

  /// Value of an ICO header's type field.
  static const int _icoType = 1;

  /// Offset of the ICO header's type field.
  static const int _icoTypeOffset = 2;

  /// Offset of the ICO header's image count.
  static const int _icoCountOffset = 4;

  /// Bytes of each ICO directory entry.
  static const int _icoEntryLength = 16;

  /// An ICO entry's width or height byte of zero means this many pixels.
  static const int _icoZeroSize = 256;

  /// Offset of an ICO entry's height byte, after its width byte.
  static const int _icoEntryHeightOffset = 1;

  /// Reads the icon at [file]; null when it is missing or neither a PNG
  /// nor an ICO.
  static AppIconFileInfo? read(File file) {
    final Uint8List bytes;
    try {
      bytes = file.readAsBytesSync();
    } on FileSystemException {
      return null;
    }
    return _readPng(bytes) ?? _readIco(bytes);
  }

  /// The PNG described by [bytes], or null when they are not a PNG.
  static AppIconFileInfo? _readPng(Uint8List bytes) {
    if (bytes.length <= _pngColorTypeOffset) return null;
    for (var i = 0; i < _pngSignature.length; i++) {
      if (bytes[i] != _pngSignature[i]) return null;
    }
    final data = ByteData.sublistView(bytes);
    return AppIconFileInfo(
      width: data.getUint32(_pngWidthOffset),
      height: data.getUint32(_pngHeightOffset),
      hasAlpha:
          _pngAlphaColorTypes.contains(bytes[_pngColorTypeOffset]) ||
          _hasPngTransparencyChunk(data),
    );
  }

  /// Whether a `tRNS` chunk comes before the pixel data in [data].
  static bool _hasPngTransparencyChunk(ByteData data) {
    var offset = _pngFirstChunkOffset;
    while (offset + _pngChunkHeaderLength <= data.lengthInBytes) {
      final length = data.getUint32(offset);
      final type = String.fromCharCodes(
        Uint8List.sublistView(
          data,
          offset + _pngChunkLengthLength,
          offset + _pngChunkHeaderLength,
        ),
      );
      if (type == _pngTransparencyChunk) return true;
      if (type == _pngDataChunk) return false;
      offset += _pngChunkHeaderLength + length + _pngChunkCrcLength;
    }
    return false;
  }

  /// The ICO described by [bytes], or null when they are not an ICO.
  static AppIconFileInfo? _readIco(Uint8List bytes) {
    if (bytes.length < _icoHeaderLength) return null;
    final data = ByteData.sublistView(bytes);
    if (data.getUint16(0, Endian.little) != 0 ||
        data.getUint16(_icoTypeOffset, Endian.little) != _icoType) {
      return null;
    }
    final count = data.getUint16(_icoCountOffset, Endian.little);
    if (count == 0 ||
        bytes.length < _icoHeaderLength + count * _icoEntryLength) {
      return null;
    }
    final sizes = <int>{};
    var width = 0;
    var height = 0;
    for (var i = 0; i < count; i++) {
      final offset = _icoHeaderLength + i * _icoEntryLength;
      final entryWidth = _icoSize(bytes[offset]);
      final entryHeight = _icoSize(bytes[offset + _icoEntryHeightOffset]);
      if (entryWidth == entryHeight) sizes.add(entryWidth);
      if (entryWidth * entryHeight > width * height) {
        width = entryWidth;
        height = entryHeight;
      }
    }
    return AppIconFileInfo(width: width, height: height, icoSizes: sizes);
  }

  /// An ICO entry's [byte] width or height in pixels.
  static int _icoSize(int byte) => byte == 0 ? _icoZeroSize : byte;
}
