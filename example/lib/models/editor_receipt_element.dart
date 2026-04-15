import 'dart:convert';
import 'dart:typed_data';
import 'package:multiprinter/multiprinter.dart';

/// Rich editor model for a receipt element. Extends [ReceiptLine] with
/// image bytes support, separate leftText/rightText fields, and visual
/// sizing fields (displayWidth, displayHeight) for barcode / QR / image.
class EditorReceiptElement {
  final ReceiptLineType type;
  final String text;
  final String leftText;
  final String rightText;
  final ReceiptTextAlign alignment;
  final ReceiptTextSize size;
  final bool bold;
  final bool underline;
  final Uint8List? imageBytes;

  /// Fraction of the paper width (0.2 – 1.0). Used by QR and image.
  final double displayWidth;

  /// Display height in logical pixels (30 – 250).
  /// Used by barcode (bar height) and image (element height).
  /// QR ignores this; it stays square at displayWidth * paperWidth.
  final double displayHeight;

  const EditorReceiptElement({
    required this.type,
    this.text = '',
    this.leftText = '',
    this.rightText = '',
    this.alignment = ReceiptTextAlign.left,
    this.size = ReceiptTextSize.normal,
    this.bold = false,
    this.underline = false,
    this.imageBytes,
    this.displayWidth = 1.0,
    this.displayHeight = 80.0,
  });

  EditorReceiptElement copyWith({
    ReceiptLineType? type,
    String? text,
    String? leftText,
    String? rightText,
    ReceiptTextAlign? alignment,
    ReceiptTextSize? size,
    bool? bold,
    bool? underline,
    Uint8List? imageBytes,
    bool clearImage = false,
    double? displayWidth,
    double? displayHeight,
  }) {
    return EditorReceiptElement(
      type: type ?? this.type,
      text: text ?? this.text,
      leftText: leftText ?? this.leftText,
      rightText: rightText ?? this.rightText,
      alignment: alignment ?? this.alignment,
      size: size ?? this.size,
      bold: bold ?? this.bold,
      underline: underline ?? this.underline,
      imageBytes: clearImage ? null : (imageBytes ?? this.imageBytes),
      displayWidth: displayWidth ?? this.displayWidth,
      displayHeight: displayHeight ?? this.displayHeight,
    );
  }

  /// Convert to domain [ReceiptLine] for printing.
  ///
  /// For barcode, QR and image, the size is encoded as a short prefix in the
  /// `text` field so [PrinterDataSource._printReceiptLine] can apply it:
  ///
  ///   Barcode  → `BRCH{heightDots}|{data}`
  ///   QR       → `QRMS{moduleSize}|{data}`
  ///   Image    → `IMGW{widthPct}|{base64}`
  ReceiptLine toReceiptLine() {
    switch (type) {
      case ReceiptLineType.text:
        return ReceiptLine.text(
          text,
          alignment: alignment,
          size: size,
          bold: bold,
          underline: underline,
        );
      case ReceiptLineType.leftRight:
        return ReceiptLine.leftRight(leftText, rightText);
      case ReceiptLineType.divider:
        return ReceiptLine(text: text, lineType: ReceiptLineType.divider);
      case ReceiptLineType.barcode:
        final heightDots = displayHeight.round().clamp(30, 255);
        return ReceiptLine.barcode('BRCH$heightDots|$text');
      case ReceiptLineType.qrCode:
        // Map displayWidth (0.2–1.0) → module size (2–8)
        final moduleSize = (displayWidth * 8).round().clamp(2, 8);
        return ReceiptLine.qrCode('QRMS$moduleSize|$text');
      case ReceiptLineType.empty:
        return ReceiptLine.empty();
      case ReceiptLineType.image:
        if (imageBytes != null) {
          final widthPct = (displayWidth * 100).round().clamp(20, 100);
          return ReceiptLine(
            text: 'IMGW$widthPct|${base64Encode(imageBytes!)}',
            lineType: ReceiptLineType.image,
          );
        }
        return ReceiptLine.empty();
    }
  }

  // ── Factory constructors ──────────────────────────────────────────────────

  factory EditorReceiptElement.newText({
    String text = 'Text',
    ReceiptTextAlign alignment = ReceiptTextAlign.left,
    bool bold = false,
  }) =>
      EditorReceiptElement(type: ReceiptLineType.text, text: text, alignment: alignment, bold: bold);

  factory EditorReceiptElement.newLeftRight({
    String leftText = 'Item',
    String rightText = '0.00',
  }) =>
      EditorReceiptElement(
        type: ReceiptLineType.leftRight,
        leftText: leftText,
        rightText: rightText,
      );

  factory EditorReceiptElement.newDivider({String char = '-', int length = 32}) =>
      EditorReceiptElement(type: ReceiptLineType.divider, text: char * length);

  factory EditorReceiptElement.newBarcode([String data = '123456789']) =>
      EditorReceiptElement(type: ReceiptLineType.barcode, text: data, displayHeight: 60);

  factory EditorReceiptElement.newQrCode([String data = 'https://example.com']) =>
      EditorReceiptElement(
        type: ReceiptLineType.qrCode,
        text: data,
        displayWidth: 0.6,
        displayHeight: 80,
      );

  factory EditorReceiptElement.newEmpty() =>
      const EditorReceiptElement(type: ReceiptLineType.empty);

  factory EditorReceiptElement.newImage(Uint8List bytes) =>
      EditorReceiptElement(
        type: ReceiptLineType.image,
        imageBytes: bytes,
        displayWidth: 0.8,
        displayHeight: 80,
      );

  // ── JSON serialisation ────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'text': text,
        'leftText': leftText,
        'rightText': rightText,
        'alignment': alignment.name,
        'size': size.name,
        'bold': bold,
        'underline': underline,
        'imageBytes': imageBytes != null ? base64Encode(imageBytes!) : null,
        'displayWidth': displayWidth,
        'displayHeight': displayHeight,
      };

  factory EditorReceiptElement.fromJson(Map<String, dynamic> j) {
    Uint8List? img;
    if (j['imageBytes'] != null) {
      try {
        img = base64Decode(j['imageBytes'] as String);
      } catch (_) {}
    }
    return EditorReceiptElement(
      type: ReceiptLineType.values.firstWhere(
        (e) => e.name == j['type'],
        orElse: () => ReceiptLineType.text,
      ),
      text: j['text'] as String? ?? '',
      leftText: j['leftText'] as String? ?? '',
      rightText: j['rightText'] as String? ?? '',
      alignment: ReceiptTextAlign.values.firstWhere(
        (e) => e.name == j['alignment'],
        orElse: () => ReceiptTextAlign.left,
      ),
      size: ReceiptTextSize.values.firstWhere(
        (e) => e.name == j['size'],
        orElse: () => ReceiptTextSize.normal,
      ),
      bold: j['bold'] as bool? ?? false,
      underline: j['underline'] as bool? ?? false,
      imageBytes: img,
      displayWidth: (j['displayWidth'] as num?)?.toDouble() ?? 1.0,
      displayHeight: (j['displayHeight'] as num?)?.toDouble() ?? 80.0,
    );
  }

  bool get isResizable =>
      type == ReceiptLineType.barcode ||
      type == ReceiptLineType.qrCode ||
      type == ReceiptLineType.image;

  /// Label for display in UI.
  String get typeLabel {
    switch (type) {
      case ReceiptLineType.text:
        return 'Text';
      case ReceiptLineType.leftRight:
        return 'Two-Column';
      case ReceiptLineType.divider:
        return 'Divider';
      case ReceiptLineType.barcode:
        return 'Barcode';
      case ReceiptLineType.qrCode:
        return 'QR Code';
      case ReceiptLineType.empty:
        return 'Spacer';
      case ReceiptLineType.image:
        return 'Image';
    }
  }
}
