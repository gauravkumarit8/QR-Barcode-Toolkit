import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../models/history_item.dart';
import '../l10n/app_strings.dart';
import '../services/export_service.dart';
import '../services/review_prompt.dart';
import '../services/share_service.dart';
import '../services/history_service.dart';
import '../services/pro_service.dart';
import '../utils/code_payloads.dart';
import '../utils/qr_style.dart';
import '../utils/scan_content.dart';
import '../utils/svg_export.dart';
import '../utils/upi_link.dart';
import '../widgets/pro_gate.dart';

enum _GenType { text, url, wifi, phone, upi, email, sms, location, contact, barcode }

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
  final _upiIdController = TextEditingController();
  final _upiNameController = TextEditingController();
  final _upiAmountController = TextEditingController();
  final _upiNoteController = TextEditingController();
  final _emailController = TextEditingController();
  final _emailSubjectController = TextEditingController();
  final _emailBodyController = TextEditingController();
  final _smsNumberController = TextEditingController();
  final _smsMessageController = TextEditingController();
  final _locationController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactOrgController = TextEditingController();
  final _contactWebsiteController = TextEditingController();

  _WifiEncryption _wifiEncryption = _WifiEncryption.wpa;
  bool _wifiHidden = false;

  // QR style (Pro). Colours are 0xAARRGGBB integers, see QrStyleRules.
  int _fgArgb = QrStyleRules.defaultForeground;
  int _bgArgb = QrStyleRules.defaultBackground;
  bool _rounded = false;
  Uint8List? _logoBytes;
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
    _upiIdController.dispose();
    _upiNameController.dispose();
    _upiAmountController.dispose();
    _upiNoteController.dispose();
    _emailController.dispose();
    _emailSubjectController.dispose();
    _emailBodyController.dispose();
    _smsNumberController.dispose();
    _smsMessageController.dispose();
    _locationController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    _contactOrgController.dispose();
    _contactWebsiteController.dispose();
    super.dispose();
  }

  void _onRegeneratePrefill() {
    final value = widget.regeneratePrefill.value;
    if (value == null) return;
    // A UPI pay link goes back into the UPI form. A "collect" request does
    // not: this generator only makes pay links, so it stays as plain text.
    final scanned = ScanContent.parse(value).payment;
    final upi = (scanned != null &&
            scanned.scheme == 'upi' &&
            !scanned.isCollectRequest &&
            scanned.payeeId != null)
        ? scanned
        : null;
    setState(() {
      if (upi != null) {
        _selected = _GenType.upi;
        _upiIdController.text = upi.payeeId!;
        _upiNameController.text = upi.payeeName ?? '';
        _upiAmountController.text = upi.amount ?? '';
        _upiNoteController.text = upi.note ?? '';
      } else {
        _selected = _GenType.text;
        _textController.text = value;
      }
    });
    widget.regeneratePrefill.value = null;
  }

  String get _qrData {
    switch (_selected) {
      case _GenType.text:
        return _textController.text;
      case _GenType.url:
        return CodePayloads.normalizeUrl(_urlController.text);
      case _GenType.phone:
        return CodePayloads.tel(_phoneController.text);
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
        return 'WIFI:T:$enc;S:${_escapeWifi(_ssidController.text)};${password}H:$_wifiHidden;;';
      case _GenType.upi:
        return UpiLink.build(
              vpa: _upiIdController.text,
              name: _upiNameController.text,
              amount: _upiAmountController.text,
              note: _upiNoteController.text,
            ) ??
            '';
      case _GenType.email:
        return CodePayloads.mailto(
          address: _emailController.text,
          subject: _emailSubjectController.text,
          body: _emailBodyController.text,
        );
      case _GenType.sms:
        return CodePayloads.smsto(
          number: _smsNumberController.text,
          message: _smsMessageController.text,
        );
      case _GenType.location:
        return CodePayloads.geo(_locationController.text);
      case _GenType.contact:
        return CodePayloads.contactVCard(
          name: _contactNameController.text,
          phone: _contactPhoneController.text,
          email: _contactEmailController.text,
          organization: _contactOrgController.text,
          website: _contactWebsiteController.text,
        );
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
  /// True when the QR code differs from plain black on white squares.
  /// Linear barcodes are never styled.
  bool get _styleActive =>
      _selected != _GenType.barcode &&
      !QrStyleRules.isDefault(
        foreground: _fgArgb,
        background: _bgArgb,
        rounded: _rounded,
        hasLogo: _logoBytes != null,
      );

  int get _errorLevel {
    final level = QrStyleRules.ecLevel(styled: _styleActive, hasLogo: _logoBytes != null);
    return switch (level) {
      QrEcLevel.low => QrErrorCorrectLevel.L,
      QrEcLevel.medium => QrErrorCorrectLevel.M,
      QrEcLevel.high => QrErrorCorrectLevel.H,
    };
  }

  Future<void> _pickLogo() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _logoBytes = bytes);
    } catch (_) {
      _snack('Could not open that image');
    }
  }

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
    if (_styleActive && !await unlockOrWatchAd(context, feature: AppStrings.of(context).t('feature.styled'))) return;
    if (!mounted) return;
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
    if (ok) ReviewPrompt.recordPositiveAction();
  }

  Future<void> _share() async {
    if (!_hasData) return;
    if (_styleActive && !await unlockOrWatchAd(context, feature: AppStrings.of(context).t('feature.styled'))) return;
    if (!mounted) return;
    final bytes = await _capturePreviewPng();
    final shareText = _selected == _GenType.barcode ? _barcodeValueController.text : _qrData;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not attach the image — sharing text only')),
        );
      }
      await ShareService.text(shareText);
      return;
    }
    await ShareService.files(
      [XFile.fromData(bytes, name: 'code.png', mimeType: 'image/png')],
      text: shareText,
    );
    ReviewPrompt.recordPositiveAction();
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
    if (!await unlockOrWatchAd(context, feature: AppStrings.of(context).t('feature.print'))) return;
    if (!mounted) return;
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
    if (ok) ReviewPrompt.recordPositiveAction();
  }

  Future<void> _exportSvg() async {
    if (!_hasData) return;
    if (!await unlockOrWatchAd(context, feature: AppStrings.of(context).t('feature.print'))) return;
    if (!mounted) return;
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
            runSpacing: 4,
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
          if (_selected != _GenType.barcode) ...[
            const SizedBox(height: 8),
            _buildStyleSection(),
          ],
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
                        : QrImageView(
                            data: _qrData,
                            version: QrVersions.auto,
                            size: 200,
                            backgroundColor: Color(_bgArgb),
                            errorCorrectionLevel: _errorLevel,
                            eyeStyle: QrEyeStyle(
                              eyeShape: _rounded ? QrEyeShape.circle : QrEyeShape.square,
                              color: Color(_fgArgb),
                            ),
                            dataModuleStyle: QrDataModuleStyle(
                              dataModuleShape:
                                  _rounded ? QrDataModuleShape.circle : QrDataModuleShape.square,
                              color: Color(_fgArgb),
                            ),
                            embeddedImage: _logoBytes == null
                                ? null
                                : ResizeImage(MemoryImage(_logoBytes!), width: 128),
                            embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(44, 44)),
                            errorStateBuilder: (context, error) => const SizedBox(
                              width: 200,
                              height: 200,
                              child: Center(
                                child: Text(
                                  'Too much data for this style.\nTry a shorter text or remove the logo.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
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

  Widget _buildStyleSection() {
    final isPro = ProService.isPro.value;
    final labelStyle = Theme.of(context).textTheme.labelLarge;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Row(
        children: [
          const Text('Style'),
          const SizedBox(width: 8),
          if (!isPro)
            const Chip(label: Text('Pro'), visualDensity: VisualDensity.compact),
        ],
      ),
      subtitle: const Text('Colors, rounded dots, logo'),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Code color', style: labelStyle),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final c in QrStyleRules.foregrounds)
              _ColorDot(
                argb: c.argb,
                label: c.name,
                selected: _fgArgb == c.argb,
                onTap: () => setState(() => _fgArgb = c.argb),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Background', style: labelStyle),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final c in QrStyleRules.backgrounds)
              _ColorDot(
                argb: c.argb,
                label: c.name,
                selected: _bgArgb == c.argb,
                onTap: () => setState(() => _bgArgb = c.argb),
              ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Rounded dots'),
          value: _rounded,
          onChanged: (v) => setState(() => _rounded = v),
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _pickLogo,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_logoBytes == null ? 'Add logo' : 'Change logo'),
            ),
            if (_logoBytes != null)
              TextButton(
                onPressed: () => setState(() => _logoBytes = null),
                child: const Text('Remove logo'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Only dark-on-light colors are offered, because scanners need them. '
          'Try any style for free; saving or sharing a styled code needs Pro, '
          'or one short ad. SVG export is always plain black and white. '
          'Test a styled code with a scanner before you print it.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
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
            hintText: 'example.com',
            helperText: 'https:// is added if you leave it out',
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
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Hidden network'),
              value: _wifiHidden,
              onChanged: (v) => setState(() => _wifiHidden = v ?? false),
            ),
          ],
        );
      case _GenType.upi:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _upiIdController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'UPI ID',
                hintText: 'name@bank',
                errorText: UpiLink.vpaError(_upiIdController.text),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _upiNameController,
              maxLength: UpiLink.nameMax,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Payee name (optional)',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _upiAmountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Amount in \u20B9 (optional)',
                helperText: 'Leave empty to let the payer enter it',
                errorText: UpiLink.amountError(_upiAmountController.text),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _upiNoteController,
              maxLength: UpiLink.noteMax,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Note (optional)',
              ),
              onChanged: (_) => setState(() {}),
            ),
            Text(
              'Anyone who scans this code pays this UPI ID, so check it '
              'carefully. Test the code with your own UPI app before you print it.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        );
      case _GenType.email:
        return Column(
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Email address',
                errorText: CodePayloads.emailError(_emailController.text),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailSubjectController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Subject (optional)',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailBodyController,
              maxLines: 4,
              minLines: 1,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Message (optional)',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        );
      case _GenType.sms:
        return Column(
          children: [
            TextField(
              controller: _smsNumberController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Phone number',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _smsMessageController,
              maxLines: 4,
              minLines: 1,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Message (optional)',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        );
      case _GenType.location:
        return TextField(
          controller: _locationController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'Latitude, longitude',
            hintText: '48.8584, 2.2945',
            helperText: 'Paste coordinates copied from a maps app',
            errorText: CodePayloads.locationError(_locationController.text),
          ),
          onChanged: (_) => setState(() {}),
        );
      case _GenType.contact:
        return Column(
          children: [
            TextField(
              controller: _contactNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Name',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contactPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Phone (optional)',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contactEmailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Email (optional)',
                errorText: CodePayloads.emailError(_contactEmailController.text),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contactOrgController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Company (optional)',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contactWebsiteController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Website (optional)',
              ),
              onChanged: (_) => setState(() {}),
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
      case _GenType.upi:
        return 'UPI';
      case _GenType.email:
        return 'Email';
      case _GenType.sms:
        return 'SMS';
      case _GenType.location:
        return 'Location';
      case _GenType.contact:
        return 'Contact';
      case _GenType.barcode:
        return 'Barcode';
    }
  }
}

/// A round colour swatch used in the style options.
class _ColorDot extends StatelessWidget {
  final int argb;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.argb,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(argb),
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? scheme.primary : scheme.outline,
                width: selected ? 3 : 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
