/// A Flutter package for multi-printer management supporting Bluetooth,
/// TCP/LAN, and USB printers with simultaneous printing capabilities.
///
/// This package provides a complete solution for managing multiple thermal
/// printers in a POS (Point of Sale) environment, including:
///
/// - **Multi-connection support**: Bluetooth, TCP/IP, LAN, and USB
/// - **Simultaneous printing**: Print to multiple printers at once
/// - **Receipt printing**: ESC/POS format with store headers, items, and footers
/// - **Sticker/label printing**: TSPL format for label printers
/// - **Clean Architecture**: Domain-driven design with proper separation of concerns
/// - **Ready-to-use UI widgets**: Printer cards, dialogs, and provider integration
///
/// ## Quick Start
///
/// ```dart
/// import 'package:multiprinter/multiprinter.dart';
///
/// // Initialize the package
/// await MultiPrinter.init();
///
/// // Access the printer provider
/// final provider = MultiPrinter.printerProvider;
///
/// // Scan for printers
/// await provider.scanBluetoothPrinters();
///
/// // Print a receipt
/// final receipt = ReceiptContent(
///   storeName: 'My Store',
///   lines: [
///     ReceiptLine.text('Coffee', bold: true),
///     ReceiptLine.leftRight('1x Coffee', '\$5.00'),
///     ReceiptLine.divider(),
///     ReceiptLine.leftRight('TOTAL', '\$5.00'),
///   ],
///   footer: 'Thank you!',
/// );
///
/// await provider.printReceiptToSelected(receipt);
/// ```
library;

// Core exports
export 'src/core/constants/printer_constants.dart';
export 'src/core/errors/exceptions.dart';
export 'src/core/errors/failures.dart';
export 'src/core/utils/result.dart';
export 'src/core/utils/tspl_builder.dart';
export 'src/core/services/permission_service.dart';

// Domain exports
export 'src/domain/entities/print_job.dart';
export 'src/domain/entities/printer_device.dart';
export 'src/domain/repositories/printer_repository.dart';
export 'src/domain/usecases/connect_printer_usecase.dart';
export 'src/domain/usecases/manage_printers_usecase.dart';
export 'src/domain/usecases/print_usecase.dart';
export 'src/domain/usecases/scan_printers_usecase.dart';
export 'src/domain/value_objects/print_content.dart';
export 'src/domain/value_objects/printer_address.dart';

// Data exports
export 'src/data/datasources/printer_data_source.dart';
export 'src/data/models/print_job_model.dart';
export 'src/data/models/printer_device_model.dart';
export 'src/data/repositories/printer_repository_impl.dart';

// Presentation exports
export 'src/presentation/providers/printer_provider.dart';
export 'src/presentation/widgets/add_printer_dialog.dart';
export 'src/presentation/widgets/permission_request_widget.dart';
export 'src/presentation/widgets/print_content_dialog.dart';
export 'src/presentation/widgets/printer_card.dart';

// Dependency injection
export 'src/core/di/injection_container.dart';

// Main entry point
export 'src/multiprinter_base.dart';

