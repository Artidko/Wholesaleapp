// lib/main.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Supabase (เก็บสลิป)
import 'package:supabase_flutter/supabase_flutter.dart';

// Theme & Providers
import 'theme/app_theme.dart';
import 'providers/cart_provider.dart';

// Pages
import 'pages/login/login_user_page.dart';
import 'pages/login/login_admin_page.dart';
import 'pages/signup/signup_page.dart';
import 'pages/user/tabs/home_user_page.dart';
import 'pages/admin/home_admin_page.dart';
import 'pages/login/choose_login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ---------- Global error handling ----------
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // TODO: ส่ง log ไป analytics/service ของคุณ
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    // TODO: ส่ง log ไป analytics/service ของคุณ
    return true; // กันแอป crash บน release
  };

  // ---------- Firebase ----------
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ---------- Supabase ----------
  // แนะนำใช้ --dart-define บน production (ตัวอย่างอยู่ด้านล่าง)
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL',
      defaultValue: 'https://sajuhewvozglzwmjbhbf.supabase.co');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY',
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNhanVoZXd2b3pnbHp3bWpiaGJmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk1Nzk3ODEsImV4cCI6MjA3NTE1NTc4MX0.PyPoNQsRdAwGqskRwZLboO0DCyvEl8iBHwpIIozyFFM');

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runZonedGuarded(() {
    runApp(const WholesaleApp());
  }, (error, stack) {
    // TODO: log global uncaught errors
  });
}

class WholesaleApp extends StatelessWidget {
  const WholesaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MaterialApp(
        title: 'Wholesale App',
        debugShowCheckedModeBanner: false,
        theme: appTheme,
        initialRoute: '/choose-login',
        routes: {
          '/choose-login': (_) => const ChooseLoginPage(),

          '/login-user': (_) => const LoginUserPage(),
          '/login-admin': (_) => const LoginAdminPage(),
          '/signup': (_) => const SignUpPage(),
          '/home-user': (_) => const HomeUserPage(),
          '/home-admin': (_) => const AdminHomePage(),

          // aliases เดิม
          '/login/user': (_) => const LoginUserPage(),
          '/login/admin': (_) => const LoginAdminPage(),
          '/home/user': (_) => const HomeUserPage(),
          '/home/admin': (_) => const AdminHomePage(),
        },
        onUnknownRoute: (_) => MaterialPageRoute(
          builder: (_) => const ChooseLoginPage(),
          settings: const RouteSettings(name: '/choose-login'),
        ),
      ),
    );
  }
}
