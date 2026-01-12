import '../../core/constants/printer_constants.dart';
import '../../domain/entities/printer_device.dart';
import '../../domain/value_objects/printer_address.dart';

/// Data model for PrinterDevice with serialization support
class PrinterDeviceModel extends PrinterDevice {
  const PrinterDeviceModel({
    required super.id,
    required super.name,
    required super.address,
    super.role = PrinterRole.general,
    super.isConnected = false,
    super.supportedDocuments = const [
      PrintDocumentType.receipt,
      PrintDocumentType.sticker,
    ],
    super.lastConnectedAt,
  });

  /// Create from domain entity
  factory PrinterDeviceModel.fromEntity(PrinterDevice entity) {
    return PrinterDeviceModel(
      id: entity.id,
      name: entity.name,
      address: entity.address,
      role: entity.role,
      isConnected: entity.isConnected,
      supportedDocuments: entity.supportedDocuments,
      lastConnectedAt: entity.lastConnectedAt,
    );
  }

  /// Create from JSON map
  factory PrinterDeviceModel.fromJson(Map<String, dynamic> json) {
    return PrinterDeviceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      address: PrinterAddress(
        address: json['address'] as String,
        port: json['port'] as int?,
        connectionType: PrinterConnectionType.values.firstWhere(
          (e) => e.name == json['connectionType'],
          orElse: () => PrinterConnectionType.bluetooth,
        ),
      ),
      role: PrinterRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => PrinterRole.general,
      ),
      isConnected: json['isConnected'] as bool? ?? false,
      supportedDocuments:
          (json['supportedDocuments'] as List<dynamic>?)
              ?.map(
                (e) => PrintDocumentType.values.firstWhere(
                  (type) => type.name == e,
                  orElse: () => PrintDocumentType.receipt,
                ),
              )
              .toList() ??
          const [PrintDocumentType.receipt, PrintDocumentType.sticker],
      lastConnectedAt: json['lastConnectedAt'] != null
          ? DateTime.parse(json['lastConnectedAt'] as String)
          : null,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address.address,
      'port': address.port,
      'connectionType': address.connectionType.name,
      'role': role.name,
      'isConnected': isConnected,
      'supportedDocuments': supportedDocuments.map((e) => e.name).toList(),
      'lastConnectedAt': lastConnectedAt?.toIso8601String(),
    };
  }

  /// Convert to domain entity
  PrinterDevice toEntity() {
    return PrinterDevice(
      id: id,
      name: name,
      address: address,
      role: role,
      isConnected: isConnected,
      supportedDocuments: supportedDocuments,
      lastConnectedAt: lastConnectedAt,
    );
  }

  @override
  PrinterDeviceModel copyWith({
    String? id,
    String? name,
    PrinterAddress? address,
    PrinterRole? role,
    bool? isConnected,
    List<PrintDocumentType>? supportedDocuments,
    DateTime? lastConnectedAt,
  }) {
    return PrinterDeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      role: role ?? this.role,
      isConnected: isConnected ?? this.isConnected,
      supportedDocuments: supportedDocuments ?? this.supportedDocuments,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
    );
  }
}

