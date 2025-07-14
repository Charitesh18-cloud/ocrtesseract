import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isRecoveryMode = false;

  @override
  void initState() {
    super.initState();

    final currentUser = Supabase.instance.client.auth.currentUser;
    final accessToken = Supabase.instance.client.auth.currentSession?.accessToken;

    if (currentUser != null && accessToken != null) {
      final isRecovery = Supabase.instance.client.auth.currentSession?.user?.appMetadata['provider'] == 'email';
      setState(() {
        _isRecoveryMode = true;
        _emailController.text = currentUser.email ?? '';
      });
    }
  }

  Future<void> _sendResetEmail() async {
    setState(() => _isLoading = true);
    final email = _emailController.text.trim();

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Password reset email sent. Check your inbox.')),
      );

      // Switch to recovery UI instead of navigating away
      setState(() {
        _isRecoveryMode = true;
        _emailController.text = email;
      });
    } on AuthException catch (e) {
      _showError('Reset failed: ${e.message}');
    } catch (_) {
      _showError('Unexpected error during reset.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePassword() async {
    setState(() => _isLoading = true);
    final newPassword = _newPasswordController.text.trim();

    if (newPassword.length < 6) {
      _showError('Password must be at least 6 characters long.');
      setState(() => _isLoading = false);
      return;
    }

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Password updated! Please log in again.')),
      );

      await Supabase.instance.client.auth.signOut();

      Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false); // Login screen
    } on AuthException catch (e) {
      _showError('Update failed: ${e.message}');
    } catch (_) {
      _showError('Unexpected error updating password.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text(
          _isRecoveryMode ? 'Set New Password' : 'Reset Password',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0047AB),
        centerTitle: true,
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(), // dismiss keyboard on tap outside
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_isRecoveryMode) ...[
                    // Instruction Text added here
                    const Text(
                      "Enter your email account here, check your email and click the configure link which redirects to the app, enter your new password, continue your login/sign-in process.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildTextField(_emailController, 'Email', false),
                    const SizedBox(height: 32),
                    _buildButton('Send Reset Email', _sendResetEmail),
                  ] else ...[
                    Text(
                      '🔐 Resetting password for ${_emailController.text}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(_newPasswordController, 'New Password', true),
                    const SizedBox(height: 32),
                    _buildButton('Update Password', _updatePassword),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, bool obscure) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        keyboardType: obscure ? TextInputType.visiblePassword : TextInputType.emailAddress,
      ),
    );
  }

  Widget _buildButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0047AB),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: _isLoading ? null : onPressed,
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : Text(label, style: const TextStyle(fontSize: 16, color: Colors.white)),
    );
  }
}