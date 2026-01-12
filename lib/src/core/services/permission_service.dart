import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

/// Service for handling app permissions
class PermissionService {
  PermissionService._();

  static final PermissionService instance = PermissionService._();

  /// Check if all required permissions are granted
  Future<bool> hasAllPermissions() async {
    final bluetoothPermissions = await hasBluetoothPermissions();
    final locationPermissions = await hasLocationPermissions();
    
    // On Android 12+, also check nearby devices permission
    if (Platform.isAndroid) {
      final nearbyDevices = await Permission.nearbyWifiDevices.isGranted;
      return bluetoothPermissions && locationPermissions && nearbyDevices;
    }
    
    return bluetoothPermissions && locationPermissions;
  }

  /// Check Bluetooth permissions
  Future<bool> hasBluetoothPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    if (Platform.isAndroid) {
      final bluetoothScan = await Permission.bluetoothScan.isGranted;
      final bluetoothConnect = await Permission.bluetoothConnect.isGranted;
      return bluetoothScan && bluetoothConnect;
    }

    // iOS uses Bluetooth permission
    if (Platform.isIOS) {
      return await Permission.bluetooth.isGranted;
    }

    return true;
  }

  /// Check Location permissions (required for Bluetooth on Android)
  Future<bool> hasLocationPermissions() async {
    if (!Platform.isAndroid) return true;
    return await Permission.locationWhenInUse.isGranted;
  }

  /// Request all required permissions
  Future<PermissionResult> requestAllPermissions() async {
    final results = <String, bool>{};

    // Request Bluetooth permissions
    final bluetoothResult = await requestBluetoothPermissions();
    results['bluetooth'] = bluetoothResult;

    // Request Location permissions (Android only, required for BT scanning)
    if (Platform.isAndroid) {
      final locationResult = await requestLocationPermissions();
      results['location'] = locationResult;

      // Request Nearby Devices permission (Android 12+)
      final nearbyResult = await requestNearbyDevicesPermission();
      results['nearbyDevices'] = nearbyResult;
    }

    final allGranted = results.values.every((granted) => granted);

    return PermissionResult(allGranted: allGranted, details: results);
  }

  /// Request Bluetooth permissions
  Future<bool> requestBluetoothPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
      ].request();

      return statuses.values.every(
        (status) => status.isGranted || status.isLimited,
      );
    }

    if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      return status.isGranted || status.isLimited;
    }

    return true;
  }

  /// Request Location permissions
  Future<bool> requestLocationPermissions() async {
    if (!Platform.isAndroid) return true;

    final status = await Permission.locationWhenInUse.request();
    return status.isGranted || status.isLimited;
  }

  /// Request nearby devices permission (Android 12+)
  Future<bool> requestNearbyDevicesPermission() async {
    if (!Platform.isAndroid) return true;

    final status = await Permission.nearbyWifiDevices.request();
    return status.isGranted || status.isLimited;
  }

  /// Check if permission is permanently denied
  Future<bool> isPermissionPermanentlyDenied(Permission permission) async {
    return await permission.isPermanentlyDenied;
  }

  /// Open app settings
  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// Get permission status description
  String getPermissionStatusDescription(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return 'Granted';
      case PermissionStatus.denied:
        return 'Denied';
      case PermissionStatus.restricted:
        return 'Restricted';
      case PermissionStatus.limited:
        return 'Limited';
      case PermissionStatus.permanentlyDenied:
        return 'Permanently Denied';
      case PermissionStatus.provisional:
        return 'Provisional';
    }
  }

  /// Get detailed permission statuses
  Future<Map<String, PermissionStatus>> getDetailedPermissionStatuses() async {
    final Map<String, PermissionStatus> statuses = {};

    if (Platform.isAndroid) {
      statuses['Bluetooth Scan'] = await Permission.bluetoothScan.status;
      statuses['Bluetooth Connect'] = await Permission.bluetoothConnect.status;
      statuses['Location'] = await Permission.locationWhenInUse.status;
      statuses['Nearby Devices'] = await Permission.nearbyWifiDevices.status;
    }

    if (Platform.isIOS) {
      statuses['Bluetooth'] = await Permission.bluetooth.status;
    }

    return statuses;
  }
}

/// Result of permission request
class PermissionResult {
  final bool allGranted;
  final Map<String, bool> details;

  const PermissionResult({required this.allGranted, required this.details});

  String get summary {
    if (allGranted) {
      return 'All permissions granted';
    }

    final denied = details.entries
        .where((e) => !e.value)
        .map((e) => e.key)
        .join(', ');

    return 'Missing permissions: $denied';
  }
}

