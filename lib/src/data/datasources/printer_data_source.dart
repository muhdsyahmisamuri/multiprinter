import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart'
    as pos_printer;
import 'package:pos_universal_printer/pos_universal_printer.dart' hide TsplBuilder;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/printer_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/utils/tspl_builder.dart';
import '../../domain/entities/printer_device.dart' as domain;
import '../../domain/value_objects/print_content.dart';
import '../../domain/value_objects/printer_address.dart';
import '../models/printer_device_model.dart';

/// Storage key for persisting printers
const String _printersStorageKey = 'registered_printers';

/// Data source for printer operations using pos_universal_printer and flutter_pos_printer_platform
class PrinterDataSource {
  final PosUniversalPrinter _printer;
  final Uuid _uuid;
  final Map<String, domain.PrinterDevice> _connectedPrinters = {};
  final List<PrinterDeviceModel> _registeredPrinters = [];
  bool _isInitialized = false;

  // USB printer manager from flutter_pos_printer_platform
  final pos_printer.PrinterManager _usbPrinterManager =
      pos_printer.PrinterManager.instance;

  // Cache of scanned USB devices for proper connection
  final Map<String, pos_printer.PrinterDevice> _scannedUsbDevices = {};

  // USB status subscription and pending task
  StreamSubscription<pos_printer.USBStatus>? _usbStatusSubscription;
  List<int>? _pendingUsbTask;
  Completer<void>? _usbPrintCompleter;

  // Active TCP socket connections for network printers
  // Key: printer ID, Value: active Socket connection
  final Map<String, Socket> _tcpConnections = {};

  // Track warm-up state to prevent concurrent warm-ups and prints
  bool _isWarmingUp = false;
  bool _networkWarmedUp = false;

  PrinterDataSource({PosUniversalPrinter? printer, Uuid? uuid})
    : _printer = printer ?? PosUniversalPrinter.instance,
      _uuid = uuid ?? const Uuid();

  /// Initialize the data source and load persisted printers
  Future<void> init() async {
    if (_isInitialized) return;
    await _loadPrintersFromStorage();

    // Workaround for flutter_pos_printer_platform crash:
    // The plugin has a lateinit bluetoothService that crashes onDestroy
    // if never initialized. We briefly trigger discovery to initialize it.
    _initializePrinterPlugin();

    // Set up USB status listener for proper printing
    _setupUsbStatusListener();

    // Warm up the network stack to avoid cold start delays on first print
    _warmUpNetwork();

    _isInitialized = true;
  }

  /// Warm up Android network stack to avoid cold start delays
  /// This makes a quick connection attempt to wake up Wi-Fi
  void _warmUpNetwork() {
    // Run in background, don't await
    Future(() async {
      try {
        // Try to connect to localhost to wake up network stack
        final socket = await Socket.connect(
          '127.0.0.1',
          9100,
          timeout: const Duration(milliseconds: 100),
        );
        socket.destroy();
      } catch (_) {
        // Ignore errors - this is just to wake up the network stack
      }
    });
  }

  /// Pre-warm network connections to registered TCP printers
  /// This runs quick connection attempts in background to wake up Android network
  Future<void> warmUpPrinterConnections() async {
    // Skip if already warmed up
    if (_networkWarmedUp || _isWarmingUp) return;

    final tcpPrinters = _registeredPrinters.where(
      (p) => p.address.connectionType == PrinterConnectionType.tcp ||
             p.address.connectionType == PrinterConnectionType.lan,
    ).toList();

    if (tcpPrinters.isEmpty) {
      _networkWarmedUp = true;
      return;
    }

    _isWarmingUp = true;

    // Fire quick connection attempts to wake up Android network stack
    try {
      await Future.wait(
        tcpPrinters.map((printer) async {
          for (int i = 0; i < 3; i++) {
            try {
              final socket = await Socket.connect(
                printer.address.address,
                printer.address.port ?? PrinterConstants.defaultTcpPort,
                timeout: const Duration(milliseconds: 500),
              );
              await socket.close();
              return;
            } catch (_) {
              // Expected to fail initially, just continue poking
            }
          }
        }),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {
      // Timeout is fine - warm-up is best-effort
    }

    _isWarmingUp = false;
    _networkWarmedUp = true;
  }

  /// Set up USB status listener to handle printing when connected
  void _setupUsbStatusListener() {
    _usbStatusSubscription?.cancel();
    _usbStatusSubscription = _usbPrinterManager.stateUSB.listen((status) {
      if (status == pos_printer.USBStatus.connected && _pendingUsbTask != null) {
        // USB connected and we have pending bytes to print
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (_pendingUsbTask != null) {
            _usbPrinterManager.send(
              type: pos_printer.PrinterType.usb,
              bytes: _pendingUsbTask!,
            );
            _pendingUsbTask = null;
            _usbPrintCompleter?.complete();
            _usbPrintCompleter = null;
          }
        });
      }
    });
  }

  /// Initialize the printer plugin to prevent crashes on activity destroy
  void _initializePrinterPlugin() {
    try {
      // Briefly trigger USB discovery to initialize the plugin's internal services
      // This prevents "lateinit property bluetoothService has not been initialized"
      final subscription = _usbPrinterManager
          .discovery(type: pos_printer.PrinterType.usb)
          .listen((_) {}, onError: (_) {});
      // Cancel immediately - we just need the plugin to initialize
      Future.delayed(const Duration(milliseconds: 100), () {
        subscription.cancel();
      });
    } catch (_) {
      // Ignore initialization errors
    }
  }

  /// Load printers from SharedPreferences
  Future<void> _loadPrintersFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final printersJson = prefs.getStringList(_printersStorageKey);

      if (printersJson != null) {
        _registeredPrinters.clear();
        for (final json in printersJson) {
          try {
            final map = jsonDecode(json) as Map<String, dynamic>;
            final printer = PrinterDeviceModel.fromJson(map);
            // Reset connection status on load
            _registeredPrinters.add(printer.copyWith(isConnected: false));
          } catch (_) {
            // Skip invalid entries
          }
        }
      }
    } catch (_) {
      // Ignore storage errors on load
    }
  }

  /// Save printers to SharedPreferences
  Future<void> _savePrintersToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final printersJson = _registeredPrinters.map((p) {
        // Don't save connection status
        final printerToSave = p.copyWith(isConnected: false);
        return jsonEncode(printerToSave.toJson());
      }).toList();

      await prefs.setStringList(_printersStorageKey, printersJson);
    } catch (_) {
      // Ignore storage errors on save
    }
  }

  /// Scan for Bluetooth devices
  Future<List<PrinterDeviceModel>> scanBluetoothDevices() async {
    try {
      final Map<String, PrinterDeviceModel> result = {};
      final completer = Completer<List<PrinterDeviceModel>>();

      // Listen to the stream and collect devices with timeout
      final subscription = _printer
          .scanBluetooth()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: (sink) {
              sink.close();
            },
          )
          .listen(
            (device) {
              final addr = device.address;
              final deviceId = (addr != null && addr.isNotEmpty)
                  ? addr
                  : _uuid.v4();
              final deviceName = device.name.isNotEmpty
                  ? device.name
                  : 'Unknown Bluetooth Printer';
              
              // Use deviceId as key to prevent duplicates
              if (!result.containsKey(deviceId)) {
                result[deviceId] = PrinterDeviceModel(
                  id: deviceId,
                  name: deviceName,
                  address: PrinterAddress.bluetooth(addr ?? ''),
                  role: PrinterRole.general,
                  isConnected: false,
                  supportedDocuments: const [
                    PrintDocumentType.receipt,
                    PrintDocumentType.sticker,
                  ],
                );
              }
            },
            onDone: () {
              if (!completer.isCompleted) {
                completer.complete(result.values.toList());
              }
            },
            onError: (error) {
              if (!completer.isCompleted) {
                completer.completeError(error);
              }
            },
          );

      // Cancel subscription after timeout
      Future.delayed(const Duration(seconds: 10), () {
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.complete(result.values.toList());
        }
      });

      return completer.future;
    } catch (e) {
      throw BluetoothException(
        message: 'Failed to scan Bluetooth devices: $e',
        code: 'BLUETOOTH_SCAN_ERROR',
      );
    }
  }

  /// Scan for network devices by checking common IP addresses
  Future<List<PrinterDeviceModel>> scanNetworkDevices({
    String subnet = '192.168.1',
    int port = PrinterConstants.defaultTcpPort,
  }) async {
    try {
      final List<PrinterDeviceModel> foundPrinters = [];

      // Try to auto-detect the subnet from device's IP
      String actualSubnet = subnet;
      try {
        final interfaces = await NetworkInterface.list();
        for (final interface in interfaces) {
          for (final addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 &&
                !addr.address.startsWith('127.')) {
              // Extract subnet (first 3 octets)
              final parts = addr.address.split('.');
              if (parts.length == 4) {
                actualSubnet = '${parts[0]}.${parts[1]}.${parts[2]}';
                break;
              }
            }
          }
        }
      } catch (_) {
        // Use default subnet if detection fails
      }

      // Common printer ports to check
      final portsToScan = {
        port,
        9100, // Standard raw print port
        515, // LPD/LPR
        631, // IPP (Internet Printing Protocol)
      }.toList(); // Using Set literal to remove duplicates

      // Scan full IP range (1-254) for thorough discovery
      final ipRanges = List.generate(254, (i) => i + 1); // 1-254

      // Scan IPs in parallel batches for speed
      // Larger batch = faster but more network load
      const batchSize = 50;
      for (var i = 0; i < ipRanges.length; i += batchSize) {
        final batch = ipRanges.skip(i).take(batchSize);
        final futures = batch.map((lastOctet) async {
          final ip = '$actualSubnet.$lastOctet';
          for (final scanPort in portsToScan) {
            final printer = await _tryConnectToNetworkPrinter(ip, scanPort);
            if (printer != null) {
              return printer;
            }
          }
          return null;
        });

        final results = await Future.wait(futures);
        foundPrinters.addAll(results.whereType<PrinterDeviceModel>());
      }

      return foundPrinters;
    } catch (e) {
      throw TcpException(
        message: 'Failed to scan network devices: $e',
        code: 'NETWORK_SCAN_ERROR',
      );
    }
  }

  /// Try to connect to a potential printer at the given IP and port
  Future<PrinterDeviceModel?> _tryConnectToNetworkPrinter(
    String ip,
    int port,
  ) async {
    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(milliseconds: 300),
      );

      // Connection successful - likely a printer
      await socket.close();

      return PrinterDeviceModel(
        id: '$ip:$port',
        name: 'Network Printer ($ip)',
        address: PrinterAddress.tcp(ip, port: port),
        role: PrinterRole.general,
        isConnected: false,
        supportedDocuments: const [
          PrintDocumentType.receipt,
          PrintDocumentType.sticker,
        ],
      );
    } on SocketException {
      // Connection refused or timed out - not a printer
      return null;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Scan for USB devices (Android only)
  Future<List<PrinterDeviceModel>> scanUsbDevices() async {
    try {
      final Map<String, PrinterDeviceModel> foundPrinters = {};
      final completer = Completer<List<PrinterDeviceModel>>();

      // Clear old cache
      _scannedUsbDevices.clear();

      // Use flutter_pos_printer_platform to discover USB devices
      final subscription = _usbPrinterManager
          .discovery(type: pos_printer.PrinterType.usb)
          .listen(
            (device) {
              // Create unique ID from vendor and product IDs
              final vendorId = device.vendorId ?? 'unknown';
              final productId = device.productId ?? 'unknown';
              final deviceId = 'usb_${vendorId}_$productId';
              final deviceName = device.name.isNotEmpty
                  ? device.name
                  : 'USB Printer';

              // Cache the actual device for later use
              _scannedUsbDevices[deviceId] = device;

              // Use deviceId as key to prevent duplicates
              if (!foundPrinters.containsKey(deviceId)) {
                foundPrinters[deviceId] = PrinterDeviceModel(
                  id: deviceId,
                  name: deviceName,
                  address: PrinterAddress.usb(deviceId),
                  role: PrinterRole.general,
                  isConnected: false,
                  supportedDocuments: const [
                    PrintDocumentType.receipt,
                    PrintDocumentType.sticker,
                  ],
                );
              }
            },
            onDone: () {
              if (!completer.isCompleted) {
                completer.complete(foundPrinters.values.toList());
              }
            },
            onError: (error) {
              if (!completer.isCompleted) {
                completer.completeError(error);
              }
            },
          );

      // Timeout after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.complete(foundPrinters.values.toList());
        }
      });

      return completer.future;
    } catch (e) {
      throw UsbException(
        message: 'Failed to scan USB devices: $e',
        code: 'USB_SCAN_ERROR',
      );
    }
  }

  /// Connect to USB printer using flutter_pos_printer_platform
  Future<void> _connectUsbPrinter(PrinterDeviceModel printer) async {
    try {
      // Check if we have the cached device from scanning
      final cachedDevice = _scannedUsbDevices[printer.id];

      String? vendorId;
      String? productId;

      if (cachedDevice != null) {
        // Use cached device info
        vendorId = cachedDevice.vendorId;
        productId = cachedDevice.productId;
      } else {
        // Parse vendor and product IDs from the address
        final parts = printer.id.split('_');
        if (parts.length >= 3) {
          vendorId = parts[1];
          productId = parts[2];
        }
      }

      await _usbPrinterManager.connect(
        type: pos_printer.PrinterType.usb,
        model: pos_printer.UsbPrinterInput(
          name: printer.name,
          vendorId: vendorId,
          productId: productId,
        ),
      );

      // Give USB time to fully initialize
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      throw ConnectionException(
        message: 'Failed to connect USB printer: $e',
        code: 'USB_CONNECT_ERROR',
      );
    }
  }

  /// Disconnect USB printer
  Future<void> _disconnectUsbPrinter() async {
    try {
      await _usbPrinterManager.disconnect(type: pos_printer.PrinterType.usb);
    } catch (e) {
      throw ConnectionException(
        message: 'Failed to disconnect USB printer: $e',
        code: 'USB_DISCONNECT_ERROR',
      );
    }
  }

  /// Connect to TCP/Network printer and store the socket
  Future<void> _connectTcpPrinter(PrinterDeviceModel printer) async {
    try {
      final address = printer.address.address;
      final port = printer.address.port ?? PrinterConstants.defaultTcpPort;

      // Close existing connection if any
      if (_tcpConnections.containsKey(printer.id)) {
        try {
          await _tcpConnections[printer.id]?.close();
        } catch (_) {}
        _tcpConnections.remove(printer.id);
      }

      // Open direct socket connection to this specific printer
      final socket = await Socket.connect(
        address,
        port,
        timeout: const Duration(milliseconds: PrinterConstants.connectionTimeout),
      );

      // Store the socket for later use
      _tcpConnections[printer.id] = socket;
    } catch (e) {
      throw ConnectionException(
        message: 'Failed to connect to network printer ${printer.address.address}: $e',
        code: 'TCP_CONNECT_ERROR',
      );
    }
  }

  /// Disconnect TCP/Network printer
  Future<void> _disconnectTcpPrinter(PrinterDeviceModel printer) async {
    try {
      final socket = _tcpConnections[printer.id];
      if (socket != null) {
        await socket.close();
        _tcpConnections.remove(printer.id);
      }
    } catch (e) {
      throw ConnectionException(
        message: 'Failed to disconnect from network printer: $e',
        code: 'TCP_DISCONNECT_ERROR',
      );
    }
  }

  /// Print to USB printer using flutter_pos_printer_platform
  Future<void> _printToUsbPrinter(
    List<int> bytes,
    PrinterDeviceModel printer,
  ) async {
    try {
      // Parse vendor and product IDs
      final parts = printer.id.split('_');
      String? vendorId;
      String? productId;

      if (parts.length >= 3) {
        vendorId = parts[1];
        productId = parts[2];
      }

      // Try multiple connection attempts (USB permission may be granted between attempts)
      bool printed = false;
      for (int attempt = 1; attempt <= 3 && !printed; attempt++) {
        // Store bytes as pending task
        _pendingUsbTask = bytes;
        _usbPrintCompleter = Completer<void>();

        // Connect to USB device
        await _usbPrinterManager.connect(
          type: pos_printer.PrinterType.usb,
          model: pos_printer.UsbPrinterInput(
            name: printer.name,
            vendorId: vendorId,
            productId: productId,
          ),
        );

        // Wait for USB connected status
        try {
          await _usbPrintCompleter!.future.timeout(
            const Duration(seconds: 3),
          );
          printed = true;
        } on TimeoutException {
          _pendingUsbTask = null;

          if (attempt == 3) {
            // Final attempt - try direct send
            await _usbPrinterManager.send(
              type: pos_printer.PrinterType.usb,
              bytes: bytes,
            );
          } else {
            // Wait before retry (gives user time to grant permission)
            await Future.delayed(const Duration(seconds: 2));
          }
        }
      }
    } catch (e) {
      _pendingUsbTask = null;
      _usbPrintCompleter = null;
      if (e is PrintJobException) rethrow;
      throw PrintJobException(
        message: 'Failed to print to USB printer: $e',
        code: 'USB_PRINT_ERROR',
      );
    }
  }

  /// Print to TCP/Network printer using direct socket connection
  /// Includes retry logic to handle Android network "cold start" issues
  Future<void> _printToTcpPrinter(
    List<int> bytes,
    PrinterDeviceModel printer,
  ) async {
    final address = printer.address.address;
    final port = printer.address.port ?? PrinterConstants.defaultTcpPort;
    
    // Close any existing connection first - printers only accept one connection
    if (_tcpConnections.containsKey(printer.id)) {
      try {
        await _tcpConnections[printer.id]?.close();
      } catch (_) {}
      _tcpConnections.remove(printer.id);
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    // Retry logic for Android network cold start issues
    const maxRetries = 3;
    Exception? lastException;
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      Socket? socket;
      try {
        // First attempt: long timeout to let network wake up
        final timeout = switch (attempt) {
          1 => const Duration(seconds: 8),
          2 => const Duration(seconds: 5),
          _ => const Duration(seconds: 10),
        };
        
        socket = await Socket.connect(address, port, timeout: timeout);
        
        // Send the print data
        socket.add(bytes);
        await socket.flush();
        
        // Give printer time to process
        await Future.delayed(const Duration(milliseconds: 500));
        await socket.close();
        return; // Success!

      } on SocketException catch (e) {
        socket?.destroy();
        lastException = e;
        if (attempt < maxRetries) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      } on TimeoutException catch (e) {
        socket?.destroy();
        lastException = e;
        if (attempt < maxRetries) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      } catch (e) {
        socket?.destroy();
        if (e is PrintJobException) rethrow;
        lastException = e is Exception ? e : Exception(e.toString());
        if (attempt < maxRetries) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
    }
    
    // All retries failed
    if (lastException is SocketException) {
      throw PrintJobException(
        message: 'Cannot connect to printer at $address. Check if printer is on and connected to network.',
        code: 'TCP_SOCKET_ERROR',
      );
    } else if (lastException is TimeoutException) {
      throw PrintJobException(
        message: 'Printer at $address not responding. Is it powered on?',
        code: 'TCP_TIMEOUT',
      );
    } else {
      throw PrintJobException(
        message: 'Failed to print to $address',
        code: 'TCP_PRINT_ERROR',
      );
    }
  }

  /// Get all registered printers
  Future<List<PrinterDeviceModel>> getRegisteredPrinters() async {
    if (!_isInitialized) {
      await init();
    }
    return List.unmodifiable(_registeredPrinters);
  }

  /// Register a new printer
  Future<PrinterDeviceModel> registerPrinter(PrinterDeviceModel printer) async {
    if (!_isInitialized) {
      await init();
    }

    final existingIndex = _registeredPrinters.indexWhere(
      (p) => p.id == printer.id,
    );
    if (existingIndex >= 0) {
      _registeredPrinters[existingIndex] = printer;
    } else {
      _registeredPrinters.add(printer);
    }

    // Persist changes
    await _savePrintersToStorage();

    return printer;
  }

  /// Update a registered printer
  Future<PrinterDeviceModel> updatePrinter(PrinterDeviceModel printer) async {
    if (!_isInitialized) {
      await init();
    }

    final index = _registeredPrinters.indexWhere((p) => p.id == printer.id);
    if (index < 0) {
      throw PrinterException(
        message: 'Printer not found: ${printer.id}',
        code: 'PRINTER_NOT_FOUND',
      );
    }
    _registeredPrinters[index] = printer;

    // Persist changes
    await _savePrintersToStorage();

    return printer;
  }

  /// Remove a registered printer
  Future<void> removePrinter(String printerId) async {
    if (!_isInitialized) {
      await init();
    }

    // Close TCP connection if exists
    if (_tcpConnections.containsKey(printerId)) {
      try {
        await _tcpConnections[printerId]?.close();
      } catch (_) {}
      _tcpConnections.remove(printerId);
    }

    _registeredPrinters.removeWhere((p) => p.id == printerId);
    _connectedPrinters.remove(printerId);

    // Persist changes
    await _savePrintersToStorage();
  }

  /// Connect to a printer
  Future<PrinterDeviceModel> connectToPrinter(
    PrinterDeviceModel printer,
  ) async {
    try {
      // Handle USB connection separately using flutter_pos_printer_platform
      if (printer.address.connectionType == PrinterConnectionType.usb) {
        await _connectUsbPrinter(printer);
      } else if (printer.address.connectionType == PrinterConnectionType.tcp ||
                 printer.address.connectionType == PrinterConnectionType.lan) {
        // Use direct TCP connection for network printers
        // This allows true parallel printing to multiple printers
        await _connectTcpPrinter(printer);
      } else {
        // Use pos_universal_printer for Bluetooth only
        final printerType = _mapConnectionType(printer.address.connectionType);
        final role = _mapRole(printer.role);

        final device = PrinterDevice(
          id: printer.id,
          name: printer.name,
          type: printerType,
          address: printer.address.address,
          port: printer.address.port ?? PrinterConstants.defaultTcpPort,
        );

        await _printer.registerDevice(role, device);
      }

      final connectedPrinter = printer.copyWith(
        isConnected: true,
        lastConnectedAt: DateTime.now(),
      );

      _connectedPrinters[printer.id] = connectedPrinter;

      // Update registered printers list
      final index = _registeredPrinters.indexWhere((p) => p.id == printer.id);
      if (index >= 0) {
        _registeredPrinters[index] = connectedPrinter;
      }

      return connectedPrinter;
    } catch (e) {
      throw ConnectionException(
        message: 'Failed to connect to printer ${printer.name}: $e',
        code: 'CONNECTION_ERROR',
      );
    }
  }

  /// Disconnect from a printer
  Future<void> disconnectFromPrinter(PrinterDeviceModel printer) async {
    try {
      // Handle USB disconnection separately
      if (printer.address.connectionType == PrinterConnectionType.usb) {
        await _disconnectUsbPrinter();
      } else if (printer.address.connectionType == PrinterConnectionType.tcp ||
                 printer.address.connectionType == PrinterConnectionType.lan) {
        // Handle TCP disconnection
        await _disconnectTcpPrinter(printer);
      }

      _connectedPrinters.remove(printer.id);

      // Update registered printers list
      final index = _registeredPrinters.indexWhere((p) => p.id == printer.id);
      if (index >= 0) {
        _registeredPrinters[index] = printer.copyWith(isConnected: false);
      }
    } catch (e) {
      throw ConnectionException(
        message: 'Failed to disconnect from printer ${printer.name}: $e',
        code: 'DISCONNECT_ERROR',
      );
    }
  }

  /// Check if printer is connected
  Future<bool> isPrinterConnected(PrinterDeviceModel printer) async {
    return _connectedPrinters.containsKey(printer.id);
  }

  /// Print a receipt using ESC/POS
  Future<void> printReceipt(
    PrinterDeviceModel printer,
    ReceiptContent content,
  ) async {
    try {
      // Build ESC/POS commands using the package's EscPosBuilder
      final builder = EscPosBuilder();

      // Initialize printer
      builder.init();

      // Store header
      if (content.storeName != null) {
        builder.text(content.storeName!, align: PosAlign.center, bold: true);
      }

      if (content.storeAddress != null) {
        builder.text(content.storeAddress!, align: PosAlign.center);
      }

      // Empty line
      builder.feed(1);

      // Print lines
      for (final line in content.lines) {
        _printReceiptLine(builder, line);
      }

      // Footer
      if (content.footer != null) {
        builder.feed(1);
        builder.text(content.footer!, align: PosAlign.center);
      }

      // Feed before cut
      builder.feed(3);

      // Cut paper
      if (content.cutPaper) {
        builder.cut();
      }

      // Get the bytes
      final bytes = builder.build();

      // Send to USB printer using flutter_pos_printer_platform
      if (printer.address.connectionType == PrinterConnectionType.usb) {
        await _printToUsbPrinter(bytes, printer);

        // Open cash drawer if needed
        if (content.openCashDrawer) {
          await _printToUsbPrinter(EscPosHelper.openDrawer(), printer);
        }
      } else if (printer.address.connectionType == PrinterConnectionType.tcp ||
                 printer.address.connectionType == PrinterConnectionType.lan) {
        // Use direct TCP connection for network printers
        // This allows true parallel printing to multiple printers
        await _printToTcpPrinter(bytes, printer);

        // Open cash drawer if needed
        if (content.openCashDrawer) {
          await _printToTcpPrinter(EscPosHelper.openDrawer(), printer);
        }
      } else {
        // Use pos_universal_printer for Bluetooth
        final role = _mapRole(printer.role);
        _printer.printEscPos(role, builder);

        // Open cash drawer if needed (send separately)
        if (content.openCashDrawer) {
          final drawerBuilder = EscPosBuilder();
          drawerBuilder.raster(EscPosHelper.openDrawer());
          _printer.printEscPos(role, drawerBuilder);
        }
      }
    } catch (e) {
      throw PrintJobException(
        message: 'Failed to print receipt: $e',
        code: 'PRINT_RECEIPT_ERROR',
      );
    }
  }

  void _printReceiptLine(EscPosBuilder builder, ReceiptLine line) {
    switch (line.lineType) {
      case ReceiptLineType.text:
        builder.text(
          line.text,
          align: _mapAlign(line.alignment),
          bold: line.bold,
        );
        break;
      case ReceiptLineType.leftRight:
        final parts = line.text.split('\t');
        if (parts.length >= 2) {
          // Create padded string for left-right alignment
          final leftText = parts[0];
          final rightText = parts[1];
          const totalWidth = 32; // Standard 58mm receipt width in chars
          final padding = totalWidth - leftText.length - rightText.length;
          final paddedText =
              leftText + ' ' * (padding > 0 ? padding : 1) + rightText;
          builder.text(paddedText, align: PosAlign.left);
        }
        break;
      case ReceiptLineType.divider:
        builder.text(line.text, align: PosAlign.left);
        break;
      case ReceiptLineType.barcode:
        builder.barcode(line.text);
        builder.feed(1);
        break;
      case ReceiptLineType.qrCode:
        builder.qrCode(line.text);
        builder.feed(1);
        break;
      case ReceiptLineType.empty:
        builder.feed(1);
        break;
      case ReceiptLineType.image:
        // Image printing requires bitmap data
        break;
    }
  }

  /// Print raw bytes to a printer
  /// Supports all connection types: Bluetooth, TCP/LAN, USB
  Future<void> printRaw(
    PrinterDeviceModel printer,
    List<int> bytes,
  ) async {
    try {
      switch (printer.address.connectionType) {
        case PrinterConnectionType.usb:
          await _printToUsbPrinter(bytes, printer);
          break;
        case PrinterConnectionType.tcp:
        case PrinterConnectionType.lan:
          await _printToTcpPrinter(bytes, printer);
          break;
        case PrinterConnectionType.bluetooth:
          // For Bluetooth, use pos_universal_printer
          final role = _mapRole(printer.role);
          _printer.printRaw(role, bytes);
          break;
      }
    } catch (e) {
      throw PrintJobException(
        message: 'Failed to print raw data: $e',
        code: 'PRINT_RAW_ERROR',
      );
    }
  }

  /// Print a sticker using TSPL
  Future<void> printSticker(
    PrinterDeviceModel printer,
    StickerContent content,
  ) async {
    try {
      // Build TSPL commands using TsplBuilder
      final tspl = TsplBuilder();

      // Setup sticker size
      tspl.size(content.width, content.height);
      tspl.gap(content.gap, 0);
      tspl.density(content.density);
      tspl.cls(); // Clear buffer before drawing

      // Calculate positions (8 dots per mm)
      const dotsPerMm = 8;
      const marginLeft = 2 * dotsPerMm; // 2mm margin
      var currentY = 2 * dotsPerMm; // Start 2mm from top

      // Font size mapping: 1=small, 2=medium, 3=large, 4=extra large
      final productFont = content.fontSize;
      final detailFont = content.fontSize > 1 ? content.fontSize - 1 : 1;

      // Customer name (smaller font)
      tspl.text(
        marginLeft,
        currentY,
        detailFont, // font based on size setting
        0, // rotation
        1, // x multiplier
        1, // y multiplier
        content.customerName,
      );
      currentY += 4 * dotsPerMm; // 4mm spacing

      // Product name (larger font based on fontSize setting)
      tspl.text(
        marginLeft,
        currentY,
        productFont, // font based on size setting
        0,
        1,
        1,
        content.productName,
      );
      currentY += 6 * dotsPerMm; // 6mm spacing

      // Variants and additions
      final details = <String>[
        ...content.variants,
        ...content.additions,
        if (content.notes != null && content.notes!.isNotEmpty) content.notes!,
      ];

      if (details.isNotEmpty) {
        final detailText = details.join(', ');
        // Wrap text if too long
        const maxChars = 24;
        if (detailText.length <= maxChars) {
          tspl.text(marginLeft, currentY, 1, 0, 1, 1, detailText);
        } else {
          // Split into multiple lines
          final lines = _wrapText(detailText, maxChars);
          for (final line in lines) {
            tspl.text(marginLeft, currentY, 1, 0, 1, 1, line);
            currentY += 3 * dotsPerMm;
          }
        }
      }

      // Add barcode if provided
      if (content.barcode != null && content.barcode!.isNotEmpty) {
        currentY += 2 * dotsPerMm;
        tspl.barcode(
          marginLeft,
          currentY,
          'CODE128',
          40, // height in dots
          1, // human readable
          content.barcode!,
        );
      }

      // Print label
      tspl.printLabel(content.quantity);

      // Get the bytes
      final bytes = tspl.build();

      // Send to USB printer using flutter_pos_printer_platform
      if (printer.address.connectionType == PrinterConnectionType.usb) {
        await _printToUsbPrinter(bytes, printer);
      } else if (printer.address.connectionType == PrinterConnectionType.tcp ||
                 printer.address.connectionType == PrinterConnectionType.lan) {
        // Use direct TCP connection for network printers
        await _printToTcpPrinter(bytes, printer);
      } else {
        // Send TSPL command string to printer using pos_universal_printer (Bluetooth)
        final role = _mapRole(printer.role);
        final payload = String.fromCharCodes(bytes);
        _printer.printTspl(role, payload);
      }
    } catch (e) {
      throw PrintJobException(
        message: 'Failed to print sticker: $e',
        code: 'PRINT_STICKER_ERROR',
      );
    }
  }

  /// Helper to wrap text into multiple lines
  List<String> _wrapText(String text, int maxLength) {
    if (text.length <= maxLength) return [text];

    final List<String> lines = [];
    String currentLine = '';
    final words = text.split(' ');

    for (final word in words) {
      if ((currentLine + word).length <= maxLength) {
        currentLine += (currentLine.isEmpty ? '' : ' ') + word;
      } else {
        if (currentLine.isNotEmpty) {
          lines.add(currentLine);
          currentLine = word;
        } else {
          // Word too long, force break
          lines.add(word.substring(0, maxLength));
          currentLine = word.length > maxLength
              ? word.substring(maxLength)
              : '';
        }
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }

    return lines;
  }

  /// Map domain connection type to printer type
  PrinterType _mapConnectionType(PrinterConnectionType type) {
    switch (type) {
      case PrinterConnectionType.bluetooth:
        return PrinterType.bluetooth;
      case PrinterConnectionType.tcp:
      case PrinterConnectionType.lan:
        return PrinterType.tcp;
      case PrinterConnectionType.usb:
        return PrinterType.bluetooth;
    }
  }

  /// Map domain role to printer role
  PosPrinterRole _mapRole(PrinterRole role) {
    switch (role) {
      case PrinterRole.cashier:
        return PosPrinterRole.cashier;
      case PrinterRole.kitchen:
        return PosPrinterRole.kitchen;
      case PrinterRole.bar:
      case PrinterRole.sticker:
        return PosPrinterRole.sticker;
      case PrinterRole.general:
        return PosPrinterRole.cashier;
    }
  }

  /// Map receipt text alignment to PosAlign
  PosAlign _mapAlign(ReceiptTextAlign align) {
    switch (align) {
      case ReceiptTextAlign.left:
        return PosAlign.left;
      case ReceiptTextAlign.center:
        return PosAlign.center;
      case ReceiptTextAlign.right:
        return PosAlign.right;
    }
  }
}

