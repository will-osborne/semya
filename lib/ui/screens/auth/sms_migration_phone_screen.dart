import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:semya/config/router.dart';
import 'package:semya/l10n/app_localizations.dart';
import 'package:semya/providers/auth_provider.dart';

class SmsMigrationPhoneScreen extends ConsumerStatefulWidget {
  const SmsMigrationPhoneScreen({super.key});

  @override
  ConsumerState<SmsMigrationPhoneScreen> createState() =>
      _SmsMigrationPhoneScreenState();
}

class _SmsMigrationPhoneScreenState
    extends ConsumerState<SmsMigrationPhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;

    final rawNumber = _phoneController.text.trim();
    final phoneNumber = rawNumber.startsWith('+') ? rawNumber : '+$rawNumber';

    try {
      final verificationId = await ref
          .read(authProvider.notifier)
          .requestSmsCode(phoneNumber);

      if (!mounted) return;
      if (verificationId.isEmpty) {
        final needsLink = !ref.read(authProvider.notifier).hasPasswordProvider;
        context.go(needsLink ? AppRoutes.linkEmailPassword : AppRoutes.home);
        return;
      }

      context.push(AppRoutes.smsMigrationOtp, extra: verificationId);
    } catch (_) {
      // Provider state already contains and surfaces the error.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider);
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen<AuthState>(authProvider, (previous, next) {
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
      appBar: AppBar(title: Text(l10n.smsMigrationTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.smsMigrationDescription,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
                  ],
                  enabled: !authState.isLoading,
                  decoration: InputDecoration(
                    labelText: l10n.phoneNumberLabel,
                    hintText: l10n.phoneNumberHint,
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                  onFieldSubmitted: (_) => _sendCode(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.phoneNumberEmpty;
                    }
                    final stripped = value.replaceAll(RegExp(r'[\s\-()]'), '');
                    if (stripped.length < 8) {
                      return l10n.phoneNumberInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: authState.isLoading ? null : _sendCode,
                  child: authState.isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : Text(l10n.sendCode),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
