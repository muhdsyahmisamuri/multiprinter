/// Constants related to printer configurations
class PrinterConstants {
  PrinterConstants._();

  /// Default TCP port for thermal printers
  static const int defaultTcpPort = 9100;

  /// Connection timeout in milliseconds
  static const int connectionTimeout = 10000;

  /// Print timeout in milliseconds
  static const int printTimeout = 30000;

  /// Maximum retry attempts
  static const int maxRetryAttempts = 3;

  /// Delay between retries in milliseconds
  static const int retryDelay = 1000;

  /// Default paper width for receipts (58mm or 80mm)
  static const int defaultReceiptWidth = 58;

  /// Default sticker width
  static const int defaultStickerWidth = 40;

  /// Default sticker height
  static const int defaultStickerHeight = 30;

  /// Default gap between stickers
  static const int defaultStickerGap = 3;
}

/// Printer type enumeration
enum PrinterConnectionType { bluetooth, tcp, usb, lan }

/// Print document type
enum PrintDocumentType { receipt, sticker }

/// Printer role for multi-printer setup
enum PrinterRole { cashier, kitchen, bar, sticker, general }

/// Print job status
enum PrintJobStatus { pending, inProgress, completed, failed, cancelled }

