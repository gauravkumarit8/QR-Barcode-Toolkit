import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/history_item.dart';
import '../services/history_service.dart';

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
  final _historyService = HistoryService();
  final _scannerController = MobileScannerController();

  bool _permissionGranted = false;
  bool _torchOn = false;
  bool _autoDetect = true;
  String? _lastScanValue;
  bool _savedToHistory = false;

  Future<void> _requestCameraPermission() async {
    final granted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera access needed'),
        content: const Text(
          'This lets you scan QR codes and barcodes with your camera. '
          'Nothing is uploaded — scanning happens entirely on your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (granted != true) return;

    final status = await Permission.camera.request();
    setState(() => _permissionGranted = status.isGranted);

    if (status.isPermanentlyDenied && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Camera permission denied. Enable it in system settings.'),
          action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    Permission.camera.status.then((status) {
      if (mounted) setState(() => _permissionGranted = status.isGranted);
    });
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_autoDetect || _lastScanValue != null) return;
    final barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      setState(() {
        _lastScanValue = barcodes.first.rawValue;
        _savedToHistory = false;
      });
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _lastScanValue!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to clipboard')),
      );
    }
  }

  Future<void> _open() async {
    final value = _lastScanValue!;
    final uri = Uri.tryParse(value);
    final looksLikeLink = uri != null && (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https'));

    if (!looksLikeLink) return;

    // TODO: replace with a real phishing/malicious-link check before opening.
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open this link?'),
        content: Text(value, maxLines: 3, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open'),
          ),
        ],
      ),
    );

    if (proceed == true) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _share() async {
    await Share.share(_lastScanValue!);
  }

  Future<void> _saveToHistory() async {
    await _historyService.add(HistoryItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: 'scan',
      value: _lastScanValue!,
      timestamp: DateTime.now(),
    ));
    setState(() => _savedToHistory = true);
  }

  bool get _isUrl {
    if (_lastScanValue == null) return false;
    final uri = Uri.tryParse(_lastScanValue!);
    return uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
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
                'Camera access is needed to scan QR codes and barcodes.',
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
              MobileScanner(controller: _scannerController, onDetect: _onDetect),
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white70, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Text(
                  _lastScanValue == null ? 'Align QR or barcode within the frame' : '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
                onPressed: () {
                  _scannerController.toggleTorch();
                  setState(() => _torchOn = !_torchOn);
                },
              ),
              Row(
                children: [
                  const Text('Auto-detect'),
                  Switch(
                    value: _autoDetect,
                    onChanged: (v) => setState(() => _autoDetect = v),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.cameraswitch_outlined),
                onPressed: () => _scannerController.switchCamera(),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 8,
          child: _lastScanValue == null
              ? const Center(child: Text('Point your camera at a QR code or barcode'))
              : _ResultCard(
                  value: _lastScanValue!,
                  isUrl: _isUrl,
                  savedToHistory: _savedToHistory,
                  onCopy: _copy,
                  onOpen: _isUrl ? _open : null,
                  onShare: _share,
                  onSave: _savedToHistory ? null : _saveToHistory,
                  onScanAgain: () => setState(() {
                    _lastScanValue = null;
                    _savedToHistory = false;
                  }),
                ),
        ),
        // TODO: banner ad (free tier only) below results
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String value;
  final bool isUrl;
  final bool savedToHistory;
  final VoidCallback onCopy;
  final VoidCallback? onOpen;
  final VoidCallback onShare;
  final VoidCallback? onSave;
  final VoidCallback onScanAgain;

  const _ResultCard({
    required this.value,
    required this.isUrl,
    required this.savedToHistory,
    required this.onCopy,
    required this.onOpen,
    required this.onShare,
    required this.onSave,
    required this.onScanAgain,
  });

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
                  TextButton(onPressed: onCopy, child: const Text('Copy')),
                  if (isUrl) TextButton(onPressed: onOpen, child: const Text('Open')),
                  TextButton(onPressed: onShare, child: const Text('Share')),
                  TextButton(
                    onPressed: onSave,
                    child: Text(savedToHistory ? 'Saved' : 'Save to History'),
                  ),
                ],
              ),
              TextButton(onPressed: onScanAgain, child: const Text('Scan again')),
            ],
          ),
        ),
      ),
    );
  }
}
