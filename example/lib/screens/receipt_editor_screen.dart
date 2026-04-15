import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multiprinter/multiprinter.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/editor_receipt_element.dart';

/// WYSIWYG receipt editor.
///
/// Shows a live paper-preview of the receipt on a grey background.
/// Tap any element to select it; a properties panel slides up from the bottom.
/// Drag the ≡ handle to reorder elements.
/// Barcode / QR / Image elements show a corner resize handle when selected —
/// drag it to adjust width and/or height. The resize is reflected in print output.
class ReceiptEditorScreen extends StatefulWidget {
  final ReceiptContent? initialContent;

  const ReceiptEditorScreen({super.key, this.initialContent});

  @override
  State<ReceiptEditorScreen> createState() => _ReceiptEditorScreenState();
}

class _ReceiptEditorScreenState extends State<ReceiptEditorScreen> {
  // ── Document-level state ─────────────────────────────────────────────────

  final _storeNameCtrl = TextEditingController();
  final _storeAddressCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();
  bool _cutPaper = true;
  bool _openCashDrawer = false;

  // ── Element list ─────────────────────────────────────────────────────────

  final List<EditorReceiptElement> _elements = [];

  // ── Selection state ──────────────────────────────────────────────────────

  int? _selectedIndex;

  // Persistent property-panel controllers (synced when selection changes)
  final _propTextCtrl = TextEditingController();
  final _propLeftCtrl = TextEditingController();
  final _propRightCtrl = TextEditingController();

  // ── Paper width measured from LayoutBuilder ───────────────────────────────

  /// Effective content width of the paper column (pixels).
  /// Used for converting drag deltas → display fractions.
  double _paperWidth = 260.0;

  // ── Session persistence ───────────────────────────────────────────────────

  static const _kSessionKey = 'receipt_editor_session';
  /// True once the initial session load (or default setup) is complete.
  /// Guards auto-save from firing before there is any real state to save.
  bool _sessionReady = false;
  Timer? _saveTimer;

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    // Debounce: save 2 s after the last change.
    if (_sessionReady && widget.initialContent == null) {
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(seconds: 2), _saveSession);
    }
  }

  Future<void> _saveSession({bool showFeedback = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode({
        'storeName': _storeNameCtrl.text,
        'storeAddress': _storeAddressCtrl.text,
        'footer': _footerCtrl.text,
        'cutPaper': _cutPaper,
        'openCashDrawer': _openCashDrawer,
        'elements': _elements.map((e) => e.toJson()).toList(),
      });
      await prefs.setString(_kSessionKey, data);
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session saved'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSessionKey);
      if (raw != null && mounted) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        setState(() {
          _storeNameCtrl.text = data['storeName'] as String? ?? '';
          _storeAddressCtrl.text = data['storeAddress'] as String? ?? '';
          _footerCtrl.text = data['footer'] as String? ?? '';
          _cutPaper = data['cutPaper'] as bool? ?? true;
          _openCashDrawer = data['openCashDrawer'] as bool? ?? false;
          _elements.clear();
          for (final e in (data['elements'] as List? ?? [])) {
            _elements.add(
                EditorReceiptElement.fromJson(e as Map<String, dynamic>));
          }
          _sessionReady = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session restored'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    } catch (_) {}
    // No saved session — keep the defaults that initState already set.
    if (mounted) setState(() => _sessionReady = true);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionKey);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    final initial = widget.initialContent;
    if (initial != null) {
      // When content is injected externally, use it directly — no session.
      _storeNameCtrl.text = initial.storeName ?? '';
      _storeAddressCtrl.text = initial.storeAddress ?? '';
      _footerCtrl.text = initial.footer ?? '';
      _cutPaper = initial.cutPaper;
      _openCashDrawer = initial.openCashDrawer;
      for (final line in initial.lines) {
        _elements.add(_lineToEditorElement(line));
      }
      _sessionReady = true;
    } else {
      // Set up defaults, then try to restore the last session.
      _storeNameCtrl.text = 'My Store';
      _storeAddressCtrl.text = '123 Main Street';
      _elements.addAll([
        EditorReceiptElement.newText(
          text: 'ORDER #1001',
          alignment: ReceiptTextAlign.center,
          bold: true,
        ),
        EditorReceiptElement.newDivider(),
        EditorReceiptElement.newLeftRight(leftText: 'Item 1', rightText: '\$0.00'),
        EditorReceiptElement.newLeftRight(leftText: 'Item 2', rightText: '\$0.00'),
        EditorReceiptElement.newDivider(char: '='),
        EditorReceiptElement.newText(
          text: 'TOTAL: \$0.00',
          alignment: ReceiptTextAlign.center,
          bold: true,
        ),
        EditorReceiptElement.newEmpty(),
        EditorReceiptElement.newQrCode('https://example.com/receipt/1001'),
      ]);
      _footerCtrl.text = 'Thank you!';
      // Load asynchronously so the first frame can render immediately.
      Future.microtask(_loadSession);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _storeNameCtrl.dispose();
    _storeAddressCtrl.dispose();
    _footerCtrl.dispose();
    _propTextCtrl.dispose();
    _propLeftCtrl.dispose();
    _propRightCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  EditorReceiptElement _lineToEditorElement(ReceiptLine line) {
    if (line.lineType == ReceiptLineType.leftRight) {
      final parts = line.text.split('\t');
      return EditorReceiptElement(
        type: ReceiptLineType.leftRight,
        leftText: parts.isNotEmpty ? parts[0] : '',
        rightText: parts.length > 1 ? parts[1] : '',
      );
    }
    return EditorReceiptElement(
      type: line.lineType,
      text: line.text,
      alignment: line.alignment,
      size: line.size,
      bold: line.bold,
      underline: line.underline,
    );
  }

  void _selectElement(int index) {
    final el = _elements[index];
    _propTextCtrl.text = el.text;
    _propLeftCtrl.text = el.leftText;
    _propRightCtrl.text = el.rightText;
    setState(() => _selectedIndex = index);
  }

  void _deselect() => setState(() => _selectedIndex = null);

  void _updateSelected(EditorReceiptElement Function(EditorReceiptElement) update) {
    if (_selectedIndex == null) return;
    setState(() => _elements[_selectedIndex!] = update(_elements[_selectedIndex!]));
  }

  ReceiptContent _buildContent() {
    return ReceiptContent(
      storeName:
          _storeNameCtrl.text.trim().isEmpty ? null : _storeNameCtrl.text.trim(),
      storeAddress:
          _storeAddressCtrl.text.trim().isEmpty ? null : _storeAddressCtrl.text.trim(),
      lines: _elements.map((e) => e.toReceiptLine()).toList(),
      footer: _footerCtrl.text.trim().isEmpty ? null : _footerCtrl.text.trim(),
      cutPaper: _cutPaper,
      openCashDrawer: _openCashDrawer,
    );
  }

  void _print(PrinterProvider provider) {
    provider.printReceiptToSelected(_buildContent());
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    _updateSelected((el) => el.copyWith(imageBytes: bytes));
  }

  // ── Font / alignment helpers ──────────────────────────────────────────────

  TextAlign _toTextAlign(ReceiptTextAlign a) {
    switch (a) {
      case ReceiptTextAlign.left:
        return TextAlign.left;
      case ReceiptTextAlign.center:
        return TextAlign.center;
      case ReceiptTextAlign.right:
        return TextAlign.right;
    }
  }

  double _toFontSize(ReceiptTextSize s) {
    switch (s) {
      case ReceiptTextSize.small:
        return 10;
      case ReceiptTextSize.normal:
        return 13;
      case ReceiptTextSize.large:
        return 16;
      case ReceiptTextSize.extraLarge:
        return 20;
    }
  }

  // ── Properties panel height ───────────────────────────────────────────────

  double get _panelHeight {
    if (_selectedIndex == null) return 0;
    final type = _elements[_selectedIndex!].type;
    switch (type) {
      case ReceiptLineType.barcode:
      case ReceiptLineType.qrCode:
        return 260;
      case ReceiptLineType.image:
        return 300;
      default:
        return 220;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Editor'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Document Settings',
            onPressed: _showDocumentSettingsSheet,
          ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (v) async {
              if (v == 'save') {
                _saveTimer?.cancel();
                await _saveSession(showFeedback: true);
              } else if (v == 'reset') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Reset session?'),
                    content: const Text(
                        'This will clear the saved session and restore the default template.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Reset')),
                    ],
                  ),
                );
                if (ok == true && mounted) {
                  await _clearSession();
                  setState(() {
                    _elements.clear();
                    _elements.addAll([
                      EditorReceiptElement.newText(
                        text: 'ORDER #1001',
                        alignment: ReceiptTextAlign.center,
                        bold: true,
                      ),
                      EditorReceiptElement.newDivider(),
                      EditorReceiptElement.newLeftRight(
                          leftText: 'Item 1', rightText: '\$0.00'),
                      EditorReceiptElement.newDivider(char: '='),
                      EditorReceiptElement.newText(
                        text: 'TOTAL: \$0.00',
                        alignment: ReceiptTextAlign.center,
                        bold: true,
                      ),
                      EditorReceiptElement.newEmpty(),
                    ]);
                    _storeNameCtrl.text = 'My Store';
                    _storeAddressCtrl.text = '123 Main Street';
                    _footerCtrl.text = 'Thank you!';
                    _selectedIndex = null;
                  });
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'save',
                child: ListTile(
                  leading: Icon(Icons.save_outlined),
                  title: Text('Save session'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'reset',
                child: ListTile(
                  leading: Icon(Icons.restart_alt),
                  title: Text('Reset to default'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          Consumer<PrinterProvider>(
            builder: (context, provider, _) {
              final canPrint =
                  provider.selectedPrinters.isNotEmpty && !provider.isLoading;
              return FilledButton.icon(
                onPressed: canPrint ? () => _print(provider) : null,
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Print'),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildPaperArea(theme)),
          _buildPropertiesPanelAnimated(theme),
          _buildAddElementBar(theme),
        ],
      ),
    );
  }

  // ── Paper preview ─────────────────────────────────────────────────────────

  Widget _buildPaperArea(ThemeData theme) {
    return GestureDetector(
      onTap: _deselect,
      behavior: HitTestBehavior.translucent,
      child: Container(
        color: const Color(0xFFE0E0E0),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(60),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPaperTopEdge(),
                    _buildPaperHeader(),
                    _buildReorderableElements(),
                    _buildPaperFooter(theme),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaperTopEdge() {
    return Container(
      height: 8,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
    );
  }

  Widget _buildPaperHeader() {
    final storeName = _storeNameCtrl.text.trim();
    final storeAddress = _storeAddressCtrl.text.trim();
    if (storeName.isEmpty && storeAddress.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        children: [
          if (storeName.isNotEmpty)
            Text(
              storeName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          if (storeAddress.isNotEmpty)
            Text(
              storeAddress,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildReorderableElements() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Capture paper width minus the drag handle (≈20px).
        _paperWidth = (constraints.maxWidth - 20).clamp(100, 280);

        return ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              final moved = _elements.removeAt(oldIndex);
              _elements.insert(newIndex, moved);
              if (_selectedIndex == oldIndex) {
                _selectedIndex = newIndex;
              } else if (_selectedIndex != null) {
                if (oldIndex < _selectedIndex! && newIndex >= _selectedIndex!) {
                  _selectedIndex = _selectedIndex! - 1;
                } else if (oldIndex > _selectedIndex! &&
                    newIndex <= _selectedIndex!) {
                  _selectedIndex = _selectedIndex! + 1;
                }
              }
            });
          },
          children: [
            for (int i = 0; i < _elements.length; i++)
              _buildElementTile(i, key: ValueKey('el_$i')),
          ],
        );
      },
    );
  }

  Widget _buildElementTile(int index, {required Key key}) {
    final element = _elements[index];
    final isSelected = _selectedIndex == index;
    final theme = Theme.of(context);

    return GestureDetector(
      key: key,
      onTap: () => _selectElement(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          border: isSelected
              ? Border.all(color: theme.colorScheme.primary, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
          color: isSelected
              ? theme.colorScheme.primary.withAlpha(12)
              : Colors.transparent,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Icon(Icons.drag_indicator, size: 16, color: Colors.grey[350]),
              ),
            ),
            // Preview + optional resize handle
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildElementPreview(element),
                  if (isSelected && element.isResizable)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: _buildResizeHandle(index, theme),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Resize handle ─────────────────────────────────────────────────────────

  Widget _buildResizeHandle(int index, ThemeData theme) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Consume tap so it doesn't bubble up and deselect the element.
      onTap: () {},
      onPanUpdate: (details) {
        if (_paperWidth <= 0) return;
        final dx = details.delta.dx;
        final dy = details.delta.dy;

        setState(() {
          // Read from _elements[index] inside setState so every delta is
          // applied to the LATEST value — not the stale closure captured
          // at the last build.
          final current = _elements[index];
          switch (current.type) {
            case ReceiptLineType.barcode:
              _elements[index] = current.copyWith(
                displayHeight: (current.displayHeight + dy).clamp(30.0, 250.0),
              );
              break;
            case ReceiptLineType.qrCode:
              _elements[index] = current.copyWith(
                displayWidth:
                    (current.displayWidth + dx / _paperWidth).clamp(0.2, 1.0),
              );
              break;
            case ReceiptLineType.image:
              _elements[index] = current.copyWith(
                displayWidth:
                    (current.displayWidth + dx / _paperWidth).clamp(0.2, 1.0),
                displayHeight:
                    (current.displayHeight + dy).clamp(30.0, 250.0),
              );
              break;
            default:
              break;
          }
        });
      },
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            bottomRight: Radius.circular(2),
          ),
        ),
        child: const Icon(Icons.open_in_full, size: 13, color: Colors.white),
      ),
    );
  }

  // ── Element preview ───────────────────────────────────────────────────────

  Widget _buildElementPreview(EditorReceiptElement element) {
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 12);

    switch (element.type) {
      case ReceiptLineType.text:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
          child: Text(
            element.text.isEmpty ? '(empty text)' : element.text,
            textAlign: _toTextAlign(element.alignment),
            style: mono.copyWith(
              fontWeight: element.bold ? FontWeight.bold : FontWeight.normal,
              decoration: element.underline ? TextDecoration.underline : null,
              fontSize: _toFontSize(element.size),
              color: element.text.isEmpty ? Colors.grey[400] : Colors.black87,
            ),
          ),
        );

      case ReceiptLineType.leftRight:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                element.leftText.isEmpty ? '(left)' : element.leftText,
                style: mono.copyWith(
                    color:
                        element.leftText.isEmpty ? Colors.grey[400] : Colors.black87),
              ),
              Text(
                element.rightText.isEmpty ? '(right)' : element.rightText,
                style: mono.copyWith(
                    color:
                        element.rightText.isEmpty ? Colors.grey[400] : Colors.black87),
              ),
            ],
          ),
        );

      case ReceiptLineType.divider:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
          child: Text(
            element.text,
            style: mono.copyWith(color: Colors.grey[500], fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        );

      case ReceiptLineType.barcode:
        final barcodeH = element.displayHeight.clamp(30.0, 250.0);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            children: [
              _buildBarcodeMockup(height: barcodeH),
              const SizedBox(height: 3),
              Text(
                element.text.isEmpty ? '(no data)' : element.text,
                textAlign: TextAlign.center,
                style: mono.copyWith(fontSize: 10, color: Colors.black54),
              ),
            ],
          ),
        );

      case ReceiptLineType.qrCode:
        final qrSize = (element.displayWidth * _paperWidth).clamp(60.0, 280.0);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Center(
            child: element.text.isEmpty
                ? SizedBox(
                    width: qrSize,
                    height: qrSize,
                    child: const Icon(Icons.qr_code, color: Colors.grey),
                  )
                : QrImageView(
                    data: element.text,
                    size: qrSize,
                    version: QrVersions.auto,
                  ),
          ),
        );

      case ReceiptLineType.empty:
        return const SizedBox(height: 12);

      case ReceiptLineType.image:
        final imgW = (element.displayWidth * _paperWidth).clamp(40.0, 280.0);
        final imgH = element.displayHeight.clamp(30.0, 250.0);

        if (element.imageBytes != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Center(
              child: ClipRRect(
                child: Image.memory(
                  element.imageBytes!,
                  width: imgW,
                  height: imgH,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        }
        return Padding(
          padding: EdgeInsets.symmetric(vertical: imgH / 4, horizontal: 4),
          child: Column(
            children: [
              Icon(Icons.image, size: 40, color: Colors.grey[400]),
              const SizedBox(height: 4),
              Text(
                'Tap to add image',
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildBarcodeMockup({required double height}) {
    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < 48; i++)
            Container(
              width: _barcodeBarWidth(i),
              color: _isBarcodeBarBlack(i) ? Colors.black : Colors.white,
            ),
        ],
      ),
    );
  }

  double _barcodeBarWidth(int i) {
    if (i < 3 || i > 44) return 2;
    if (i % 7 == 0) return 3;
    if (i % 11 == 0) return 2.5;
    return 1.5;
  }

  bool _isBarcodeBarBlack(int i) {
    if (i < 3 || i > 44) return true;
    return (i % 2 == 0) ^ (i % 5 == 0);
  }

  Widget _buildPaperFooter(ThemeData theme) {
    final footer = _footerCtrl.text.trim();
    return Column(
      children: [
        if (footer.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Text(
              footer,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        if (_cutPaper)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.cut, size: 14, color: Colors.grey),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return CustomPaint(
                        size: Size(constraints.maxWidth, 1),
                        painter: _DashedLinePainter(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Properties panel ──────────────────────────────────────────────────────

  Widget _buildPropertiesPanelAnimated(ThemeData theme) {
    final isOpen = _selectedIndex != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      height: isOpen ? _panelHeight : 0,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: isOpen && _selectedIndex! < _elements.length
          ? _buildPropertiesPanel(theme)
          : const SizedBox.shrink(),
    );
  }

  Widget _buildPropertiesPanel(ThemeData theme) {
    final index = _selectedIndex!;
    final el = _elements[index];

    return Column(
      children: [
        // Panel header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withAlpha(80),
            border:
                Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
          ),
          child: Row(
            children: [
              Icon(_elementIcon(el.type), size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                el.typeLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (el.isResizable) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Drag ↘ to resize',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete'),
                style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                onPressed: () {
                  setState(() {
                    _elements.removeAt(index);
                    _selectedIndex = null;
                  });
                },
              ),
            ],
          ),
        ),

        // Panel body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: _buildPanelFields(el, theme),
          ),
        ),
      ],
    );
  }

  Widget _buildPanelFields(EditorReceiptElement el, ThemeData theme) {
    switch (el.type) {
      case ReceiptLineType.text:
        return _buildTextFields(el, theme);
      case ReceiptLineType.leftRight:
        return _buildLeftRightFields(el, theme);
      case ReceiptLineType.divider:
        return _buildDividerFields(el, theme);
      case ReceiptLineType.barcode:
        return _buildBarcodeFields(el, theme);
      case ReceiptLineType.qrCode:
        return _buildQrFields(el, theme);
      case ReceiptLineType.empty:
        return Center(
          child: Text(
            'Spacer — adds vertical space',
            style: TextStyle(color: Colors.grey[500]),
          ),
        );
      case ReceiptLineType.image:
        return _buildImageFields(el, theme);
    }
  }

  Widget _buildTextFields(EditorReceiptElement el, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _propTextCtrl,
                decoration: const InputDecoration(
                  labelText: 'Text',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _updateSelected((e) => e.copyWith(text: v)),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('B', style: TextStyle(fontWeight: FontWeight.bold)),
              selected: el.bold,
              onSelected: (v) => _updateSelected((e) => e.copyWith(bold: v)),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            FilterChip(
              label: const Text(
                'U',
                style: TextStyle(decoration: TextDecoration.underline),
              ),
              selected: el.underline,
              onSelected: (v) => _updateSelected((e) => e.copyWith(underline: v)),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _alignButton(el, ReceiptTextAlign.left, Icons.format_align_left),
            _alignButton(el, ReceiptTextAlign.center, Icons.format_align_center),
            _alignButton(el, ReceiptTextAlign.right, Icons.format_align_right),
            const SizedBox(width: 12),
            Text('Size:', style: theme.textTheme.bodySmall),
            const SizedBox(width: 6),
            DropdownButton<ReceiptTextSize>(
              value: el.size,
              isDense: true,
              items: ReceiptTextSize.values.map((s) {
                return DropdownMenuItem(value: s, child: Text(_sizeName(s)));
              }).toList(),
              onChanged: (v) {
                if (v != null) _updateSelected((e) => e.copyWith(size: v));
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _alignButton(EditorReceiptElement el, ReceiptTextAlign align, IconData icon) {
    final isSelected = el.alignment == align;
    final theme = Theme.of(context);
    return IconButton(
      icon: Icon(icon, size: 20),
      color: isSelected ? theme.colorScheme.primary : Colors.grey,
      onPressed: () => _updateSelected((e) => e.copyWith(alignment: align)),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
    );
  }

  Widget _buildLeftRightFields(EditorReceiptElement el, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _propLeftCtrl,
            decoration: const InputDecoration(
              labelText: 'Left text',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _updateSelected((e) => e.copyWith(leftText: v)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _propRightCtrl,
            decoration: const InputDecoration(
              labelText: 'Right text',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _updateSelected((e) => e.copyWith(rightText: v)),
          ),
        ),
      ],
    );
  }

  Widget _buildDividerFields(EditorReceiptElement el, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Divider character:', style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: ['-', '=', '*', '~', '#'].map((char) {
            final isSelected = el.text.startsWith(char);
            return ChoiceChip(
              label: Text(char, style: const TextStyle(fontFamily: 'monospace')),
              selected: isSelected,
              onSelected: (_) => _updateSelected((e) => e.copyWith(text: char * 32)),
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBarcodeFields(EditorReceiptElement el, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _propTextCtrl,
          decoration: const InputDecoration(
            labelText: 'Barcode data',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => _updateSelected((e) => e.copyWith(text: v)),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text('Height:', style: theme.textTheme.bodySmall),
            const SizedBox(width: 6),
            Text(
              '${el.displayHeight.round()} px',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        Slider(
          value: el.displayHeight.clamp(30, 250),
          min: 30,
          max: 250,
          divisions: 44,
          label: '${el.displayHeight.round()}',
          onChanged: (v) => _updateSelected((e) => e.copyWith(displayHeight: v)),
        ),
      ],
    );
  }

  Widget _buildQrFields(EditorReceiptElement el, ThemeData theme) {
    final pct = (el.displayWidth * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _propTextCtrl,
          decoration: const InputDecoration(
            labelText: 'QR content / URL',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => _updateSelected((e) => e.copyWith(text: v)),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text('Size:', style: theme.textTheme.bodySmall),
            const SizedBox(width: 6),
            Text(
              '$pct% of paper width',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        Slider(
          value: el.displayWidth.clamp(0.2, 1.0),
          min: 0.2,
          max: 1.0,
          divisions: 16,
          label: '$pct%',
          onChanged: (v) => _updateSelected((e) => e.copyWith(displayWidth: v)),
        ),
      ],
    );
  }

  Widget _buildImageFields(EditorReceiptElement el, ThemeData theme) {
    final wPct = (el.displayWidth * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image picker row
        if (el.imageBytes != null)
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(el.imageBytes!, height: 56, width: 80, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.image, size: 16),
                    label: const Text('Replace'),
                    onPressed: _pickImage,
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Remove'),
                    onPressed: () => _updateSelected((e) => e.copyWith(clearImage: true)),
                    style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
            ],
          )
        else
          FilledButton.icon(
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Pick Image from Gallery'),
            onPressed: _pickImage,
          ),

        const SizedBox(height: 12),

        // Width slider
        Row(
          children: [
            Text('Width:', style: theme.textTheme.bodySmall),
            const SizedBox(width: 6),
            Text(
              '$wPct% of paper',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        Slider(
          value: el.displayWidth.clamp(0.2, 1.0),
          min: 0.2,
          max: 1.0,
          divisions: 16,
          label: '$wPct%',
          onChanged: (v) => _updateSelected((e) => e.copyWith(displayWidth: v)),
        ),

        // Height slider
        Row(
          children: [
            Text('Height:', style: theme.textTheme.bodySmall),
            const SizedBox(width: 6),
            Text(
              '${el.displayHeight.round()} px',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        Slider(
          value: el.displayHeight.clamp(30, 250),
          min: 30,
          max: 250,
          divisions: 44,
          label: '${el.displayHeight.round()}',
          onChanged: (v) => _updateSelected((e) => e.copyWith(displayHeight: v)),
        ),
      ],
    );
  }

  // ── Add element toolbar ───────────────────────────────────────────────────

  Widget _buildAddElementBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              'Add:',
              style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(width: 4),
            _addButton(context, 'Text', Icons.text_fields, () {
              setState(() {
                _elements.add(EditorReceiptElement.newText());
                _selectElement(_elements.length - 1);
              });
            }),
            _addButton(context, 'Two-col', Icons.table_rows_outlined, () {
              setState(() {
                _elements.add(EditorReceiptElement.newLeftRight());
                _selectElement(_elements.length - 1);
              });
            }),
            _addButton(context, 'Divider', Icons.horizontal_rule, () {
              setState(() {
                _elements.add(EditorReceiptElement.newDivider());
                _selectElement(_elements.length - 1);
              });
            }),
            _addButton(context, 'Barcode', Icons.barcode_reader, () {
              setState(() {
                _elements.add(EditorReceiptElement.newBarcode());
                _selectElement(_elements.length - 1);
              });
            }),
            _addButton(context, 'QR', Icons.qr_code, () {
              setState(() {
                _elements.add(EditorReceiptElement.newQrCode());
                _selectElement(_elements.length - 1);
              });
            }),
            _addButton(context, 'Image', Icons.image, () async {
              final picker = ImagePicker();
              final file = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 80,
              );
              if (file == null) return;
              final bytes = await file.readAsBytes();
              setState(() {
                _elements.add(EditorReceiptElement.newImage(bytes));
                _selectElement(_elements.length - 1);
              });
            }),
            _addButton(context, 'Space', Icons.space_bar, () {
              setState(() {
                _elements.add(EditorReceiptElement.newEmpty());
              });
            }),
          ],
        ),
      ),
    );
  }

  Widget _addButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // ── Document settings sheet ───────────────────────────────────────────────

  void _showDocumentSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Document Settings',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _storeNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Store name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _storeAddressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Store address',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _footerCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Footer message',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    title: const Text('Cut paper after print'),
                    value: _cutPaper,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) {
                      setSheetState(() => _cutPaper = v);
                      setState(() {});
                    },
                  ),
                  SwitchListTile.adaptive(
                    title: const Text('Open cash drawer'),
                    value: _openCashDrawer,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) {
                      setSheetState(() => _openCashDrawer = v);
                      setState(() {});
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  IconData _elementIcon(ReceiptLineType type) {
    switch (type) {
      case ReceiptLineType.text:
        return Icons.text_fields;
      case ReceiptLineType.leftRight:
        return Icons.table_rows_outlined;
      case ReceiptLineType.divider:
        return Icons.horizontal_rule;
      case ReceiptLineType.barcode:
        return Icons.barcode_reader;
      case ReceiptLineType.qrCode:
        return Icons.qr_code;
      case ReceiptLineType.empty:
        return Icons.space_bar;
      case ReceiptLineType.image:
        return Icons.image;
    }
  }

  String _sizeName(ReceiptTextSize s) {
    switch (s) {
      case ReceiptTextSize.small:
        return 'Small';
      case ReceiptTextSize.normal:
        return 'Normal';
      case ReceiptTextSize.large:
        return 'Large';
      case ReceiptTextSize.extraLarge:
        return 'XL';
    }
  }
}

// ── Dashed line painter (cut indicator) ───────────────────────────────────────

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 1;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) => false;
}
