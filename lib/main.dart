import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_strings.dart';
import 'screens/scan_screen.dart';
import 'screens/generate_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'services/ad_pacing.dart';
import 'services/ad_service.dart';
import 'services/error_log.dart';
import 'services/pro_service.dart';
import 'services/purchase_service.dart';
import 'services/rewarded_ad_service.dart';
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

/// Language chosen in Settings (a code such as 'es'), or null to follow the
/// phone's language.
final ValueNotifier<String?> languageNotifier = ValueNotifier(null);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep the last few errors on the device. They are only ever sent if the
  // user adds them to a support email (Settings > Contact support).
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    previousOnError?.call(details);
    ErrorLog.record(details.exception, details.stack, source: 'flutter');
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    ErrorLog.record(error, stack, source: 'async');
    return false; // keep the default handling as well
  };
  final settings = SettingsService();
  themeModeNotifier.value = await settings.getThemeMode();
  autoSaveScansNotifier.value = await settings.getAutoSaveScans();
  hapticFeedbackNotifier.value = await settings.getHapticFeedback();
  soundFeedbackNotifier.value = await settings.getSoundFeedback();
  languageNotifier.value = await settings.getLanguageCode();
  await ProService.load();
  await AdPacing.loadAndCountLaunch();
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
        return ValueListenableBuilder<String?>(
          valueListenable: languageNotifier,
          builder: (context, languageCode, _) {
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
              // null follows the phone's language; unsupported languages use English.
              locale: languageCode == null ? null : Locale(languageCode),
              supportedLocales: AppStrings.supportedLocales,
              localizationsDelegates: [
                AppStrings.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const RootShell(),
            );
          },
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

  void _onAdsReady() {
    if (AdService.adsReady.value) RewardedAdService.preload();
  }

  @override
  void initState() {
    super.initState();
    AdService.adsReady.addListener(_onAdsReady);
    // Consent form needs a visible Activity, so start after the first frame.
    // Skipped entirely for Pro users (no ads, so no consent needed).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ProService.isPro.value) AdService.init();
    });
  }

  @override
  void dispose() {
    AdService.adsReady.removeListener(_onAdsReady);
    _regeneratePrefill.dispose();
    _scanActive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final titles = [s.t('nav.scan'), s.t('nav.generate'), s.t('nav.history')];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
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
          // No banner on the Scan tab: the camera needs the whole screen and
          // an ad next to it invites accidental taps.
          BannerAdWidget(visible: _currentIndex != 0),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          _scanActive.value = index == 0;
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: const Icon(Icons.qr_code_scanner),
            label: titles[0],
          ),
          NavigationDestination(
            icon: const Icon(Icons.qr_code_2_outlined),
            selectedIcon: const Icon(Icons.qr_code_2),
            label: titles[1],
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: titles[2],
          ),
        ],
      ),
    );
  }
}
