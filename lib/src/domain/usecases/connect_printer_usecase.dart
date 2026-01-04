import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../entities/printer_device.dart';
import '../repositories/printer_repository.dart';

/// Use case for connecting to printers
class ConnectPrinterUseCase {
  final PrinterRepository _repository;

  ConnectPrinterUseCase(this._repository);

  /// Connect to a single printer
  Future<Result<PrinterDevice>> connect(PrinterDevice printer) async {
    return _repository.connectToPrinter(printer);
  }

  /// Disconnect from a printer
  Future<Result<void>> disconnect(PrinterDevice printer) async {
    return _repository.disconnectFromPrinter(printer);
  }

  /// Connect to multiple printers simultaneously
  Future<Result<List<PrinterDevice>>> connectMultiple(
    List<PrinterDevice> printers,
  ) async {
    final List<PrinterDevice> connectedPrinters = [];
    final List<String> errors = [];

    // Connect to all printers in parallel
    final results = await Future.wait(
      printers.map((printer) => _repository.connectToPrinter(printer)),
    );

    for (int i = 0; i < results.length; i++) {
      results[i].fold(
        (failure) => errors.add('${printers[i].name}: ${failure.message}'),
        (printer) => connectedPrinters.add(printer),
      );
    }

    if (connectedPrinters.isEmpty) {
      return Left(
        ConnectionFailure(
          message: 'Failed to connect to any printer: ${errors.join(", ")}',
        ),
      );
    }

    return Right(connectedPrinters);
  }

  /// Disconnect from all printers
  Future<Result<void>> disconnectAll(List<PrinterDevice> printers) async {
    await Future.wait(
      printers.map((printer) => _repository.disconnectFromPrinter(printer)),
    );
    return const Right(null);
  }
}

