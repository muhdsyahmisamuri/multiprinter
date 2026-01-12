# MultiPrinter

A comprehensive Flutter package for multi-printer management supporting Bluetooth, TCP/LAN, and USB thermal printers with simultaneous printing capabilities.

## Features

✅ **Multi-connection support**: Bluetooth, TCP/IP, LAN, and USB  
✅ **Simultaneous printing**: Print to multiple printers at once  
✅ **Receipt printing**: ESC/POS format with store headers, items, and footers  
✅ **Sticker/label printing**: TSPL format for label printers  
✅ **Clean Architecture**: Domain-driven design with proper separation of concerns  
✅ **Ready-to-use UI widgets**: Printer cards, dialogs, and provider integration  
✅ **Permission handling**: Built-in Bluetooth and location permission management  
✅ **Persistent storage**: Registered printers are saved locally  
✅ **Auto-reconnect**: TCP printers connect automatically on print

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  multiprinter:
    path: /path/to/multiprinter/packages/multiprinter
```

## Quick Start

### 1. Initialize the package

```dart
import 'package:multiprinter/multiprinter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize MultiPrinter
  await MultiPrinter.init();
  
  runApp(MyApp());
}
```

### 2. Add the provider to your app

```dart
import 'package:provider/provider.dart';
import 'package:multiprinter/multiprinter.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        MultiPrinter.createPrinterProvider(),
      ],
      child: MaterialApp(
        home: MyHomePage(),
      ),
    );
  }
}
```

### 3. Use the PrinterProvider

```dart
class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<PrinterProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            // Scan for printers
            ElevatedButton(
              onPressed: () => provider.scanBluetoothPrinters(),
              child: Text('Scan Bluetooth'),
            ),
            
            // Display printers
            ListView.builder(
              itemCount: provider.registeredPrinters.length,
              itemBuilder: (context, index) {
                final printer = provider.registeredPrinters[index];
                return PrinterCard(
                  printer: printer,
                  isSelected: provider.isPrinterSelected(printer),
                  onTap: () => provider.togglePrinterSelection(printer),
                  onConnect: () => provider.connectToPrinter(printer),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
```

---

## TCP/IP Printer Flow

TCP/IP printers (network printers) use a different connection model than Bluetooth. Understanding this flow is important for implementing reliable printing.

### Connection Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        TCP Printer Flow                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────┐    Print Request    ┌─────────────────────────┐  │
│  │   App    │ ──────────────────► │   PrinterDataSource     │  │
│  └──────────┘                     └───────────┬─────────────┘  │
│                                               │                  │
│                                               ▼                  │
│                               ┌─────────────────────────────┐   │
│                               │   _printToTcpPrinter()      │   │
│                               │                             │   │
│                               │  1. Close existing socket   │   │
│                               │  2. Connect (with retry)    │   │
│                               │  3. Send data               │   │
│                               │  4. Close socket            │   │
│                               └─────────────┬───────────────┘   │
│                                             │                    │
│                                             ▼                    │
│                               ┌─────────────────────────────┐   │
│                               │    TCP Socket (Port 9100)   │   │
│                               │    ─────────────────────    │   │
│                               │    • 3 retry attempts       │   │
│                               │    • 8s/5s/10s timeouts     │   │
│                               │    • Auto close on complete │   │
│                               └─────────────┬───────────────┘   │
│                                             │                    │
│                                             ▼                    │
│                               ┌─────────────────────────────┐   │
│                               │     Network Printer         │   │
│                               │     192.168.x.x:9100        │   │
│                               └─────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Key Concepts

#### 1. Auto-Connect Model

TCP printers use an **auto-connect** model. Unlike Bluetooth printers that require pairing:

- **No persistent connection** - Each print job creates a new connection
- **No manual connect/disconnect** - The connection is managed automatically
- **Status shows "Auto"** - UI indicates automatic connection handling

```dart
// TCP printers connect automatically when printing
// No need to call connectToPrinter() for TCP/LAN printers
await provider.printReceiptToSelected(receipt);
```

#### 2. Network Cold Start (Android)

On Android, the first network connection after app launch can be slow due to the network stack "warming up". The package handles this with:

- **Retry logic**: 3 attempts with increasing timeouts (8s → 5s → 10s)
- **Network warm-up**: Optional pre-warming of connections

```dart
// Optional: Warm up network connections on screen init
@override
void initState() {
  super.initState();
  final provider = context.read<PrinterProvider>();
  provider.warmUpConnections(); // Pre-warms TCP connections
}
```

#### 3. Print Flow for TCP Printers

```dart
// 1. Add a TCP printer
await provider.addManualPrinter(
  name: 'Kitchen Printer',
  address: '192.168.1.100',
  connectionType: PrinterConnectionType.tcp,
  port: 9100,
  role: PrinterRole.kitchen,
  supportedDocuments: [PrintDocumentType.receipt],
);

// 2. Select the printer for printing
provider.togglePrinterSelection(printer);

// 3. Print - connection handled automatically
final receipt = ReceiptContent(
  storeName: 'My Store',
  lines: [
    ReceiptLine.leftRight('Item', '\$10.00'),
  ],
);

await provider.printReceiptToSelected(receipt);
```

### Retry Mechanism

TCP printing includes automatic retry on failure:

| Attempt | Timeout | Delay Before |
|---------|---------|--------------|
| 1st     | 8 sec   | -            |
| 2nd     | 5 sec   | 200ms        |
| 3rd     | 10 sec  | 200ms        |

```
Print Request
     │
     ▼
┌─────────────┐
│ Attempt 1   │──── Success ────► Print Complete
│ (8s timeout)│
└──────┬──────┘
       │ Fail
       ▼
┌─────────────┐
│ Attempt 2   │──── Success ────► Print Complete
│ (5s timeout)│
└──────┬──────┘
       │ Fail
       ▼
┌─────────────┐
│ Attempt 3   │──── Success ────► Print Complete
│ (10s timeout)│
└──────┬──────┘
       │ Fail
       ▼
   Print Failed
```

### Simultaneous Printing

Print to multiple TCP printers at once:

```dart
// Select multiple printers
provider.togglePrinterSelection(kitchenPrinter);
provider.togglePrinterSelection(barPrinter);
provider.togglePrinterSelection(counterPrinter);

// Print to all simultaneously
final result = await provider.printReceiptToSelected(receipt);

// Check results
print('Success: ${result.successCount}/${result.jobs.length}');
for (final job in result.jobs) {
  print('${job.printer.name}: ${job.status}');
}
```

---

## Printing Receipts (ESC/POS)

```dart
final receipt = ReceiptContent(
  storeName: 'My Coffee Shop',
  storeAddress: '123 Main Street',
  lines: [
    ReceiptLine.text('ORDER #1234', 
      alignment: ReceiptTextAlign.center, 
      bold: true,
      size: ReceiptTextSize.large,
    ),
    ReceiptLine.divider(),
    ReceiptLine.text('Items:', bold: true),
    ReceiptLine.leftRight('1x Cappuccino', '\$4.50'),
    ReceiptLine.leftRight('1x Croissant', '\$3.00'),
    ReceiptLine.divider(),
    ReceiptLine.leftRight('Subtotal', '\$7.50'),
    ReceiptLine.leftRight('Tax (10%)', '\$0.75'),
    ReceiptLine.divider(char: '='),
    ReceiptLine.text('TOTAL: \$8.25',
      alignment: ReceiptTextAlign.center,
      bold: true,
      size: ReceiptTextSize.large,
    ),
    ReceiptLine.empty(),
    ReceiptLine.qrCode('https://shop.com/receipt/1234'),
  ],
  footer: 'Thank you for visiting!',
  cutPaper: true,
  openCashDrawer: false,
);

await provider.printReceiptToSelected(receipt);
```

### Receipt Line Types

| Type | Usage |
|------|-------|
| `ReceiptLine.text()` | Regular text with formatting |
| `ReceiptLine.leftRight()` | Two-column layout (item + price) |
| `ReceiptLine.divider()` | Horizontal line separator |
| `ReceiptLine.empty()` | Empty line for spacing |
| `ReceiptLine.barcode()` | 1D barcode |
| `ReceiptLine.qrCode()` | QR code |

---

## Printing Stickers/Labels (TSPL)

### Basic Usage

```dart
final sticker = StickerContent(
  customerName: 'John Doe',
  productName: 'Iced Caramel Latte',
  variants: ['Large', 'Extra Shot'],
  additions: ['Oat Milk', 'Vanilla Syrup'],
  notes: 'Less ice, extra sweet',
  quantity: 1,
  // Label settings
  width: 40,      // mm
  height: 30,     // mm
  gap: 3,         // mm between labels
  density: 8,     // 1-15, darkness level
  fontSize: 3,    // 1=small, 2=medium, 3=large, 4=extra large
  barcode: '123456789',
);

await provider.printStickerToSelected(sticker);
```

### TSPL Builder (Advanced)

For custom label layouts, use `TsplBuilder` directly:

```dart
import 'package:multiprinter/multiprinter.dart';

final tspl = TsplBuilder()
  ..size(50, 30)           // 50x30mm label
  ..gap(2, 0)              // 2mm gap between labels
  ..density(8)             // medium darkness
  ..cls()                  // clear buffer
  
  // Text at x=16, y=16 (in dots, 8 dots = 1mm)
  ..text(16, 16, 1, 0, 1, 1, 'Customer: John')
  
  // Larger text for product name
  ..text(16, 48, 3, 0, 1, 1, 'Iced Latte')
  
  // Barcode at x=16, y=100
  ..barcode(16, 100, 'CODE128', 40, 1, '12345678')
  
  // QR code
  ..qrcode(150, 16, 'M', 4, 'A', 0, 'https://example.com')
  
  // Print 1 copy
  ..printLabel(1);

// Get bytes to send to printer
final bytes = tspl.build();
```

### TSPL Commands Reference

| Method | Description | Parameters |
|--------|-------------|------------|
| `size(w, h)` | Label size in mm | width, height |
| `gap(d, o)` | Gap between labels | distance, offset (mm) |
| `density(n)` | Print darkness | 1-15 |
| `cls()` | Clear buffer | - |
| `text(x, y, font, rot, xm, ym, text)` | Print text | position in dots |
| `barcode(x, y, type, h, readable, data)` | 1D barcode | CODE128, EAN13, etc |
| `qrcode(x, y, ecc, size, mode, rot, data)` | QR code | L/M/Q/H error correction |
| `box(x, y, w, h, thickness)` | Rectangle | position and size |
| `line(x, y, w, h)` | Line/bar | - |
| `printLabel(qty)` | Print labels | quantity |
| `build()` | Get command bytes | returns List<int> |

### Coordinate System

- **Origin**: Top-left corner of label
- **Units**: Dots (8 dots = 1mm at 200 DPI)
- **X**: Horizontal from left
- **Y**: Vertical from top

```
┌────────────────────────────┐
│ (0,0)                      │
│    ┌──────────────┐        │
│    │ Text at      │        │
│    │ (16, 16)     │        │
│    └──────────────┘        │
│                            │
│    ┌──────────────┐        │
│    │ Barcode at   │        │
│    │ (16, 80)     │        │
│    └──────────────┘        │
└────────────────────────────┘
```

---

## Raw Printing (Direct Bytes)

For full control over printing, you can send raw ESC/POS or TSPL commands directly.

### Raw ESC/POS

```dart
// Build raw ESC/POS commands manually
final List<int> rawEscPos = [
  0x1B, 0x40,           // Initialize printer
  0x1B, 0x61, 0x01,     // Center align
  0x1B, 0x21, 0x30,     // Bold + Double height
  ...'HELLO WORLD\n'.codeUnits,
  0x1B, 0x21, 0x00,     // Normal text
  ...'Regular text\n'.codeUnits,
  0x1D, 0x56, 0x00,     // Cut paper
];

// Print to selected printers
await provider.printRawToSelected(rawEscPos);

// Or print to a specific printer
await provider.printRawToPrinter(printer, rawEscPos);
```

### Raw TSPL with TsplBuilder

```dart
// Use TsplBuilder for convenience
final tspl = TsplBuilder()
  ..size(50, 30)
  ..gap(2, 0)
  ..density(8)
  ..cls()
  ..text(16, 16, 3, 0, 1, 1, 'Custom Label')
  ..barcode(16, 60, 'CODE128', 40, 1, 'ABC123')
  ..printLabel(1);

// Print using TsplBuilder directly
await provider.printTsplToSelected(tspl);

// Or to a specific printer
await provider.printTsplToPrinter(printer, tspl);
```

### Raw TSPL Commands (Manual)

```dart
// Build TSPL commands as string
const tsplCommands = '''
SIZE 50 mm, 30 mm
GAP 2 mm, 0 mm
DENSITY 8
CLS
TEXT 16,16,"3",0,1,1,"Custom Label"
BARCODE 16,60,"128",40,1,0,2,2,"ABC123"
PRINT 1
''';

// Convert to bytes and print
await provider.printRawToSelected(tsplCommands.codeUnits);
```

### Raw Printing API Reference

| Method | Description |
|--------|-------------|
| `printRawToSelected(List<int> bytes)` | Print raw bytes to all selected printers |
| `printRawToPrinter(printer, List<int> bytes)` | Print raw bytes to a specific printer |
| `printTsplToSelected(TsplBuilder builder)` | Print TSPL using TsplBuilder to selected printers |
| `printTsplToPrinter(printer, TsplBuilder builder)` | Print TSPL to a specific printer |

### Common ESC/POS Commands

| Command | Hex | Description |
|---------|-----|-------------|
| Initialize | `1B 40` | Reset printer |
| Center align | `1B 61 01` | Align text center |
| Left align | `1B 61 00` | Align text left |
| Right align | `1B 61 02` | Align text right |
| Bold on | `1B 45 01` | Enable bold |
| Bold off | `1B 45 00` | Disable bold |
| Double height | `1B 21 10` | Double height text |
| Double width | `1B 21 20` | Double width text |
| Normal | `1B 21 00` | Normal text |
| Cut paper | `1D 56 00` | Full cut |
| Partial cut | `1D 56 01` | Partial cut |
| Open drawer | `1B 70 00 19 FA` | Open cash drawer |
| Line feed | `0A` | New line |

---

## Adding Printers

### Manual TCP/LAN Printer

```dart
await provider.addManualPrinter(
  name: 'Kitchen Printer',
  address: '192.168.1.100',
  connectionType: PrinterConnectionType.tcp,
  port: 9100,
  role: PrinterRole.kitchen,
  supportedDocuments: [PrintDocumentType.receipt],
);
```

### Scan for Bluetooth Printers

```dart
// Request permissions first
await provider.requestPermissions();

// Scan for Bluetooth printers
await provider.scanBluetoothPrinters();

// Access discovered printers
final discovered = provider.discoveredPrinters;

// Register a discovered printer
await provider.registerPrinter(
  device: discovered.first,
  role: PrinterRole.cashier,
  supportedDocuments: [PrintDocumentType.receipt],
);
```

### Scan Network (mDNS)

```dart
await provider.scanNetworkPrinters();
```

---

## UI Widgets

### PrinterCard

```dart
PrinterCard(
  printer: printer,
  isSelected: provider.isPrinterSelected(printer),
  onTap: () => provider.togglePrinterSelection(printer),
  onConnect: () => provider.connectToPrinter(printer),
  onDisconnect: () => provider.disconnectFromPrinter(printer),
  onDelete: () => provider.removePrinter(printer),
  onTestPrint: () => provider.printTestPage(printer),
)
```

**Note**: For TCP/LAN printers, Connect/Disconnect buttons are hidden and status shows "Auto" since connections are managed automatically.

### AddPrinterDialog

```dart
showDialog(
  context: context,
  builder: (context) => AddPrinterDialog(
    onAdd: (name, address, type, port, role, docs) async {
      await provider.addManualPrinter(
        name: name,
        address: address,
        connectionType: type,
        port: port,
        role: role,
        supportedDocuments: docs,
      );
    },
  ),
);
```

### PrintContentDialog

```dart
// For receipts
showDialog(
  context: context,
  builder: (context) => PrintContentDialog(
    documentType: PrintDocumentType.receipt,
    onPrint: (content) {
      provider.printReceiptToSelected(content as ReceiptContent);
    },
  ),
);

// For stickers
showDialog(
  context: context,
  builder: (context) => PrintContentDialog(
    documentType: PrintDocumentType.sticker,
    onPrint: (content) {
      provider.printStickerToSelected(content as StickerContent);
    },
  ),
);
```

### PermissionRequestWidget

```dart
PermissionRequestWidget(
  onPermissionsGranted: () {
    provider.scanBluetoothPrinters();
  },
  child: YourScanScreen(),
)
```

---

## Best Practices

### 1. Warm Up Network on App Start

```dart
class PrintScreen extends StatefulWidget {
  @override
  _PrintScreenState createState() => _PrintScreenState();
}

class _PrintScreenState extends State<PrintScreen> {
  @override
  void initState() {
    super.initState();
    // Warm up TCP connections to reduce first-print delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrinterProvider>().warmUpConnections();
    });
  }
}
```

### 2. Handle Print Results

```dart
final result = await provider.printReceiptToSelected(receipt);

if (result.hasFailures) {
  // Show error for failed prints
  for (final job in result.jobs.where((j) => j.status == PrintJobStatus.failed)) {
    showSnackBar('Failed: ${job.printer.name} - ${job.errorMessage}');
  }
}
```

### 3. Use Roles for Multi-Printer Setup

```dart
// Assign roles to printers
await provider.addManualPrinter(
  name: 'Counter',
  address: '192.168.1.100',
  role: PrinterRole.cashier,  // Receipts for customers
  supportedDocuments: [PrintDocumentType.receipt],
);

await provider.addManualPrinter(
  name: 'Kitchen',
  address: '192.168.1.101',
  role: PrinterRole.kitchen,  // Kitchen orders
  supportedDocuments: [PrintDocumentType.receipt],
);

await provider.addManualPrinter(
  name: 'Sticker',
  address: '192.168.1.102',
  role: PrinterRole.sticker,  // Product labels
  supportedDocuments: [PrintDocumentType.sticker],
);
```

---

## Architecture

```
lib/
├── src/
│   ├── core/
│   │   ├── constants/      # Printer types, roles, status enums
│   │   ├── errors/         # Exceptions and failures
│   │   ├── services/       # Permission service
│   │   └── utils/          # TsplBuilder, Result type
│   ├── data/
│   │   ├── datasources/    # PrinterDataSource (TCP, BT, USB handling)
│   │   ├── models/         # Data models with JSON serialization
│   │   └── repositories/   # Repository implementations
│   ├── domain/
│   │   ├── entities/       # PrinterDevice, PrintJob
│   │   ├── repositories/   # Abstract repository interfaces
│   │   ├── usecases/       # Business logic
│   │   └── value_objects/  # ReceiptContent, StickerContent
│   └── presentation/
│       ├── providers/      # PrinterProvider (state management)
│       └── widgets/        # UI components
└── multiprinter.dart       # Public API exports
```

---

## Platform Support

| Platform | Bluetooth | TCP/IP | USB |
|----------|-----------|--------|-----|
| Android  | ✅ | ✅ | ✅ |
| iOS      | ✅ | ✅ | ❌ |
| Windows  | ❌ | ✅ | ❌ |
| macOS    | ❌ | ✅ | ❌ |
| Linux    | ❌ | ✅ | ❌ |
| Web      | ❌ | ❌ | ❌ |

---

## Permissions

### Android (`AndroidManifest.xml`)

```xml
<!-- Bluetooth -->
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />

<!-- Location (required for Bluetooth scanning) -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- Network -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />

<!-- Nearby Devices (Android 12+) -->
<uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES" />
```

### iOS (`Info.plist`)

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to printers</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to connect to printers</string>
<key>NSLocalNetworkUsageDescription</key>
<string>This app needs local network access to connect to printers</string>
```

---

## Troubleshooting

### TCP Print Slow on First Attempt

This is normal on Android due to network stack initialization. Solutions:
1. Call `provider.warmUpConnections()` on app/screen init
2. The built-in retry mechanism handles this automatically

### Bluetooth Scan Not Finding Printers

1. Check all permissions are granted
2. Ensure Bluetooth is enabled
3. Make sure printer is in pairing mode
4. Try `provider.checkPermissions()` to refresh permission status

### Print Shows Success But Nothing Prints

1. Verify printer IP address is correct
2. Check printer is on the same network
3. Confirm port 9100 is not blocked
4. Try test print: `provider.printTestPage(printer)`

---

## License

MIT License - see LICENSE file for details.
