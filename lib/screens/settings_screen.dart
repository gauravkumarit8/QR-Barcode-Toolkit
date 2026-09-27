import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Pro'),
            subtitle: Text('TODO: Remove Ads / Unlimited History / Custom Colors'),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Auto-save scans to history'),
            value: true,
            onChanged: (_) {
              // TODO: persist via shared_preferences
            },
          ),
          const Divider(),
          const ListTile(
            title: Text('Privacy Policy'),
            // TODO: point to the hosted GitHub Pages privacy policy URL
          ),
          const ListTile(
            title: Text('App version'),
            // TODO: read from package_info_plus
          ),
        ],
      ),
    );
  }
}
