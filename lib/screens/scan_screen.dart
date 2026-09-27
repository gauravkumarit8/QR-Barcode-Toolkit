import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

/// Scan tab.
///
/// IMPORTANT (Play Store compliance): camera permission is requested only
/// after this screen shows an in-app rationale dialog — never on app launch.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _permissionGranted = false;
  String? _lastScanValue;

  Future<void> _requestCameraPermission() async {
    // TODO: replace with a proper dialog explaining *why* camera is needed
    // before calling Permission.camera.request() — required for Play review
    // and for a good first-run UX.
    final status = await Permission.camera.request();
    setState(() => _permissionGranted = status.isGranted);
  }

  @override
  void initState() {
    super.initState();
    Permission.camera.status.then((status) {
      setState(() => _permissionGranted = status.isGranted);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_permissionGranted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Camera access is needed to scan QR codes and barcodes. '
                'Nothing is uploaded — scanning happens entirely on your device.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _requestCameraPermission,
                child: const Text('Allow Camera Access'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          flex: 11,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                onDetect: (capture) {
                  final barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    setState(() {
                      _lastScanValue = barcodes.first.rawValue;
                    });
                  }
                },
              ),
              // TODO: overlay scan frame + corner markers
            ],
          ),
        ),
        Expanded(
          flex: 9,
          child: _lastScanValue == null
              ? const Center(
                  child: Text('Point your camera at a QR code or barcode'),
                )
              : _ResultCard(
                  value: _lastScanValue!,
                  onScanAgain: () => setState(() => _lastScanValue = null),
                ),
        ),
        // TODO: banner ad (free tier only) below results
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String value;
  final VoidCallback onScanAgain;

  const _ResultCard({required this.value, required this.onScanAgain});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  // TODO: Copy, Open, Share, Save to History actions
                  TextButton(onPressed: () {}, child: const Text('Copy')),
                  TextButton(onPressed: () {}, child: const Text('Share')),
                  TextButton(onPressed: () {}, child: const Text('Save')),
                ],
              ),
              TextButton(
                onPressed: onScanAgain,
                child: const Text('Scan again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
