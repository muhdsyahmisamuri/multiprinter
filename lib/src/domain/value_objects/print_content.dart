import 'package:equatable/equatable.dart';
import '../../core/constants/printer_constants.dart';

/// Value object representing print content
abstract class PrintContent extends Equatable {
  final PrintDocumentType documentType;

  const PrintContent({required this.documentType});
}

/// Receipt content for ESC/POS printing
class ReceiptContent extends PrintContent {
  final String? storeName;
  final String? storeAddress;
  final List<ReceiptLine> lines;
  final String? footer;
  final bool cutPaper;
  final bool openCashDrawer;

  const ReceiptContent({
    this.storeName,
    this.storeAddress,
    required this.lines,
    this.footer,
    this.cutPaper = true,
    this.openCashDrawer = false,
  }) : super(documentType: PrintDocumentType.receipt);

  @override
  List<Object?> get props => [
    storeName,
    storeAddress,
    lines,
    footer,
    cutPaper,
    openCashDrawer,
    documentType,
  ];
}

/// Single line in a receipt
class ReceiptLine extends Equatable {
  final String text;
  final ReceiptTextAlign alignment;
  final ReceiptTextSize size;
  final bool bold;
  final bool underline;
  final ReceiptLineType lineType;

  const ReceiptLine({
    required this.text,
    this.alignment = ReceiptTextAlign.left,
    this.size = ReceiptTextSize.normal,
    this.bold = false,
    this.underline = false,
    this.lineType = ReceiptLineType.text,
  });

  /// Create a text line
  factory ReceiptLine.text(
    String text, {
    ReceiptTextAlign alignment = ReceiptTextAlign.left,
    ReceiptTextSize size = ReceiptTextSize.normal,
    bool bold = false,
    bool underline = false,
  }) {
    return ReceiptLine(
      text: text,
      alignment: alignment,
      size: size,
      bold: bold,
      underline: underline,
      lineType: ReceiptLineType.text,
    );
  }

  /// Create a left-right line (e.g., "Item    $10.00")
  factory ReceiptLine.leftRight(String left, String right) {
    return ReceiptLine(
      text: '$left\t$right',
      lineType: ReceiptLineType.leftRight,
    );
  }

  /// Create a divider line
  factory ReceiptLine.divider({String char = '-', int length = 32}) {
    return ReceiptLine(text: char * length, lineType: ReceiptLineType.divider);
  }

  /// Create a barcode line
  factory ReceiptLine.barcode(String data) {
    return ReceiptLine(text: data, lineType: ReceiptLineType.barcode);
  }

  /// Create a QR code line
  factory ReceiptLine.qrCode(String data) {
    return ReceiptLine(text: data, lineType: ReceiptLineType.qrCode);
  }

  /// Create empty line for spacing
  factory ReceiptLine.empty() {
    return const ReceiptLine(text: '', lineType: ReceiptLineType.empty);
  }

  @override
  List<Object?> get props => [text, alignment, size, bold, underline, lineType];
}

enum ReceiptTextAlign { left, center, right }

enum ReceiptTextSize { small, normal, large, extraLarge }

enum ReceiptLineType { text, leftRight, divider, barcode, qrCode, empty, image }

/// Raw content for direct byte printing
class RawContent extends PrintContent {
  final List<int> bytes;

  const RawContent({
    required this.bytes,
  }) : super(documentType: PrintDocumentType.receipt);

  @override
  List<Object?> get props => [bytes, documentType];
}

/// Sticker content for TSPL printing
class StickerContent extends PrintContent {
  final String customerName;
  final String productName;
  final List<String> variants;
  final List<String> additions;
  final String? notes;
  final int quantity;
  final int width;
  final int height;
  final int gap;
  final String? barcode;
  final int density;
  final int fontSize; // 1=small, 2=medium, 3=large, 4=extra large

  const StickerContent({
    required this.customerName,
    required this.productName,
    this.variants = const [],
    this.additions = const [],
    this.notes,
    this.quantity = 1,
    this.width = PrinterConstants.defaultStickerWidth,
    this.height = PrinterConstants.defaultStickerHeight,
    this.gap = PrinterConstants.defaultStickerGap,
    this.barcode,
    this.density = 8,
    this.fontSize = 3,
  }) : super(documentType: PrintDocumentType.sticker);

  @override
  List<Object?> get props => [
    customerName,
    productName,
    variants,
    additions,
    notes,
    quantity,
    width,
    height,
    gap,
    barcode,
    density,
    fontSize,
    documentType,
  ];
}

