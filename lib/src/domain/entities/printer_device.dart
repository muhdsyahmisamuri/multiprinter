import 'package:equatable/equatable.dart';
import '../../core/constants/printer_constants.dart';
import '../value_objects/printer_address.dart';

/// Domain entity representing a printer device
class PrinterDevice extends Equatable {
  final String id;
  final String name;
  final PrinterAddress address;
  final PrinterRole role;
  final bool isConnected;
  final List<PrintDocumentType> supportedDocuments;
  final DateTime? lastConnectedAt;

  const PrinterDevice({
    required this.id,
    required this.name,
    required this.address,
    this.role = PrinterRole.general,
    this.isConnected = false,
    this.supportedDocuments = const [
      PrintDocumentType.receipt,
      PrintDocumentType.sticker,
    ],
    this.lastConnectedAt,
  });

  /// Connection type from address
  PrinterConnectionType get connectionType => address.connectionType;

  /// Check if printer supports receipts
  bool get supportsReceipts =>
      supportedDocuments.contains(PrintDocumentType.receipt);

  /// Check if printer supports stickers
  bool get supportsStickers =>
      supportedDocuments.contains(PrintDocumentType.sticker);

  /// Create a copy with updated fields
  PrinterDevice copyWith({
    String? id,
    String? name,
    PrinterAddress? address,
    PrinterRole? role,
    bool? isConnected,
    List<PrintDocumentType>? supportedDocuments,
    DateTime? lastConnectedAt,
  }) {
    return PrinterDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      role: role ?? this.role,
      isConnected: isConnected ?? this.isConnected,
      supportedDocuments: supportedDocuments ?? this.supportedDocuments,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    address,
    role,
    isConnected,
    supportedDocuments,
    lastConnectedAt,
  ];
}

