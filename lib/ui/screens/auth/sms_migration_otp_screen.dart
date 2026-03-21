import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:semya/config/router.dart';
import 'package:semya/l10n/app_localizations.dart';
import 'package:semya/providers/auth_provider.dart';

class SmsMigrationOtpScreen extends ConsumerStatefulWidget {
  const SmsMigrationOtpScreen({super.key});

  @override
  ConsumerState<SmsMigrationOtpScreen> createState() =>
      _SmsMigrationOtpScreenState();
}

class _SmsMigrationOtpScreenState extends ConsumerState<SmsMigrationOtpScreen> {
  final _otpController = TextEditingController();
  String? _verificationId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra is String && extra.isNotEmpty) {
      _verificationId = extra;
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final code = _otpController.text.trim();
    if (code.length != 6) return;

    final verificationId = _verificationId;
    if (verificationId == null || verificationId.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.verificationExpired)),
      );
      return;
    }

    await ref.read(authProvider.notifier).signInWithSmsCode(
      verificationId: verificationId,
      smsCode: code,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider);
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated && !(previous?.isAuthenticated ?? false)) {
        final needsLink = !ref.read(authProvider.notifier).hasPasswordProvider;
        context.go(needsLink ? AppRoutes.linkEmailPassword : AppRoutes.home);
      }

      if (next.error != null && next.error != previous?.error) {
        _otpController.clear();
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
      appBar: AppBar(title: Text(l10n.verifyNumber)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.smsMigrationOtpDescription,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                enabled: !authState.isLoading,
                decoration: const InputDecoration(counterText: ''),
                onChanged: (value) {
                  if (value.length == 6) _verifyCode();
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: authState.isLoading ? null : _verifyCode,
                child: authState.isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : Text(l10n.verify),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
