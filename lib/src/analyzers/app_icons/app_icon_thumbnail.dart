import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// What an icon looks like, small enough to compare icons whatever their
/// size: its colors averaged over a [side] by [side] grid, composited on
/// white.
class AppIconThumbnail {
  /// Cells per row and column.
  static const int side = 8;

  /// Color channels per cell: red, green, blue.
  static const int _channels = 3;

  /// Largest channel value.
  static const int _channelMax = 255;

  /// The eight bytes every PNG file starts with.
  static const List<int> _pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

  /// Bytes of a chunk's length field and of its type field.
  static const int _fieldLength = 4;

  /// Bytes of a chunk's length and type fields together.
  static const int _chunkHeaderLength = 8;

  /// Hexadecimal digits, and radix, of a channel in [toHex].
  static const int _hexDigits = 2;
  static const int _hexRadix = 16;

  /// The PNG Average filter predicts the mean of two neighbors.
  static const int _averaged = 2;

  /// Offsets in the IHDR data of the bit depth, color type and interlace
  /// method, after the 4-byte width and height.
  static const int _bitDepthOffset = 8;
  static const int _colorTypeOffset = 9;
  static const int _interlaceOffset = 12;

  /// Samples per pixel of each PNG color type: gray, RGB, palette index,
  /// gray + alpha, RGBA.
  static const Map<int, int> _samplesPerPixel = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4};

  /// PNG color types.
  static const int _gray = 0;
  static const int _rgb = 2;
  static const int _palette = 3;
  static const int _grayAlpha = 4;

  /// Bits per byte.
  static const int _byteBits = 8;

  /// PNG row filters.
  static const int _filterSub = 1;
  static const int _filterUp = 2;
  static const int _filterAverage = 3;
  static const int _filterPaeth = 4;

  /// ICO header and directory entry layout.
  static const int _icoHeaderLength = 6;
  static const int _icoCountOffset = 4;
  static const int _icoEntryLength = 16;
  static const int _icoEntrySizeOffset = 8;
  static const int _icoEntryDataOffset = 12;
  static const int _icoZeroSize = 256;

  /// Red, green, blue of each cell, row by row.
  final Uint8List cells;

  /// Creates a thumbnail from its [cells].
  const AppIconThumbnail(this.cells);

  /// The thumbnail written by [toHex].
  factory AppIconThumbnail.fromHex(String hex) => AppIconThumbnail(
    Uint8List.fromList([
      for (var i = 0; i < hex.length; i += _hexDigits)
        int.parse(hex.substring(i, i + _hexDigits), radix: _hexRadix),
    ]),
  );

  /// The cells as hexadecimal text, two digits per channel.
  String toHex() => cells
      .map((value) => value.toRadixString(_hexRadix).padLeft(_hexDigits, '0'))
      .join();

  /// How different this looks from [other]: the mean difference of their
  /// channels, 0 (identical) to 255.
  double distanceTo(AppIconThumbnail other) {
    var total = 0;
    for (var i = 0; i < cells.length; i++) {
      total += (cells[i] - other.cells[i]).abs();
    }
    return total / cells.length;
  }

  /// The thumbnail of the PNG, or of the largest PNG image of the ICO, at
  /// [file]; null when it has none that can be decoded (interlaced PNGs
  /// and BMP-only ICOs are not).
  static AppIconThumbnail? of(File file) {
    final Uint8List bytes;
    try {
      bytes = file.readAsBytesSync();
    } on FileSystemException {
      return null;
    }
    try {
      return _ofPng(bytes) ?? _ofPng(_largestIcoPng(bytes));
    } on FormatException {
      return null;
    }
  }

  /// The largest PNG image embedded in ICO [bytes]; null when there is none.
  static Uint8List? _largestIcoPng(Uint8List bytes) {
    if (bytes.length < _icoHeaderLength) return null;
    final data = ByteData.sublistView(bytes);
    final count = data.getUint16(_icoCountOffset, Endian.little);
    Uint8List? best;
    var bestSize = 0;
    for (var i = 0; i < count; i++) {
      final entry = _icoHeaderLength + i * _icoEntryLength;
      if (entry + _icoEntryLength > bytes.length) return best;
      final size = bytes[entry] == 0 ? _icoZeroSize : bytes[entry];
      final length = data.getUint32(entry + _icoEntrySizeOffset, Endian.little);
      final offset = data.getUint32(entry + _icoEntryDataOffset, Endian.little);
      if (size <= bestSize || offset + length > bytes.length) continue;
      final image = Uint8List.sublistView(bytes, offset, offset + length);
      if (_isPng(image)) {
        best = image;
        bestSize = size;
      }
    }
    return best;
  }

  static bool _isPng(Uint8List bytes) {
    if (bytes.length < _pngSignature.length) return false;
    for (var i = 0; i < _pngSignature.length; i++) {
      if (bytes[i] != _pngSignature[i]) return false;
    }
    return true;
  }

  /// Decodes PNG [bytes] into a thumbnail; null when they are not a PNG
  /// this decoder reads.
  static AppIconThumbnail? _ofPng(Uint8List? bytes) {
    if (bytes == null || !_isPng(bytes)) return null;
    final data = ByteData.sublistView(bytes);
    Uint8List? header;
    Uint8List? palette;
    Uint8List? transparency;
    final compressed = BytesBuilder(copy: false);
    var offset = _pngSignature.length;
    while (offset + _chunkHeaderLength <= bytes.length) {
      final length = data.getUint32(offset);
      final type = String.fromCharCodes(
        bytes.sublist(offset + _fieldLength, offset + _chunkHeaderLength),
      );
      final start = offset + _chunkHeaderLength;
      if (start + length > bytes.length) return null;
      final chunk = Uint8List.sublistView(bytes, start, start + length);
      switch (type) {
        case 'IHDR':
          header = chunk;
        case 'PLTE':
          palette = chunk;
        case 'tRNS':
          transparency = chunk;
        case 'IDAT':
          compressed.add(chunk);
      }
      if (type == 'IEND') break;
      offset = start + length + _fieldLength;
    }
    if (header == null || header[_interlaceOffset] != 0) return null;
    final width = ByteData.sublistView(header).getUint32(0);
    final height = ByteData.sublistView(header).getUint32(_fieldLength);
    final bitDepth = header[_bitDepthOffset];
    final colorType = header[_colorTypeOffset];
    final samples = _samplesPerPixel[colorType];
    if (samples == null || width == 0 || height == 0) return null;
    if (colorType == _palette && palette == null) return null;

    final pixels = Uint8List.fromList(
      ZLibDecoder().convert(compressed.takeBytes()),
    );
    final bitsPerPixel = samples * bitDepth;
    final pixelBytes = max(1, bitsPerPixel ~/ _byteBits);
    final stride = (width * bitsPerPixel + _byteBits - 1) ~/ _byteBits;
    if (pixels.length < height * (stride + 1)) return null;

    final sums = List<int>.filled(side * side * _channels, 0);
    final counts = List<int>.filled(side * side, 0);
    var previous = Uint8List(stride);
    for (var y = 0; y < height; y++) {
      final rowStart = y * (stride + 1);
      final row = Uint8List.fromList(
        pixels.sublist(rowStart + 1, rowStart + 1 + stride),
      );
      _unfilter(pixels[rowStart], row, previous, pixelBytes);
      final cellRow = y * side ~/ height;
      for (var x = 0; x < width; x++) {
        final rgba = _pixel(
          row,
          x,
          colorType,
          bitDepth,
          samples,
          palette,
          transparency,
        );
        final alpha = rgba[_channels];
        final cell = cellRow * side + x * side ~/ width;
        for (var c = 0; c < _channels; c++) {
          // Composite on white
          sums[cell * _channels + c] +=
              (rgba[c] * alpha + _channelMax * (_channelMax - alpha)) ~/
              _channelMax;
        }
        counts[cell]++;
      }
      previous = row;
    }
    return AppIconThumbnail(
      Uint8List.fromList([
        for (var i = 0; i < sums.length; i++)
          counts[i ~/ _channels] == 0 ? 0 : sums[i] ~/ counts[i ~/ _channels],
      ]),
    );
  }

  /// Reverses the PNG [filter] of [row] in place, given the decoded
  /// [previous] row and the bytes of a whole pixel.
  static void _unfilter(
    int filter,
    Uint8List row,
    Uint8List previous,
    int pixelBytes,
  ) {
    for (var i = 0; i < row.length; i++) {
      final left = i >= pixelBytes ? row[i - pixelBytes] : 0;
      final up = previous[i];
      final upLeft = i >= pixelBytes ? previous[i - pixelBytes] : 0;
      final predicted = switch (filter) {
        _filterSub => left,
        _filterUp => up,
        _filterAverage => (left + up) ~/ _averaged,
        _filterPaeth => _paeth(left, up, upLeft),
        _ => 0,
      };
      row[i] = (row[i] + predicted) & _channelMax;
    }
  }

  /// The Paeth predictor: whichever neighbor is closest to
  /// [left] + [up] - [upLeft].
  static int _paeth(int left, int up, int upLeft) {
    final estimate = left + up - upLeft;
    final toLeft = (estimate - left).abs();
    final toUp = (estimate - up).abs();
    final toUpLeft = (estimate - upLeft).abs();
    if (toLeft <= toUp && toLeft <= toUpLeft) return left;
    return toUp <= toUpLeft ? up : upLeft;
  }

  /// Red, green, blue and alpha, 0 to 255, of pixel [x] of decoded [row].
  static List<int> _pixel(
    Uint8List row,
    int x,
    int colorType,
    int bitDepth,
    int samples,
    Uint8List? palette,
    Uint8List? transparency,
  ) {
    int sample(int index) {
      final bit = (x * samples + index) * bitDepth;
      if (bitDepth == _byteBits) return row[bit ~/ _byteBits];
      if (bitDepth > _byteBits) return row[bit ~/ _byteBits]; // High byte
      final shift = _byteBits - bitDepth - bit % _byteBits;
      return (row[bit ~/ _byteBits] >> shift) & ((1 << bitDepth) - 1);
    }

    // Scales a sub-byte sample to 0..255
    int full(int value) => bitDepth >= _byteBits
        ? value
        : value * _channelMax ~/ ((1 << bitDepth) - 1);

    switch (colorType) {
      case _palette:
        final index = sample(0);
        final base = index * _channels;
        final alpha = transparency != null && index < transparency.length
            ? transparency[index]
            : _channelMax;
        if (base + _channels > palette!.length) return [0, 0, 0, alpha];
        return [
          palette[base],
          palette[base + 1],
          palette[base + _channels - 1],
          alpha,
        ];
      case _gray:
      case _grayAlpha:
        final gray = full(sample(0));
        final alpha = colorType == _grayAlpha ? full(sample(1)) : _channelMax;
        return [gray, gray, gray, alpha];
      case _rgb:
        return [...List.generate(_channels, sample), _channelMax];
      default:
        return List.generate(_channels + 1, sample);
    }
  }
}
