import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_autofill_service/flutter_autofill_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keepassux/autofill/autofill_app.dart';
import 'package:keepassux/bloc/entries/keepass_bloc.dart';
import 'package:keepassux/ui/pages/start_page.dart';
import 'package:keepassux/services/auto_lock_controller.dart';
import 'package:keepassux/services/screenshot_protection_service.dart';
import 'package:keepassux/ui/theme/theme.dart';
import 'package:keepassux/ui/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zxcvbnm/messages.dart';
import 'package:zxcvbnm_flutter/zxcvbnm_flutter.dart';

@pragma('vm:entry-point')
Future<void> autofillEntryPoint() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  _configureAutofillPreferences();
  await themeController.load();
  runApp(
    EasyLocalization(
      supportedLocales: [Locale('en'), Locale('es')],
      path: 'assets/translations',
      fallbackLocale: Locale('en'),
      child: const AutofillApp(),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await initializeZxcvbnmMessages('es');
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('screenshot_protection_enabled') ?? true) {
    await ScreenshotProtectionService().enableProtection();
  }
  await _configureAutofillPreferences();
  await themeController.load();
  runApp(
    EasyLocalization(
      supportedLocales: [Locale('en'), Locale('es')],
      path: 'assets/translations',
      fallbackLocale: Locale('en'),
      child: const MyApp(),
    ),
  );
}

Future<void> _configureAutofillPreferences() async {
  try {
    await AutofillService().setPreferences(
      AutofillPreferences(
        enableDebug: kDebugMode,
        enableSaving: true,
        enableIMERequests: true,
      ),
    );
  } catch (e) {
    debugPrint('Could not set autofill preferences: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => KeePassBloc(),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeController,
        builder: (context, themeMode, _) {
          return MaterialApp(
            title: 'KeepassUX',
            localizationsDelegates: [
              ...context.localizationDelegates,
              ZxcvbnmLocalizations.delegate,
            ],
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            theme: lightThemeData,
            darkTheme: darkThemeData,
            themeMode: themeMode,
            builder: (context, child) => Listener(
              onPointerDown: (_) => autoLock.registerInteraction(),
              onPointerMove: (_) => autoLock.registerInteraction(),
              child: child ?? const SizedBox.shrink(),
            ),
            home: StartPage(),
          );
        },
      ),
    );
  }
}
