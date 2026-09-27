import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Generate tab.
///
/// v1 scope (intentionally trimmed from the original spec):
/// Text, URL, WiFi, Phone + one barcode format (Code128).
/// vCard / Event / multi-barcode-format support deferred to v2.
class GenerateScreen extends StatefulWidget {
  const GenerateScreen({super.key});

  @override
  State<GenerateScreen> createState() => _GenerateScreenState();
}

enum _GenType { text, url, wifi, phone, barcode }

class _GenerateScreenState extends State<GenerateScreen> {
  _GenType _selected = _GenType.text;
  final _controller = TextEditingController();

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
          // (WiFi needs SSID/password/encryption, etc.)
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
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: _controller.text.isEmpty
                  ? const SizedBox(
                      height: 200,
                      width: 200,
                      child: Center(child: Text('Preview')),
                    )
                  : QrImageView(
                      data: _controller.text,
                      version: QrVersions.auto,
                      size: 200,
                    ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // TODO: wire up Save PNG / Share / Save to History
              FilledButton(onPressed: () {}, child: const Text('Save PNG')),
              OutlinedButton(onPressed: () {}, child: const Text('Share')),
            ],
          ),
          // TODO: banner ad (free tier only)
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
