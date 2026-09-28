import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart' show themeModeNotifier, autoSaveScansNotifier;
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsService = SettingsService();

  bool _autoSave = true;
  String _version = '';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final autoSave = await _settingsService.getAutoSaveScans();
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _autoSave = autoSave;
      _version = '${info.version} (${info.buildNumber})';
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const ListTile(
                  title: Text('Pro'),
                  subtitle: Text('Remove Ads · Unlimited History · Custom Colors (coming soon)'),
                ),
                const Divider(),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeModeNotifier,
                  builder: (context, mode, _) => ListTile(
                    title: const Text('Theme'),
                    subtitle: Text(_themeLabel(mode)),
                    trailing: DropdownButton<ThemeMode>(
                      value: mode,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                        DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                        DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                      ],
                      onChanged: (newMode) async {
                        if (newMode == null) return;
                        themeModeNotifier.value = newMode;
                        await _settingsService.setThemeMode(newMode);
                      },
                    ),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Auto-save scans to history'),
                  subtitle: const Text('Off: use "Save to History" manually after each scan'),
                  value: _autoSave,
                  onChanged: (value) async {
                    setState(() => _autoSave = value);
                    autoSaveScansNotifier.value = value;
                    await _settingsService.setAutoSaveScans(value);
                  },
                ),
                const Divider(),
                ListTile(
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () async {
                    // TODO: replace with the real hosted GitHub Pages URL once
                    // the policy is published (see PROGRESS.md).
                    const url = 'https://example.com/qr-barcode-toolkit-privacy';
                    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  },
                ),
                ListTile(
                  title: const Text('App version'),
                  subtitle: Text(_version),
                ),
                ListTile(
                  title: const Text('Contact support'),
                  trailing: const Icon(Icons.email_outlined, size: 18),
                  onTap: () async {
                    // TODO: replace with the real support email address.
                    final uri = Uri(scheme: 'mailto', path: 'support@example.com');
                    await launchUrl(uri);
                  },
                ),
              ],
            ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Following system setting';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }
}
