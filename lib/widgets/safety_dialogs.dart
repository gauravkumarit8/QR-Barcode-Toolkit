import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_strings.dart';
import '../utils/link_safety.dart';
import '../utils/scan_content.dart';

/// A red box listing one or more warnings.
class WarningBox extends StatelessWidget {
  final List<String> messages;

  const WarningBox({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < messages.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  Text(
                    messages[i],
                    style: TextStyle(fontSize: 13, color: scheme.onErrorContainer),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _toast(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> _launch(BuildContext context, Uri uri, String failureMessage) async {
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _toast(context, failureMessage);
  } catch (_) {
    _toast(context, failureMessage);
  }
}

/// Asks before opening a scanned link. The site name (host) is shown large,
/// on its own, because that is the part that tells you where you are really
/// going; the long path after it is shown small. Used for links from both
/// the Scan result and History, so neither route skips the check.
Future<void> openLinkSafely(BuildContext context, Uri uri) async {
  final s = AppStrings.of(context);
  final reasons = LinkSafety.reasons(uri);
  final rest = LinkSafety.restOf(uri);

  final proceed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final text = Theme.of(dialogContext).textTheme;
      return AlertDialog(
        title: Text(s.t('safety.openLinkTitle')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('safety.goingTo'), style: text.labelMedium),
              const SizedBox(height: 2),
              Text(
                uri.host,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (rest.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    rest,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                ),
              if (reasons.isNotEmpty) ...[
                const SizedBox(height: 12),
                WarningBox(messages: reasons),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(s.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: reasons.isNotEmpty
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  )
                : null,
            child: Text(reasons.isNotEmpty ? s.t('safety.openAnyway') : s.t('common.open')),
          ),
        ],
      );
    },
  );

  if (proceed != true || !context.mounted) return;
  await _launch(context, uri, s.t('safety.noApp'));
}

/// Last chance before a payment app opens: says who is being paid and how
/// much, and repeats that scanning a code is never how you receive money.
Future<void> confirmAndOpenPayment(
  BuildContext context,
  Uri uri,
  PaymentInfo info,
) async {
  final s = AppStrings.of(context);
  final who = info.payeeName ?? info.payeeId ?? s.t('safety.payWho');
  final amount = info.amountLabel;

  final proceed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(s.t('safety.payTitle')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              amount == null
                  ? s.t('safety.payNoAmount', {'who': who})
                  : s.t('safety.payAmount', {'who': who, 'amount': amount}),
              style: Theme.of(dialogContext).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            WarningBox(messages: [info.warning]),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(s.t('common.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(s.t('safety.iWantToPay')),
        ),
      ],
    ),
  );

  if (proceed != true || !context.mounted) return;
  await _launch(context, uri, s.t('safety.noPaymentApp'));
}
