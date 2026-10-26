import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_strings.dart';
import '../l10n/translations.dart';
import '../main.dart'
    show
        themeModeNotifier,
        autoSaveScansNotifier,
        hapticFeedbackNotifier,
        soundFeedbackNotifier,
        languageNotifier;
import '../services/ad_service.dart';
import '../services/error_log.dart';
import '../services/pro_service.dart';
import '../services/purchase_service.dart';
import '../services/settings_service.dart';
import '../services/share_service.dart';
import '../utils/feedback_report.dart';

const _privacyPolicyUrl = 'https://grvthakur.bid/qr-barcode-toolkit/privacy-policy.html';
const _supportEmail = 'gaurav954624@gmail.com';
const _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.grv.qr_barcode_toolkit';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsService = SettingsService();

  bool _autoSave = true;
  String _version = '';
  bool _showPrivacyOptions = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
    PurchaseService.loadProduct();
    PurchaseService.message.addListener(_showPurchaseMessage);
  }

  @override
  void dispose() {
    PurchaseService.message.removeListener(_showPurchaseMessage);
    super.dispose();
  }

  void _showPurchaseMessage() {
    final msg = PurchaseService.message.value;
    if (msg == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    PurchaseService.message.value = null;
  }

  Future<void> _load() async {
    final autoSave = await _settingsService.getAutoSaveScans();
    final info = await PackageInfo.fromPlatform();
    final privacyRequired =
        ProService.isPro.value ? false : await AdService.privacyOptionsRequired();
    if (!mounted) return;
    setState(() {
      _autoSave = autoSave;
      _showPrivacyOptions = privacyRequired;
      _version = '${info.version} (${info.buildNumber})';
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('settings.title'))),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ListenableBuilder(
                  listenable: Listenable.merge([
                    ProService.isPro,
                    PurchaseService.product,
                    PurchaseService.busy,
                  ]),
                  builder: (context, _) {
                    if (ProService.isPro.value) {
                      return ListTile(
                        leading: const Icon(Icons.verified_outlined),
                        title: Text(s.t('settings.proUnlocked')),
                        subtitle: Text(s.t('settings.proUnlockedSubtitle')),
                      );
                    }
                    final product = PurchaseService.product.value;
                    final busy = PurchaseService.busy.value;
                    return Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.workspace_premium_outlined),
                          title: Text(s.t('settings.upgrade')),
                          subtitle: Text(s.t('settings.upgradeSubtitle')),
                          trailing: FilledButton(
                            onPressed: (product == null || busy) ? null : PurchaseService.buyPro,
                            child: Text(busy ? '…' : (product?.price ?? s.t('settings.unavailable'))),
                          ),
                        ),
                        ListTile(
                          title: Text(s.t('settings.restore')),
                          subtitle: Text(s.t('settings.restoreSubtitle')),
                          onTap: busy ? null : PurchaseService.restore,
                        ),
                      ],
                    );
                  },
                ),
                const Divider(),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeModeNotifier,
                  builder: (context, mode, _) => ListTile(
                    title: Text(s.t('settings.theme')),
                    subtitle: Text(_themeLabel(mode, s)),
                    trailing: DropdownButton<ThemeMode>(
                      value: mode,
                      underline: const SizedBox.shrink(),
                      items: [
                        DropdownMenuItem(
                            value: ThemeMode.system, child: Text(s.t('settings.themeSystem'))),
                        DropdownMenuItem(
                            value: ThemeMode.light, child: Text(s.t('settings.themeLight'))),
                        DropdownMenuItem(
                            value: ThemeMode.dark, child: Text(s.t('settings.themeDark'))),
                      ],
                      onChanged: (newMode) async {
                        if (newMode == null) return;
                        themeModeNotifier.value = newMode;
                        await _settingsService.setThemeMode(newMode);
                      },
                    ),
                  ),
                ),
                ValueListenableBuilder<String?>(
                  valueListenable: languageNotifier,
                  builder: (context, code, _) => ListTile(
                    title: Text(s.t('settings.language')),
                    subtitle: Text(code == null
                        ? s.t('settings.languageSystem')
                        : (Translations.languageNames[code] ?? code)),
                    trailing: DropdownButton<String>(
                      value: code ?? 'system',
                      underline: const SizedBox.shrink(),
                      items: [
                        DropdownMenuItem(
                            value: 'system', child: Text(s.t('settings.languageSystem'))),
                        for (final c in Translations.languageCodes)
                          DropdownMenuItem(
                              value: c, child: Text(Translations.languageNames[c] ?? c)),
                      ],
                      onChanged: (chosen) async {
                        if (chosen == null) return;
                        final newCode = chosen == 'system' ? null : chosen;
                        languageNotifier.value = newCode;
                        await _settingsService.setLanguageCode(newCode);
                      },
                    ),
                  ),
                ),
                SwitchListTile(
                  title: Text(s.t('settings.autoSave')),
                  subtitle: Text(s.t('settings.autoSaveSubtitle')),
                  value: _autoSave,
                  onChanged: (value) async {
                    setState(() => _autoSave = value);
                    autoSaveScansNotifier.value = value;
                    await _settingsService.setAutoSaveScans(value);
                  },
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: hapticFeedbackNotifier,
                  builder: (context, value, _) => SwitchListTile(
                    title: Text(s.t('settings.vibrate')),
                    subtitle: Text(s.t('settings.vibrateSubtitle')),
                    value: value,
                    onChanged: (v) async {
                      hapticFeedbackNotifier.value = v;
                      await _settingsService.setHapticFeedback(v);
                    },
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: soundFeedbackNotifier,
                  builder: (context, value, _) => SwitchListTile(
                    title: Text(s.t('settings.sound')),
                    subtitle: Text(s.t('settings.soundSubtitle')),
                    value: value,
                    onChanged: (v) async {
                      soundFeedbackNotifier.value = v;
                      await _settingsService.setSoundFeedback(v);
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.qr_code_scanner),
                  title: Text(s.t('settings.tile')),
                  subtitle: Text(s.t('settings.tileSubtitle')),
                  onTap: _showTileHelp,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: Text(s.t('settings.share')),
                  subtitle: Text(s.t('settings.shareSubtitle')),
                  onTap: () => ShareService.text(
                    s.t('settings.shareMessage', {'url': _playStoreUrl}),
                  ),
                ),
                if (_showPrivacyOptions)
                  ListTile(
                    title: Text(s.t('settings.adPrivacy')),
                    subtitle: Text(s.t('settings.adPrivacySubtitle')),
                    onTap: AdService.showPrivacyOptions,
                  ),
                ListTile(
                  title: Text(s.t('settings.privacyPolicy')),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () async {
                    await launchUrl(Uri.parse(_privacyPolicyUrl),
                        mode: LaunchMode.externalApplication);
                  },
                ),
                ListTile(
                  title: Text(s.t('settings.version')),
                  subtitle: Text(_version),
                ),
                ListTile(
                  title: Text(s.t('settings.contact')),
                  trailing: const Icon(Icons.email_outlined, size: 18),
                  onTap: _contactSupport,
                ),
                ListTile(
                  title: Text(s.t('settings.reportAd')),
                  subtitle: Text(s.t('settings.reportAdSubtitle')),
                  trailing: const Icon(Icons.flag_outlined, size: 18),
                  onTap: () async {
                    final uri = Uri(
                      scheme: 'mailto',
                      path: _supportEmail,
                      query: 'subject=${Uri.encodeComponent('Ad report — QR Barcode Toolkit')}'
                          '&body=${Uri.encodeComponent('Please describe the ad you saw (and a screenshot if possible):\n\n')}',
                    );
                    await launchUrl(uri);
                  },
                ),
              ],
            ),
    );
  }

  /// Opens an email to support. The user chooses whether technical details
  /// are added, and can read and edit the email before sending it.
  Future<void> _contactSupport() async {
    final s = AppStrings.of(context);
    final withDetails = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.t('settings.contact')),
        content: Text(s.t('settings.contactBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(s.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(s.t('settings.noDetails')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(s.t('settings.addDetails')),
          ),
        ],
      ),
    );
    if (withDetails == null) return;

    final errors = withDetails ? await ErrorLog.recent() : const <String>[];
    final uri = FeedbackReport.mailto(
      to: _supportEmail,
      subject: 'QR Barcode Toolkit — Support',
      body: FeedbackReport.body(
        appVersion: _version,
        phone: '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
        errors: errors,
        includeDetails: withDetails,
      ),
    );
    final opened = await launchUrl(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.t('settings.noEmailApp', {'email': _supportEmail}))),
      );
    }
  }

  void _showTileHelp() {
    final s = AppStrings.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.t('settings.tileTitle')),
        content: Text(s.t('settings.tileBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(s.t('common.gotIt')),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode, AppStrings s) {
    switch (mode) {
      case ThemeMode.system:
        return s.t('settings.themeFollowing');
      case ThemeMode.light:
        return s.t('settings.themeLight');
      case ThemeMode.dark:
        return s.t('settings.themeDark');
    }
  }
}
