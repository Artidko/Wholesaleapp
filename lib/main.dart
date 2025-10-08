import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // ต้องมีไฟล์นี้จาก `flutterfire configure`

// Supabase (เก็บรูป)
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/app_theme.dart';
// ถ้าจะใช้ Provider
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
    // ส่ง log ไปที่ service/analytics ของคุณได้ที่นี่
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    // ส่ง log ไปที่ service/analytics ของคุณได้ที่นี่
    return true; // ป้องกันแอป crash บน release
  };

  // ---------- Firebase ----------
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ---------- Supabase ----------
  // แนะนำให้ย้าย URL/KEY ไปที่ --dart-define สำหรับ production (ดูคอมเมนต์ด้านล่าง)
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
    // จับ error นอกเหนือจาก FlutterError.onError
    // ส่ง log ได้ที่นี่
  });
}

class WholesaleApp extends StatelessWidget {
  const WholesaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        // ถ้าจะให้ทั้งแอปเข้าถึง auth service:
        // Provider<AuthService>.value(value: AuthService.instance),
      ],
      child: MaterialApp(
        title: 'Wholesale App',
        debugShowCheckedModeBanner: false,
        theme:
            appTheme, // ใช้ธีมโปรเจ็กต์ของคุณ (Material 3 ควรถูกตั้งใน app_theme.dart)

        // หน้าเริ่มต้น
        initialRoute: '/choose-login',

        routes: {
          '/choose-login': (_) => const ChooseLoginPage(),

          // login / sign up / home
          '/login-user': (_) => const LoginUserPage(),
          '/login-admin': (_) => const LoginAdminPage(),
          '/signup': (_) => const SignUpPage(),
          '/home-user': (_) => const HomeUserPage(),
          '/home-admin': (_) => const AdminHomePage(),

          // aliases (รองรับ path เดิม)
          '/login/user': (_) => const LoginUserPage(),
          '/login/admin': (_) => const LoginAdminPage(),
          '/home/user': (_) => const HomeUserPage(),
          '/home/admin': (_) => const AdminHomePage(),
        },

        // กัน route แปลก → กลับ choose-login
        onUnknownRoute: (_) => MaterialPageRoute(
          builder: (_) => const ChooseLoginPage(),
          settings: const RouteSettings(name: '/choose-login'),
        ),
      ),
    );
  }
}
