import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Screens
import 'login_screen.dart';
import 'home_screen.dart';
import 'new_scan_screen.dart'; // OCR screen
import 'help_screen.dart';
import 'signin_screen.dart';
import 'signup_screen.dart';
import 'reset_password_screen.dart';
import 'history_screen.dart';
import 'documents_screen.dart';
import 'edit_text_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'trash_screen.dart';
import 'pdf_screen.dart'; // ✅ ADD THIS - Import your PDF screen

// ✅ Deep Link Handler
import 'deep_link_handler.dart';

// ✅ Supabase config
const supabaseUrl = 'https://ymsnnnhdxkgeamqbfiqs.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inltc25ubmhkeGtnZWFtcWJmaXFzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxNjQwOTEsImV4cCI6MjA2Nzc0MDA5MX0.u8WyiUsz_Nr_nitQkItFt7EG5_Fk4RY6O2EjKtUQWUc';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const TesseractOCRApp());
}

class TesseractOCRApp extends StatefulWidget {
  const TesseractOCRApp({super.key});

  @override
  State<TesseractOCRApp> createState() => _TesseractOCRAppState();
}

class _TesseractOCRAppState extends State<TesseractOCRApp> {
  late final StreamSubscription<AuthState> _authSub;
  bool _isAuthenticated = Supabase.instance.client.auth.currentSession != null;

  @override
  void initState() {
    super.initState();

    // ✅ Init deep links AFTER widget has mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkHandler.initialize(context);
    });

    final supabase = Supabase.instance.client;

    // ✅ Listen for auth changes
    _authSub = supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        debugPrint('✅ Auth state: signed in');
        if (mounted) {
          setState(() => _isAuthenticated = true);
          Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
        }
      } else if (event == AuthChangeEvent.signedOut) {
        debugPrint('🔓 Auth state: signed out');
        if (mounted) {
          setState(() => _isAuthenticated = false);
          Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
        }
      }
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    DeepLinkHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SuryOCR Flutter',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        fontFamily: 'Poppins',
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: _isAuthenticated ? '/home' : '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/signin': (context) => const SignInScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/reset': (context) => const ResetPasswordScreen(),
        '/scan': (context) => const OCRScreen(),
        '/help': (context) => const HelpScreen(),
        '/history': (context) => const HistoryScreen(),
        '/documents': (context) => const DocumentsScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/trash': (context) => const TrashScreen(),
        // ✅ ADD THIS - PDF Screen route
        '/pdf': (context) => const PDFScreen(),
        '/edit': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return EditTextScreen(
            imagePath: args['imagePath'],
            ocrText: args['ocrText'],
          );
        },
      },
    );
  }
}
