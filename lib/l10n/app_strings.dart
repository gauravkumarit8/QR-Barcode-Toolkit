import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';
import 'translations.dart';

/// Gives widgets translated text: `AppStrings.of(context).t('settings.title')`.
///
/// The language comes from the app's locale (the phone's language, or the
/// choice in Settings > Language). See [Translations] for the fallback rules.
class AppStrings {
  final String languageCode;

  const AppStrings(this.languageCode);

  /// English is first, so a phone in an unsupported language gets English.
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('es'),
    Locale('pt'),
    Locale('fr'),
    Locale('de'),
    Locale('id'),
    Locale('hi'),
  ];

  static const LocalizationsDelegate<AppStrings> delegate = _AppStringsDelegate();

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ?? const AppStrings('en');

  String t(String key, [Map<String, Object?> args = const {}]) =>
      Translations.lookup(languageCode, key, args);
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      Translations.languageCodes.contains(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) => SynchronousFuture<AppStrings>(
        AppStrings(Translations.resolve(locale.languageCode)),
      );

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
