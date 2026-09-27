import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:share_plus/share_plus.dart';
import '../models/history_item.dart';
import '../services/history_service.dart';

/// Generate tab.
///
/// v1 scope (intentionally trimmed from the original spec):
/// Text, URL, WiFi, Phone + one barcode format (Code128 — deferred, see TODO).
/// vCard / Event / multi-barcode-format support deferred to v2.
class GenerateScreen extends StatefulWidget {
  const GenerateScreen({super.key});

  @override
  State<GenerateScreen> createState() => _GenerateScreenState();
}

enum _GenType { text, url, wifi, phone, barcode }

class _GenerateScreenState extends State<GenerateScreen> {
  final _historyService = HistoryService();
  final _previewKey = GlobalKey();

  _GenType _selected = _GenType.text;
  final _controller = TextEditingController();
  bool _saving = false;

  String get _qrData => _controller.text;

  Future<Uint8List?> _capturePreviewPng() async {
    try {
      final boundary =
          _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _savePng() async {
    if (_qrData.isEmpty) return;
    setState(() => _saving = true);
    final bytes = await _capturePreviewPng();
    setState(() => _saving = false);

    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not save image')));
      }
      return;
    }

    // Uses MediaStore under the hood on Android 10+ (scoped storage) —
    // no broad WRITE_EXTERNAL_STORAGE permission required.
    final result = await ImageGallerySaver.saveImage(
      bytes,
      quality: 100,
      name: 'qr_${DateTime.now().millisecondsSinceEpoch}',
    );

    if (mounted) {
      final ok = result is Map && (result['isSuccess'] == true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Saved to gallery' : 'Save failed')),
      );
    }
  }

  Future<void> _share() async {
    if (_qrData.isEmpty) return;
    final bytes = await _capturePreviewPng();
    if (bytes == null) {
      await Share.share(_qrData);
      return;
    }
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: 'qr.png', mimeType: 'image/png')],
      text: _qrData,
    );
  }

  Future<void> _saveToHistory() async {
    if (_qrData.isEmpty) return;
    await _historyService.add(HistoryItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: 'generate',
      value: _qrData,
      timestamp: DateTime.now(),
    ));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved to history')));
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
                onSelected: (_) => setState(() => _selected = type),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // TODO: swap this single field for the per-type form
          // (WiFi needs SSID/password/encryption dropdown, etc.)
          // TODO: barcode format (Code128 etc.) uses barcode_widget instead
          // of QrImageView when _selected == _GenType.barcode.
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: _labelFor(_selected),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          Center(
            child: RepaintBoundary(
              key: _previewKey,
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: _qrData.isEmpty
                    ? const SizedBox(
                        height: 200,
                        width: 200,
                        child: Center(child: Text('Preview')),
                      )
                    : QrImageView(data: _qrData, version: QrVersions.auto, size: 200),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FilledButton(
                onPressed: _qrData.isEmpty || _saving ? null : _savePng,
                child: Text(_saving ? 'Saving…' : 'Save PNG'),
              ),
              OutlinedButton(
                onPressed: _qrData.isEmpty ? null : _share,
                child: const Text('Share'),
              ),
              OutlinedButton(
                onPressed: _qrData.isEmpty ? null : _saveToHistory,
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
