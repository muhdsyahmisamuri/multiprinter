import 'package:dartz/dartz.dart';
import '../../core/constants/printer_constants.dart';
import '../../core/utils/result.dart';
import '../entities/printer_device.dart';
import '../repositories/printer_repository.dart';

/// Use case for scanning available printers
class ScanPrintersUseCase {
  final PrinterRepository _repository;

  ScanPrintersUseCase(this._repository);

  /// Scan for Bluetooth printers
  Future<Result<List<PrinterDevice>>> scanBluetooth() async {
    return _repository.scanBluetoothDevices();
  }

  /// Scan for network printers
  Future<Result<List<PrinterDevice>>> scanNetwork({
    String subnet = '192.168.1',
    int port = PrinterConstants.defaultTcpPort,
  }) async {
    return _repository.scanNetworkDevices(subnet: subnet, port: port);
  }

  /// Scan for USB printers (Android only)
  Future<Result<List<PrinterDevice>>> scanUsb() async {
    return _repository.scanUsbDevices();
  }

  /// Scan all connection types
  Future<Result<List<PrinterDevice>>> scanAll() async {
    final List<PrinterDevice> allDevices = [];

    // Scan Bluetooth
    final bluetoothResult = await scanBluetooth();
    bluetoothResult.fold(
      (_) {}, // Ignore failures for partial results
      (devices) => allDevices.addAll(devices),
    );

    // Scan Network
    final networkResult = await scanNetwork();
    networkResult.fold((_) {}, (devices) => allDevices.addAll(devices));

    // Scan USB
    final usbResult = await scanUsb();
    usbResult.fold((_) {}, (devices) => allDevices.addAll(devices));

    return Right(allDevices);
  }
}

