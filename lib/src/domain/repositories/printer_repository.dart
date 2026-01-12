import '../../core/constants/printer_constants.dart';
import '../../core/utils/result.dart';
import '../entities/print_job.dart';
import '../entities/printer_device.dart';
import '../value_objects/print_content.dart';

/// Abstract repository interface for printer operations
abstract class PrinterRepository {
  /// Scan for available Bluetooth devices
  Future<Result<List<PrinterDevice>>> scanBluetoothDevices();

  /// Scan for available TCP/LAN devices on network
  Future<Result<List<PrinterDevice>>> scanNetworkDevices({
    String subnet = '192.168.1',
    int port = PrinterConstants.defaultTcpPort,
  });

  /// Scan for available USB devices (Android only)
  Future<Result<List<PrinterDevice>>> scanUsbDevices();

  /// Get all registered printers
  Future<Result<List<PrinterDevice>>> getRegisteredPrinters();

  /// Register a new printer
  Future<Result<PrinterDevice>> registerPrinter(PrinterDevice printer);

  /// Update printer details
  Future<Result<PrinterDevice>> updatePrinter(PrinterDevice printer);

  /// Remove a registered printer
  Future<Result<void>> removePrinter(String printerId);

  /// Connect to a printer
  Future<Result<PrinterDevice>> connectToPrinter(PrinterDevice printer);

  /// Disconnect from a printer
  Future<Result<void>> disconnectFromPrinter(PrinterDevice printer);

  /// Check printer connection status
  Future<Result<bool>> isPrinterConnected(PrinterDevice printer);

  /// Print a receipt
  Future<Result<PrintJob>> printReceipt(
    PrinterDevice printer,
    ReceiptContent content,
  );

  /// Print a sticker
  Future<Result<PrintJob>> printSticker(
    PrinterDevice printer,
    StickerContent content,
  );

  /// Print raw bytes to a printer
  Future<Result<PrintJob>> printRaw(
    PrinterDevice printer,
    List<int> bytes,
  );

  /// Print raw bytes to multiple printers simultaneously
  Future<Result<BatchPrintResult>> printRawToMultiple(
    List<PrinterDevice> printers,
    List<int> bytes,
  );

  /// Print to multiple printers simultaneously
  Future<Result<BatchPrintResult>> printToMultiplePrinters(
    List<PrinterDevice> printers,
    PrintContent content,
  );

  /// Get print job status
  Future<Result<PrintJob>> getPrintJobStatus(String jobId);

  /// Cancel a print job
  Future<Result<void>> cancelPrintJob(String jobId);

  /// Get print history
  Future<Result<List<PrintJob>>> getPrintHistory({
    int limit = 50,
    DateTime? fromDate,
  });

  /// Warm up network connections to TCP printers
  /// Call this before printing to reduce first-print latency
  Future<void> warmUpConnections();
}

