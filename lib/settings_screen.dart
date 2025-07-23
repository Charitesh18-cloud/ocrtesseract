// settings_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with TickerProviderStateMixin {
  static const Color cobaltBlue = Color(0xFF0047AB);

  late final List<AnimationController> _controllers;
  late final List<Animation<Offset>> _animations;
  bool _animationsInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    // 5 options now: Profile, Reset Password, Send Feedback, Help, Logout
    _controllers = List.generate(
      5,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );
    _animations = _controllers
        .map(
          (c) => Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeOut)),
        )
        .toList();
    setState(() {
      _animationsInitialized = true;
    });
  }

  Future<void> _startAnimations() async {
    for (int i = 0; i < _controllers.length; i++) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (mounted) _controllers[i].forward();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Logout Confirmation', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Do you really want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes',
                  style: TextStyle(color: cobaltBlue, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true) {
      final supabase = Supabase.instance.client;
      try {
        await supabase.auth.signOut();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } catch (e) {
        debugPrint('Logout failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Logout failed, please try again'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _sendFeedback(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'ocr9384@gmail.com',
      query:
          'subject=App Feedback&body=Hi,%0A%0AI would like to share the following feedback:%0A%0A',
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Send Feedback'),
            content: const Text('Please send your feedback to:\nocr9384@gmail.com'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error launching email: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open email app'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Animation<Offset> animation,
  }) {
    return SlideTransition(
      position: animation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          leading: Icon(icon, color: cobaltBlue),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w400)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: cobaltBlue,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        toolbarHeight: 80,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 24, color: Colors.white),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: cobaltBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Account Settings',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildOption(
                      icon: Icons.person,
                      label: 'Profile',
                      onTap: () => Navigator.pushNamed(context, '/profile'),
                      animation: _animations[0],
                    ),
                    _buildOption(
                      icon: Icons.lock_reset,
                      label: 'Reset Password',
                      onTap: () => Navigator.pushNamed(context, '/reset'),
                      animation: _animations[1],
                    ),
                    _buildOption(
                      icon: Icons.feedback,
                      label: 'Send Feedback',
                      onTap: () => _sendFeedback(context),
                      animation: _animations[2],
                    ),
                    _buildOption(
                      icon: Icons.help_outline,
                      label: 'Help & FAQs',
                      onTap: () => Navigator.pushNamed(context, '/help'),
                      animation: _animations[3],
                    ),
                    _buildOption(
                      icon: Icons.logout,
                      label: 'Logout',
                      onTap: () => _logout(context),
                      animation: _animations.length > 4 ? _animations[4] : _animations.last,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
