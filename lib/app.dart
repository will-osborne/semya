import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:semya/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/router.dart';
import 'config/theme.dart';
import 'config/constants.dart';
import 'providers/conversation_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/notification_provider.dart';
import 'ui/screens/call/incoming_call_overlay.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Firestore listeners can silently go stale while backgrounded: bump the
    // resume tick so conversation/message streams resubscribe, and re-sync
    // the FCM token.
    ref.read(appResumedProvider.notifier).state++;
    unawaited(ref.read(notificationProvider.notifier).syncTokenIfPossible());
  }

  @override
  Widget build(BuildContext context) {
    // First-launch language selection is a route (see routerProvider), so the
    // app always lives under this single MaterialApp.router — switching
    // language never remounts the whole tree.
    final locale = ref.watch(localeProvider);

    ref.watch(conversationSyncProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      theme: MaterialTheme.light(),
      darkTheme: MaterialTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return IncomingCallOverlay(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
