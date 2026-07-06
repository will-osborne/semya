import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:semya/config/router.dart';
import 'package:semya/l10n/app_localizations.dart';
import 'package:semya/providers/auth_provider.dart';
import 'package:semya/providers/locale_provider.dart';
import 'package:semya/providers/notification_provider.dart';
import 'package:semya/providers/user_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authState = ref.watch(authProvider);
    final firebaseUser = authState.user;
    final userState = ref.watch(userProvider);
    final l10n = AppLocalizations.of(context)!;

    final contactIdentifier =
        firebaseUser?.phoneNumber ?? firebaseUser?.email ?? '—';
    final displayName =
        userState.appUser?.displayName ??
        firebaseUser?.displayName ??
        l10n.unknown;
    final initials = displayName.isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : '?';

    final currentLocale = ref.watch(localeProvider);
    final languageLabel = currentLocale?.languageCode == 'ru'
        ? 'Русский'
        : 'English';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          // User profile header card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        initials,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayName, style: theme.textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(
                            contactIdentifier,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: l10n.editProfile,
                      onPressed: () {
                        context.push(AppRoutes.profileSetup);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Section header
          _SectionHeader(label: l10n.account),

          _SettingsTile(
            icon: Icons.person_outline,
            title: l10n.profile,
            subtitle: l10n.displayNamePhoto,
            onTap: () => context.push(AppRoutes.profileSetup),
          ),

          // Section header
          _SectionHeader(label: l10n.preferences),

          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: l10n.notifications,
            subtitle: l10n.alertsSoundsBadges,
            onTap: () {
              // Notification settings – wired later.
            },
          ),

          _SettingsTile(
            icon: Icons.lock_outline,
            title: l10n.privacy,
            subtitle: l10n.privacySubtitle,
            onTap: () {
              // Privacy settings – wired later.
            },
          ),

          _SettingsTile(
            icon: Icons.language,
            title: l10n.language,
            subtitle: languageLabel,
            onTap: () => _showLanguagePicker(context, ref),
          ),

          // Section header
          _SectionHeader(label: 'Developer'),

          _SettingsTile(
            icon: Icons.bug_report_outlined,
            title: 'Call Debug Logs',
            subtitle: 'ICE candidates, TURN, connection state',
            onTap: () => context.push(AppRoutes.callDebug),
          ),

          const SizedBox(height: 24),

          // Sign out
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
                side: BorderSide(color: colorScheme.error),
              ),
              icon: const Icon(Icons.logout),
              label: Text(l10n.signOut),
              onPressed: authState.isLoading
                  ? null
                  : () => _confirmSignOut(context, ref),
            ),
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.read(localeProvider);

    showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.language),
        children: [
          ListTile(
            title: const Text('English'),
            leading: Radio<String>(
              value: 'en',
              groupValue: currentLocale?.languageCode ?? 'en',
              onChanged: (_) {},
            ),
            onTap: () {
              ref.read(localeProvider.notifier).setLocale(const Locale('en'));
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            title: const Text('Русский'),
            leading: Radio<String>(
              value: 'ru',
              groupValue: currentLocale?.languageCode ?? 'en',
              onChanged: (_) {},
            ),
            onTap: () {
              ref.read(localeProvider.notifier).setLocale(const Locale('ru'));
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.signOutConfirmTitle),
        content: Text(l10n.signOutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(notificationProvider.notifier).removeToken();
      await ref.read(authProvider.notifier).signOut();
      if (context.mounted) {
        context.go(AppRoutes.login);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: colorScheme.onSurfaceVariant, size: 20),
      ),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
