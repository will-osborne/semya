import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:semya/l10n/app_localizations.dart';

import 'package:semya/providers/locale_provider.dart';

class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen> {
  Locale _selected = _defaultLocale();

  static Locale _defaultLocale() {
    final systemLang = PlatformDispatcher.instance.locale.languageCode;
    return Locale(systemLang == 'ru' ? 'ru' : 'en');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Use a fallback since localization may not be fully resolved yet.
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),

                // App icon
                Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    'С',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Семья',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 48),

                Text(
                  l10n?.languageSelectionTitle ?? 'Choose your language',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),

                const SizedBox(height: 24),

                _LanguageOption(
                  label: 'English',
                  locale: const Locale('en'),
                  isSelected: _selected.languageCode == 'en',
                  onTap: () => setState(() => _selected = const Locale('en')),
                ),

                const SizedBox(height: 12),

                _LanguageOption(
                  label: 'Русский',
                  locale: const Locale('ru'),
                  isSelected: _selected.languageCode == 'ru',
                  onTap: () => setState(() => _selected = const Locale('ru')),
                ),

                const SizedBox(height: 16),

                Text(
                  l10n?.languageSelectionSubtitle ??
                      'You can change this later in Settings.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 32),

                FilledButton(
                  onPressed: () {
                    ref.read(localeProvider.notifier).setLocale(_selected);
                  },
                  child: Text(
                    l10n?.continueButton ?? 'Continue',
                  ),
                ),

                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.locale,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final Locale locale;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
