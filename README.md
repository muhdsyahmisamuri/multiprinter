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

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  multiprinter:
    path: /path/to/multiprinter/packages/multiprinter  # Absolute or relative path
```

For example, if your project is at the same level as multiprinter:
```yaml
dependencies:
  multiprinter:
    path: ../multiprinter/packages/multiprinter
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

## Printing Receipts

```dart
final receipt = ReceiptContent(
  storeName: 'My Store',
  storeAddress: '123 Main Street',
  lines: [
    ReceiptLine.divider(),
    ReceiptLine.leftRight('Coffee', '\$5.00'),
    ReceiptLine.leftRight('Sandwich', '\$8.50'),
    ReceiptLine.divider(),
    ReceiptLine.leftRight('TOTAL', '\$13.50'),
    ReceiptLine.empty(),
    ReceiptLine.qrCode('https://mystore.com/receipt/123'),
  ],
  footer: 'Thank you for your purchase!',
  cutPaper: true,
  openCashDrawer: false,
);

// Print to all selected printers simultaneously
await provider.printReceiptToSelected(receipt);
```

## Printing Stickers/Labels

```dart
final sticker = StickerContent(
  customerName: 'John Doe',
  productName: 'Iced Latte',
  variants: ['Large', 'Extra Shot'],
  additions: ['Oat Milk'],
  notes: 'Less Ice',
  quantity: 2,
);

await provider.printStickerToSelected(sticker);
```

## Adding Printers Manually

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

## UI Widgets

The package includes ready-to-use widgets:

### PrinterCard
Displays printer information with connection status and actions:

```dart
PrinterCard(
  printer: printer,
  isSelected: true,
  onTap: () => {},
  onConnect: () => {},
  onDisconnect: () => {},
  onDelete: () => {},
)
```

### AddPrinterDialog
Dialog for manually adding printers:

```dart
showDialog(
  context: context,
  builder: (context) => AddPrinterDialog(
    onAdd: (name, address, type, port, role, docs) {
      // Handle printer addition
    },
  ),
);
```

### PrintContentDialog
Dialog for creating and printing receipts/stickers:

```dart
showDialog(
  context: context,
  builder: (context) => PrintContentDialog(
    documentType: PrintDocumentType.receipt,
    onPrint: (content) {
      provider.printReceiptToSelected(content as ReceiptContent);
    },
  ),
);
```

### PermissionRequestWidget
Handles permission requests for Bluetooth scanning:

```dart
PermissionRequestWidget(
  onPermissionsGranted: () {
    // Permissions granted, proceed with scanning
  },
  child: YourWidget(),
)
```

## Architecture

The package follows Clean Architecture principles:

```
lib/
├── src/
│   ├── core/           # Constants, errors, utilities
│   ├── data/           # Data sources, models, repositories
│   ├── domain/         # Entities, use cases, repository interfaces
│   └── presentation/   # Providers, widgets
└── multiprinter.dart   # Main exports
```

## Supported Printer Types

| Type | ESC/POS Receipts | TSPL Stickers |
|------|------------------|---------------|
| Bluetooth | ✅ | ✅ |
| TCP/IP | ✅ | ✅ |
| LAN | ✅ | ✅ |
| USB (Android) | ✅ | ✅ |

## Platform Support

| Platform | Support |
|----------|---------|
| Android | ✅ Full |
| iOS | ✅ Bluetooth only |
| Windows | ✅ TCP/IP |
| macOS | ✅ TCP/IP |
| Linux | ✅ TCP/IP |
| Web | ❌ |

## Permissions

### Android

Add to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### iOS

Add to `Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to printers</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to connect to printers</string>
```

## License

MIT License - see LICENSE file for details.

