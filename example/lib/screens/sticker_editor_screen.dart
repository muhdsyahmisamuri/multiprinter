import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multiprinter/multiprinter.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sticker_element.dart';

/// WYSIWYG sticker / label editor.
///
/// The canvas is a scaled representation of the physical label dimensions.
/// Each element can be:
///   • Moved   – drag anywhere on the element body
///   • Resized – drag the blue ↘ corner handle (barcode, QR, image only)
///   • Edited  – tap to select, then edit in the properties panel below
class StickerEditorScreen extends StatefulWidget {
  const StickerEditorScreen({super.key});

  @override
  State<StickerEditorScreen> createState() => _StickerEditorScreenState();
}

class _StickerEditorScreenState extends State<StickerEditorScreen> {
  // ── Label settings ────────────────────────────────────────────────────────

  int _labelWidth = 80;  // mm
  int _labelHeight = 40; // mm
  int _labelGap = 2;     // mm
  int _density = 8;
  int _quantity = 1;

  // ── Elements ──────────────────────────────────────────────────────────────

  final List<StickerElement> _elements = [];
  int? _selectedIndex;

  // ── Property panel controllers ────────────────────────────────────────────

  final _propContentCtrl = TextEditingController();
  final _propXCtrl = TextEditingController();
  final _propYCtrl = TextEditingController();
  final _propWCtrl = TextEditingController();
  final _propHCtrl = TextEditingController();

  // ── Canvas scale (px/mm, computed from LayoutBuilder) ────────────────────

  double _scale = 4.0;

  // ── Session persistence ───────────────────────────────────────────────────

  static const _kSessionKey = 'sticker_editor_session';
  bool _sessionReady = false;
  Timer? _saveTimer;

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (_sessionReady) {
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(seconds: 2), _saveSession);
    }
  }

  Future<void> _saveSession({bool showFeedback = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode({
        'labelWidth': _labelWidth,
        'labelHeight': _labelHeight,
        'labelGap': _labelGap,
        'density': _density,
        'quantity': _quantity,
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
          _labelWidth = data['labelWidth'] as int? ?? 80;
          _labelHeight = data['labelHeight'] as int? ?? 40;
          _labelGap = data['labelGap'] as int? ?? 2;
          _density = data['density'] as int? ?? 8;
          _quantity = data['quantity'] as int? ?? 1;
          _elements.clear();
          for (final e in (data['elements'] as List? ?? [])) {
            _elements
                .add(StickerElement.fromJson(e as Map<String, dynamic>));
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
    if (mounted) setState(() => _sessionReady = true);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionKey);
  }

  void _resetToDefaults() {
    setState(() {
      _labelWidth = 80;
      _labelHeight = 40;
      _labelGap = 2;
      _density = 8;
      _quantity = 1;
      _selectedIndex = null;
      _elements.clear();
      _elements.addAll([
        StickerElement.newText(
            content: 'Customer Name', x: 4, y: 4, fontSize: 3),
        StickerElement.newText(
            content: 'Product Name', x: 4, y: 12, fontSize: 2),
        StickerElement.newBarcode(content: '123456789', x: 4, y: 22),
      ]);
    });
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Add defaults first so the first frame is never blank.
    _elements.addAll([
      StickerElement.newText(content: 'Customer Name', x: 4, y: 4, fontSize: 3),
      StickerElement.newText(content: 'Product Name', x: 4, y: 12, fontSize: 2),
      StickerElement.newBarcode(content: '123456789', x: 4, y: 22),
    ]);
    Future.microtask(_loadSession);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _propContentCtrl.dispose();
    _propXCtrl.dispose();
    _propYCtrl.dispose();
    _propWCtrl.dispose();
    _propHCtrl.dispose();
    super.dispose();
  }

  // ── Selection ─────────────────────────────────────────────────────────────

  void _selectElement(int index) {
    final el = _elements[index];
    _propContentCtrl.text = el.content;
    _propXCtrl.text = el.x.toStringAsFixed(1);
    _propYCtrl.text = el.y.toStringAsFixed(1);
    _propWCtrl.text = (el.width ?? 0).toStringAsFixed(1);
    _propHCtrl.text = (el.height ?? 0).toStringAsFixed(1);
    setState(() => _selectedIndex = index);
  }

  void _deselect() => setState(() => _selectedIndex = null);

  void _updateSelected(StickerElement Function(StickerElement) update) {
    if (_selectedIndex == null) return;
    setState(() => _elements[_selectedIndex!] = update(_elements[_selectedIndex!]));
  }

  // ── Resize helpers ────────────────────────────────────────────────────────

  bool _isResizable(StickerElement el) =>
      el.type == StickerElementType.barcode ||
      el.type == StickerElementType.qrCode ||
      el.type == StickerElementType.image;

  void _onResizeDrag(int index, DragUpdateDetails d) {
    final dx = d.delta.dx / _scale; // px → mm
    final dy = d.delta.dy / _scale;

    setState(() {
      // Read the CURRENT element inside setState so every delta accumulates
      // onto the latest value rather than the stale closure from last build.
      final el = _elements[index];
      StickerElement updated;
      switch (el.type) {
        case StickerElementType.barcode:
          final newW =
              ((el.width ?? 32) + dx).clamp(8.0, _labelWidth - el.x + 0.0);
          final newH = ((el.height ?? 10) + dy).clamp(3.0, 30.0);
          updated = el.copyWith(width: newW, height: newH);
          break;
        case StickerElementType.qrCode:
          final newS =
              ((el.width ?? 16) + dx).clamp(5.0, _labelWidth - el.x + 0.0);
          updated = el.copyWith(width: newS, height: newS);
          break;
        case StickerElementType.image:
          final newW =
              ((el.width ?? 20) + dx).clamp(5.0, _labelWidth - el.x + 0.0);
          final newH =
              ((el.height ?? 20) + dy).clamp(3.0, _labelHeight - el.y + 0.0);
          updated = el.copyWith(width: newW, height: newH);
          break;
        default:
          return;
      }
      _elements[index] = updated;
      if (_selectedIndex == index) {
        _propWCtrl.text = (updated.width ?? 0).toStringAsFixed(1);
        _propHCtrl.text = (updated.height ?? 0).toStringAsFixed(1);
      }
    });
  }

  // ── TSPL generation & print ───────────────────────────────────────────────

  Future<List<int>> _buildTsplBytes() async {
    const int dpm = 8; // dots per mm (200 DPI)

    // Build all text-based TSPL commands (SIZE, GAP, DENSITY, CLS,
    // TEXT, BARCODE, QRCODE) through the builder.
    // Images are handled separately as raw binary (see below).
    final builder = TsplBuilder()
      ..size(_labelWidth, _labelHeight)
      ..gap(_labelGap, 0)
      ..density(_density)
      ..cls();

    // Collect raw-binary BITMAP commands for image elements.
    // TSPL BITMAP requires the pixel data as actual binary bytes embedded
    // directly in the command stream — NOT as a hex string.  Sending hex
    // ASCII causes the printer to render each ASCII code as 8 dots, producing
    // vertical-stripe artefacts.
    final bitmapSegments = <List<int>>[];

    for (final el in _elements) {
      final xD = (el.x * dpm).round();
      final yD = (el.y * dpm).round();

      switch (el.type) {
        case StickerElementType.text:
          builder.text(xD, yD, el.fontSize.clamp(1, 5), 0, 1, 1, el.content);
          break;

        case StickerElementType.barcode:
          if (el.content.isNotEmpty) {
            final heightDots =
                ((el.height ?? 10) * dpm).round().clamp(8, 240);
            builder.barcode(xD, yD, '128', heightDots, 2, el.content);
          }
          break;

        case StickerElementType.qrCode:
          if (el.content.isNotEmpty) {
            // Map width in mm → cell width (1–10): roughly 1 cell ≈ 4mm
            final cellWidth = ((el.width ?? 16) / 4).round().clamp(1, 10);
            builder.qrcode(xD, yD, 'M', cellWidth, 'A', 0, el.content);
          }
          break;

        case StickerElementType.image:
          if (el.imageBytes != null) {
            final maxW = ((el.width ?? 20) * dpm).round();
            final maxH = ((el.height ?? 20) * dpm).round();
            final bmp = await _imageToBitmap(el.imageBytes!, maxW, maxH);
            if (bmp != null) {
              // Build: "BITMAP x,y,widthBytes,height,0," + raw pixel bytes + CRLF
              final header = utf8.encode(
                  'BITMAP $xD,$yD,${bmp.widthBytes},${bmp.height},0,');
              bitmapSegments.add([...header, ...bmp.rawBytes, 0x0D, 0x0A]);
            }
          }
          break;
      }
    }

    // builder.build() returns: CLS + SIZE + GAP + DENSITY + element commands
    // (no PRINT — we never called printLabel so we can insert bitmaps before it).
    final textBytes = builder.build();
    final printBytes = utf8.encode('PRINT $_quantity,1\r\n');

    return [...textBytes, ...bitmapSegments.expand((s) => s), ...printBytes];
  }

  Future<void> _print(PrinterProvider provider) async {
    final bytes = await _buildTsplBytes();
    if (!mounted) return;
    provider.printRawToSelected(bytes);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    _updateSelected((el) => el.copyWith(imageBytes: bytes));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Label Editor'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.aspect_ratio),
            tooltip: 'Label Settings',
            onPressed: _showLabelSettingsSheet,
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
                  _resetToDefaults();
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
          Expanded(child: _buildCanvasArea(theme)),
          _buildPropertiesPanelAnimated(theme),
          _buildAddElementBar(theme),
        ],
      ),
    );
  }

  // ── Canvas ────────────────────────────────────────────────────────────────

  Widget _buildCanvasArea(ThemeData theme) {
    return GestureDetector(
      onTap: _deselect,
      behavior: HitTestBehavior.translucent,
      child: Container(
        color: const Color(0xFFD0D0D0),
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.maxWidth - 40;
              final maxH = constraints.maxHeight - 40;

              final aspect = _labelWidth / _labelHeight;
              double canvasW = maxW;
              double canvasH = canvasW / aspect;
              if (canvasH > maxH) {
                canvasH = maxH;
                canvasW = canvasH * aspect;
              }
              _scale = canvasW / _labelWidth;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(80),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                width: canvasW,
                height: canvasH,
                child: ClipRect(
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      // Grid
                      CustomPaint(
                        size: Size(canvasW, canvasH),
                        painter: _GridPainter(scale: _scale),
                      ),

                      // Elements — resize handle is INSIDE each element so
                      // Flutter's "inner gesture wins" rule prevents the move
                      // gesture from competing with the resize gesture.
                      for (int i = 0; i < _elements.length; i++)
                        _buildCanvasElement(i, theme),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Canvas element (move + optional resize handle inside) ────────────────

  Widget _buildCanvasElement(int index, ThemeData theme) {
    final el = _elements[index];
    final isSelected = _selectedIndex == index;

    return Positioned(
      left: el.x * _scale,
      top: el.y * _scale,
      child: GestureDetector(
        onTap: () => _selectElement(index),
        onPanUpdate: (d) {
          setState(() {
            // Read current element INSIDE setState so rapid pan events
            // accumulate correctly instead of all updating from stale el.
            final current = _elements[index];
            final newX = (current.x + d.delta.dx / _scale)
                .clamp(0.0, _labelWidth.toDouble());
            final newY = (current.y + d.delta.dy / _scale)
                .clamp(0.0, _labelHeight.toDouble());
            _elements[index] = current.copyWith(x: newX, y: newY);
            if (_selectedIndex == index) {
              _propXCtrl.text = newX.toStringAsFixed(1);
              _propYCtrl.text = newY.toStringAsFixed(1);
            }
          });
        },
        child: Container(
          decoration: isSelected
              ? BoxDecoration(
                  border: Border.all(
                      color: theme.colorScheme.primary, width: 1.5),
                  color: theme.colorScheme.primary.withAlpha(15),
                )
              : null,
          // Stack so the resize handle can overlay the element content.
          // clipBehavior: Clip.none lets the handle overflow the element
          // border slightly without being clipped.
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _renderCanvasElement(el),
              // Resize handle as a CHILD gesture — Flutter's "inner gesture
              // wins" rule ensures this beats the parent move gesture above.
              if (isSelected && _isResizable(el))
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {}, // absorb tap — don't deselect
                    onPanUpdate: (d) => _onResizeDrag(index, d),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          bottomRight: Radius.circular(4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(80),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.open_in_full,
                          size: 13, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Element rendering on canvas ───────────────────────────────────────────

  Widget _renderCanvasElement(StickerElement el) {
    final s = _scale;

    switch (el.type) {
      case StickerElementType.text:
        return Text(
          el.content.isEmpty ? '(text)' : el.content,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: (el.fontSize * 3.0 * s / 4).clamp(8, 24),
            color: el.content.isEmpty ? Colors.grey[400] : Colors.black,
          ),
        );

      case StickerElementType.barcode:
        final bW = (el.width ?? 32) * s;
        final bH = (el.height ?? 10) * s;
        return SizedBox(
          width: bW,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBarcodeMockup(bW, bH),
              Text(
                el.content.isEmpty ? '(barcode)' : el.content,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: (1.5 * s).clamp(7.0, 11.0),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );

      case StickerElementType.qrCode:
        final qrS = ((el.width ?? 16) * s).clamp(16.0, double.infinity);
        return el.content.isEmpty
            ? SizedBox(
                width: qrS,
                height: qrS,
                child: Icon(Icons.qr_code, size: qrS * 0.8, color: Colors.grey[400]),
              )
            : QrImageView(data: el.content, size: qrS, version: QrVersions.auto);

      case StickerElementType.image:
        final imgW = (el.width ?? 20) * s;
        final imgH = (el.height ?? 20) * s;
        if (el.imageBytes != null) {
          return Image.memory(
            el.imageBytes!,
            width: imgW,
            height: imgH,
            fit: BoxFit.contain,
          );
        }
        return SizedBox(
          width: imgW,
          height: imgH,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image,
                  color: Colors.grey[400], size: (imgH * 0.5).clamp(16, 40)),
              Text('image',
                  style: TextStyle(fontSize: 8, color: Colors.grey[400])),
            ],
          ),
        );
    }
  }

  Widget _buildBarcodeMockup(double width, double height) {
    return SizedBox(
      width: width,
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < 30; i++)
            Expanded(
              flex: _barFlex(i),
              child: Container(
                color: _isBarcodeBlack(i) ? Colors.black : Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  int _barFlex(int i) {
    if (i < 3 || i > 26) return 2;
    if (i % 7 == 0) return 3;
    return 1;
  }

  bool _isBarcodeBlack(int i) {
    if (i < 3 || i > 26) return true;
    return (i % 2 == 0) ^ (i % 5 == 0);
  }

  // ── Properties panel ──────────────────────────────────────────────────────

  double get _panelHeight {
    if (_selectedIndex == null) return 0;
    final t = _elements[_selectedIndex!].type;
    if (t == StickerElementType.image) return 300;
    if (t == StickerElementType.barcode || t == StickerElementType.qrCode) {
      return 270;
    }
    return 220;
  }

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
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withAlpha(80),
            border:
                Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
          ),
          child: Row(
            children: [
              Icon(_typeIcon(el.type), size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                el.typeLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isResizable(el)) ...[
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
                style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error),
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
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: _buildPanelFields(el, theme),
          ),
        ),
      ],
    );
  }

  Widget _buildPanelFields(StickerElement el, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Content field
        if (el.type != StickerElementType.image)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: _propContentCtrl,
              decoration: InputDecoration(
                labelText: el.type == StickerElementType.text ? 'Text' : 'Data',
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => _updateSelected((e) => e.copyWith(content: v)),
            ),
          ),

        // Font size chips (text only)
        if (el.type == StickerElementType.text)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Text('Font size:', style: theme.textTheme.bodySmall),
                const SizedBox(width: 8),
                for (int s = 1; s <= 5; s++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ChoiceChip(
                      label: Text('$s'),
                      selected: el.fontSize == s,
                      onSelected: (_) =>
                          _updateSelected((e) => e.copyWith(fontSize: s)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),

        // Image picker
        if (el.type == StickerElementType.image)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                if (el.imageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.memory(
                      el.imageBytes!,
                      height: 48,
                      width: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.image, size: 16),
                  label: Text(el.imageBytes != null ? 'Replace' : 'Pick Image'),
                  onPressed: _pickImage,
                  style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                ),
              ],
            ),
          ),

        // Position row (X, Y)
        Row(
          children: [
            Expanded(child: _numField(_propXCtrl, 'X (mm)', (v) {
              final d = double.tryParse(v);
              if (d != null) _updateSelected((e) => e.copyWith(x: d));
            })),
            const SizedBox(width: 8),
            Expanded(child: _numField(_propYCtrl, 'Y (mm)', (v) {
              final d = double.tryParse(v);
              if (d != null) _updateSelected((e) => e.copyWith(y: d));
            })),
          ],
        ),

        // Size row (W, H) — barcode, QR, image
        if (_isResizable(el)) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _numField(
                  _propWCtrl,
                  el.type == StickerElementType.qrCode ? 'Size (mm)' : 'W (mm)',
                  (v) {
                    final d = double.tryParse(v);
                    if (d == null) return;
                    if (el.type == StickerElementType.qrCode) {
                      _updateSelected((e) => e.copyWith(width: d, height: d));
                    } else {
                      _updateSelected((e) => e.copyWith(width: d));
                    }
                  },
                ),
              ),
              if (el.type != StickerElementType.qrCode) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _numField(_propHCtrl, 'H (mm)', (v) {
                    final d = double.tryParse(v);
                    if (d != null) _updateSelected((e) => e.copyWith(height: d));
                  }),
                ),
              ],
            ],
          ),
          // Visual size sliders
          const SizedBox(height: 8),
          if (el.type == StickerElementType.barcode) ...[
            _sizeSlider(
              theme,
              label: 'Width',
              value: (el.width ?? 32).clamp(8, _labelWidth - el.x),
              min: 8,
              max: (_labelWidth - el.x).clamp(8, 80).toDouble(),
              unit: 'mm',
              onChanged: (v) => _updateSelected((e) {
                _propWCtrl.text = v.toStringAsFixed(1);
                return e.copyWith(width: v);
              }),
            ),
            _sizeSlider(
              theme,
              label: 'Height',
              value: (el.height ?? 10).clamp(3, 30),
              min: 3,
              max: 30,
              unit: 'mm',
              onChanged: (v) => _updateSelected((e) {
                _propHCtrl.text = v.toStringAsFixed(1);
                return e.copyWith(height: v);
              }),
            ),
          ],
          if (el.type == StickerElementType.qrCode)
            _sizeSlider(
              theme,
              label: 'Size',
              value: (el.width ?? 16).clamp(5, _labelWidth - el.x),
              min: 5,
              max: (_labelWidth - el.x).clamp(5, 60).toDouble(),
              unit: 'mm',
              onChanged: (v) => _updateSelected((e) {
                _propWCtrl.text = v.toStringAsFixed(1);
                _propHCtrl.text = v.toStringAsFixed(1);
                return e.copyWith(width: v, height: v);
              }),
            ),
          if (el.type == StickerElementType.image) ...[
            _sizeSlider(
              theme,
              label: 'Width',
              value: (el.width ?? 20).clamp(5, _labelWidth - el.x),
              min: 5,
              max: (_labelWidth - el.x).clamp(5, 80).toDouble(),
              unit: 'mm',
              onChanged: (v) => _updateSelected((e) {
                _propWCtrl.text = v.toStringAsFixed(1);
                return e.copyWith(width: v);
              }),
            ),
            _sizeSlider(
              theme,
              label: 'Height',
              value: (el.height ?? 20).clamp(5, _labelHeight - el.y),
              min: 5,
              max: (_labelHeight - el.y).clamp(5, 60).toDouble(),
              unit: 'mm',
              onChanged: (v) => _updateSelected((e) {
                _propHCtrl.text = v.toStringAsFixed(1);
                return e.copyWith(height: v);
              }),
            ),
          ],
        ],
      ],
    );
  }

  // ── Shared field widgets ──────────────────────────────────────────────────

  Widget _numField(
    TextEditingController ctrl,
    String label,
    ValueChanged<String> onChanged,
  ) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }

  Widget _sizeSlider(
    ThemeData theme, {
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 46,
          child: Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            label: '${value.toStringAsFixed(1)} $unit',
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '${value.toStringAsFixed(1)}$unit',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
          ),
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
      child: Row(
        children: [
          Text('Add:', style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey[600])),
          const SizedBox(width: 4),
          _addBtn('Text', Icons.text_fields, () {
            setState(() {
              _elements.add(StickerElement.newText());
              _selectElement(_elements.length - 1);
            });
          }),
          _addBtn('Barcode', Icons.barcode_reader, () {
            setState(() {
              _elements.add(StickerElement.newBarcode());
              _selectElement(_elements.length - 1);
            });
          }),
          _addBtn('QR', Icons.qr_code, () {
            setState(() {
              _elements.add(StickerElement.newQrCode());
              _selectElement(_elements.length - 1);
            });
          }),
          _addBtn('Image', Icons.image, () async {
            final picker = ImagePicker();
            final file = await picker.pickImage(
                source: ImageSource.gallery, imageQuality: 80);
            if (file == null) return;
            final bytes = await file.readAsBytes();
            setState(() {
              _elements.add(StickerElement.newImage(bytes));
              _selectElement(_elements.length - 1);
            });
          }),
          const Spacer(),
          // Quantity
          Text('Qty:', style: theme.textTheme.labelSmall),
          const SizedBox(width: 4),
          SizedBox(
            width: 32,
            child: Text(
              '$_quantity',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 18,
                width: 24,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(Icons.keyboard_arrow_up),
                  onPressed: () => setState(() => _quantity++),
                ),
              ),
              SizedBox(
                height: 18,
                width: 24,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  onPressed:
                      _quantity > 1 ? () => setState(() => _quantity--) : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addBtn(String label, IconData icon, VoidCallback onPressed) {
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

  // ── Label settings sheet ──────────────────────────────────────────────────

  void _showLabelSettingsSheet() {
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
                    'Label Settings',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _settingField(ctx, 'Width (mm)', '$_labelWidth',
                            (v) {
                          final i = int.tryParse(v);
                          if (i != null && i > 0) {
                            setSheetState(() => _labelWidth = i);
                            setState(() {});
                          }
                        }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _settingField(ctx, 'Height (mm)', '$_labelHeight',
                            (v) {
                          final i = int.tryParse(v);
                          if (i != null && i > 0) {
                            setSheetState(() => _labelHeight = i);
                            setState(() {});
                          }
                        }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _settingField(ctx, 'Gap (mm)', '$_labelGap', (v) {
                          final i = int.tryParse(v);
                          if (i != null && i >= 0) {
                            setSheetState(() => _labelGap = i);
                            setState(() {});
                          }
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Density: $_density',
                      style: Theme.of(ctx).textTheme.bodySmall),
                  Slider(
                    value: _density.toDouble(),
                    min: 0,
                    max: 15,
                    divisions: 15,
                    label: '$_density',
                    onChanged: (v) {
                      setSheetState(() => _density = v.round());
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

  Widget _settingField(
    BuildContext ctx,
    String label,
    String initial,
    ValueChanged<String> onChanged,
  ) {
    return TextField(
      controller: TextEditingController(text: initial),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  IconData _typeIcon(StickerElementType type) {
    switch (type) {
      case StickerElementType.text:
        return Icons.text_fields;
      case StickerElementType.barcode:
        return Icons.barcode_reader;
      case StickerElementType.qrCode:
        return Icons.qr_code;
      case StickerElementType.image:
        return Icons.image;
    }
  }

  // ── Image → TSPL BITMAP (raw binary) ─────────────────────────────────────
  //
  // Decodes a JPEG/PNG, scales it to fit [maxWidthDots]×[maxHeightDots],
  // and returns a _BitmapResult with the raw monochrome pixel bytes ready to
  // be embedded directly in the TSPL byte stream.
  //
  // TSPL BITMAP bit convention: 0 = dark dot (print), 1 = light (no print).
  // MSB of each byte = leftmost dot in that group of eight.
  //
  // IMPORTANT: the data MUST be raw binary, not a hex string.  Sending ASCII
  // hex causes each character's code (e.g. 'F' = 0x46) to be rendered as
  // 8 dots, producing the "vertical lines" artefact.
  static Future<_BitmapResult?> _imageToBitmap(
    Uint8List imageBytes,
    int maxWidthDots,
    int maxHeightDots, {
    int threshold = 160,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;

      final scaleX = maxWidthDots / img.width;
      final scaleY = maxHeightDots / img.height;
      final scale = scaleX < scaleY ? scaleX : scaleY;
      final tw = (img.width * scale).round().clamp(1, maxWidthDots);
      final th = (img.height * scale).round().clamp(1, maxHeightDots);

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.scale(scale);
      canvas.drawImage(img, ui.Offset.zero, ui.Paint());
      final picture = recorder.endRecording();
      final resized = await picture.toImage(tw, th);
      final byteData =
          await resized.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return null;

      final pixels = byteData.buffer.asUint8List();
      final bytesPerRow = (tw / 8).ceil();
      final raw = <int>[];

      for (int y = 0; y < th; y++) {
        for (int b = 0; b < bytesPerRow; b++) {
          // All bits start as 1 = light (no print) in TSPL convention.
          int byte = 0xFF;
          for (int bit = 0; bit < 8; bit++) {
            final px = b * 8 + bit;
            if (px < tw) {
              final idx = (y * tw + px) * 4;
              final r = pixels[idx];
              final g = pixels[idx + 1];
              final bl = pixels[idx + 2];
              final lum = (0.299 * r + 0.587 * g + 0.114 * bl).round();
              // Clear the bit (0 = dark/print) for dark pixels.
              if (lum < threshold) byte &= ~(0x80 >> bit);
            }
          }
          raw.add(byte);
        }
      }

      return _BitmapResult(bytesPerRow, th, Uint8List.fromList(raw));
    } catch (_) {
      return null;
    }
  }
}

// ── TSPL bitmap result ────────────────────────────────────────────────────────

class _BitmapResult {
  final int widthBytes;
  final int height;
  /// Raw monochrome pixel bytes (TSPL convention: 0=dark, 1=light, MSB=left).
  final Uint8List rawBytes;
  const _BitmapResult(this.widthBytes, this.height, this.rawBytes);
}

// ── Grid painter ──────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  final double scale;

  const _GridPainter({required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withAlpha(25)
      ..strokeWidth = 0.5;
    final step = scale * 5; // 5mm grid
    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => oldDelegate.scale != scale;
}
