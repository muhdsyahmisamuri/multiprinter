import 'package:dartz/dartz.dart';
import '../../core/constants/printer_constants.dart';
import '../../core/utils/result.dart';
import '../entities/printer_device.dart';
import '../repositories/printer_repository.dart';

/// Use case for managing registered printers
class ManagePrintersUseCase {
  final PrinterRepository _repository;

  ManagePrintersUseCase(this._repository);

  /// Get all registered printers
  Future<Result<List<PrinterDevice>>> getAll() async {
    return _repository.getRegisteredPrinters();
  }

  /// Register a new printer
  Future<Result<PrinterDevice>> register(PrinterDevice printer) async {
    return _repository.registerPrinter(printer);
  }

  /// Update printer details
  Future<Result<PrinterDevice>> update(PrinterDevice printer) async {
    return _repository.updatePrinter(printer);
  }

  /// Remove a registered printer
  Future<Result<void>> remove(String printerId) async {
    return _repository.removePrinter(printerId);
  }

  /// Get connected printers
  Future<Result<List<PrinterDevice>>> getConnected() async {
    final result = await _repository.getRegisteredPrinters();
    return result.fold(
      (failure) => Left(failure),
      (printers) => Right(printers.where((p) => p.isConnected).toList()),
    );
  }

  /// Get printers by role
  Future<Result<List<PrinterDevice>>> getByRole(PrinterRole role) async {
    final result = await _repository.getRegisteredPrinters();
    return result.fold(
      (failure) => Left(failure),
      (printers) => Right(printers.where((p) => p.role == role).toList()),
    );
  }

  /// Warm up network connections to TCP printers
  /// Call this before printing to reduce first-print latency
  Future<void> warmUpConnections() async {
    await _repository.warmUpConnections();
  }
}

