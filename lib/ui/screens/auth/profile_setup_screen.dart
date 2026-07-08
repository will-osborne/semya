import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:semya/config/router.dart';
import 'package:semya/l10n/app_localizations.dart';
import 'package:semya/providers/auth_provider.dart';
import 'package:semya/providers/user_provider.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final userState = ref.read(userProvider);
    final displayName = _nameController.text.trim();

    try {
      if (userState.appUser != null) {
        await ref
            .read(userProvider.notifier)
            .updateProfile(displayName: displayName);
      } else {
        await ref.read(userProvider.notifier).createProfile(displayName);
      }

      final error = ref.read(userProvider).error;
      if (error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
          );
        }
      } else if (mounted) {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // If user signs out during setup, the router redirect handles navigation.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (!next.isAuthenticated) {
        context.go(AppRoutes.login);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),

                  // Avatar placeholder
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 52,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Icon(
                            Icons.person_outline,
                            size: 52,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.camera_alt_outlined,
                              color: colorScheme.onPrimary,
                              size: 18,
                            ),
                            onPressed: () {
                              // Photo picker will be wired later.
                            },
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  Text(
                    l10n.setupProfile,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    l10n.chooseDisplayName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Display name field
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    autofocus: true,
                    enabled: !_isSaving,
                    maxLength: 32,
                    decoration: InputDecoration(
                      labelText: l10n.displayNameLabel,
                      hintText: l10n.displayNameHint,
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                    onFieldSubmitted: (_) => _saveProfile(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.displayNameEmpty;
                      }
                      if (value.trim().length < 2) {
                        return l10n.displayNameTooShort;
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 8),

                  Text(l10n.changeInSettings, style: theme.textTheme.bodySmall),

                  const SizedBox(height: 32),

                  // Get Started button
                  FilledButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    child: _isSaving
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : Text(l10n.getStarted),
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
