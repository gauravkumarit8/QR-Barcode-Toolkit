import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart'
    show autoSaveScansNotifier, hapticFeedbackNotifier, soundFeedbackNotifier;
import '../models/history_item.dart';
import '../services/history_service.dart';
import '../utils/link_safety.dart';
import '../utils/scan_content.dart';

/// Scan tab.
///
/// Camera permission is requested only after an in-app explanation, never on
/// app launch (Play policy). The camera is paused whenever this tab is not
/// the visible screen or the app is in the background, so it never runs
/// unseen (battery, and the green camera-in-use dot on Android 12+).
class ScanScreen extends StatefulWidget {
  /// True while the Scan tab is the visible screen (driven by RootShell).
  final ValueListenable<bool> isActive;

  const ScanScreen({super.key, required this.isActive});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _Action {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _Action(this.label, this.icon, this.onTap);
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  final _historyService = HistoryService();
  final _scannerController = MobileScannerController();

  bool _permissionGranted = false;
  bool _permissionPermanentlyDenied = false;
  bool _torchOn = false;

  String? _lastScanValue;
  BarcodeFormat? _lastScanFormat;
  bool _savedToHistory = false;

  // Several codes in one frame (e.g. a parcel with multiple barcodes): we
  // collect for a moment, and if there is more than one, ask which one.
  final Map<String, Barcode> _pending = {};
  Timer? _decideTimer;
  bool _choosing = false;
  DateTime _ignoreDetectionsUntil = DateTime.fromMillisecondsSinceEpoch(0);

  // Camera lifecycle.
  bool _tabActive = true;
  bool _appResumed = true;
  bool _cameraRunning = true; // MobileScanner auto-starts when first built

  Timer? _idleHintTimer;
  bool _shownIdleHint = false;

  // Zoom: mobile_scanner's scale is 0.0 (min) to 1.0 (max). Pinch gives
  // direct control; the auto-nudge zooms in gradually if nothing is detected,
  // to help with small or far-away codes.
  double _zoomScale = 0.0;
  double _pinchStartZoom = 0.0;
  Timer? _autoZoomTimer;
  static const _maxAutoZoom = 0.6;
  static const _autoZoomStep = 0.15;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabActive = widget.isActive.value;
    widget.isActive.addListener(_onTabActiveChanged);
    _refreshPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.isActive.removeListener(_onTabActiveChanged);
    _decideTimer?.cancel();
    _cancelIdleTimers();
    _scannerController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- lifecycle

  void _onTabActiveChanged() {
    _tabActive = widget.isActive.value;
    _syncCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    // The user may have just granted permission in system settings.
    if (_appResumed) _refreshPermission();
    _syncCamera();
  }

  Future<void> _syncCamera() async {
    if (!_permissionGranted) return;
    final shouldRun = _tabActive && _appResumed;
    if (shouldRun == _cameraRunning) return;
    _cameraRunning = shouldRun;

    if (!shouldRun) {
      _cancelIdleTimers();
      _decideTimer?.cancel();
      _decideTimer = null;
      _pending.clear();
    }

    try {
      if (shouldRun) {
        await _scannerController.start();
      } else {
        await _scannerController.stop();
      }
    } catch (_) {
      // start()/stop() throw if the camera is already in that state — harmless.
    }

    if (shouldRun && mounted) {
      setState(() {
        _torchOn = false; // the torch turns off when the camera restarts
        _zoomScale = 0.0;
      });
      if (_lastScanValue == null) _startIdleTimers();
    }
  }

  // --------------------------------------------------------------- permission

  Future<void> _refreshPermission() async {
    final status = await Permission.camera.status;
    if (!mounted) return;
    final justGranted = status.isGranted && !_permissionGranted;
    setState(() {
      _permissionGranted = status.isGranted;
      _permissionPermanentlyDenied = status.isPermanentlyDenied;
    });
    if (justGranted) _startIdleTimers();
  }

  Future<void> _onAllowCameraPressed() async {
    if (_permissionPermanentlyDenied) {
      await openAppSettings();
      return;
    }
    final go = await showDialog<bool>(
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
    if (go != true) return;

    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _permissionGranted = status.isGranted;
      _permissionPermanentlyDenied = status.isPermanentlyDenied;
    });
    if (status.isGranted) _startIdleTimers();
  }

  // ------------------------------------------------------------ idle & zoom

  void _startIdleTimers() {
    _idleHintTimer?.cancel();
    _idleHintTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted || _lastScanValue != null || _shownIdleHint || !_cameraRunning) {
        return;
      }
      _shownIdleHint = true;
      _snack(
        'Having trouble? Try the flashlight, move a little closer, '
        'or scan from a photo with the gallery button.',
        seconds: 6,
      );
    });
    _startAutoZoom();
  }

  void _cancelIdleTimers() {
    _idleHintTimer?.cancel();
    _autoZoomTimer?.cancel();
  }

  /// Every 3s with no detection, zoom in a little further (up to a cap).
  void _startAutoZoom() {
    _autoZoomTimer?.cancel();
    _autoZoomTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || _lastScanValue != null || !_cameraRunning) {
        timer.cancel();
        return;
      }
      if (_zoomScale >= _maxAutoZoom) return;
      _setZoom((_zoomScale + _autoZoomStep).clamp(0.0, _maxAutoZoom).toDouble());
    });
  }

  void _setZoom(double value) {
    final clamped = value.clamp(0.0, 1.0).toDouble();
    setState(() => _zoomScale = clamped);
    unawaited(_scannerController.setZoomScale(clamped).catchError((_) {}));
  }

  // ---------------------------------------------------------------- detection

  void _onDetect(BarcodeCapture capture) {
    if (_lastScanValue != null || _choosing || !_cameraRunning) return;
    if (DateTime.now().isBefore(_ignoreDetectionsUntil)) return;

    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v != null && v.isNotEmpty) _pending[v] = b;
    }
    if (_pending.isEmpty) return;

    // Wait a beat so a second code entering the frame is included before we
    // decide — this is what stops "first code wins" on parcels with several.
    _decideTimer ??= Timer(const Duration(milliseconds: 350), _decide);
  }

  Future<void> _decide() async {
    _decideTimer = null;
    if (!mounted || _lastScanValue != null) return;
    final found = _pending.values.toList();
    _pending.clear();
    await _resolveFound(found);
  }

  Future<void> _resolveFound(List<Barcode> found) async {
    if (found.isEmpty) return;
    if (found.length == 1) {
      _accept(found.first.rawValue!, found.first.format);
      return;
    }
    _choosing = true;
    final picked = await _showChooser(found);
    _choosing = false;
    if (!mounted) return;
    if (picked == null) {
      // Dismissed: don't instantly re-open the chooser for the same codes.
      _ignoreDetectionsUntil = DateTime.now().add(const Duration(seconds: 2));
      return;
    }
    _accept(picked.rawValue!, picked.format);
  }

  Future<Barcode?> _showChooser(List<Barcode> found) {
    return showModalBottomSheet<Barcode>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Several codes found — tap the one you want',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final b in found)
                    ListTile(
                      leading: const Icon(Icons.qr_code_2),
                      title: Text(
                        b.rawValue ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(_formatName(b.format)),
                      onTap: () => Navigator.pop(context, b),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _accept(String value, BarcodeFormat format) {
    _cancelIdleTimers();
    if (hapticFeedbackNotifier.value) HapticFeedback.mediumImpact();
    if (soundFeedbackNotifier.value) SystemSound.play(SystemSoundType.click);
    setState(() {
      _lastScanValue = value;
      _lastScanFormat = format;
      _savedToHistory = false;
    });
    if (autoSaveScansNotifier.value) _saveToHistory();
  }

  void _dismissResult() {
    setState(() {
      _lastScanValue = null;
      _lastScanFormat = null;
      _savedToHistory = false;
    });
    _setZoom(0.0);
    _startIdleTimers();
  }

  /// Decodes a QR/barcode from an existing photo. Works even before camera
  /// permission is granted (the system photo picker needs no permission).
  Future<void> _pickFromGallery() async {
    final XFile? file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;

    BarcodeCapture? capture;
    try {
      capture = await _scannerController.analyzeImage(file.path);
    } catch (_) {
      capture = null;
    }
    if (!mounted) return;

    final unique = <String, Barcode>{};
    for (final b in capture?.barcodes ?? const <Barcode>[]) {
      final v = b.rawValue;
      if (v != null && v.isNotEmpty) unique[v] = b;
    }
    if (unique.isEmpty) {
      _snack('No QR code or barcode found in that image');
      return;
    }
    await _resolveFound(unique.values.toList());
  }

  // ------------------------------------------------------------------ actions

  void _snack(String message, {int seconds = 3}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: Duration(seconds: seconds)),
      );
  }

  Future<void> _copyText(String text, String confirmation) async {
    await Clipboard.setData(ClipboardData(text: text));
    _snack(confirmation);
  }

  Future<void> _launch(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _snack('No app found to handle this');
    } catch (_) {
      _snack('No app found to handle this');
    }
  }

  Future<void> _openLink(Uri uri) async {
    final warning = LinkSafety.checkReason(uri);

    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open this link?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(uri.toString(), maxLines: 3, overflow: TextOverflow.ellipsis),
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
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
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
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            child: Text(warning != null ? 'Open anyway' : 'Open'),
          ),
        ],
      ),
    );

    if (proceed == true) await _launch(uri);
  }

  Future<void> _searchOnline() async {
    final query = Uri.encodeComponent(_lastScanValue!);
    await _launch(Uri.parse('https://www.google.com/search?q=$query'));
  }

  Future<void> _comparePrices() async {
    final query = Uri.encodeComponent(_lastScanValue!);
    await _launch(Uri.parse('https://www.google.com/search?tbm=shop&q=$query'));
  }

  Future<void> _saveToHistory() async {
    final value = _lastScanValue;
    if (value == null || _savedToHistory) return;
    setState(() => _savedToHistory = true); // set first: avoids double-saves
    await _historyService.add(HistoryItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: 'scan',
      value: value,
      timestamp: DateTime.now(),
    ));
  }

  /// True for retail product barcodes (EAN-13/8, UPC-A/E) with a numeric value.
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

  _Action? _primaryAction(ScanContent c) {
    switch (c.kind) {
      case ScanKind.url:
        return _Action('Open link', Icons.open_in_new, () => _openLink(c.uri!));
      case ScanKind.wifi:
        final w = c.wifi!;
        if (w.hasPassword) {
          return _Action('Copy password', Icons.key,
              () => _copyText(w.password!, 'Wi-Fi password copied'));
        }
        return _Action('Copy network name', Icons.wifi,
            () => _copyText(w.ssid, 'Network name copied'));
      case ScanKind.phone:
        return _Action('Call', Icons.call_outlined, () => _launch(c.uri!));
      case ScanKind.email:
        return _Action('Send email', Icons.email_outlined, () => _launch(c.uri!));
      case ScanKind.sms:
        return _Action('Send message', Icons.sms_outlined, () => _launch(c.uri!));
      case ScanKind.geo:
        return _Action('Open in Maps', Icons.map_outlined, () => _launch(c.uri!));
      case ScanKind.product:
        return _Action('Compare prices', Icons.price_check, _comparePrices);
      case ScanKind.text:
        return _Action('Search online', Icons.search, _searchOnline);
    }
  }

  String _kindTitle(ScanKind kind) => switch (kind) {
        ScanKind.url => 'Link',
        ScanKind.wifi => 'Wi-Fi network',
        ScanKind.phone => 'Phone number',
        ScanKind.email => 'Email',
        ScanKind.sms => 'Text message',
        ScanKind.geo => 'Location',
        ScanKind.product => 'Product barcode',
        ScanKind.text => 'Text',
      };

  String _formatName(BarcodeFormat f) {
    switch (f) {
      case BarcodeFormat.qrCode:
        return 'QR code';
      case BarcodeFormat.ean13:
        return 'EAN-13';
      case BarcodeFormat.ean8:
        return 'EAN-8';
      case BarcodeFormat.upcA:
        return 'UPC-A';
      case BarcodeFormat.upcE:
        return 'UPC-E';
      case BarcodeFormat.code128:
        return 'Code 128';
      case BarcodeFormat.code39:
        return 'Code 39';
      case BarcodeFormat.code93:
        return 'Code 93';
      case BarcodeFormat.codabar:
        return 'Codabar';
      case BarcodeFormat.itf:
        return 'ITF';
      case BarcodeFormat.dataMatrix:
        return 'Data Matrix';
      case BarcodeFormat.pdf417:
        return 'PDF417';
      case BarcodeFormat.aztec:
        return 'Aztec';
      default:
        return 'Barcode';
    }
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    if (!_permissionGranted) return _buildPermissionPrompt();

    final value = _lastScanValue;
    final content = value == null
        ? null
        : ScanContent.parse(value, isProductBarcode: _isProductBarcode);

    return Column(
      children: [
        Expanded(child: _buildCameraArea()),
        if (content != null)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: SingleChildScrollView(
              child: _ResultPanel(
                content: content,
                headline:
                    '${_formatName(_lastScanFormat ?? BarcodeFormat.unknown)} · ${_kindTitle(content.kind)}',
                primary: _primaryAction(content),
                savedToHistory: _savedToHistory,
                onCopy: () => _copyText(content.raw, 'Copied to clipboard'),
                onShare: () => Share.share(content.raw),
                onSave: _saveToHistory,
                onDismiss: _dismissResult,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPermissionPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 48),
            const SizedBox(height: 16),
            Text(
              _permissionPermanentlyDenied
                  ? 'Camera access is turned off. Turn it on in Settings to scan.'
                  : 'Camera access is needed to scan QR codes and barcodes. '
                      'Nothing is uploaded — scanning happens on your device.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _onAllowCameraPressed,
              child: Text(_permissionPermanentlyDenied ? 'Open Settings' : 'Allow camera'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Scan from a photo instead'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraArea() {
    return GestureDetector(
      onScaleStart: (_) => _pinchStartZoom = _zoomScale,
      onScaleUpdate: (details) {
        // details.scale is relative to the gesture start, so apply it on top
        // of the zoom recorded at onScaleStart (not the current zoom, which
        // would compound every frame).
        _autoZoomTimer?.cancel(); // a manual pinch overrides the auto-nudge
        _setZoom(_pinchStartZoom + (details.scale - 1) * 0.5);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _scannerController, onDetect: _onDetect),
          IgnorePointer(
            child: Center(
              child: SizedBox(
                width: 240,
                height: 240,
                child: CustomPaint(painter: _ScanFramePainter()),
              ),
            ),
          ),
          if (_zoomScale > 0.01)
            Positioned(
              top: 12,
              left: 12,
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
            top: 8,
            right: 8,
            child: Column(
              children: [
                _CamButton(
                  icon: _torchOn ? Icons.flash_on : Icons.flash_off,
                  tooltip: 'Flashlight',
                  active: _torchOn,
                  onPressed: () {
                    unawaited(_scannerController.toggleTorch().catchError((_) {}));
                    setState(() => _torchOn = !_torchOn);
                  },
                ),
                const SizedBox(height: 8),
                _CamButton(
                  icon: Icons.cameraswitch_outlined,
                  tooltip: 'Switch camera',
                  onPressed: () =>
                      unawaited(_scannerController.switchCamera().catchError((_) {})),
                ),
                const SizedBox(height: 8),
                _CamButton(
                  icon: Icons.photo_library_outlined,
                  tooltip: 'Scan from gallery',
                  onPressed: _pickFromGallery,
                ),
              ],
            ),
          ),
          if (_lastScanValue == null)
            const Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Text(
                  'Point at a QR code or barcode',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Round translucent icon button that stays readable over any camera image.
class _CamButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  const _CamButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Colors.amber : Colors.black54,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: active ? Colors.black : Colors.white),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

/// Four L-shaped corner markers (the standard "scan frame" look).
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

/// Result shown under the camera after a scan. One prominent primary action
/// that fits the content, plus Copy / Share / Save.
class _ResultPanel extends StatelessWidget {
  final ScanContent content;
  final String headline;
  final _Action? primary;
  final bool savedToHistory;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onDismiss;

  const _ResultPanel({
    required this.content,
    required this.headline,
    required this.primary,
    required this.savedToHistory,
    required this.onCopy,
    required this.onShare,
    required this.onSave,
    required this.onDismiss,
  });

  Widget _body(BuildContext context) {
    final wifi = content.wifi;
    if (content.kind == ScanKind.wifi && wifi != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            wifi.ssid,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(wifi.security == 'nopass'
              ? 'Open network (no password)'
              : 'Security: ${wifi.security}'),
          if (wifi.hasPassword) SelectableText('Password: ${wifi.password}'),
        ],
      );
    }
    return SelectableText(content.raw, maxLines: 5);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    headline,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Scan again',
                  onPressed: onDismiss,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _body(context),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (primary != null)
                  FilledButton.icon(
                    onPressed: primary!.onTap,
                    icon: Icon(primary!.icon),
                    label: Text(primary!.label),
                  ),
                OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy'),
                ),
                OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share'),
                ),
                if (!savedToHistory)
                  TextButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('Save'),
                  ),
              ],
            ),
            if (savedToHistory)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Saved to history',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
