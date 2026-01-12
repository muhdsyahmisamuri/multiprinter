import 'package:flutter/material.dart';
import '../../core/constants/printer_constants.dart';
import '../../domain/entities/printer_device.dart';

/// Card widget displaying printer information
class PrinterCard extends StatelessWidget {
  final PrinterDevice printer;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;
  final VoidCallback? onDelete;

  const PrinterCard({
    super.key,
    required this.printer,
    this.isSelected = false,
    this.onTap,
    this.onConnect,
    this.onDisconnect,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildConnectionIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          printer.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          printer.address.formattedAddress,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(context),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildChip(
                    context,
                    _getConnectionTypeLabel(),
                    _getConnectionTypeIcon(),
                  ),
                  const SizedBox(width: 8),
                  _buildChip(context, _getRoleLabel(), Icons.work_outline),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildSupportedDocsBadges(context),
                  const Spacer(),
                  _buildActionButtons(context),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionIcon() {
    IconData icon;
    Color color;

    switch (printer.connectionType) {
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isConnected = printer.isConnected;
    
    // TCP/LAN printers auto-connect when printing
    final isAutoConnect = printer.connectionType == PrinterConnectionType.tcp ||
                          printer.connectionType == PrinterConnectionType.lan;

    if (isAutoConnect) {
      // Show "Auto" badge for network printers
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue.withAlpha(25),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi, size: 14, color: Colors.blue),
            SizedBox(width: 4),
            Text(
              'Auto',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isConnected
            ? Colors.green.withAlpha(25)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: isConnected ? Colors.green : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            isConnected ? 'Connected' : 'Disconnected',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isConnected ? Colors.green : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportedDocsBadges(BuildContext context) {
    return Row(
      children: [
        if (printer.supportsReceipts)
          _buildDocBadge(context, 'Receipt', Icons.receipt_long),
        if (printer.supportsReceipts && printer.supportsStickers)
          const SizedBox(width: 6),
        if (printer.supportsStickers)
          _buildDocBadge(context, 'Sticker', Icons.label_outline),
      ],
    );
  }

  Widget _buildDocBadge(BuildContext context, String label, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline.withAlpha(76)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    // TCP/LAN printers connect automatically - no manual connect needed
    final needsManualConnect = printer.connectionType == PrinterConnectionType.bluetooth ||
                                printer.connectionType == PrinterConnectionType.usb;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (needsManualConnect && !printer.isConnected && onConnect != null)
          IconButton(
            onPressed: onConnect,
            icon: const Icon(Icons.link),
            tooltip: 'Connect',
            iconSize: 20,
          ),
        if (needsManualConnect && printer.isConnected && onDisconnect != null)
          IconButton(
            onPressed: onDisconnect,
            icon: const Icon(Icons.link_off),
            tooltip: 'Disconnect',
            iconSize: 20,
          ),
        if (onDelete != null)
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
            tooltip: 'Delete',
            iconSize: 20,
          ),
      ],
    );
  }

  String _getConnectionTypeLabel() {
    switch (printer.connectionType) {
      case PrinterConnectionType.bluetooth:
        return 'Bluetooth';
      case PrinterConnectionType.tcp:
        return 'TCP/IP';
      case PrinterConnectionType.lan:
        return 'LAN';
      case PrinterConnectionType.usb:
        return 'USB';
    }
  }

  IconData _getConnectionTypeIcon() {
    switch (printer.connectionType) {
      case PrinterConnectionType.bluetooth:
        return Icons.bluetooth;
      case PrinterConnectionType.tcp:
        return Icons.router;
      case PrinterConnectionType.lan:
        return Icons.wifi;
      case PrinterConnectionType.usb:
        return Icons.usb;
    }
  }

  String _getRoleLabel() {
    switch (printer.role) {
      case PrinterRole.cashier:
        return 'Cashier';
      case PrinterRole.kitchen:
        return 'Kitchen';
      case PrinterRole.bar:
        return 'Bar';
      case PrinterRole.sticker:
        return 'Sticker';
      case PrinterRole.general:
        return 'General';
    }
  }
}

