import 'package:flutter/material.dart';
import 'screens/scan_screen.dart';
import 'screens/generate_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'services/ad_service.dart';
import 'services/pro_service.dart';
import 'services/purchase_service.dart';
import 'services/settings_service.dart';
import 'widgets/banner_ad_widget.dart';

/// App-wide theme mode, set from persisted settings at startup and updated
/// live by SettingsScreen. A plain ValueNotifier is enough here — no need
/// for a full state-management package for one shared value.
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);

/// Whether Scan should auto-save each detected code to History. Loaded at
/// startup, updated live by SettingsScreen, read (not listened to for
/// rebuilds) by ScanScreen at detection time.
final ValueNotifier<bool> autoSaveScansNotifier = ValueNotifier(true);

/// Vibrate / beep when a code is scanned. Same pattern as above.
final ValueNotifier<bool> hapticFeedbackNotifier = ValueNotifier(true);
final ValueNotifier<bool> soundFeedbackNotifier = ValueNotifier(false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsService();
  themeModeNotifier.value = await settings.getThemeMode();
  autoSaveScansNotifier.value = await settings.getAutoSaveScans();
  hapticFeedbackNotifier.value = await settings.getHapticFeedback();
  soundFeedbackNotifier.value = await settings.getSoundFeedback();
  await ProService.load();
  PurchaseService.init();
  runApp(const QrBarcodeToolkitApp());
}

class QrBarcodeToolkitApp extends StatelessWidget {
  const QrBarcodeToolkitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'QR & Barcode Toolkit',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.teal,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.teal,
            brightness: Brightness.dark,
          ),
          themeMode: themeMode,
          home: const RootShell(),
        );
      },
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _currentIndex = 0;

  // Shared between History ("Re-generate") and Generate (consumes the value).
  final ValueNotifier<String?> _regeneratePrefill = ValueNotifier(null);

  // True only while the Scan tab is the visible screen. ScanScreen pauses the
  // camera when this goes false (other tab, or Settings open on top) so the
  // camera is not left running in the background.
  final ValueNotifier<bool> _scanActive = ValueNotifier(true);

  static const _titles = ['Scan', 'Generate', 'History'];

  late final List<Widget> _screens = [
    ScanScreen(isActive: _scanActive),
    GenerateScreen(regeneratePrefill: _regeneratePrefill),
    HistoryScreen(
      onRegenerate: (value) {
        _regeneratePrefill.value = value;
        setState(() => _currentIndex = 1);
        _scanActive.value = false;
      },
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Consent form needs a visible Activity, so start after the first frame.
    // Skipped entirely for Pro users (no ads, so no consent needed).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ProService.isPro.value) AdService.init();
    });
  }

  @override
  void dispose() {
    _regeneratePrefill.dispose();
    _scanActive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              _scanActive.value = false;
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _scanActive.value = _currentIndex == 0;
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          _scanActive.value = index == 0;
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_2_outlined),
            selectedIcon: Icon(Icons.qr_code_2),
            label: 'Generate',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
