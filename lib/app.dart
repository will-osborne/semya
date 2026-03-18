import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:semya/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/router.dart';
import 'config/theme.dart';
import 'config/constants.dart';
import 'providers/conversation_provider.dart';
import 'providers/locale_provider.dart';
import 'ui/screens/call/incoming_call_overlay.dart';
import 'ui/screens/language/language_selection_screen.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final hasChosen = ref.watch(hasChosenLocaleProvider);

    // Show language selection before anything else on first launch.
    if (!hasChosen) {
      return MaterialApp(
        title: AppConstants.appName,
        theme: MaterialTheme.light(),
        darkTheme: MaterialTheme.dark(),
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const LanguageSelectionScreen(),
      );
    }

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
