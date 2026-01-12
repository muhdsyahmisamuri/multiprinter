import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/services/permission_service.dart';

/// Widget for displaying and requesting permissions
class PermissionRequestWidget extends StatefulWidget {
  final VoidCallback? onPermissionsGranted;
  final Widget? child;

  const PermissionRequestWidget({
    super.key,
    this.onPermissionsGranted,
    this.child,
  });

  @override
  State<PermissionRequestWidget> createState() =>
      _PermissionRequestWidgetState();
}

class _PermissionRequestWidgetState extends State<PermissionRequestWidget> {
  final _permissionService = PermissionService.instance;
  bool _isLoading = true;
  bool _hasPermissions = false;
  Map<String, PermissionStatus> _permissionStatuses = {};

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final hasAll = await _permissionService.hasAllPermissions();
    final statuses = await _permissionService.getDetailedPermissionStatuses();

    if (!mounted) return;
    setState(() {
      _hasPermissions = hasAll;
      _permissionStatuses = statuses;
      _isLoading = false;
    });

    if (hasAll && widget.onPermissionsGranted != null) {
      widget.onPermissionsGranted!();
    }
  }

  Future<void> _requestPermissions() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final result = await _permissionService.requestAllPermissions();

    if (!mounted) return;
    
    if (!result.allGranted) {
      // Check if any permission is permanently denied
      final statuses = await _permissionService.getDetailedPermissionStatuses();
      final hasPermanentlyDenied = statuses.values.any(
        (status) => status.isPermanentlyDenied,
      );

      if (hasPermanentlyDenied && mounted) {
        _showSettingsDialog();
      }
    }

    await _checkPermissions();
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'Some permissions were permanently denied. '
          'Please enable them in the app settings to use all features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _permissionService.openSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasPermissions && widget.child != null) {
      return widget.child!;
    }

    return _buildPermissionRequest();
  }

  Widget _buildPermissionRequest() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security, size: 80, color: colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'Permissions Required',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'This app needs the following permissions to connect to printers:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildPermissionList(),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _requestPermissions,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Grant Permissions'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _permissionService.openSettings(),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionList() {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: _permissionStatuses.entries.map((entry) {
            final isGranted = entry.value.isGranted || entry.value.isLimited;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    isGranted ? Icons.check_circle : Icons.cancel,
                    color: isGranted ? Colors.green : Colors.red,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          _permissionService.getPermissionStatusDescription(
                            entry.value,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Simple dialog to request permissions
class PermissionRequestDialog extends StatelessWidget {
  final VoidCallback? onGranted;

  const PermissionRequestDialog({super.key, this.onGranted});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.bluetooth_searching),
          SizedBox(width: 12),
          Text('Permissions Needed'),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('To scan and connect to printers, this app needs:'),
          SizedBox(height: 16),
          _PermissionItem(
            icon: Icons.bluetooth,
            title: 'Bluetooth',
            description: 'To find and connect to Bluetooth printers',
          ),
          _PermissionItem(
            icon: Icons.location_on,
            title: 'Location',
            description: 'Required for Bluetooth scanning on Android',
          ),
          _PermissionItem(
            icon: Icons.wifi,
            title: 'Network',
            description: 'To connect to TCP/LAN printers',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final result = await PermissionService.instance
                .requestAllPermissions();
            if (context.mounted) {
              Navigator.of(context).pop();
              if (result.allGranted && onGranted != null) {
                onGranted!();
              }
            }
          },
          child: const Text('Grant'),
        ),
      ],
    );
  }
}

class _PermissionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

