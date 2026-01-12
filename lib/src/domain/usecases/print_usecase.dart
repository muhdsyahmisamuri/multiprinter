import 'package:dartz/dartz.dart';
import '../../core/constants/printer_constants.dart';
import '../../core/utils/result.dart';
import '../entities/print_job.dart';
import '../entities/printer_device.dart';
import '../repositories/printer_repository.dart';
import '../value_objects/print_content.dart';

/// Use case for printing operations
class PrintUseCase {
  final PrinterRepository _repository;

  PrintUseCase(this._repository);

  /// Print a receipt to a single printer
  Future<Result<PrintJob>> printReceipt(
    PrinterDevice printer,
    ReceiptContent content,
  ) async {
    return _repository.printReceipt(printer, content);
  }

  /// Print a sticker to a single printer
  Future<Result<PrintJob>> printSticker(
    PrinterDevice printer,
    StickerContent content,
  ) async {
    return _repository.printSticker(printer, content);
  }

  /// Print to multiple printers simultaneously
  Future<Result<BatchPrintResult>> printToMultiple(
    List<PrinterDevice> printers,
    PrintContent content,
  ) async {
    return _repository.printToMultiplePrinters(printers, content);
  }

  /// Print receipt to multiple printers simultaneously
  Future<Result<BatchPrintResult>> printReceiptToMultiple(
    List<PrinterDevice> printers,
    ReceiptContent content,
  ) async {
    final stopwatch = Stopwatch()..start();
    final List<PrintJob> jobs = [];
    int successCount = 0;
    int failureCount = 0;

    // Execute all print jobs in parallel
    final results = await Future.wait(
      printers.map((printer) => _repository.printReceipt(printer, content)),
    );

    for (final result in results) {
      result.fold(
        (failure) {
          failureCount++;
        },
        (job) {
          jobs.add(job);
          if (job.status == PrintJobStatus.completed) {
            successCount++;
          } else {
            failureCount++;
          }
        },
      );
    }

    stopwatch.stop();

    return Right(
      BatchPrintResult(
        jobs: jobs,
        successCount: successCount,
        failureCount: failureCount,
        totalDuration: stopwatch.elapsed,
      ),
    );
  }

  /// Print sticker to multiple printers simultaneously
  Future<Result<BatchPrintResult>> printStickerToMultiple(
    List<PrinterDevice> printers,
    StickerContent content,
  ) async {
    final stopwatch = Stopwatch()..start();
    final List<PrintJob> jobs = [];
    int successCount = 0;
    int failureCount = 0;

    // Execute all print jobs in parallel
    final results = await Future.wait(
      printers.map((printer) => _repository.printSticker(printer, content)),
    );

    for (final result in results) {
      result.fold(
        (failure) {
          failureCount++;
        },
        (job) {
          jobs.add(job);
          if (job.status == PrintJobStatus.completed) {
            successCount++;
          } else {
            failureCount++;
          }
        },
      );
    }

    stopwatch.stop();

    return Right(
      BatchPrintResult(
        jobs: jobs,
        successCount: successCount,
        failureCount: failureCount,
        totalDuration: stopwatch.elapsed,
      ),
    );
  }

  /// Print raw bytes to a single printer
  Future<Result<PrintJob>> printRaw(
    PrinterDevice printer,
    List<int> bytes,
  ) async {
    return _repository.printRaw(printer, bytes);
  }

  /// Print raw bytes to multiple printers simultaneously
  Future<Result<BatchPrintResult>> printRawToMultiple(
    List<PrinterDevice> printers,
    List<int> bytes,
  ) async {
    return _repository.printRawToMultiple(printers, bytes);
  }
}

