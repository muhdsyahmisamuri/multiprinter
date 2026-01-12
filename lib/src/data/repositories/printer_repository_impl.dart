import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/printer_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/print_job.dart';
import '../../domain/entities/printer_device.dart';
import '../../domain/repositories/printer_repository.dart';
import '../../domain/value_objects/print_content.dart';
import '../datasources/printer_data_source.dart';
import '../models/print_job_model.dart';
import '../models/printer_device_model.dart';

/// Implementation of PrinterRepository
class PrinterRepositoryImpl implements PrinterRepository {
  final PrinterDataSource _dataSource;
  final Uuid _uuid;
  final Map<String, PrintJobModel> _printJobs = {};

  PrinterRepositoryImpl({required PrinterDataSource dataSource, Uuid? uuid})
    : _dataSource = dataSource,
      _uuid = uuid ?? const Uuid();

  @override
  Future<Result<List<PrinterDevice>>> scanBluetoothDevices() async {
    try {
      final devices = await _dataSource.scanBluetoothDevices();
      return Right(devices.map((d) => d.toEntity()).toList());
    } on BluetoothException catch (e) {
      return Left(BluetoothFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(PrinterFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Result<List<PrinterDevice>>> scanNetworkDevices({
    String subnet = '192.168.1',
    int port = PrinterConstants.defaultTcpPort,
  }) async {
    try {
      final devices = await _dataSource.scanNetworkDevices(
        subnet: subnet,
        port: port,
      );
      return Right(devices.map((d) => d.toEntity()).toList());
    } on TcpException catch (e) {
      return Left(TcpFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(PrinterFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Result<List<PrinterDevice>>> scanUsbDevices() async {
    try {
      final devices = await _dataSource.scanUsbDevices();
      return Right(devices.map((d) => d.toEntity()).toList());
    } on UsbException catch (e) {
      return Left(UsbFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(PrinterFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Result<List<PrinterDevice>>> getRegisteredPrinters() async {
    try {
      final printers = await _dataSource.getRegisteredPrinters();
      return Right(printers.map((p) => p.toEntity()).toList());
    } catch (e) {
      return Left(PrinterFailure(message: 'Failed to get printers: $e'));
    }
  }

  @override
  Future<Result<PrinterDevice>> registerPrinter(PrinterDevice printer) async {
    try {
      final model = PrinterDeviceModel.fromEntity(printer);
      final registered = await _dataSource.registerPrinter(model);
      return Right(registered.toEntity());
    } catch (e) {
      return Left(PrinterFailure(message: 'Failed to register printer: $e'));
    }
  }

  @override
  Future<Result<PrinterDevice>> updatePrinter(PrinterDevice printer) async {
    try {
      final model = PrinterDeviceModel.fromEntity(printer);
      final updated = await _dataSource.updatePrinter(model);
      return Right(updated.toEntity());
    } on PrinterException catch (e) {
      return Left(DeviceNotFoundFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(PrinterFailure(message: 'Failed to update printer: $e'));
    }
  }

  @override
  Future<Result<void>> removePrinter(String printerId) async {
    try {
      await _dataSource.removePrinter(printerId);
      return const Right(null);
    } catch (e) {
      return Left(PrinterFailure(message: 'Failed to remove printer: $e'));
    }
  }

  @override
  Future<Result<PrinterDevice>> connectToPrinter(PrinterDevice printer) async {
    try {
      final model = PrinterDeviceModel.fromEntity(printer);
      final connected = await _dataSource.connectToPrinter(model);
      return Right(connected.toEntity());
    } on ConnectionException catch (e) {
      return Left(ConnectionFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(ConnectionFailure(message: 'Failed to connect: $e'));
    }
  }

  @override
  Future<Result<void>> disconnectFromPrinter(PrinterDevice printer) async {
    try {
      final model = PrinterDeviceModel.fromEntity(printer);
      await _dataSource.disconnectFromPrinter(model);
      return const Right(null);
    } on ConnectionException catch (e) {
      return Left(ConnectionFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(ConnectionFailure(message: 'Failed to disconnect: $e'));
    }
  }

  @override
  Future<Result<bool>> isPrinterConnected(PrinterDevice printer) async {
    try {
      final model = PrinterDeviceModel.fromEntity(printer);
      final isConnected = await _dataSource.isPrinterConnected(model);
      return Right(isConnected);
    } catch (e) {
      return Left(PrinterFailure(message: 'Failed to check connection: $e'));
    }
  }

  @override
  Future<Result<PrintJob>> printReceipt(
    PrinterDevice printer,
    ReceiptContent content,
  ) async {
    final jobId = _uuid.v4();
    var job = PrintJobModel.create(
      id: jobId,
      printer: printer,
      content: content,
    );

    _printJobs[jobId] = job;

    try {
      job = job.copyWith(status: PrintJobStatus.inProgress);
      _printJobs[jobId] = job;

      final model = PrinterDeviceModel.fromEntity(printer);
      await _dataSource.printReceipt(model, content);

      job = job.copyWith(
        status: PrintJobStatus.completed,
        completedAt: DateTime.now(),
      );
      _printJobs[jobId] = job;

      return Right(job.toEntity());
    } on PrintJobException catch (e) {
      job = job.copyWith(
        status: PrintJobStatus.failed,
        errorMessage: e.message,
        completedAt: DateTime.now(),
      );
      _printJobs[jobId] = job;
      return Left(PrintJobFailure(message: e.message, code: e.code));
    } catch (e) {
      job = job.copyWith(
        status: PrintJobStatus.failed,
        errorMessage: e.toString(),
        completedAt: DateTime.now(),
      );
      _printJobs[jobId] = job;
      return Left(PrintJobFailure(message: 'Print failed: $e'));
    }
  }

  @override
  Future<Result<PrintJob>> printSticker(
    PrinterDevice printer,
    StickerContent content,
  ) async {
    final jobId = _uuid.v4();
    var job = PrintJobModel.create(
      id: jobId,
      printer: printer,
      content: content,
    );

    _printJobs[jobId] = job;

    try {
      job = job.copyWith(status: PrintJobStatus.inProgress);
      _printJobs[jobId] = job;

      final model = PrinterDeviceModel.fromEntity(printer);
      await _dataSource.printSticker(model, content);

      job = job.copyWith(
        status: PrintJobStatus.completed,
        completedAt: DateTime.now(),
      );
      _printJobs[jobId] = job;

      return Right(job.toEntity());
    } on PrintJobException catch (e) {
      job = job.copyWith(
        status: PrintJobStatus.failed,
        errorMessage: e.message,
        completedAt: DateTime.now(),
      );
      _printJobs[jobId] = job;
      return Left(PrintJobFailure(message: e.message, code: e.code));
    } catch (e) {
      job = job.copyWith(
        status: PrintJobStatus.failed,
        errorMessage: e.toString(),
        completedAt: DateTime.now(),
      );
      _printJobs[jobId] = job;
      return Left(PrintJobFailure(message: 'Print failed: $e'));
    }
  }

  @override
  Future<Result<PrintJob>> printRaw(
    PrinterDevice printer,
    List<int> bytes,
  ) async {
    final jobId = _uuid.v4();
    var job = PrintJobModel.createRaw(
      id: jobId,
      printer: printer,
    );

    _printJobs[jobId] = job;

    try {
      job = job.copyWith(status: PrintJobStatus.inProgress);
      _printJobs[jobId] = job;

      final model = PrinterDeviceModel.fromEntity(printer);
      await _dataSource.printRaw(model, bytes);

      job = job.copyWith(
        status: PrintJobStatus.completed,
        completedAt: DateTime.now(),
      );
      _printJobs[jobId] = job;

      return Right(job.toEntity());
    } on PrintJobException catch (e) {
      job = job.copyWith(
        status: PrintJobStatus.failed,
        errorMessage: e.message,
        completedAt: DateTime.now(),
      );
      _printJobs[jobId] = job;
      return Left(PrintJobFailure(message: e.message, code: e.code));
    } catch (e) {
      job = job.copyWith(
        status: PrintJobStatus.failed,
        errorMessage: e.toString(),
        completedAt: DateTime.now(),
      );
      _printJobs[jobId] = job;
      return Left(PrintJobFailure(message: 'Print failed: $e'));
    }
  }

  @override
  Future<Result<BatchPrintResult>> printRawToMultiple(
    List<PrinterDevice> printers,
    List<int> bytes,
  ) async {
    final stopwatch = Stopwatch()..start();
    final List<PrintJob> jobs = [];
    int successCount = 0;
    int failureCount = 0;

    // Execute all print jobs in parallel
    final futures = printers.map((printer) => printRaw(printer, bytes));
    final results = await Future.wait(futures);

    for (final result in results) {
      result.fold((failure) => failureCount++, (job) {
        jobs.add(job);
        if (job.status == PrintJobStatus.completed) {
          successCount++;
        } else {
          failureCount++;
        }
      });
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

  @override
  Future<Result<BatchPrintResult>> printToMultiplePrinters(
    List<PrinterDevice> printers,
    PrintContent content,
  ) async {
    final stopwatch = Stopwatch()..start();
    final List<PrintJob> jobs = [];
    int successCount = 0;
    int failureCount = 0;

    // Execute all print jobs in parallel
    final futures = printers.map((printer) async {
      if (content is ReceiptContent) {
        return printReceipt(printer, content);
      } else if (content is StickerContent) {
        return printSticker(printer, content);
      }
      return const Left<Failure, PrintJob>(
        PrintJobFailure(message: 'Unknown content type'),
      );
    });

    final results = await Future.wait(futures);

    for (final result in results) {
      result.fold((failure) => failureCount++, (job) {
        jobs.add(job);
        if (job.status == PrintJobStatus.completed) {
          successCount++;
        } else {
          failureCount++;
        }
      });
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

  @override
  Future<Result<PrintJob>> getPrintJobStatus(String jobId) async {
    final job = _printJobs[jobId];
    if (job == null) {
      return Left(
        DeviceNotFoundFailure(
          message: 'Print job not found: $jobId',
          code: 'JOB_NOT_FOUND',
        ),
      );
    }
    return Right(job.toEntity());
  }

  @override
  Future<Result<void>> cancelPrintJob(String jobId) async {
    final job = _printJobs[jobId];
    if (job == null) {
      return Left(
        DeviceNotFoundFailure(
          message: 'Print job not found: $jobId',
          code: 'JOB_NOT_FOUND',
        ),
      );
    }

    if (job.status == PrintJobStatus.completed ||
        job.status == PrintJobStatus.cancelled) {
      return Left(
        PrintJobFailure(
          message: 'Cannot cancel job with status: ${job.status}',
          code: 'INVALID_STATUS',
        ),
      );
    }

    _printJobs[jobId] = job.copyWith(
      status: PrintJobStatus.cancelled,
      completedAt: DateTime.now(),
    );

    return const Right(null);
  }

  @override
  Future<Result<List<PrintJob>>> getPrintHistory({
    int limit = 50,
    DateTime? fromDate,
  }) async {
    var jobs = _printJobs.values.toList();

    if (fromDate != null) {
      jobs = jobs.where((j) => j.createdAt.isAfter(fromDate)).toList();
    }

    jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (jobs.length > limit) {
      jobs = jobs.take(limit).toList();
    }

    return Right(jobs.map((j) => j.toEntity()).toList());
  }

  @override
  Future<void> warmUpConnections() async {
    await _dataSource.warmUpPrinterConnections();
  }
}

