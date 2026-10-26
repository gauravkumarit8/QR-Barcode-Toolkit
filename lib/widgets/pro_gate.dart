import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../screens/settings_screen.dart';
import '../services/ad_pacing.dart';
import '../services/pro_service.dart';
import '../services/rewarded_ad_service.dart';

/// Explains that [feature] is part of Pro and offers to open the Pro screen.
/// Pro is a one-time purchase, and the dialog says so plainly.
Future<void> showProRequired(BuildContext context, {required String feature}) {
  final s = AppStrings.of(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(s.t('pro.title')),
      content: Text(s.t('pro.body', {'feature': feature})),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(s.t('common.notNow')),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
          child: Text(s.t('pro.seePro')),
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

  final s = AppStrings.of(context);
  final canWatch = RewardedAdService.isAvailable && await AdPacing.canOfferRewarded();
  if (!context.mounted) return false;

  if (!canWatch) {
    await showProRequired(context, feature: feature);
    return false;
  }

  final choice = await showDialog<_UnlockChoice>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(s.t('pro.unlockTitle')),
      content: Text(s.t('pro.unlockBody', {'feature': feature})),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(s.t('common.notNow')),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(dialogContext, _UnlockChoice.seePro),
          child: Text(s.t('pro.seePro')),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(dialogContext, _UnlockChoice.watchAd),
          icon: const Icon(Icons.play_circle_outline),
          label: Text(s.t('pro.watchAd')),
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
          SnackBar(content: Text(s.t('pro.adClosed'))),
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
