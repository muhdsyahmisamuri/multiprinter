import 'package:flutter/material.dart';
import 'package:multiprinter/multiprinter.dart';
import 'package:provider/provider.dart';

/// Screen displaying registered printers with management options
class PrintersScreen extends StatelessWidget {
  const PrintersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Printers'),
        centerTitle: true,
        actions: [
          // Refresh button
          Consumer<PrinterProvider>(
            builder: (context, provider, _) {
              return IconButton(
                onPressed: provider.isLoading
                    ? null
                    : () => provider.loadRegisteredPrinters(),
                icon: provider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                tooltip: 'Refresh',
              );
            },
          ),
        ],
      ),
      body: Consumer<PrinterProvider>(
        builder: (context, provider, _) {
          // Show permission request if not granted
          if (!provider.hasPermissions) {
            return PermissionRequestWidget(
              onPermissionsGranted: () {
                provider.checkPermissions();
                provider.loadRegisteredPrinters();
              },
            );
          }

          // Show empty state if no printers
          if (provider.registeredPrinters.isEmpty) {
            return _buildEmptyState(context);
          }

          // Show printer list
          return _buildPrinterList(context, provider);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPrinterDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Printer'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.print_disabled,
              size: 80,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 24),
            Text(
              'No Printers Registered',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Add printers manually or scan for available devices',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _showAddPrinterDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Printer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrinterList(BuildContext context, PrinterProvider provider) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(76),
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline.withAlpha(51),
              ),
            ),
          ),
          child: Row(
            children: [
              _buildSummaryItem(
                context,
                'Total',
                provider.registeredPrinters.length.toString(),
                Icons.print,
              ),
              const SizedBox(width: 16),
              _buildSummaryItem(
                context,
                'Connected',
                provider.connectedPrinters.length.toString(),
                Icons.check_circle,
                color: Colors.green,
              ),
              const SizedBox(width: 16),
              _buildSummaryItem(
                context,
                'Selected',
                provider.selectedPrinters.length.toString(),
                Icons.select_all,
                color: theme.colorScheme.primary,
              ),
              const Spacer(),
              // Select all / Clear selection
              if (provider.registeredPrinters.isNotEmpty)
                TextButton.icon(
                  onPressed: provider.selectedPrinters.length ==
                          provider.registeredPrinters.length
                      ? provider.clearSelection
                      : provider.selectAllPrinters,
                  icon: Icon(
                    provider.selectedPrinters.length ==
                            provider.registeredPrinters.length
                        ? Icons.deselect
                        : Icons.select_all,
                    size: 18,
                  ),
                  label: Text(
                    provider.selectedPrinters.length ==
                            provider.registeredPrinters.length
                        ? 'Clear'
                        : 'Select All',
                  ),
                ),
            ],
          ),
        ),
        // Error message
        if (provider.errorMessage != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: theme.colorScheme.errorContainer,
            child: Row(
              children: [
                Icon(Icons.error, color: theme.colorScheme.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    provider.errorMessage!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
                IconButton(
                  onPressed: provider.clearError,
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
          ),
        // Printer list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.registeredPrinters.length,
            itemBuilder: (context, index) {
              final printer = provider.registeredPrinters[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    PrinterCard(
                      printer: printer,
                      isSelected: provider.isPrinterSelected(printer),
                      onTap: () => provider.togglePrinterSelection(printer),
                      onConnect: () => provider.connectToPrinter(printer),
                      onDisconnect: () => provider.disconnectFromPrinter(printer),
                      onDelete: () => _confirmDelete(context, provider, printer),
                    ),
                    // Test print button
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: provider.isLoading
                              ? null
                              : () {
                                  provider.printTestPage(printer);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Sending test print to ${printer.name}...'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.print, size: 18),
                          label: const Text('Test Print'),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Action buttons for selected printers
        if (provider.selectedPrinters.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: provider.isLoading
                        ? null
                        : () => provider.connectToSelectedPrinters(),
                    icon: const Icon(Icons.link),
                    label: Text(
                      'Connect (${provider.selectedPrinters.length})',
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    final theme = Theme.of(context);
    color ??= theme.colorScheme.onSurface;

    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showAddPrinterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddPrinterDialog(
        onAdd: (name, address, connectionType, port, role, supportedDocuments) {
          context.read<PrinterProvider>().addManualPrinter(
                name: name,
                address: address,
                connectionType: connectionType,
                port: port,
                role: role,
                supportedDocuments: supportedDocuments,
              );
        },
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    PrinterProvider provider,
    PrinterDevice printer,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Printer'),
        content: Text('Are you sure you want to delete "${printer.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              provider.removePrinter(printer.id);
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
