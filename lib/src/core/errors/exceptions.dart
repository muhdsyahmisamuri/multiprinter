/// Base exception class for data layer errors
class AppException implements Exception {
  final String message;
  final String? code;

  const AppException({required this.message, this.code});

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// Printer-related exception
class PrinterException extends AppException {
  const PrinterException({required super.message, super.code});
}

/// Connection exception
class ConnectionException extends AppException {
  const ConnectionException({required super.message, super.code});
}

/// Bluetooth exception
class BluetoothException extends ConnectionException {
  const BluetoothException({required super.message, super.code});
}

/// TCP/LAN exception
class TcpException extends ConnectionException {
  const TcpException({required super.message, super.code});
}

/// USB exception
class UsbException extends ConnectionException {
  const UsbException({required super.message, super.code});
}

/// Print job exception
class PrintJobException extends AppException {
  const PrintJobException({required super.message, super.code});
}

