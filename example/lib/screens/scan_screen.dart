import 'package:flutter/material.dart';
import 'package:multiprinter/multiprinter.dart';
import 'package:provider/provider.dart';

/// Screen for scanning and discovering printers
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  String _subnet = '192.168.1';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan for Printers'),
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
                // Scan options
                _buildScanSection(context, theme, provider),
                const SizedBox(height: 24),

                // Status indicator
                if (provider.state == PrinterProviderState.scanning)
                  Center(
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Scanning for printers...',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),

                // Error message
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

                // Scanned printers
                if (provider.scannedPrinters.isNotEmpty) ...[
                  Text(
                    'Found Printers (${provider.scannedPrinters.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...provider.scannedPrinters.map((printer) {
                    final isRegistered = provider.registeredPrinters.any(
                      (p) => p.address.address == printer.address.address,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: _buildConnectionIcon(printer.connectionType),
                        title: Text(printer.name),
                        subtitle: Text(printer.address.formattedAddress),
                        trailing: isRegistered
                            ? Chip(
                                label: const Text('Registered'),
                                backgroundColor:
                                    theme.colorScheme.primaryContainer,
                              )
                            : FilledButton.tonal(
                                onPressed: () =>
                                    provider.registerPrinter(printer),
                                child: const Text('Add'),
                              ),
                      ),
                    );
                  }),
                ],

                // Empty state when no printers found after scanning
                if (provider.scannedPrinters.isEmpty &&
                    provider.state != PrinterProviderState.scanning)
                  _buildEmptyState(context, theme),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScanSection(
    BuildContext context,
    ThemeData theme,
    PrinterProvider provider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scan Options',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Scan buttons
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // Bluetooth scan
                _buildScanButton(
                  context,
                  icon: Icons.bluetooth,
                  label: 'Bluetooth',
                  color: Colors.blue,
                  onPressed: provider.isLoading
                      ? null
                      : () => provider.scanBluetoothPrinters(),
                ),
                // USB scan
                _buildScanButton(
                  context,
                  icon: Icons.usb,
                  label: 'USB',
                  color: Colors.orange,
                  onPressed: provider.isLoading
                      ? null
                      : () => provider.scanUsbPrinters(),
                ),
                // Scan all
                _buildScanButton(
                  context,
                  icon: Icons.radar,
                  label: 'Scan All',
                  color: theme.colorScheme.primary,
                  onPressed: provider.isLoading
                      ? null
                      : () => provider.scanAllPrinters(),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Network scan with subnet input
            Text(
              'Network Scan',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _subnet,
                    decoration: const InputDecoration(
                      labelText: 'Subnet',
                      hintText: '192.168.1',
                      prefixIcon: Icon(Icons.wifi),
                      helperText: 'Enter the first 3 octets of your network',
                    ),
                    onChanged: (value) => _subnet = value,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: provider.isLoading
                      ? null
                      : () => provider.scanNetworkPrinters(subnet: _subnet),
                  icon: const Icon(Icons.search),
                  label: const Text('Scan'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  Widget _buildConnectionIcon(PrinterConnectionType type) {
    IconData icon;
    Color color;

    switch (type) {
      case PrinterConnectionType.bluetooth:
        icon = Icons.bluetooth;
        color = Colors.blue;
        break;
      case PrinterConnectionType.tcp:
      case PrinterConnectionType.lan:
        icon = Icons.wifi;
        color = Colors.green;
        break;
      case PrinterConnectionType.usb:
        icon = Icons.usb;
        color = Colors.orange;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No Printers Found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Use the scan options above to discover printers on your network or connected via Bluetooth/USB.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
