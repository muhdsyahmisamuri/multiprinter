import 'dart:convert';
import 'dart:typed_data';

enum StickerElementType { text, barcode, qrCode, image }

/// A positioned element on the sticker canvas. Coordinates are stored in mm.
class StickerElement {
  final StickerElementType type;
  final String content;
  final double x;
  final double y;
  final double? width;
  final double? height;

  /// TSPL font index (1–5). For text elements only.
  final int fontSize;

  final Uint8List? imageBytes;

  const StickerElement({
    required this.type,
    this.content = '',
    this.x = 2,
    this.y = 2,
    this.width,
    this.height,
    this.fontSize = 2,
    this.imageBytes,
  });

  StickerElement copyWith({
    StickerElementType? type,
    String? content,
    double? x,
    double? y,
    double? width,
    double? height,
    int? fontSize,
    Uint8List? imageBytes,
    bool clearImage = false,
  }) {
    return StickerElement(
      type: type ?? this.type,
      content: content ?? this.content,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      fontSize: fontSize ?? this.fontSize,
      imageBytes: clearImage ? null : (imageBytes ?? this.imageBytes),
    );
  }

  // ── JSON serialisation ────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'content': content,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'fontSize': fontSize,
        'imageBytes': imageBytes != null ? base64Encode(imageBytes!) : null,
      };

  factory StickerElement.fromJson(Map<String, dynamic> j) {
    Uint8List? img;
    if (j['imageBytes'] != null) {
      try {
        img = base64Decode(j['imageBytes'] as String);
      } catch (_) {}
    }
    return StickerElement(
      type: StickerElementType.values.firstWhere(
        (e) => e.name == j['type'],
        orElse: () => StickerElementType.text,
      ),
      content: j['content'] as String? ?? '',
      x: (j['x'] as num?)?.toDouble() ?? 2.0,
      y: (j['y'] as num?)?.toDouble() ?? 2.0,
      width: (j['width'] as num?)?.toDouble(),
      height: (j['height'] as num?)?.toDouble(),
      fontSize: j['fontSize'] as int? ?? 2,
      imageBytes: img,
    );
  }

  // ── Factory constructors ──────────────────────────────────────────────────

  factory StickerElement.newText({
    String content = 'Text',
    double x = 4,
    double y = 4,
    int fontSize = 2,
  }) =>
      StickerElement(type: StickerElementType.text, content: content, x: x, y: y, fontSize: fontSize);

  factory StickerElement.newBarcode({
    String content = '123456789',
    double x = 4,
    double y = 14,
    double width = 32,
    double height = 10,
  }) =>
      StickerElement(
        type: StickerElementType.barcode,
        content: content,
        x: x,
        y: y,
        width: width,
        height: height,
      );

  factory StickerElement.newQrCode({
    String content = 'https://example.com',
    double x = 4,
    double y = 14,
    double size = 16,
  }) =>
      StickerElement(
        type: StickerElementType.qrCode,
        content: content,
        x: x,
        y: y,
        width: size,
        height: size,
      );

  factory StickerElement.newImage(
    Uint8List bytes, {
    double x = 4,
    double y = 4,
    double width = 20,
    double height = 20,
  }) =>
      StickerElement(
        type: StickerElementType.image,
        imageBytes: bytes,
        x: x,
        y: y,
        width: width,
        height: height,
      );

  String get typeLabel {
    switch (type) {
      case StickerElementType.text:
        return 'Text';
      case StickerElementType.barcode:
        return 'Barcode';
      case StickerElementType.qrCode:
        return 'QR Code';
      case StickerElementType.image:
        return 'Image';
    }
  }
}
