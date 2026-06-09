import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reliefnet/main-pages/apply_volunteer_page.dart';
import 'package:reliefnet/main-pages/dashboard_page.dart';
import 'package:reliefnet/main-pages/home_page.dart';
import 'package:reliefnet/main-pages/report_page.dart';
import 'package:reliefnet/main-pages/volunteer_page.dart';
import 'package:reliefnet/login-signup/login_page.dart';
import 'package:reliefnet/themes/theme_light.dart';
import 'package:reliefnet/themes/theme_dark.dart';
import 'package:reliefnet/themes/theme_provider.dart';
import 'package:reliefnet/themes/locale_provider.dart';
import 'package:reliefnet/l10n/app_localizations.dart';
import 'package:reliefnet/widgets/mahi_ai_assistant.dart';

Future<void> main() async {
  // Ensure native bindings are ready
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize App Check
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.deviceCheck,
  );

  // Create the provider instances
  final themeProvider = ThemeProvider();
  final localeProvider = LocaleProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => themeProvider),
        ChangeNotifierProvider(create: (_) => localeProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to the providers
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: localeProvider.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      /// THEMES
      theme: lightmode,
      darkTheme: darkmode,
      // Always use the themeMode from the provider
      themeMode: themeProvider.themeMode,

      /// ROUTES
      routes: {
        '/home': (context) => const Homepage(),
        '/report': (context) => const ReportPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/volunteer': (context) => const VolunteerPage(),
        '/apply_volunteer': (context) => const ApplyVolunteerPage(),
      },

      /// AUTH HANDLER
      home: const AuthWrapper(),
      builder: (context, child) {
        return Stack(
          children: [
            ?child,
            const _MahiAssistantWrapper(),
          ],
        );
      },
    );
  }
}

class _MahiAssistantWrapper extends StatefulWidget {
  const _MahiAssistantWrapper();

  @override
  State<_MahiAssistantWrapper> createState() => _MahiAssistantWrapperState();
}

class _MahiAssistantWrapperState extends State<_MahiAssistantWrapper> {
  late Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = FirebaseAuth.instance.authStateChanges();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return const MahiAiAssistant();
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading State
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    "Checking authentication...",
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }

        // Logged In
        if (snapshot.hasData) {
          return const Homepage();
        }

        // Logged Out
        return const LoginPage();
      },
    );
  }
}
