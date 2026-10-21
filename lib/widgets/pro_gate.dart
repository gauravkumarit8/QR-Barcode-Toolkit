import 'package:flutter/material.dart';
import '../screens/settings_screen.dart';
import '../services/ad_pacing.dart';
import '../services/pro_service.dart';
import '../services/rewarded_ad_service.dart';

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

enum _UnlockChoice { watchAd, seePro }

/// Gate for a Pro-only action. Returns true when the action may go ahead:
///  - Pro users: always.
///  - Free users: only after they choose "Watch ad" and watch it to the end.
///    That unlocks this one action, nothing more.
///
/// When no ad can be offered (not loaded yet, offline, consent declined, or
/// the daily limit is used up) this falls back to the plain Pro dialog.
Future<bool> unlockOrWatchAd(BuildContext context, {required String feature}) async {
  if (ProService.isPro.value) return true;

  final canWatch = RewardedAdService.isAvailable && await AdPacing.canOfferRewarded();
  if (!context.mounted) return false;

  if (!canWatch) {
    await showProRequired(context, feature: feature);
    return false;
  }

  final choice = await showDialog<_UnlockChoice>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Unlock this export'),
      content: Text(
        '$feature is part of Pro. Watch a short ad to use it once, '
        'or get Pro (one purchase, no subscription) to remove ads and unlock everything.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Not now'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(dialogContext, _UnlockChoice.seePro),
          child: const Text('See Pro'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(dialogContext, _UnlockChoice.watchAd),
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('Watch ad'),
        ),
      ],
    ),
  );
  if (!context.mounted) return false;

  switch (choice) {
    case _UnlockChoice.watchAd:
      final earned = await RewardedAdService.showAndWait();
      if (earned) {
        await AdPacing.recordRewardedUse();
        return true;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The ad was closed before the end, so nothing was unlocked.'),
          ),
        );
      }
      return false;
    case _UnlockChoice.seePro:
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
      return false;
    case null:
      return false;
  }
}
