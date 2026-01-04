import 'package:equatable/equatable.dart';
import '../../core/constants/printer_constants.dart';
import '../value_objects/print_content.dart';
import 'printer_device.dart';

/// Domain entity representing a print job
class PrintJob extends Equatable {
  final String id;
  final PrinterDevice printer;
  final PrintContent content;
  final PrintJobStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? errorMessage;
  final int retryCount;

  const PrintJob({
    required this.id,
    required this.printer,
    required this.content,
    this.status = PrintJobStatus.pending,
    required this.createdAt,
    this.completedAt,
    this.errorMessage,
    this.retryCount = 0,
  });

  /// Duration of the print job
  Duration? get duration {
    if (completedAt == null) return null;
    return completedAt!.difference(createdAt);
  }

  /// Check if job is complete (success or failure)
  bool get isComplete =>
      status == PrintJobStatus.completed || status == PrintJobStatus.failed;

  /// Check if job can be retried
  bool get canRetry =>
      status == PrintJobStatus.failed &&
      retryCount < PrinterConstants.maxRetryAttempts;

  /// Create a copy with updated fields
  PrintJob copyWith({
    String? id,
    PrinterDevice? printer,
    PrintContent? content,
    PrintJobStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    String? errorMessage,
    int? retryCount,
  }) {
    return PrintJob(
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

  @override
  List<Object?> get props => [
    id,
    printer,
    content,
    status,
    createdAt,
    completedAt,
    errorMessage,
    retryCount,
  ];
}

/// Result of a batch print operation
class BatchPrintResult extends Equatable {
  final List<PrintJob> jobs;
  final int successCount;
  final int failureCount;
  final Duration totalDuration;

  const BatchPrintResult({
    required this.jobs,
    required this.successCount,
    required this.failureCount,
    required this.totalDuration,
  });

  /// Check if all jobs succeeded
  bool get allSucceeded => failureCount == 0;

  /// Check if any job succeeded
  bool get anySucceeded => successCount > 0;

  /// Get failed jobs
  List<PrintJob> get failedJobs =>
      jobs.where((job) => job.status == PrintJobStatus.failed).toList();

  /// Get successful jobs
  List<PrintJob> get successfulJobs =>
      jobs.where((job) => job.status == PrintJobStatus.completed).toList();

  @override
  List<Object?> get props => [jobs, successCount, failureCount, totalDuration];
}

