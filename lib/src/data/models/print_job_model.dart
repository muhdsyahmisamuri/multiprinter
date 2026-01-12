import '../../core/constants/printer_constants.dart';
import '../../domain/entities/print_job.dart';
import '../../domain/entities/printer_device.dart';
import '../../domain/value_objects/print_content.dart';

/// Data model for PrintJob with serialization support
class PrintJobModel extends PrintJob {
  const PrintJobModel({
    required super.id,
    required super.printer,
    required super.content,
    super.status = PrintJobStatus.pending,
    required super.createdAt,
    super.completedAt,
    super.errorMessage,
    super.retryCount = 0,
  });

  /// Create from domain entity
  factory PrintJobModel.fromEntity(PrintJob entity) {
    return PrintJobModel(
      id: entity.id,
      printer: entity.printer,
      content: entity.content,
      status: entity.status,
      createdAt: entity.createdAt,
      completedAt: entity.completedAt,
      errorMessage: entity.errorMessage,
      retryCount: entity.retryCount,
    );
  }

  /// Create a new print job
  factory PrintJobModel.create({
    required String id,
    required PrinterDevice printer,
    required PrintContent content,
  }) {
    return PrintJobModel(
      id: id,
      printer: printer,
      content: content,
      status: PrintJobStatus.pending,
      createdAt: DateTime.now(),
    );
  }

  /// Create a raw print job (for direct byte printing)
  factory PrintJobModel.createRaw({
    required String id,
    required PrinterDevice printer,
  }) {
    return PrintJobModel(
      id: id,
      printer: printer,
      content: const RawContent(bytes: []),
      status: PrintJobStatus.pending,
      createdAt: DateTime.now(),
    );
  }

  /// Convert to domain entity
  PrintJob toEntity() {
    return PrintJob(
      id: id,
      printer: printer,
      content: content,
      status: status,
      createdAt: createdAt,
      completedAt: completedAt,
      errorMessage: errorMessage,
      retryCount: retryCount,
    );
  }

  @override
  PrintJobModel copyWith({
    String? id,
    PrinterDevice? printer,
    PrintContent? content,
    PrintJobStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    String? errorMessage,
    int? retryCount,
  }) {
    return PrintJobModel(
      id: id ?? this.id,
      printer: printer ?? this.printer,
      content: content ?? this.content,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

