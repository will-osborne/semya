import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:semya/config/constants.dart';
import 'package:semya/config/router.dart';
import 'package:semya/l10n/app_localizations.dart';
import 'package:semya/providers/auth_provider.dart';

class PhoneInputScreen extends ConsumerStatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  ConsumerState<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends ConsumerState<PhoneInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isCreateAccountMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_isCreateAccountMode) {
      await ref
          .read(authProvider.notifier)
          .createAccountWithEmailPassword(email: email, password: password);
      return;
    }

    await ref
        .read(authProvider.notifier)
        .signInWithEmailPassword(email: email, password: password);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated && !(previous?.isAuthenticated ?? false)) {
        context.go(AppRoutes.home);
      }

      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(authProvider.notifier).clearError();
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

                  // App logo / icon
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

                  // App name
                  Text(
                    AppConstants.appName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    l10n.encryptedFamilyMessaging,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 48),

                  Text(
                    l10n.enterEmailAndPassword,
                    style: theme.textTheme.titleMedium,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    l10n.emailAuthDescription,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    autofocus: true,
                    enabled: !authState.isLoading,
                    decoration: InputDecoration(
                      labelText: l10n.emailLabel,
                      hintText: l10n.emailHint,
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(
                          Icons.email_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                    ),
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.emailEmpty;
                      }
                      final emailPattern = RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      );
                      if (!emailPattern.hasMatch(value.trim())) {
                        return l10n.emailInvalid;
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: _isCreateAccountMode
                        ? TextInputAction.next
                        : TextInputAction.done,
                    enabled: !authState.isLoading,
                    decoration: InputDecoration(
                      labelText: l10n.passwordLabel,
                      hintText: l10n.passwordHint,
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.passwordEmpty;
                      }
                      if (value.length < 6) {
                        return l10n.passwordTooShort;
                      }
                      return null;
                    },
                  ),

                  if (_isCreateAccountMode) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      enabled: !authState.isLoading,
                      decoration: InputDecoration(
                        labelText: l10n.confirmPasswordLabel,
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                      ),
                      onFieldSubmitted: (_) => _submit(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.confirmPasswordEmpty;
                        }
                        if (value != _passwordController.text) {
                          return l10n.passwordsDoNotMatch;
                        }
                        return null;
                      },
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Sign-in/create-account button
                  FilledButton(
                    onPressed: authState.isLoading ? null : _submit,
                    child: authState.isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : Text(
                            _isCreateAccountMode
                                ? l10n.createAccount
                                : l10n.signIn,
                          ),
                  ),

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: authState.isLoading
                        ? null
                        : () {
                            setState(() {
                              _isCreateAccountMode = !_isCreateAccountMode;
                              _confirmPasswordController.clear();
                            });
                          },
                    child: Text(
                      _isCreateAccountMode
                          ? l10n.alreadyHaveAccountSignIn
                          : l10n.noAccountCreateOne,
                    ),
                  ),

                  TextButton(
                    onPressed: authState.isLoading
                        ? null
                        : () => context.push(AppRoutes.smsMigrationPhone),
                    child: Text(l10n.smsMigrationEntryAction),
                  ),

                  const SizedBox(height: 8),

                  // Disclaimer
                  Text(
                    l10n.noEmailVerificationRequired,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
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
