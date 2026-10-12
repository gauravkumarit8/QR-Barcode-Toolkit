import 'package:flutter/material.dart';
import '../screens/settings_screen.dart';

/// Explains that [feature] is part of Pro and offers to open the Pro screen.
/// Pro is a one-time purchase, and the dialog says so plainly.
Future<void> showProRequired(BuildContext context, {required String feature}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Pro feature'),
      content: Text(
        '$feature is part of Pro: one purchase, no subscription. '
        'Pro also removes ads and lifts the history limit.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
          child: const Text('See Pro'),
        ),
      ],
    ),
  );
}
