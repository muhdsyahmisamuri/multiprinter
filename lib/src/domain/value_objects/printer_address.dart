import 'package:equatable/equatable.dart';
import '../../core/constants/printer_constants.dart';

/// Value object representing a printer address
class PrinterAddress extends Equatable {
  final String address;
  final int? port;
  final PrinterConnectionType connectionType;

  const PrinterAddress({
    required this.address,
    this.port,
    required this.connectionType,
  });

  /// Create Bluetooth address
  factory PrinterAddress.bluetooth(String macAddress) {
    return PrinterAddress(
      address: macAddress,
      connectionType: PrinterConnectionType.bluetooth,
    );
  }

  /// Create TCP address
  factory PrinterAddress.tcp(
    String ipAddress, {
    int port = PrinterConstants.defaultTcpPort,
  }) {
    return PrinterAddress(
      address: ipAddress,
      port: port,
      connectionType: PrinterConnectionType.tcp,
    );
  }

  /// Create LAN address
  factory PrinterAddress.lan(
    String ipAddress, {
    int port = PrinterConstants.defaultTcpPort,
  }) {
    return PrinterAddress(
      address: ipAddress,
      port: port,
      connectionType: PrinterConnectionType.lan,
    );
  }

  /// Create USB address
  factory PrinterAddress.usb(String devicePath) {
    return PrinterAddress(
      address: devicePath,
      connectionType: PrinterConnectionType.usb,
    );
  }

  /// Get formatted address string
  String get formattedAddress {
    if (port != null) {
      return '$address:$port';
    }
    return address;
  }

  /// Check if address is valid
  bool get isValid {
    switch (connectionType) {
      case PrinterConnectionType.bluetooth:
        return _isValidMacAddress(address);
      case PrinterConnectionType.tcp:
      case PrinterConnectionType.lan:
        return _isValidIpAddress(address);
      case PrinterConnectionType.usb:
        return address.isNotEmpty;
    }
  }

  bool _isValidMacAddress(String mac) {
    final macRegex = RegExp(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$');
    return macRegex.hasMatch(mac);
  }

  bool _isValidIpAddress(String ip) {
    final ipRegex = RegExp(
      r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
    );
    return ipRegex.hasMatch(ip);
  }

  @override
  List<Object?> get props => [address, port, connectionType];
}

