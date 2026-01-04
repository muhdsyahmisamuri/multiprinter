import 'package:flutter/material.dart';
import 'package:multiprinter/multiprinter.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the MultiPrinter package
  await MultiPrinter.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Use the convenience method to create the provider
        MultiPrinter.createPrinterProvider(),
      ],
      child: MaterialApp(
        title: 'MultiPrinter Example',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const ExampleHomePage(),
      ),
    );
  }
}

class ExampleHomePage extends StatefulWidget {
  const ExampleHomePage({super.key});

  @override
  State<ExampleHomePage> createState() => _ExampleHomePageState();
}

class _ExampleHomePageState extends State<ExampleHomePage> {
  @override
  void initState() {
    super.initState();
    // Load registered printers on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrinterProvider>().loadRegisteredPrinters();
      context.read<PrinterProvider>().checkPermissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MultiPrinter Example'),
        actions: [
          Consumer<PrinterProvider>(
            builder: (context, provider, _) {
              if (provider.selectedPrinters.isNotEmpty) {
                return Chip(
                  label: Text('${provider.selectedPrinters.length} selected'),
                  onDeleted: () => provider.clearSelection(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<PrinterProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.registeredPrinters.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.print_disabled, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No printers registered'),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showAddPrinterDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Printer'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => provider.scanBluetoothPrinters(),
                    icon: const Icon(Icons.bluetooth_searching),
                    label: const Text('Scan Bluetooth'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.registeredPrinters.length,
            itemBuilder: (context, index) {
              final printer = provider.registeredPrinters[index];
              final isSelected = provider.isPrinterSelected(printer);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PrinterCard(
                  printer: printer,
                  isSelected: isSelected,
                  onTap: () => provider.togglePrinterSelection(printer),
                  onConnect: () => provider.connectToPrinter(printer),
                  onDisconnect: () => provider.disconnectFromPrinter(printer),
                  onDelete: () => provider.removePrinter(printer.id),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'add',
            onPressed: () => _showAddPrinterDialog(context),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 12),
          Consumer<PrinterProvider>(
            builder: (context, provider, _) {
              return FloatingActionButton.extended(
                heroTag: 'print',
                onPressed: provider.selectedPrinters.isEmpty
                    ? null
                    : () => _printReceipt(context),
                backgroundColor: provider.selectedPrinters.isEmpty
                    ? Colors.grey
                    : null,
                icon: const Icon(Icons.print),
                label: const Text('Print'),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddPrinterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddPrinterDialog(
        onAdd: (name, address, connectionType, port, role, supportedDocs) {
          context.read<PrinterProvider>().addManualPrinter(
            name: name,
            address: address,
            connectionType: connectionType,
            port: port,
            role: role,
            supportedDocuments: supportedDocs,
          );
        },
      ),
    );
  }

  void _printReceipt(BuildContext context) {
    final provider = context.read<PrinterProvider>();

    // Create a sample receipt
    final receipt = ReceiptContent(
      storeName: 'My Coffee Shop',
      storeAddress: '123 Main Street, City',
      lines: [
        ReceiptLine.divider(),
        ReceiptLine.leftRight('Latte', '\$5.00'),
        ReceiptLine.leftRight('Croissant', '\$3.50'),
        ReceiptLine.leftRight('Cookie', '\$2.00'),
        ReceiptLine.divider(),
        ReceiptLine.leftRight('SUBTOTAL', '\$10.50'),
        ReceiptLine.leftRight('TAX (8%)', '\$0.84'),
        ReceiptLine.divider(),
        ReceiptLine.text('TOTAL: \$11.34', bold: true, alignment: ReceiptTextAlign.center),
        ReceiptLine.empty(),
        ReceiptLine.qrCode('https://myshop.com/receipt/12345'),
      ],
      footer: 'Thank you for your purchase!',
      cutPaper: true,
    );

    // Print to selected printers
    provider.printReceiptToSelected(receipt);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Printing to ${provider.selectedPrinters.length} printers...'),
      ),
    );
  }
}

