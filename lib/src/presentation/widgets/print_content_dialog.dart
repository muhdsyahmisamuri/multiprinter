import 'package:flutter/material.dart';
import '../../core/constants/printer_constants.dart';
import '../../domain/value_objects/print_content.dart';

/// Dialog for creating print content
class PrintContentDialog extends StatefulWidget {
  final PrintDocumentType documentType;
  final Function(PrintContent content) onPrint;

  const PrintContentDialog({
    super.key,
    required this.documentType,
    required this.onPrint,
  });

  @override
  State<PrintContentDialog> createState() => _PrintContentDialogState();
}

class _PrintContentDialogState extends State<PrintContentDialog> {
  // Receipt fields
  final _storeNameController = TextEditingController(text: 'My Store');
  final _storeAddressController = TextEditingController(
    text: '123 Main Street',
  );
  final _footerController = TextEditingController(
    text: 'Thank you for your purchase!',
  );
  final List<_ReceiptItemController> _receiptItems = [];
  bool _cutPaper = true;
  bool _openCashDrawer = false;

  // Sticker fields
  final _customerNameController = TextEditingController(text: 'John Doe');
  final _productNameController = TextEditingController(text: 'Iced Latte');
  final _variantsController = TextEditingController(text: 'Large, Extra Shot');
  final _additionsController = TextEditingController(text: 'Oat Milk');
  final _notesController = TextEditingController(text: 'Less Ice');
  final _barcodeController = TextEditingController();
  int _quantity = 1;
  int _labelWidth = PrinterConstants.defaultStickerWidth;
  int _labelHeight = PrinterConstants.defaultStickerHeight;
  int _labelGap = PrinterConstants.defaultStickerGap;
  int _density = 8;
  int _fontSize = 3;

  @override
  void initState() {
    super.initState();
    // Add default receipt items
    _receiptItems.add(_ReceiptItemController('Coffee', '5.00'));
    _receiptItems.add(_ReceiptItemController('Sandwich', '8.50'));
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeAddressController.dispose();
    _footerController.dispose();
    _customerNameController.dispose();
    _productNameController.dispose();
    _variantsController.dispose();
    _additionsController.dispose();
    _notesController.dispose();
    _barcodeController.dispose();
    for (final item in _receiptItems) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.documentType == PrintDocumentType.receipt
            ? 'Print Receipt'
            : 'Print Sticker',
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: widget.documentType == PrintDocumentType.receipt
              ? _buildReceiptForm()
              : _buildStickerForm(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.print),
          label: const Text('Print'),
        ),
      ],
    );
  }

  Widget _buildReceiptForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _storeNameController,
          decoration: const InputDecoration(
            labelText: 'Store Name',
            prefixIcon: Icon(Icons.store),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _storeAddressController,
          decoration: const InputDecoration(
            labelText: 'Store Address',
            prefixIcon: Icon(Icons.location_on),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Items', style: Theme.of(context).textTheme.titleSmall),
            IconButton(
              onPressed: _addReceiptItem,
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Add Item',
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._receiptItems.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: entry.value.nameController,
                    decoration: const InputDecoration(
                      labelText: 'Item',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: entry.value.priceController,
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      isDense: true,
                      prefixText: '\$',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                IconButton(
                  onPressed: () => _removeReceiptItem(entry.key),
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: Colors.red.shade400,
                  ),
                  iconSize: 20,
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        TextFormField(
          controller: _footerController,
          decoration: const InputDecoration(
            labelText: 'Footer Message',
            prefixIcon: Icon(Icons.message),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                title: const Text('Cut Paper'),
                value: _cutPaper,
                onChanged: (value) => setState(() => _cutPaper = value!),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              child: CheckboxListTile(
                title: const Text('Open Drawer'),
                value: _openCashDrawer,
                onChanged: (value) => setState(() => _openCashDrawer = value!),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStickerForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _customerNameController,
          decoration: const InputDecoration(
            labelText: 'Customer Name',
            prefixIcon: Icon(Icons.person),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _productNameController,
          decoration: const InputDecoration(
            labelText: 'Product Name',
            prefixIcon: Icon(Icons.coffee),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _variantsController,
          decoration: const InputDecoration(
            labelText: 'Variants (comma separated)',
            prefixIcon: Icon(Icons.style),
            hintText: 'e.g., Large, Extra Shot',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _additionsController,
          decoration: const InputDecoration(
            labelText: 'Additions (comma separated)',
            prefixIcon: Icon(Icons.add_box),
            hintText: 'e.g., Oat Milk, Syrup',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Notes',
            prefixIcon: Icon(Icons.note),
            hintText: 'e.g., Less Ice',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _barcodeController,
          decoration: const InputDecoration(
            labelText: 'Barcode (optional)',
            prefixIcon: Icon(Icons.qr_code),
            hintText: 'e.g., 123456789',
          ),
        ),
        const SizedBox(height: 16),
        Text('Label Settings', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _labelWidth.toString(),
                decoration: const InputDecoration(
                  labelText: 'Width (mm)',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => _labelWidth = int.tryParse(v) ?? _labelWidth,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: _labelHeight.toString(),
                decoration: const InputDecoration(
                  labelText: 'Height (mm)',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => _labelHeight = int.tryParse(v) ?? _labelHeight,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: _labelGap.toString(),
                decoration: const InputDecoration(
                  labelText: 'Gap (mm)',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => _labelGap = int.tryParse(v) ?? _labelGap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Density'),
                  Slider(
                    value: _density.toDouble(),
                    min: 1,
                    max: 15,
                    divisions: 14,
                    label: _density.toString(),
                    onChanged: (v) => setState(() => _density = v.toInt()),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _fontSize,
                decoration: const InputDecoration(
                  labelText: 'Font Size',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Small')),
                  DropdownMenuItem(value: 2, child: Text('Medium')),
                  DropdownMenuItem(value: 3, child: Text('Large')),
                  DropdownMenuItem(value: 4, child: Text('Extra Large')),
                ],
                onChanged: (v) => setState(() => _fontSize = v ?? _fontSize),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.numbers, color: Colors.grey),
            const SizedBox(width: 16),
            const Text('Quantity:'),
            const SizedBox(width: 16),
            IconButton(
              onPressed: _quantity > 1
                  ? () => setState(() => _quantity--)
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('$_quantity', style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              onPressed: () => setState(() => _quantity++),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ],
    );
  }

  void _addReceiptItem() {
    setState(() {
      _receiptItems.add(_ReceiptItemController('', ''));
    });
  }

  void _removeReceiptItem(int index) {
    if (_receiptItems.length > 1) {
      setState(() {
        _receiptItems[index].dispose();
        _receiptItems.removeAt(index);
      });
    }
  }

  void _submit() {
    if (widget.documentType == PrintDocumentType.receipt) {
      final lines = <ReceiptLine>[];

      // Add divider
      lines.add(ReceiptLine.divider());

      // Add items
      double total = 0;
      for (final item in _receiptItems) {
        if (item.nameController.text.isNotEmpty) {
          final price = double.tryParse(item.priceController.text) ?? 0;
          total += price;
          lines.add(
            ReceiptLine.leftRight(
              item.nameController.text,
              '\$${price.toStringAsFixed(2)}',
            ),
          );
        }
      }

      // Add total
      lines.add(ReceiptLine.divider());
      lines.add(
        ReceiptLine.leftRight('TOTAL', '\$${total.toStringAsFixed(2)}'),
      );
      lines.add(ReceiptLine.empty());

      final content = ReceiptContent(
        storeName: _storeNameController.text,
        storeAddress: _storeAddressController.text,
        lines: lines,
        footer: _footerController.text,
        cutPaper: _cutPaper,
        openCashDrawer: _openCashDrawer,
      );

      widget.onPrint(content);
    } else {
      final content = StickerContent(
        customerName: _customerNameController.text,
        productName: _productNameController.text,
        variants: _variantsController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        additions: _additionsController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        quantity: _quantity,
        width: _labelWidth,
        height: _labelHeight,
        gap: _labelGap,
        barcode: _barcodeController.text.isNotEmpty ? _barcodeController.text : null,
        density: _density,
        fontSize: _fontSize,
      );

      widget.onPrint(content);
    }

    Navigator.of(context).pop();
  }
}

class _ReceiptItemController {
  final TextEditingController nameController;
  final TextEditingController priceController;

  _ReceiptItemController(String name, String price)
    : nameController = TextEditingController(text: name),
      priceController = TextEditingController(text: price);

  void dispose() {
    nameController.dispose();
    priceController.dispose();
  }
}

