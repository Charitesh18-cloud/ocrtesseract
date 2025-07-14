import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';

class DeepLinkHandler {
  static final _supabase = Supabase.instance.client;
  static StreamSubscription<AuthState>? _authSub;
  static StreamSubscription<Uri?>? _linkSub;
  static final AppLinks _appLinks = AppLinks();

  static bool _alreadyHandledInitial = false;
  static bool _alreadyHandledLive = false;

  static void initialize(BuildContext context) {
    // ✅ Listen for Supabase auth state changes
    _authSub = _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.passwordRecovery) {
        debugPrint('🔁 Password recovery mode detected');
        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/reset', (_) => false);
        }
      } else if (event == AuthChangeEvent.signedIn && session != null) {
        debugPrint('✅ Signed in via deep link');
        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
        }
      }
    });

    // ✅ Handle initial deep link when app is launched
    _appLinks.getInitialAppLink().then((uri) async {
      if (uri != null && !_alreadyHandledInitial) {
        debugPrint('🔗 Initial deep link: $uri');
        _alreadyHandledInitial = true;

        try {
          await Future.delayed(const Duration(milliseconds: 500));
          await _supabase.auth.getSessionFromUrl(uri);
        } catch (e) {
          debugPrint('❌ Error getting session from URL: $e');
        }
      }
    }).catchError((e) {
      debugPrint('❌ Error getting initial deep link: $e');
    });

    // ✅ Handle deep links while app is running
    _linkSub = _appLinks.uriLinkStream.listen(
      (uri) async {
        if (uri != null && !_alreadyHandledLive) {
          debugPrint('🔗 Live deep link: $uri');
          _alreadyHandledLive = true;

          try {
            await Future.delayed(const Duration(milliseconds: 500));
            await _supabase.auth.getSessionFromUrl(uri);
          } catch (e) {
            debugPrint('❌ Error getting session from URL (live): $e');
          }
        }
      },
      onError: (err) {
        debugPrint('❌ Error in link stream: $err');
      },
    );
  }

  static void dispose() {
    _authSub?.cancel();
    _linkSub?.cancel();
    _authSub = null;
    _linkSub = null;
    _alreadyHandledInitial = false;
    _alreadyHandledLive = false;
  }
}
