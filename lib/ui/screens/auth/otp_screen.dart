import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:semya/config/router.dart';
import 'package:semya/l10n/app_localizations.dart';
import 'package:semya/providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();

  static const int _resendCooldown = 60; // seconds
  int _secondsRemaining = _resendCooldown;
  Timer? _countdownTimer;

  // The verificationId is passed via GoRouter's extra field.
  String? _verificationId;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read the verificationId from GoRouterState.extra.
    final extra = GoRouterState.of(context).extra;
    if (extra is String && extra.isNotEmpty) {
      _verificationId = extra;
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _secondsRemaining = _resendCooldown;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _verify() async {
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

    await ref
        .read(authProvider.notifier)
        .signInWithSmsCode(verificationId: verificationId, smsCode: code);
  }

  Future<void> _resendCode() async {
    if (_secondsRemaining > 0) return;

    // Re-trigger phone verification using the stored phone number.
    // We navigate back and let the user re-enter, which is the safest UX.
    if (context.mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authState = ref.watch(authProvider);
    final l10n = AppLocalizations.of(context)!;

    ref.listen<AuthState>(authProvider, (previous, next) {
      // Navigate home or to profile setup on successful auth.
      if (next.isAuthenticated && !(previous?.isAuthenticated ?? false)) {
        context.go(AppRoutes.home);
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.verifyNumber),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),

                // Icon
                Icon(Icons.sms_outlined, size: 64, color: colorScheme.primary),

                const SizedBox(height: 24),

                Text(
                  l10n.enterSixDigitCode,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),

                const SizedBox(height: 8),

                Text(
                  l10n.verificationCodeSent,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 40),

                // OTP input field – styled to look like a code entry box.
                TextFormField(
                  controller: _otpController,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  textInputAction: TextInputAction.done,
                  autofocus: true,
                  enabled: !authState.isLoading,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: theme.textTheme.headlineMedium?.copyWith(
                    letterSpacing: 16,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '——————',
                    hintStyle: theme.textTheme.headlineMedium?.copyWith(
                      letterSpacing: 16,
                      color: colorScheme.outlineVariant,
                      fontWeight: FontWeight.w300,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                  ),
                  onChanged: (value) {
                    if (value.length == 6) {
                      _verify();
                    }
                  },
                  onFieldSubmitted: (_) => _verify(),
                ),

                const SizedBox(height: 32),

                // Verify button
                FilledButton(
                  onPressed: authState.isLoading ? null : _verify,
                  child: authState.isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : Text(l10n.verify),
                ),

                const SizedBox(height: 24),

                // Resend button with countdown.
                Center(
                  child: _secondsRemaining > 0
                      ? Text(
                          l10n.resendCodeIn(_secondsRemaining),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        )
                      : TextButton(
                          onPressed: authState.isLoading ? null : _resendCode,
                          child: Text(l10n.resendCode),
                        ),
                ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
