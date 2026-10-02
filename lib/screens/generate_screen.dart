import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../models/history_item.dart';
import '../services/history_service.dart';

enum _GenType { text, url, wifi, phone, barcode }

enum _WifiEncryption { wpa, wep, none }

enum _BarcodeFormat { code128, ean13, upcA, code39, itf }

/// Generate tab.
///
/// [regeneratePrefill] lets another screen (History's "Re-generate" button)
/// push a value in here. When it changes, this screen switches to the Text
/// type and fills the field with that value.
class GenerateScreen extends StatefulWidget {
  final ValueNotifier<String?> regeneratePrefill;

  const GenerateScreen({
    super.key,
    required this.regeneratePrefill,
  });

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

    // Consume it so switching tabs away and back doesn't re-trigger this.
    widget.regeneratePrefill.value = null;
  }

  /// The literal string encoded into the QR code (not used for barcode type,
  /// which renders from _barcodeValueController directly).
  String get _qrData {
    switch (_selected) {
      case _GenType.text:
        return _textController.text;

      case _GenType.url:
        return _urlController.text;

      case _GenType.phone:
        return _phoneController.text.isEmpty
            ? ''
            : 'tel:${_phoneController.text}';

      case _GenType.wifi:
        if (_ssidController.text.isEmpty) return '';

        final enc = switch (_wifiEncryption) {
          _WifiEncryption.wpa => 'WPA',
          _WifiEncryption.wep => 'WEP',
          _WifiEncryption.none => 'nopass',
        };

        return 'WIFI:T:$enc;S:${_ssidController.text};'
            'P:${_passwordController.text};H:false;;';

      case _GenType.barcode:
        return _barcodeValueController.text;
    }
  }

  bool get _hasData =>
      _selected == _GenType.barcode
          ? _barcodeValueController.text.isNotEmpty
          : _qrData.isNotEmpty;

  Barcode get _barcode => switch (_barcodeFormat) {
        _BarcodeFormat.code128 => Barcode.code128(),
        _BarcodeFormat.ean13 => Barcode.ean13(),
        _BarcodeFormat.upcA => Barcode.upcA(),
        _BarcodeFormat.code39 => Barcode.code39(),
        _BarcodeFormat.itf => Barcode.itf(),
      };

  Future<Uint8List?> _capturePreviewPng() async {
    try {
      final boundary = _previewKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);

      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _savePng() async {
    if (!_hasData) return;

    setState(() => _saving = true);

    final bytes = await _capturePreviewPng();

    setState(() => _saving = false);

    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save image'),
          ),
        );
      }

      return;
    }

    try {
      await Gal.putImageBytes(
        bytes,
        name: 'qr_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved to gallery'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Save failed'),
          ),
        );
      }
    }
  }

  Future<void> _share() async {
    if (!_hasData) return;

    final bytes = await _capturePreviewPng();

    final shareText = _selected == _GenType.barcode
        ? _barcodeValueController.text
        : _qrData;

    if (bytes == null) {
      await Share.share(shareText);
      return;
    }

    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          name: 'code.png',
          mimeType: 'image/png',
        ),
      ],
      text: shareText,
    );
  }

  Future<void> _saveToHistory() async {
    if (!_hasData) return;

    final value = _selected == _GenType.barcode
        ? _barcodeValueController.text
        : _qrData;

    await _historyService.add(
      HistoryItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: 'generate',
        value: value,
        timestamp: DateTime.now(),
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved to history'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                onSelected: (_) {
                  setState(() => _selected = type);
                },
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
                        child: Center(
                          child: Text('Preview'),
                        ),
                      )
                    : _selected == _GenType.barcode
                        ? BarcodeWidget(
                            barcode: _barcode,
                            data: _barcodeValueController.text,
                            width: 250,
                            height: 120,
                            drawText: true,
                            errorBuilder: (context, error) {
                              return SizedBox(
                                width: 250,
                                height: 120,
                                child: Center(
                                  child: Text(
                                    'Invalid value for this format',
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            },
                          )
                        : QrImageView(
                            data: _qrData,
                            version: QrVersions.auto,
                            size: 200,
                          ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FilledButton(
                onPressed: !_hasData || _saving ? null : _savePng,
                child: Text(
                  _saving ? 'Saving…' : 'Save PNG',
                ),
              ),

              OutlinedButton(
                onPressed: !_hasData ? null : _share,
                child: const Text('Share'),
              ),

              OutlinedButton(
                onPressed: !_hasData ? null : _saveToHistory,
                child: const Text('Save to History'),
              ),
            ],
          ),

          // TODO: banner ad (free tier only)
          // TODO: Size/margin sliders, color picker + logo (Pro-gated, v2)
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
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Text',
          ),
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
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Phone number',
          ),
          onChanged: (_) => setState(() {}),
        );

      case _GenType.wifi:
        return Column(
          children: [
            TextField(
              controller: _ssidController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Network name (SSID)',
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Password',
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<_WifiEncryption>(
              initialValue: _wifiEncryption,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Encryption',
              ),
              items: const [
                DropdownMenuItem(
                  value: _WifiEncryption.wpa,
                  child: Text('WPA/WPA2'),
                ),
                DropdownMenuItem(
                  value: _WifiEncryption.wep,
                  child: Text('WEP'),
                ),
                DropdownMenuItem(
                  value: _WifiEncryption.none,
                  child: Text('None'),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  _wifiEncryption = v ?? _wifiEncryption;
                });
              },
            ),
          ],
        );

      case _GenType.barcode:
        return Column(
          children: [
            DropdownButtonFormField<_BarcodeFormat>(
              initialValue: _barcodeFormat,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Format',
              ),
              items: const [
                DropdownMenuItem(
                  value: _BarcodeFormat.code128,
                  child: Text('Code128'),
                ),
                DropdownMenuItem(
                  value: _BarcodeFormat.ean13,
                  child: Text('EAN-13'),
                ),
                DropdownMenuItem(
                  value: _BarcodeFormat.upcA,
                  child: Text('UPC-A'),
                ),
                DropdownMenuItem(
                  value: _BarcodeFormat.code39,
                  child: Text('Code39'),
                ),
                DropdownMenuItem(
                  value: _BarcodeFormat.itf,
                  child: Text('ITF'),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  _barcodeFormat = v ?? _barcodeFormat;
                });
              },
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _barcodeValueController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Value',
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