import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../locale_provider.dart';
import '../localization/localization_extensions.dart';

class LanguagePickerButton extends StatelessWidget {
  const LanguagePickerButton({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = localeProvider.locale;

    return PopupMenuButton<Locale?>(
      icon: const Icon(Icons.language),
      tooltip: l10n.languagePickerLabel,
      onSelected: (selected) {
        unawaited(localeProvider.setLocale(selected));
      },
      itemBuilder: (context) {
        final entries = <PopupMenuEntry<Locale?>>[
          PopupMenuItem<Locale?>(
            value: null,
            child: Row(
              children: [
                if (currentLocale == null)
                  const Icon(Icons.check, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.languagePickerSystem)),
              ],
            ),
          ),
        ];

        for (final locale in AppLocalizations.supportedLocales) {
          final isSelected = currentLocale != null &&
              locale.languageCode == currentLocale.languageCode &&
              (locale.countryCode?.isEmpty ?? true ||
                  locale.countryCode == currentLocale.countryCode);
          entries.add(
            PopupMenuItem<Locale?>(
              value: locale,
              child: Row(
                children: [
                  if (isSelected)
                    const Icon(Icons.check, size: 18)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.describeLocale(locale))),
                ],
              ),
            ),
          );
        }
        return entries;
      },
    );
  }
}
