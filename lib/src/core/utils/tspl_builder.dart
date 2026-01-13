import 'dart:convert';

/// Builder class for creating TSPL (TSC Printer Language) commands
/// Used for label/sticker printers
class TsplBuilder {
  final StringBuffer _buffer = StringBuffer();
  static const String _eol = '\r\n';

  /// Set label size in mm
  /// [width] - label width in mm
  /// [height] - label height in mm
  void size(int width, int height) {
    _buffer.write('SIZE $width mm,$height mm$_eol');
  }

  /// Set gap between labels
  /// [distance] - gap distance in mm
  /// [offset] - gap offset in mm (usually 0)
  void gap(int distance, int offset) {
    _buffer.write('GAP $distance mm,$offset mm$_eol');
  }

  /// Set print density (darkness)
  /// [level] - density level 0-15 (default 8)
  void density(int level) {
    _buffer.write('DENSITY $level$_eol');
  }

  /// Set print speed
  /// [speed] - speed level 1-10
  void speed(int speed) {
    _buffer.write('SPEED $speed$_eol');
  }

  /// Set print direction
  /// [direction] - 0 or 1
  void direction(int direction) {
    _buffer.write('DIRECTION $direction$_eol');
  }

  /// Set reference point (origin)
  /// [x] - x offset in dots
  /// [y] - y offset in dots
  void reference(int x, int y) {
    _buffer.write('REFERENCE $x,$y$_eol');
  }

  /// Clear image buffer
  void cls() {
    _buffer.write('CLS$_eol');
  }

  /// Print text at position
  /// [x] - x position in dots (8 dots = 1mm at 200 DPI)
  /// [y] - y position in dots
  /// [font] - font type: 1-5 for internal fonts, or font name
  /// [rotation] - 0, 90, 180, 270 degrees
  /// [xMultiplier] - horizontal magnification 1-10
  /// [yMultiplier] - vertical magnification 1-10
  /// [content] - text content
  void text(
    int x,
    int y,
    int font,
    int rotation,
    int xMultiplier,
    int yMultiplier,
    String content,
  ) {
    // Escape quotes in content
    final escapedContent = content.replaceAll('"', '\\"');
    _buffer.write('TEXT $x,$y,"$font",$rotation,$xMultiplier,$yMultiplier,"$escapedContent"$_eol');
  }

  /// Print text block with word wrap
  /// [x] - x position in dots
  /// [y] - y position in dots
  /// [width] - block width in dots
  /// [height] - block height in dots
  /// [font] - font name
  /// [rotation] - 0, 90, 180, 270 degrees
  /// [xMultiplier] - horizontal magnification
  /// [yMultiplier] - vertical magnification
  /// [content] - text content
  void block(
    int x,
    int y,
    int width,
    int height,
    String font,
    int rotation,
    int xMultiplier,
    int yMultiplier,
    String content,
  ) {
    final escapedContent = content.replaceAll('"', '\\"');
    _buffer.write('BLOCK $x,$y,$width,$height,"$font",$rotation,$xMultiplier,$yMultiplier,"$escapedContent"$_eol');
  }

  /// Print barcode at position
  /// [x] - x position in dots
  /// [y] - y position in dots
  /// [codeType] - barcode type: 128, 128M, EAN128, 25, 25C, 39, 39C, 93, EAN13, EAN8, CODA, POST, UPCA, UPCE, etc.
  /// [height] - barcode height in dots
  /// [humanReadable] - 0=no text, 1=align left, 2=align center, 3=align right
  /// [rotation] - rotation: 0, 90, 180, 270 degrees
  /// [narrow] - narrow bar width in dots (1-10, default 2)
  /// [wide] - wide bar width in dots (1-10, default 5)
  /// [content] - barcode data
  void barcode(
    int x,
    int y,
    String codeType,
    int height,
    int humanReadable,
    String content, {
    int rotation = 0,
    int narrow = 2,
    int wide = 5,
  }) {
    _buffer.write('BARCODE $x,$y,"$codeType",$height,$humanReadable,$rotation,$narrow,$wide,"$content"$_eol');
  }

  /// Print QR code at position
  /// [x] - x position in dots
  /// [y] - y position in dots
  /// [eccLevel] - error correction level: L, M, Q, H
  /// [cellWidth] - module size 1-10
  /// [mode] - A=auto, M=manual
  /// [rotation] - 0, 90, 180, 270
  /// [content] - QR code data
  void qrcode(
    int x,
    int y,
    String eccLevel,
    int cellWidth,
    String mode,
    int rotation,
    String content,
  ) {
    final escapedContent = content.replaceAll('"', '\\"');
    _buffer.write('QRCODE $x,$y,$eccLevel,$cellWidth,$mode,$rotation,"$escapedContent"$_eol');
  }

  /// Draw a box/rectangle
  /// [x] - x position in dots
  /// [y] - y position in dots
  /// [width] - box width in dots
  /// [height] - box height in dots
  /// [thickness] - line thickness in dots
  void box(int x, int y, int width, int height, int thickness) {
    _buffer.write('BOX $x,$y,${x + width},${y + height},$thickness$_eol');
  }

  /// Draw a line
  /// [x] - start x position in dots
  /// [y] - start y position in dots
  /// [width] - line width in dots
  /// [height] - line height in dots
  void line(int x, int y, int width, int height) {
    _buffer.write('BAR $x,$y,$width,$height$_eol');
  }

  /// Reverse (invert) a region
  /// [x] - x position in dots
  /// [y] - y position in dots
  /// [width] - width in dots
  /// [height] - height in dots
  void reverse(int x, int y, int width, int height) {
    _buffer.write('REVERSE $x,$y,$width,$height$_eol');
  }

  /// Print the label
  /// [quantity] - number of copies to print
  /// [copies] - number of copies for each label (default 1)
  void printLabel(int quantity, {int copies = 1}) {
    _buffer.write('PRINT $quantity,$copies$_eol');
  }

  /// End of print job
  void eop() {
    _buffer.write('EOP$_eol');
  }

  /// Get the command string
  String getCommandString() {
    return _buffer.toString();
  }

  /// Build and return the command bytes
  List<int> build() {
    // Add CLS at the beginning if not already there
    final commands = _buffer.toString();
    if (!commands.startsWith('CLS')) {
      return utf8.encode('CLS$_eol$commands');
    }
    return utf8.encode(commands);
  }

  /// Clear the builder
  void clear() {
    _buffer.clear();
  }

  /// Create a simple text label
  /// Returns the builder for chaining
  static TsplBuilder createTextLabel({
    required int width,
    required int height,
    required int gap,
    required String text,
    int x = 16,
    int y = 16,
    int font = 3,
    int quantity = 1,
  }) {
    final builder = TsplBuilder()
      ..size(width, height)
      ..gap(gap, 0)
      ..density(8)
      ..cls()
      ..text(x, y, font, 0, 1, 1, text)
      ..printLabel(quantity);
    return builder;
  }
}
