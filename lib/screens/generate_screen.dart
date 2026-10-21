import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import '../models/history_item.dart';
import '../services/export_service.dart';
import '../services/history_service.dart';
import '../services/pro_service.dart';
import '../utils/svg_export.dart';
import '../widgets/pro_gate.dart';

enum _GenType { text, url, wifi, phone, barcode }

enum _WifiEncryption { wpa, wep, none }

enum _BarcodeFormat { code128, ean13, upcA, code39, itf }

class GenerateScreen extends StatefulWidget {
  final ValueNotifier<String?> regeneratePrefill;

  const GenerateScreen({super.key, required this.regeneratePrefill});

  @override
  State<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends State<GenerateScreen> {
  final _historyService = HistoryService();
  final _previewKey = GlobalKey();

  _GenType _selected = _GenType.text;

  final _textController = TextEditingController();
  final _urlController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _barcodeValueController = TextEditingController();

  _WifiEncryption _wifiEncryption = _WifiEncryption.wpa;
  _BarcodeFormat _barcodeFormat = _BarcodeFormat.code128;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    widget.regeneratePrefill.addListener(_onRegeneratePrefill);
  }

  @override
  void dispose() {
    widget.regeneratePrefill.removeListener(_onRegeneratePrefill);
    _textController.dispose();
    _urlController.dispose();
    _phoneController.dispose();
    _ssidController.dispose();
    _passwordController.dispose();
    _barcodeValueController.dispose();
    super.dispose();
  }

  void _onRegeneratePrefill() {
    final value = widget.regeneratePrefill.value;
    if (value == null) return;
    setState(() {
      _selected = _GenType.text;
      _textController.text = value;
    });
    widget.regeneratePrefill.value = null;
  }

  String get _qrData {
    switch (_selected) {
      case _GenType.text:
        return _textController.text;
      case _GenType.url:
        return _urlController.text;
      case _GenType.phone:
        return _phoneController.text.isEmpty ? '' : 'tel:${_phoneController.text}';
      case _GenType.wifi:
        if (_ssidController.text.isEmpty) return '';
        final enc = switch (_wifiEncryption) {
          _WifiEncryption.wpa => 'WPA',
          _WifiEncryption.wep => 'WEP',
          _WifiEncryption.none => 'nopass',
        };
        final password = enc == 'nopass'
            ? ''
            : 'P:${_escapeWifi(_passwordController.text)};';
        return 'WIFI:T:$enc;S:${_escapeWifi(_ssidController.text)};${password}H:false;;';
      case _GenType.barcode:
        return _barcodeValueController.text;
    }
  }

  /// Wi-Fi QR format: backslash-escape \ ; , : and " so a password such as
  /// "pa;ss" doesn't corrupt the code (phones would read the wrong password).
  String _escapeWifi(String v) =>
      v.replaceAllMapped(RegExp(r'[\\;,:"]'), (m) => '\\${m[0]}');

  bool get _barcodeNeedsDigits =>
      _barcodeFormat == _BarcodeFormat.ean13 ||
      _barcodeFormat == _BarcodeFormat.upcA ||
      _barcodeFormat == _BarcodeFormat.itf;

  String get _barcodeHint => switch (_barcodeFormat) {
        _BarcodeFormat.code128 => 'Letters, numbers and symbols',
        _BarcodeFormat.ean13 => '12 or 13 digits',
        _BarcodeFormat.upcA => '11 or 12 digits',
        _BarcodeFormat.code39 => 'Capital letters, digits and a few symbols',
        _BarcodeFormat.itf => 'Digits only, an even number of them',
      };

  bool get _hasData => _selected == _GenType.barcode
      ? _barcodeValueController.text.isNotEmpty
      : _qrData.isNotEmpty;

  Barcode get _barcode => switch (_barcodeFormat) {
        _BarcodeFormat.code128 => Barcode.code128(),
        _BarcodeFormat.ean13 => Barcode.ean13(),
        _BarcodeFormat.upcA => Barcode.upcA(),
        _BarcodeFormat.code39 => Barcode.code39(),
        _BarcodeFormat.itf => Barcode.itf(),
      };

  /// [targetWidth] (in pixels) is for print-quality export: the preview is
  /// vector-drawn, so rendering it at a higher scale gives a sharp image
  /// instead of an enlarged blurry one.
  Future<Uint8List?> _capturePreviewPng({double? targetWidth}) async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('QR capture: no RenderRepaintBoundary found at preview key');
        return null;
      }
      final ratio = targetWidth == null ? 3.0 : targetWidth / boundary.size.width;
      final image = await boundary.toImage(pixelRatio: ratio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null || bytes.isEmpty) {
        debugPrint('QR capture: toByteData returned null/empty');
        return null;
      }
      return bytes;
    } catch (e) {
      debugPrint('QR capture failed: $e');
      return null;
    }
  }

  Future<void> _savePng() async {
    if (!_hasData) return;
    setState(() => _saving = true);
    final bytes = await _capturePreviewPng();
    if (!mounted) return;
    setState(() => _saving = false);

    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not save image')));
      }
      return;
    }

    var ok = true;
    try {
      await Gal.putImageBytes(
        bytes,
        name: 'qr_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (_) {
      ok = false;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Saved to gallery' : 'Save failed')),
      );
    }
  }

  Future<void> _share() async {
    if (!_hasData) return;
    final bytes = await _capturePreviewPng();
    final shareText = _selected == _GenType.barcode ? _barcodeValueController.text : _qrData;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not attach the image — sharing text only')),
        );
      }
      await Share.share(shareText);
      return;
    }
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: 'code.png', mimeType: 'image/png')],
      text: shareText,
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openPrintSheet() async {
    final isPro = ProService.isPro.value;
    const proChip = Chip(label: Text('Pro'), visualDensity: VisualDensity.compact);
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'Print-quality export',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('High-resolution PNG'),
              subtitle: const Text('2048 px wide, saved to your gallery'),
              trailing: isPro ? null : proChip,
              onTap: () {
                Navigator.pop(sheetContext);
                _saveHighResPng();
              },
            ),
            ListTile(
              leading: const Icon(Icons.draw_outlined),
              title: const Text('SVG (vector)'),
              subtitle: const Text('Scales to any size without blurring'),
              trailing: isPro ? null : proChip,
              onTap: () {
                Navigator.pop(sheetContext);
                _exportSvg();
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Text(
                'Both include the blank margin scanners need. '
                "Don't print smaller than about 2 cm (0.8 in) wide.",
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveHighResPng() async {
    if (!_hasData) return;
    if (!ProService.isPro.value) {
      await showProRequired(context, feature: 'Print-quality export');
      return;
    }
    setState(() => _saving = true);
    final bytes = await _capturePreviewPng(targetWidth: 2048);
    if (mounted) setState(() => _saving = false);
    if (bytes == null) {
      _snack('Could not create the image');
      return;
    }
    var ok = true;
    try {
      await Gal.putImageBytes(
        bytes,
        name: 'qr_print_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (_) {
      ok = false;
    }
    _snack(ok ? 'Saved a 2048 px image to your gallery' : 'Save failed');
  }

  Future<void> _exportSvg() async {
    if (!_hasData) return;
    if (!ProService.isPro.value) {
      await showProRequired(context, feature: 'Print-quality export');
      return;
    }
    final String svg;
    try {
      svg = _selected == _GenType.barcode
          ? SvgExport.linear(_barcode, _barcodeValueController.text)
          : SvgExport.qr(_qrData);
    } on FormatException {
      _snack('This text is too long to fit in a QR code');
      return;
    } catch (_) {
      _snack(_selected == _GenType.barcode
          ? 'This value is not valid for the chosen barcode format'
          : 'Could not create the SVG');
      return;
    }
    try {
      await ExportService.shareTextFile(
        svg,
        baseName: 'qr-toolkit-code',
        extension: 'svg',
        mimeType: 'image/svg+xml',
      );
    } catch (_) {
      _snack('Could not share the file');
    }
  }

  Future<void> _saveToHistory() async {
    if (!_hasData) return;
    final value = _selected == _GenType.barcode ? _barcodeValueController.text : _qrData;
    await _historyService.add(HistoryItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: 'generate',
      value: value,
      timestamp: DateTime.now(),
    ));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved to history')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: _GenType.values.map((type) {
              return ChoiceChip(
                label: Text(_labelFor(type)),
                selected: _selected == type,
                onSelected: (_) => setState(() => _selected = type),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _buildForm(),
          const SizedBox(height: 24),
          Center(
            child: RepaintBoundary(
              key: _previewKey,
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: !_hasData
                    ? const SizedBox(
                        height: 200,
                        width: 250,
                        child: Center(child: Text('Preview')),
                      )
                    : _selected == _GenType.barcode
                        ? BarcodeWidget(
                            barcode: _barcode,
                            data: _barcodeValueController.text,
                            width: 250,
                            height: 120,
                            drawText: true,
                            errorBuilder: (context, error) => SizedBox(
                              width: 250,
                              height: 120,
                              child: Center(
                                child: Text(
                                  'Invalid value for this format',
                                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          )
                        : QrImageView(data: _qrData, version: QrVersions.auto, size: 200),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Many "free" QR generators make dynamic codes that stop working
          // when a trial ends. Ours are static: the data is inside the code.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.all_inclusive, size: 16, color: outline),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Static code: the information is stored in the code itself, '
                    'so it never expires. No account, no tracking.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: outline),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: !_hasData || _saving ? null : _savePng,
                child: Text(_saving ? 'Saving…' : 'Save PNG'),
              ),
              OutlinedButton(onPressed: !_hasData ? null : _share, child: const Text('Share')),
              OutlinedButton(
                onPressed: !_hasData ? null : _saveToHistory,
                child: const Text('Save to History'),
              ),
              OutlinedButton.icon(
                onPressed: !_hasData ? null : _openPrintSheet,
                icon: const Icon(Icons.print_outlined),
                label: const Text('Print quality'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    switch (_selected) {
      case _GenType.text:
        return TextField(
          controller: _textController,
          maxLines: 4,
          minLines: 1,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Text'),
          onChanged: (_) => setState(() {}),
        );
      case _GenType.url:
        return TextField(
          controller: _urlController,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'URL',
            hintText: 'https://example.com',
          ),
          onChanged: (_) => setState(() {}),
        );
      case _GenType.phone:
        return TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Phone number'),
          onChanged: (_) => setState(() {}),
        );
      case _GenType.wifi:
        return Column(
          children: [
            TextField(
              controller: _ssidController,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Network name (SSID)'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Password'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<_WifiEncryption>(
              value: _wifiEncryption,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Encryption'),
              items: const [
                DropdownMenuItem(value: _WifiEncryption.wpa, child: Text('WPA/WPA2')),
                DropdownMenuItem(value: _WifiEncryption.wep, child: Text('WEP')),
                DropdownMenuItem(value: _WifiEncryption.none, child: Text('None')),
              ],
              onChanged: (v) => setState(() => _wifiEncryption = v ?? _wifiEncryption),
            ),
          ],
        );
      case _GenType.barcode:
        return Column(
          children: [
            DropdownButtonFormField<_BarcodeFormat>(
              value: _barcodeFormat,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Format'),
              items: const [
                DropdownMenuItem(value: _BarcodeFormat.code128, child: Text('Code128')),
                DropdownMenuItem(value: _BarcodeFormat.ean13, child: Text('EAN-13')),
                DropdownMenuItem(value: _BarcodeFormat.upcA, child: Text('UPC-A')),
                DropdownMenuItem(value: _BarcodeFormat.code39, child: Text('Code39')),
                DropdownMenuItem(value: _BarcodeFormat.itf, child: Text('ITF')),
              ],
              onChanged: (v) => setState(() => _barcodeFormat = v ?? _barcodeFormat),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _barcodeValueController,
              keyboardType:
                  _barcodeNeedsDigits ? TextInputType.number : TextInputType.text,
              inputFormatters:
                  _barcodeNeedsDigits ? [FilteringTextInputFormatter.digitsOnly] : null,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Value',
                helperText: _barcodeHint,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        );
    }
  }

  String _labelFor(_GenType type) {
    switch (type) {
      case _GenType.text:
        return 'Text';
      case _GenType.url:
        return 'URL';
      case _GenType.wifi:
        return 'WiFi';
      case _GenType.phone:
        return 'Phone';
      case _GenType.barcode:
        return 'Barcode';
    }
  }
}
