import 'package:flutter/material.dart';
import 'package:multiprinter/multiprinter.dart';
import 'package:provider/provider.dart';

/// Screen for printing receipts and stickers
class PrintScreen extends StatefulWidget {
  const PrintScreen({super.key});

  @override
  State<PrintScreen> createState() => _PrintScreenState();
}

class _PrintScreenState extends State<PrintScreen> {
  @override
  void initState() {
    super.initState();
    // Warm up network connections when entering print screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrinterProvider>().warmUpConnections();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Print'),
        centerTitle: true,
      ),
      body: Consumer<PrinterProvider>(
        builder: (context, provider, _) {
          // Show permission request if not granted
          if (!provider.hasPermissions) {
            return PermissionRequestWidget(
              onPermissionsGranted: () {
                provider.checkPermissions();
              },
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selected printers info
                _buildSelectedPrintersCard(context, theme, provider),
                const SizedBox(height: 24),

                // Error/Success message
                if (provider.errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: theme.colorScheme.error),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            provider.errorMessage!,
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: provider.clearError,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),

                // Print options
                Text(
                  'Print Options',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Receipt printing card
                _buildPrintOptionCard(
                  context,
                  theme,
                  icon: Icons.receipt_long,
                  title: 'Print Receipt',
                  subtitle: 'Create and print a POS receipt with items',
                  color: Colors.blue,
                  onTap: provider.selectedPrinters.isEmpty || provider.isLoading
                      ? null
                      : () => _showPrintReceiptDialog(context, provider),
                ),
                const SizedBox(height: 12),

                // Sticker printing card
                _buildPrintOptionCard(
                  context,
                  theme,
                  icon: Icons.label,
                  title: 'Print Sticker',
                  subtitle: 'Create and print a product label/sticker',
                  color: Colors.orange,
                  onTap: provider.selectedPrinters.isEmpty || provider.isLoading
                      ? null
                      : () => _showPrintStickerDialog(context, provider),
                ),
                const SizedBox(height: 24),

                // Quick print section
                Text(
                  'Quick Print',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Quick print buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickPrintButton(
                        context,
                        theme,
                        icon: Icons.receipt,
                        label: 'Test Receipt',
                        onPressed:
                            provider.selectedPrinters.isEmpty || provider.isLoading
                                ? null
                                : () => _printTestReceipt(context, provider),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickPrintButton(
                        context,
                        theme,
                        icon: Icons.label_outline,
                        label: 'Test Sticker',
                        onPressed:
                            provider.selectedPrinters.isEmpty || provider.isLoading
                                ? null
                                : () => _printTestSticker(context, provider),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Last print result
                if (provider.lastPrintResult != null) ...[
                  Text(
                    'Last Print Result',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPrintResultCard(context, theme, provider.lastPrintResult!),
                ],

                // Printing status indicator
                if (provider.state == PrinterProviderState.printing)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Printing...',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedPrintersCard(
    BuildContext context,
    ThemeData theme,
    PrinterProvider provider,
  ) {
    final selectedCount = provider.selectedPrinters.length;
    final connectedCount = provider.selectedPrinters
        .where((p) => p.isConnected)
        .length;

    return Card(
      color: selectedCount == 0
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selectedCount == 0
                    ? theme.colorScheme.outline.withAlpha(51)
                    : theme.colorScheme.primary.withAlpha(51),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                selectedCount == 0 ? Icons.print_disabled : Icons.print,
                color: selectedCount == 0
                    ? theme.colorScheme.outline
                    : theme.colorScheme.primary,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedCount == 0
                        ? 'No Printers Selected'
                        : '$selectedCount Printer${selectedCount > 1 ? 's' : ''} Selected',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: selectedCount == 0
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedCount == 0
                        ? 'Select printers from the Printers tab'
                        : '$connectedCount connected',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: selectedCount == 0
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onPrimaryContainer.withAlpha(178),
                    ),
                  ),
                ],
              ),
            ),
            if (selectedCount > 0)
              Wrap(
                spacing: 4,
                children: provider.selectedPrinters.take(3).map((printer) {
                  return CircleAvatar(
                    radius: 14,
                    backgroundColor: printer.isConnected
                        ? Colors.green
                        : theme.colorScheme.outline,
                    child: Icon(
                      _getConnectionTypeIcon(printer.connectionType),
                      size: 14,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrintOptionCard(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isEnabled ? color.withAlpha(25) : Colors.grey.withAlpha(25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: isEnabled ? color : Colors.grey,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isEnabled ? null : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isEnabled
                            ? theme.colorScheme.onSurfaceVariant
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: isEnabled ? theme.colorScheme.outline : Colors.grey,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickPrintButton(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildPrintResultCard(
    BuildContext context,
    ThemeData theme,
    BatchPrintResult result,
  ) {
    return Card(
      color: result.allSucceeded
          ? Colors.green.withAlpha(25)
          : theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.allSucceeded ? Icons.check_circle : Icons.warning,
                  color: result.allSucceeded ? Colors.green : theme.colorScheme.error,
                ),
                const SizedBox(width: 12),
                Text(
                  result.allSucceeded ? 'All prints successful' : 'Some prints failed',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: result.allSucceeded
                        ? Colors.green
                        : theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${result.successCount}/${result.jobs.length} successful',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            ...result.jobs.map((job) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      job.status == PrintJobStatus.completed
                          ? Icons.check
                          : Icons.close,
                      size: 16,
                      color: job.status == PrintJobStatus.completed
                          ? Colors.green
                          : theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        job.printer.name,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    if (job.errorMessage != null)
                      Expanded(
                        child: Text(
                          job.errorMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  IconData _getConnectionTypeIcon(PrinterConnectionType type) {
    switch (type) {
      case PrinterConnectionType.bluetooth:
        return Icons.bluetooth;
      case PrinterConnectionType.tcp:
      case PrinterConnectionType.lan:
        return Icons.wifi;
      case PrinterConnectionType.usb:
        return Icons.usb;
    }
  }

  void _showPrintReceiptDialog(BuildContext context, PrinterProvider provider) {
    showDialog(
      context: context,
      builder: (context) => PrintContentDialog(
        documentType: PrintDocumentType.receipt,
        onPrint: (content) {
          provider.printReceiptToSelected(content as ReceiptContent);
        },
      ),
    );
  }

  void _showPrintStickerDialog(BuildContext context, PrinterProvider provider) {
    showDialog(
      context: context,
      builder: (context) => PrintContentDialog(
        documentType: PrintDocumentType.sticker,
        onPrint: (content) {
          provider.printStickerToSelected(content as StickerContent);
        },
      ),
    );
  }

  void _printTestReceipt(BuildContext context, PrinterProvider provider) {
    final receipt = ReceiptContent(
      storeName: 'Demo Coffee Shop',
      storeAddress: '123 Main Street, City',
      lines: [
        ReceiptLine.text(
          'ORDER #1234',
          alignment: ReceiptTextAlign.center,
          bold: true,
          size: ReceiptTextSize.large,
        ),
        ReceiptLine.divider(),
        ReceiptLine.text('Items:', bold: true),
        ReceiptLine.leftRight('1x Cappuccino', '\$4.50'),
        ReceiptLine.leftRight('1x Croissant', '\$3.00'),
        ReceiptLine.leftRight('1x Americano', '\$3.50'),
        ReceiptLine.divider(),
        ReceiptLine.leftRight('Subtotal', '\$11.00'),
        ReceiptLine.leftRight('Tax (10%)', '\$1.10'),
        ReceiptLine.divider(char: '='),
        ReceiptLine.text(
          'TOTAL: \$12.10',
          alignment: ReceiptTextAlign.center,
          bold: true,
          size: ReceiptTextSize.large,
        ),
        ReceiptLine.empty(),
        ReceiptLine.text(
          'Payment: Credit Card',
          alignment: ReceiptTextAlign.center,
        ),
        ReceiptLine.divider(),
        ReceiptLine.qrCode('https://demo.shop/receipt/1234'),
      ],
      footer: 'Thank you for visiting! Have a great day!',
      cutPaper: true,
      openCashDrawer: false,
    );

    provider.printReceiptToSelected(receipt);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Printing test receipt...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _printTestSticker(BuildContext context, PrinterProvider provider) {
    const sticker = StickerContent(
      customerName: 'John Doe',
      productName: 'Iced Caramel Latte',
      variants: ['Large', 'Extra Shot'],
      additions: ['Oat Milk', 'Vanilla Syrup'],
      notes: 'Less ice, extra sweet',
      quantity: 1,
      barcode: '123456789',
    );

    provider.printStickerToSelected(sticker);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Printing test sticker...'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
