import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final supabase = Supabase.instance.client;

    await supabase.auth.signOut();

    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
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
        // Fallback: Show a dialog with your email
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Send Feedback'),
            content: const Text('Please send your feedback to:\nocr9384@gmail.com'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
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

  @override
  Widget build(BuildContext context) {
    const cobaltBlue = Color(0xFF0047AB);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cobaltBlue,
        centerTitle: true,
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(
            child: Text(
              'Account Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cobaltBlue,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildOption(
            icon: Icons.person,
            label: 'Profile',
            onTap: () => Navigator.pushNamed(context, '/profile'),
          ),
          _buildOption(
            icon: Icons.lock_reset,
            label: 'Reset Password',
            onTap: () => Navigator.pushNamed(context, '/reset'),
          ),
          _buildOption(
            icon: Icons.feedback,
            label: 'Send Feedback',
            onTap: () => _sendFeedback(context),
          ),
          _buildOption(
            icon: Icons.logout,
            label: 'Logout',
            onTap: () => _logout(context),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF9F9F9),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF0047AB)),
        title: Text(label),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
