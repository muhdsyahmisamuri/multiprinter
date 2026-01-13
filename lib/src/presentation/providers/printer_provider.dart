import 'package:flutter/foundation.dart';
import '../../core/constants/printer_constants.dart';
import '../../core/services/permission_service.dart';
import '../../core/utils/tspl_builder.dart';
import '../../domain/entities/print_job.dart';
import '../../domain/entities/printer_device.dart';
import '../../domain/usecases/connect_printer_usecase.dart';
import '../../domain/usecases/manage_printers_usecase.dart';
import '../../domain/usecases/print_usecase.dart';
import '../../domain/usecases/scan_printers_usecase.dart';
import '../../domain/value_objects/print_content.dart';
import '../../domain/value_objects/printer_address.dart';

/// Provider state for printer operations
enum PrinterProviderState {
  initial,
  loading,
  scanning,
  connecting,
  printing,
  success,
  error,
}

/// Provider for managing printer state and operations
class PrinterProvider extends ChangeNotifier {
  final ScanPrintersUseCase _scanUseCase;
  final ConnectPrinterUseCase _connectUseCase;
  final ManagePrintersUseCase _manageUseCase;
  final PrintUseCase _printUseCase;

  PrinterProvider({
    required ScanPrintersUseCase scanUseCase,
    required ConnectPrinterUseCase connectUseCase,
    required ManagePrintersUseCase manageUseCase,
    required PrintUseCase printUseCase,
  }) : _scanUseCase = scanUseCase,
       _connectUseCase = connectUseCase,
       _manageUseCase = manageUseCase,
       _printUseCase = printUseCase;

  // Permission service
  final PermissionService _permissionService = PermissionService.instance;

  // State
  PrinterProviderState _state = PrinterProviderState.initial;
  String? _errorMessage;
  List<PrinterDevice> _scannedPrinters = [];
  List<PrinterDevice> _registeredPrinters = [];
  List<PrinterDevice> _selectedPrinters = [];
  BatchPrintResult? _lastPrintResult;
  bool _hasPermissions = false;

  // Getters
  PrinterProviderState get state => _state;
  String? get errorMessage => _errorMessage;
  List<PrinterDevice> get scannedPrinters => _scannedPrinters;
  List<PrinterDevice> get registeredPrinters => _registeredPrinters;
  List<PrinterDevice> get selectedPrinters => _selectedPrinters;
  List<PrinterDevice> get connectedPrinters =>
      _registeredPrinters.where((p) => p.isConnected).toList();
  BatchPrintResult? get lastPrintResult => _lastPrintResult;
  bool get hasPermissions => _hasPermissions;
  bool get isLoading =>
      _state == PrinterProviderState.loading ||
      _state == PrinterProviderState.scanning ||
      _state == PrinterProviderState.connecting ||
      _state == PrinterProviderState.printing;

  // State management
  void _setState(PrinterProviderState newState, {String? error}) {
    _state = newState;
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Network warm-up for TCP printers
  Future<void> warmUpConnections() async {
    await _manageUseCase.warmUpConnections();
  }

  // Permission handling
  Future<void> checkPermissions() async {
    _hasPermissions = await _permissionService.hasAllPermissions();
    notifyListeners();
  }

  Future<PermissionResult> requestPermissions() async {
    final result = await _permissionService.requestAllPermissions();
    _hasPermissions = result.allGranted;
    notifyListeners();
    return result;
  }

  Future<void> openAppSettings() async {
    await _permissionService.openSettings();
  }

  // Scanning
  Future<void> scanBluetoothPrinters() async {
    // Check permissions first
    if (!_hasPermissions) {
      final result = await requestPermissions();
      if (!result.allGranted) {
        _setState(
          PrinterProviderState.error,
          error: 'Bluetooth permissions required. ${result.summary}',
        );
        return;
      }
    }
    _setState(PrinterProviderState.scanning);

    final result = await _scanUseCase.scanBluetooth();
    result.fold(
      (failure) =>
          _setState(PrinterProviderState.error, error: failure.message),
      (printers) {
        _scannedPrinters = _mergeScannedPrinters(printers);
        _setState(PrinterProviderState.success);
      },
    );
  }

  Future<void> scanNetworkPrinters({String subnet = '192.168.1'}) async {
    _setState(PrinterProviderState.scanning);

    final result = await _scanUseCase.scanNetwork(subnet: subnet);
    result.fold(
      (failure) =>
          _setState(PrinterProviderState.error, error: failure.message),
      (printers) {
        _scannedPrinters = _mergeScannedPrinters(printers);
        _setState(PrinterProviderState.success);
      },
    );
  }

  Future<void> scanUsbPrinters() async {
    _setState(PrinterProviderState.scanning);

    final result = await _scanUseCase.scanUsb();
    result.fold(
      (failure) =>
          _setState(PrinterProviderState.error, error: failure.message),
      (printers) {
        _scannedPrinters = _mergeScannedPrinters(printers);
        _setState(PrinterProviderState.success);
      },
    );
  }

  /// Merge new printers with existing scanned printers, avoiding duplicates.
  /// Uses printer ID and address to identify duplicates.
  List<PrinterDevice> _mergeScannedPrinters(List<PrinterDevice> newPrinters) {
    final Map<String, PrinterDevice> merged = {};
    
    // Add existing printers first
    for (final printer in _scannedPrinters) {
      merged[printer.id] = printer;
    }
    
    // Add or update with new printers
    for (final printer in newPrinters) {
      // Check by ID first
      if (!merged.containsKey(printer.id)) {
        // Also check by address to catch printers with different IDs but same address
        final existingByAddress = merged.values.where(
          (p) => p.address.address == printer.address.address,
        ).firstOrNull;
        
        if (existingByAddress == null) {
          merged[printer.id] = printer;
        }
      }
    }
    
    return merged.values.toList();
  }

  Future<void> scanAllPrinters() async {
    _setState(PrinterProviderState.scanning);
    _scannedPrinters = [];

    final result = await _scanUseCase.scanAll();
    result.fold(
      (failure) =>
          _setState(PrinterProviderState.error, error: failure.message),
      (printers) {
        _scannedPrinters = printers;
        _setState(PrinterProviderState.success);
      },
    );
  }

  // Registration
  Future<void> loadRegisteredPrinters() async {
    _setState(PrinterProviderState.loading);

    final result = await _manageUseCase.getAll();
    result.fold(
      (failure) =>
          _setState(PrinterProviderState.error, error: failure.message),
      (printers) {
        _registeredPrinters = printers;
        _setState(PrinterProviderState.success);
      },
    );
  }

  Future<void> registerPrinter(PrinterDevice printer) async {
    _setState(PrinterProviderState.loading);

    final result = await _manageUseCase.register(printer);
    result.fold(
      (failure) =>
          _setState(PrinterProviderState.error, error: failure.message),
      (registered) {
        _registeredPrinters = [..._registeredPrinters, registered];
        _setState(PrinterProviderState.success);
      },
    );
  }

  Future<void> addManualPrinter({
    required String name,
    required String address,
    required PrinterConnectionType connectionType,
    int? port,
    PrinterRole role = PrinterRole.general,
    List<PrintDocumentType> supportedDocuments = const [
      PrintDocumentType.receipt,
      PrintDocumentType.sticker,
    ],
  }) async {
    final printerAddress = PrinterAddress(
      address: address,
      port: port,
      connectionType: connectionType,
    );

    final printer = PrinterDevice(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      address: printerAddress,
      role: role,
      supportedDocuments: supportedDocuments,
    );

    await registerPrinter(printer);
  }

  Future<void> removePrinter(String printerId) async {
    _setState(PrinterProviderState.loading);

    final result = await _manageUseCase.remove(printerId);
    result.fold(
      (failure) =>
          _setState(PrinterProviderState.error, error: failure.message),
      (_) {
        _registeredPrinters.removeWhere((p) => p.id == printerId);
        _selectedPrinters.removeWhere((p) => p.id == printerId);
        _setState(PrinterProviderState.success);
      },
    );
  }

  // Connection
  Future<void> connectToPrinter(PrinterDevice printer) async {
    _setState(PrinterProviderState.connecting);

    final result = await _connectUseCase.connect(printer);
    result.fold(
      (failure) =>
          _setState(PrinterProviderState.error, error: failure.message),
      (connected) {
        final index = _registeredPrinters.indexWhere((p) => p.id == printer.id);
        if (index >= 0) {
          _registeredPrinters[index] = connected;
        }
        _setState(PrinterProviderState.success);
      },
    );
  }

  Future<void> disconnectFromPrinter(PrinterDevice printer) async {
    _setState(PrinterProviderState.loading);

    final result = await _connectUseCase.disconnect(printer);
    result.fold(
      (failure) =>
          _setState(PrinterProviderState.error, error: failure.message),
      (_) {
        final index = _registeredPrinters.indexWhere((p) => p.id == printer.id);
        if (index >= 0) {
          _registeredPrinters[index] = printer.copyWith(isConnected: false);
        }
        _setState(PrinterProviderState.success);
      },
    );
  }

  Future<void> connectToMultiplePrinters(List<PrinterDevice> printers) async {
    _setState(PrinterProviderState.connecting);

    final result = await _connectUseCase.connectMultiple(printers);
    result.fold(
      (failure) =>
          _setState(PrinterProviderState.error, error: failure.message),
      (connected) {
        for (final connectedPrinter in connected) {
          final index = _registeredPrinters.indexWhere(
            (p) => p.id == connectedPrinter.id,
          );
          if (index >= 0) {
            _registeredPrinters[index] = connectedPrinter;
          }
        }
        _setState(PrinterProviderState.success);
      },
    );
  }

  Future<void> connectToSelectedPrinters() async {
    if (_selectedPrinters.isEmpty) {
      _setState(PrinterProviderState.error, error: 'No printers selected');
      return;
    }
    await connectToMultiplePrinters(_selectedPrinters);
  }

  // Selection
  void togglePrinterSelection(PrinterDevice printer) {
    final index = _selectedPrinters.indexWhere((p) => p.id == printer.id);
    if (index >= 0) {
      _selectedPrinters.removeAt(index);
    } else {
      _selectedPrinters.add(printer);
    }
    notifyListeners();
  }

  void selectAllPrinters() {
    _selectedPrinters = List.from(_registeredPrinters);
    notifyListeners();
  }

  void clearSelection() {
    _selectedPrinters.clear();
    notifyListeners();
  }

  bool isPrinterSelected(PrinterDevice printer) {
    return _selectedPrinters.any((p) => p.id == printer.id);
  }

  // Printing
  Future<void> printReceiptToSelected(ReceiptContent content) async {
    if (_selectedPrinters.isEmpty) {
      _setState(PrinterProviderState.error, error: 'No printers selected');
      return;
    }

    _setState(PrinterProviderState.printing);

    final result = await _printUseCase.printReceiptToMultiple(
      _selectedPrinters,
      content,
    );

    result.fold(
      (failure) => _setState(PrinterProviderState.error, error: failure.message),
      (batchResult) {
        _lastPrintResult = batchResult;
        if (batchResult.allSucceeded) {
          _setState(PrinterProviderState.success);
        } else {
          _setState(
            PrinterProviderState.error,
            error:
                'Printed to ${batchResult.successCount}/${batchResult.jobs.length} printers',
          );
        }
      },
    );
  }

  Future<void> printStickerToSelected(StickerContent content) async {
    if (_selectedPrinters.isEmpty) {
      _setState(PrinterProviderState.error, error: 'No printers selected');
      return;
    }

    _setState(PrinterProviderState.printing);

    final result = await _printUseCase.printStickerToMultiple(
      _selectedPrinters,
      content,
    );

    result.fold(
      (failure) =>
          _setState(PrinterProviderState.error, error: failure.message),
      (batchResult) {
        _lastPrintResult = batchResult;
        if (batchResult.allSucceeded) {
          _setState(PrinterProviderState.success);
        } else {
          _setState(
            PrinterProviderState.error,
            error:
                'Printed to ${batchResult.successCount}/${batchResult.jobs.length} printers',
          );
        }
      },
    );
  }

  /// Print to all connected printers simultaneously
  Future<void> printToAllConnected(PrintContent content) async {
    final connected = connectedPrinters;
    if (connected.isEmpty) {
      _setState(PrinterProviderState.error, error: 'No connected printers');
      return;
    }

    _selectedPrinters = connected;

    if (content is ReceiptContent) {
      await printReceiptToSelected(content);
    } else if (content is StickerContent) {
      await printStickerToSelected(content);
    }
  }

  /// Print a test page to a single printer
  Future<void> printTestPage(PrinterDevice printer) async {
    _setState(PrinterProviderState.printing);

    final testReceipt = ReceiptContent(
      storeName: '*** TEST PRINT ***',
      storeAddress: 'Connection Test',
      lines: [
        ReceiptLine.divider(),
        ReceiptLine.text('Printer: ${printer.name}', alignment: ReceiptTextAlign.center),
        ReceiptLine.text('Address: ${printer.address.formattedAddress}', alignment: ReceiptTextAlign.center),
        ReceiptLine.text('Type: ${printer.connectionType.name.toUpperCase()}', alignment: ReceiptTextAlign.center),
        ReceiptLine.divider(),
        ReceiptLine.text('If you see this,', alignment: ReceiptTextAlign.center),
        ReceiptLine.text('printing works!', alignment: ReceiptTextAlign.center, bold: true),
        ReceiptLine.divider(),
        ReceiptLine.text('Time: ${DateTime.now()}', alignment: ReceiptTextAlign.center),
      ],
      footer: '*** END TEST ***',
      cutPaper: true,
    );

    final result = await _printUseCase.printReceipt(printer, testReceipt);
    
    result.fold(
      (failure) => _setState(PrinterProviderState.error, error: failure.message),
      (job) {
        if (job.status == PrintJobStatus.completed) {
          _setState(PrinterProviderState.success);
        } else {
          _setState(PrinterProviderState.error, error: job.errorMessage ?? 'Print failed');
        }
      },
    );
  }

  // ============================================================
  // Raw Printing (Direct bytes - ESC/POS or TSPL)
  // ============================================================

  /// Print raw bytes to selected printers
  /// Use this for direct ESC/POS or TSPL commands
  Future<void> printRawToSelected(List<int> bytes) async {
    if (_selectedPrinters.isEmpty) {
      _setState(PrinterProviderState.error, error: 'No printers selected');
      return;
    }

    _setState(PrinterProviderState.printing);

    final result = await _printUseCase.printRawToMultiple(
      _selectedPrinters,
      bytes,
    );

    result.fold(
      (failure) =>
          _setState(PrinterProviderState.error, error: failure.message),
      (batchResult) {
        _lastPrintResult = batchResult;
        if (batchResult.allSucceeded) {
          _setState(PrinterProviderState.success);
        } else {
          _setState(
            PrinterProviderState.error,
            error:
                'Printed to ${batchResult.successCount}/${batchResult.jobs.length} printers',
          );
        }
      },
    );
  }

  /// Print raw bytes to a single printer
  Future<void> printRawToPrinter(PrinterDevice printer, List<int> bytes) async {
    _setState(PrinterProviderState.printing);

    final result = await _printUseCase.printRaw(printer, bytes);

    result.fold(
      (failure) => _setState(PrinterProviderState.error, error: failure.message),
      (job) {
        if (job.status == PrintJobStatus.completed) {
          _setState(PrinterProviderState.success);
        } else {
          _setState(PrinterProviderState.error, error: job.errorMessage ?? 'Print failed');
        }
      },
    );
  }

  /// Print using TsplBuilder to selected printers
  /// Convenience method for TSPL label printing
  Future<void> printTsplToSelected(TsplBuilder builder) async {
    await printRawToSelected(builder.build());
  }

  /// Print using TsplBuilder to a single printer
  Future<void> printTsplToPrinter(PrinterDevice printer, TsplBuilder builder) async {
    await printRawToPrinter(printer, builder.build());
  }
}

