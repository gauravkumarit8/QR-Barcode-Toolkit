import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart' show autoSaveScansNotifier;
import '../models/history_item.dart';
import '../services/history_service.dart';
import '../utils/link_safety.dart';

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
  BarcodeFormat? _lastScanFormat;
  bool _savedToHistory = false;

  // ML Kit's barcode model downloads via Google Play services the first
  // time it's used on a device (not bundled in the APK). If that download
  // hasn't finished, detection silently returns nothing. This timer tells
  // the user why instead of leaving them wondering, instead of staying silent.
  Timer? _slowDetectTimer;
  bool _shownSlowHint = false;

  // Zoom: mobile_scanner's scale is 0.0 (min) to 1.0 (max). Pinch gesture
  // gives direct manual control; the auto-nudge timer gradually zooms in on
  // its own if nothing's been detected for a few seconds, specifically to
  // help with small or far-away codes the camera can't resolve at 1x.
  double _zoomScale = 0.0;
  double _pinchStartZoom = 0.0;
  Timer? _autoZoomTimer;
  static const _maxAutoZoom = 0.6; // cap auto-nudge below full zoom
  static const _autoZoomStep = 0.15;

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
    if (status.isGranted) _startSlowDetectTimer();

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
      if (mounted) {
        setState(() => _permissionGranted = status.isGranted);
        if (status.isGranted) _startSlowDetectTimer();
      }
    });
  }

  @override
  void dispose() {
    _slowDetectTimer?.cancel();
    _autoZoomTimer?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  void _startSlowDetectTimer() {
    _slowDetectTimer?.cancel();
    _slowDetectTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted || _lastScanValue != null || _shownSlowHint) return;
      _shownSlowHint = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 8),
          content: Text(
            'Not detecting anything? The scanner needs internet the first '
            'time it\'s used on a new phone to finish one-time setup. '
            'Connect to WiFi/data and try again.',
          ),
        ),
      );
    });
    _startAutoZoom();
  }

  /// Every 3s with no successful detection, nudge zoom in a bit further —
  /// helps catch small or far-away codes without the user having to
  /// manually pinch. Stops nudging once it hits _maxAutoZoom or a code is
  /// found. Resets to 1x on success / "Scan again" / re-entering the tab.
  void _startAutoZoom() {
    _autoZoomTimer?.cancel();
    _autoZoomTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || _lastScanValue != null) {
        timer.cancel();
        return;
      }
      if (_zoomScale >= _maxAutoZoom) return;
      setState(() => _zoomScale = (_zoomScale + _autoZoomStep).clamp(0.0, _maxAutoZoom));
      _scannerController.setZoomScale(_zoomScale);
    });
  }

  void _resetZoom() {
    _autoZoomTimer?.cancel();
    if (_zoomScale != 0.0) {
      setState(() => _zoomScale = 0.0);
      _scannerController.setZoomScale(0.0);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_autoDetect || _lastScanValue != null) return;
    final barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      _slowDetectTimer?.cancel();
      _autoZoomTimer?.cancel();
      setState(() {
        _lastScanValue = barcodes.first.rawValue;
        _lastScanFormat = barcodes.first.format;
        _savedToHistory = false;
      });
      if (autoSaveScansNotifier.value) {
        _saveToHistory();
      }
    }
  }

  /// Decodes a QR/barcode from an existing photo instead of the live
  /// camera — the single most-requested feature gap versus competitor
  /// scanner apps. Uses the system photo picker (no storage permission
  /// needed on modern Android via image_picker's built-in Photo Picker
  /// support).
  Future<void> _pickFromGallery() async {
    final XFile? file =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;

    final capture = await _scannerController.analyzeImage(file.path);
    final barcodes = capture?.barcodes ?? const [];

    if (barcodes.isEmpty || barcodes.first.rawValue == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No QR code or barcode found in that image')),
        );
      }
      return;
    }

    _slowDetectTimer?.cancel();
    _autoZoomTimer?.cancel();
    setState(() {
      _lastScanValue = barcodes.first.rawValue;
      _lastScanFormat = barcodes.first.format;
      _savedToHistory = false;
    });
    if (autoSaveScansNotifier.value) {
      _saveToHistory();
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

    final warning = LinkSafety.checkReason(uri);

    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open this link?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, maxLines: 3, overflow: TextOverflow.ellipsis),
            if (warning != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 18, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warning,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: warning != null
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error)
                : null,
            child: Text(warning != null ? 'Open anyway' : 'Open'),
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

  /// Opens a web search for the scanned text. Addresses a common complaint
  /// on competitor scanner apps: scanning a product barcode or unfamiliar
  /// code and getting nothing useful back. This stays opt-in (only runs on
  /// a tap) and uses the device's own browser, so it doesn't compromise the
  /// app's offline-first design — no network call happens unless the user
  /// explicitly asks for one.
  Future<void> _searchOnline() async {
    final query = Uri.encodeComponent(_lastScanValue!);
    final uri = Uri.parse('https://www.google.com/search?q=$query');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// True for retail product barcode formats (EAN-13/8, UPC-A/E) whose
  /// value is purely numeric — i.e. a real product code, not a QR-encoded
  /// piece of text that happens to use one of these formats. Matches
  /// competitor apps' "price scanner" feature at the level achievable
  /// without a backend: a direct link to Google Shopping results for the
  /// code, rather than an in-app price API (which would need a paid data
  /// source and break offline-first for a core flow).
  bool get _isProductBarcode {
    final format = _lastScanFormat;
    final value = _lastScanValue;
    if (format == null || value == null) return false;
    final isProductFormat = format == BarcodeFormat.ean13 ||
        format == BarcodeFormat.ean8 ||
        format == BarcodeFormat.upcA ||
        format == BarcodeFormat.upcE;
    return isProductFormat && RegExp(r'^\d+$').hasMatch(value);
  }

  Future<void> _comparePrices() async {
    final query = Uri.encodeComponent(_lastScanValue!);
    final uri = Uri.parse('https://www.google.com/search?tbm=shop&q=$query');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
          child: GestureDetector(
            onScaleStart: (_) => _pinchStartZoom = _zoomScale,
            onScaleUpdate: (details) {
              // details.scale is relative to gesture start, so apply it on
              // top of the zoom level recorded at onScaleStart rather than
              // the current _zoomScale (which would compound every frame).
              final next = (_pinchStartZoom + (details.scale - 1) * 0.5).clamp(0.0, 1.0);
              _autoZoomTimer?.cancel(); // manual pinch overrides the auto-nudge
              setState(() => _zoomScale = next);
              _scannerController.setZoomScale(next);
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(controller: _scannerController, onDetect: _onDetect),
                IgnorePointer(
                  child: Center(
                    child: SizedBox(
                      width: 220,
                      height: 220,
                      child: CustomPaint(painter: _ScanFramePainter()),
                    ),
                  ),
                ),
                if (_zoomScale > 0.01)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${(1 + _zoomScale * 4).toStringAsFixed(1)}x',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
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
              IconButton(
                icon: const Icon(Icons.photo_library_outlined),
                tooltip: 'Scan from gallery',
                onPressed: _pickFromGallery,
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
                  onSearchOnline: _isUrl ? null : (_isProductBarcode ? null : _searchOnline),
                  onComparePrices: _isProductBarcode ? _comparePrices : null,
                  onShare: _share,
                  onSave: _savedToHistory ? null : _saveToHistory,
                  onScanAgain: () {
                    setState(() {
                      _lastScanValue = null;
                      _lastScanFormat = null;
                      _savedToHistory = false;
                    });
                    _resetZoom();
                    _startAutoZoom();
                  },
                ),
        ),
        // TODO: banner ad (free tier only) below results
      ],
    );
  }
}

/// Draws four L-shaped corner markers (the standard "scan frame" look)
/// instead of a plain rectangle border.
class _ScanFramePainter extends CustomPainter {
  static const _cornerLength = 28.0;
  static const _strokeWidth = 4.0;
  static const _radius = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = _strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    void corner(Offset origin, bool right, bool bottom) {
      final dx = right ? -1.0 : 1.0;
      final dy = bottom ? -1.0 : 1.0;
      final path = Path()
        ..moveTo(origin.dx, origin.dy + dy * _cornerLength)
        ..lineTo(origin.dx, origin.dy + dy * _radius)
        ..quadraticBezierTo(
          origin.dx,
          origin.dy,
          origin.dx + dx * _radius,
          origin.dy,
        )
        ..lineTo(origin.dx + dx * _cornerLength, origin.dy);
      canvas.drawPath(path, paint);
    }

    corner(const Offset(0, 0), false, false);
    corner(Offset(size.width, 0), true, false);
    corner(Offset(0, size.height), false, true);
    corner(Offset(size.width, size.height), true, true);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ResultCard extends StatelessWidget {
  final String value;
  final bool isUrl;
  final bool savedToHistory;
  final VoidCallback onCopy;
  final VoidCallback? onOpen;
  final VoidCallback? onSearchOnline;
  final VoidCallback? onComparePrices;
  final VoidCallback onShare;
  final VoidCallback? onSave;
  final VoidCallback onScanAgain;

  const _ResultCard({
    required this.value,
    required this.isUrl,
    required this.savedToHistory,
    required this.onCopy,
    required this.onOpen,
    required this.onSearchOnline,
    required this.onComparePrices,
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
                  if (onSearchOnline != null)
                    TextButton(onPressed: onSearchOnline, child: const Text('Search online')),
                  if (onComparePrices != null)
                    TextButton(onPressed: onComparePrices, child: const Text('Compare prices')),
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
