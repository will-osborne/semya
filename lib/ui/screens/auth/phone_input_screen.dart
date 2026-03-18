import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _phoneController = TextEditingController();
  bool _hasNavigated = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;

    final rawNumber = _phoneController.text.trim();
    // Ensure E.164 format: strip leading 0s if user forgot, prefix +
    final phoneNumber = rawNumber.startsWith('+') ? rawNumber : '+$rawNumber';

    await ref.read(authProvider.notifier).verifyPhone(phoneNumber);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final authState = ref.watch(authProvider);

    // Navigate to OTP screen when code has been sent.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.codeSent && !_hasNavigated && next.verificationId != null) {
        _hasNavigated = true;
        context.push(AppRoutes.otp, extra: next.verificationId);
        // Reset flag after a short delay so the user can request a resend.
        Future<void>.delayed(const Duration(seconds: 1), () {
          if (mounted) _hasNavigated = false;
        });
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
                    l10n.enterPhoneNumber,
                    style: theme.textTheme.titleMedium,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    l10n.phoneVerificationDescription,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Phone number field
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9+\-\s()]'),
                      ),
                    ],
                    autofocus: true,
                    enabled: !authState.isLoading,
                    decoration: InputDecoration(
                      labelText: l10n.phoneNumberLabel,
                      hintText: l10n.phoneNumberHint,
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(
                          Icons.phone_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                    ),
                    onFieldSubmitted: (_) => _sendCode(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.phoneNumberEmpty;
                      }
                      final stripped = value.replaceAll(
                        RegExp(r'[\s\-()]'),
                        '',
                      );
                      if (stripped.length < 8) {
                        return l10n.phoneNumberInvalid;
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Send Code button
                  FilledButton(
                    onPressed: authState.isLoading ? null : _sendCode,
                    child: authState.isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : Text(l10n.sendCode),
                  ),

                  const SizedBox(height: 24),

                  // Disclaimer
                  Text(
                    l10n.standardRatesDisclaimer,
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
