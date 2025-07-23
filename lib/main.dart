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
import 'settings_screeimport 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Screens
import 'login_screen.dart';
import 'home_screen.dart';
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
import 'pdf_screen.dart';
import 'deep_link_handler.dart';
// Updated import: Use OCRScreen (with new UI/UX)
import 'new_scan_screen.dart';

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
        '/home': (context) => const MainScreenWrapper(child: HomeScreen()),
        '/signin': (context) => const SignInScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/reset': (context) => const ResetPasswordScreen(),
        // NOTE: Use the modern OCRScreen with new UI/UX, as built in your latest file
        '/scan': (context) =>
            const BottomNavBackHandler(child: MainScreenWrapper(child: OCRScreen())),
        '/help': (context) => const HelpScreen(),
        '/history': (context) => const MainScreenWrapper(child: HistoryScreen()),
        '/documents': (context) => const MainScreenWrapper(child: DocumentsScreen()),
        '/profile': (context) =>
            const BottomNavBackHandler(child: MainScreenWrapper(child: ProfileScreen())),
        '/settings': (context) => const MainScreenWrapper(child: SettingsScreen()),
        '/trash': (context) =>
            const BottomNavBackHandler(child: MainScreenWrapper(child: TrashScreen())),
        '/pdf': (context) => const MainScreenWrapper(child: PDFScreen()),
        '/edit': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return MainScreenWrapper(
            child: EditTextScreen(
              imagePath: args['imagePath'],
              ocrText: args['ocrText'],
            ),
          );
        },
      },
    );
  }
}

// ✅ Bottom Navigation Back Handler - For Scan, Trash, Profile screens
class BottomNavBackHandler extends StatelessWidget {
  final Widget child;
  const BottomNavBackHandler({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent default pop behavior
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // ✅ Always go back to home when back button is pressed
          Navigator.pushReplacementNamed(context, '/home');
        }
      },
      child: child,
    );
  }
}

// ✅ Bottom Navigation Wrapper - no bottom navigation bar.
class MainScreenWrapper extends StatefulWidget {
  final Widget child;
  const MainScreenWrapper({super.key, required this.child});
  @override
  State<MainScreenWrapper> createState() => _MainScreenWrapperState();
}

class _MainScreenWrapperState extends State<MainScreenWrapper> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      // bottomNavigationBar removed as per latest instruction
    );
  }
}

// --- Individual Screen Wrappers for custom pop logic (optional, keep/remove as needed) ---

class ScanScreenWrapper extends StatelessWidget {
  final Widget child;
  const ScanScreenWrapper({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      },
      child: MainScreenWrapper(child: child),
    );
  }
}

class TrashScreenWrapper extends StatelessWidget {
  final Widget child;
  const TrashScreenWrapper({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      },
      child: MainScreenWrapper(child: child),
    );
  }
}

class ProfileScreenWrapper extends StatelessWidget {
  final Widget child;
  const ProfileScreenWrapper({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      },
      child: MainScreenWrapper(child: child),
    );
  }
}
n.dart';
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
        '/home': (context) => const MainScreenWrapper(child: HomeScreen()),
        '/signin': (context) => const SignInScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/reset': (context) => const ResetPasswordScreen(),
        '/scan': (context) =>
            const BottomNavBackHandler(child: MainScreenWrapper(child: OCRScreen())),
        '/help': (context) => const HelpScreen(),
        '/history': (context) => const MainScreenWrapper(child: HistoryScreen()),
        '/documents': (context) => const MainScreenWrapper(child: DocumentsScreen()),
        '/profile': (context) =>
            const BottomNavBackHandler(child: MainScreenWrapper(child: ProfileScreen())),
        '/settings': (context) => const MainScreenWrapper(child: SettingsScreen()),
        '/trash': (context) =>
            const BottomNavBackHandler(child: MainScreenWrapper(child: TrashScreen())),
        '/pdf': (context) => const MainScreenWrapper(child: PDFScreen()),
        '/edit': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return MainScreenWrapper(
            child: EditTextScreen(
              imagePath: args['imagePath'],
              ocrText: args['ocrText'],
            ),
          );
        },
      },
    );
  }
}

// ✅ Bottom Navigation Back Handler - For Scan, Trash, Profile screens
class BottomNavBackHandler extends StatelessWidget {
  final Widget child;

  const BottomNavBackHandler({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent default pop behavior
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // ✅ Always go back to home when back button is pressed
          Navigator.pushReplacementNamed(context, '/home');
        }
      },
      child: child,
    );
  }
}

// ✅ Bottom Navigation Wrapper - ENHANCED with custom back logic
class MainScreenWrapper extends StatefulWidget {
  final Widget child;

  const MainScreenWrapper({super.key, required this.child});

  @override
  State<MainScreenWrapper> createState() => _MainScreenWrapperState();
}

class _MainScreenWrapperState extends State<MainScreenWrapper> {
  int _currentIndex = 0;
  static const Color cobaltBlue = Color(0xFF0047AB);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setCurrentIndex();
  }

  void _setCurrentIndex() {
    final routeName = ModalRoute.of(context)?.settings.name;
    switch (routeName) {
      case '/home':
        _currentIndex = 0;
        break;
      case '/scan':
        _currentIndex = 1;
        break;
      case '/trash':
        _currentIndex = 2;
        break;
      case '/profile':
        _currentIndex = 3;
        break;
      default:
        _currentIndex = 0;
    }
  }

  void _onBottomNavTapped(int index) {
    if (_currentIndex == index) return; // Don't navigate if already on the same screen

    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/scan');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/trash');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  Widget _buildBottomNavItem(IconData icon, String label, int index) {
    final bool isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onBottomNavTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? cobaltBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBottomNavItem(Icons.home, 'Home', 0),
              _buildBottomNavItem(Icons.camera_alt, 'Scan', 1),
              _buildBottomNavItem(Icons.delete, 'Trash', 2),
              _buildBottomNavItem(Icons.person, 'Profile', 3),
            ],
          ),
        ),
      ),
    );
  }
}

// ✅ ALTERNATIVE: Individual Screen Wrappers (if you want more control)
// You can also create individual wrappers for each screen if you need different logic

class ScanScreenWrapper extends StatelessWidget {
  final Widget child;

  const ScanScreenWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // ✅ Go back to home when back button is pressed from Scan screen
          Navigator.pushReplacementNamed(context, '/home');
        }
      },
      child: MainScreenWrapper(child: child),
    );
  }
}

class TrashScreenWrapper extends StatelessWidget {
  final Widget child;

  const TrashScreenWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // ✅ Go back to home when back button is pressed from Trash screen
          Navigator.pushReplacementNamed(context, '/home');
        }
      },
      child: MainScreenWrapper(child: child),
    );
  }
}

class ProfileScreenWrapper extends StatelessWidget {
  final Widget child;

  const ProfileScreenWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // ✅ Go back to home when back button is pressed from Profile screen
          Navigator.pushReplacementNamed(context, '/home');
        }
      },
      child: MainScreenWrapper(child: child),
    );
  }
}
