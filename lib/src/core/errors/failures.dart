import 'package:equatable/equatable.dart';

/// Base failure class for domain layer errors
abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];
}

/// Printer-related failures
class PrinterFailure extends Failure {
  const PrinterFailure({required super.message, super.code});
}

/// Connection failures (Bluetooth, TCP, USB, LAN)
class ConnectionFailure extends Failure {
  const ConnectionFailure({required super.message, super.code});
}

/// Bluetooth specific failures
class BluetoothFailure extends ConnectionFailure {
  const BluetoothFailure({required super.message, super.code});
}

/// TCP/LAN specific failures
class TcpFailure extends ConnectionFailure {
  const TcpFailure({required super.message, super.code});
}

/// USB specific failures
class UsbFailure extends ConnectionFailure {
  const UsbFailure({required super.message, super.code});
}

/// Print job failures
class PrintJobFailure extends Failure {
  const PrintJobFailure({required super.message, super.code});
}

/// Device not found failure
class DeviceNotFoundFailure extends Failure {
  const DeviceNotFoundFailure({required super.message, super.code});
}

/// Permission denied failure
class PermissionDeniedFailure extends Failure {
  const PermissionDeniedFailure({required super.message, super.code});
}

