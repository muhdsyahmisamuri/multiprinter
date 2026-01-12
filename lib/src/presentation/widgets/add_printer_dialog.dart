import 'package:flutter/material.dart';
import '../../core/constants/printer_constants.dart';

/// Dialog for adding a printer manually
class AddPrinterDialog extends StatefulWidget {
  final Function(
    String name,
    String address,
    PrinterConnectionType connectionType,
    int? port,
    PrinterRole role,
    List<PrintDocumentType> supportedDocuments,
  )
  onAdd;

  const AddPrinterDialog({super.key, required this.onAdd});

  @override
  State<AddPrinterDialog> createState() => _AddPrinterDialogState();
}

class _AddPrinterDialogState extends State<AddPrinterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _portController = TextEditingController(text: '9100');

  PrinterConnectionType _connectionType = PrinterConnectionType.bluetooth;
  PrinterRole _role = PrinterRole.general;
  bool _supportsReceipt = true;
  bool _supportsSticker = true;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Add Printer'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Printer Name',
                  hintText: 'e.g., Kitchen Printer',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<PrinterConnectionType>(
                initialValue: _connectionType,
                decoration: const InputDecoration(
                  labelText: 'Connection Type',
                  prefixIcon: Icon(Icons.cable),
                ),
                items: PrinterConnectionType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(_getConnectionTypeName(type)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _connectionType = value!;
                    if (_connectionType == PrinterConnectionType.bluetooth) {
                      _portController.clear();
                    } else {
                      _portController.text = '9100';
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: _getAddressLabel(),
                  hintText: _getAddressHint(),
                  prefixIcon: Icon(_getAddressIcon()),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an address';
                  }
                  return null;
                },
              ),
              if (_connectionType == PrinterConnectionType.tcp ||
                  _connectionType == PrinterConnectionType.lan) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _portController,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    hintText: '9100',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final port = int.tryParse(value);
                      if (port == null || port < 1 || port > 65535) {
                        return 'Invalid port number';
                      }
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<PrinterRole>(
                initialValue: _role,
                decoration: const InputDecoration(
                  labelText: 'Printer Role',
                  prefixIcon: Icon(Icons.work_outline),
                ),
                items: PrinterRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(_getRoleName(role)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _role = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text('Supported Documents', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Receipt'),
                      value: _supportsReceipt,
                      onChanged: (value) {
                        setState(() {
                          _supportsReceipt = value!;
                        });
                      },
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Sticker'),
                      value: _supportsSticker,
                      onChanged: (value) {
                        setState(() {
                          _supportsSticker = value!;
                        });
                      },
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final supportedDocs = <PrintDocumentType>[];
      if (_supportsReceipt) supportedDocs.add(PrintDocumentType.receipt);
      if (_supportsSticker) supportedDocs.add(PrintDocumentType.sticker);

      if (supportedDocs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one document type'),
          ),
        );
        return;
      }

      widget.onAdd(
        _nameController.text,
        _addressController.text,
        _connectionType,
        _portController.text.isNotEmpty
            ? int.tryParse(_portController.text)
            : null,
        _role,
        supportedDocs,
      );
      Navigator.of(context).pop();
    }
  }

  String _getConnectionTypeName(PrinterConnectionType type) {
    switch (type) {
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

  String _getRoleName(PrinterRole role) {
    switch (role) {
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

  String _getAddressLabel() {
    switch (_connectionType) {
      case PrinterConnectionType.bluetooth:
        return 'MAC Address';
      case PrinterConnectionType.tcp:
      case PrinterConnectionType.lan:
        return 'IP Address';
      case PrinterConnectionType.usb:
        return 'Device Path';
    }
  }

  String _getAddressHint() {
    switch (_connectionType) {
      case PrinterConnectionType.bluetooth:
        return 'AA:BB:CC:DD:EE:FF';
      case PrinterConnectionType.tcp:
      case PrinterConnectionType.lan:
        return '192.168.1.100';
      case PrinterConnectionType.usb:
        return '/dev/usb/lp0';
    }
  }

  IconData _getAddressIcon() {
    switch (_connectionType) {
      case PrinterConnectionType.bluetooth:
        return Icons.bluetooth;
      case PrinterConnectionType.tcp:
      case PrinterConnectionType.lan:
        return Icons.wifi;
      case PrinterConnectionType.usb:
        return Icons.usb;
    }
  }
}

