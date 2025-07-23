// help_screen.dart
import 'package:flutter/material.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  static const Color cobaltBlue = Color(0xFF0047AB);
  static const Color lightCobaltBlue = Color(0xFFE8F0FF); // lightest shade

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnimation = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildHelpBox(String title, String content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HelpScreen.lightCobaltBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: HelpScreen.cobaltBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 15, height: 1.5),
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: HelpScreen.cobaltBlue,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        toolbarHeight: 80,
        title: const Text(
          'Help & FAQs',
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
      body: SlideTransition(
        position: _slideAnimation,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: HelpScreen.cobaltBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'Help & Support',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildHelpBox(
                          '1. Signup & Login Process',
                          '• On the Signup screen, enter your email and create a strong password.\n'
                              '• After clicking Signup, you will receive a configuration email.\n'
                              '• Click the link in the email to verify and activate your account.\n'
                              '• Then, on the Login screen, enter the same email and password to sign in.\n'
                              '• Password is required to keep your account secure and for authentication.',
                        ),
                        _buildHelpBox(
                          '2. Reset Password Process',
                          '• If you forget your password, go to the Reset Password screen.\n'
                              '• Enter your registered email to receive a reset configuration link.\n'
                              '• Click the link, which will redirect you back to the app.\n'
                              '• Enter a new password and then use it to login with your email on the Login screen.',
                        ),
                        _buildHelpBox(
                          '3. Document Scanning Guidelines',
                          '• Use clear, well-lit images of your Telugu documents.\n'
                              '• Documents must be properly scanned or cropped to show the full text.\n'
                              '• Avoid blurred or partially visible texts for better OCR accuracy.\n'
                              '• Tap "Pick Image & Run OCR" to select your document image and extract text.',
                        ),
                        _buildHelpBox(
                          '4. Using the App',
                          '• You can use the app as a Guest without signup.\n'
                              '• Upload documents to extract Telugu text using Tesseract OCR.\n'
                              '• Edit extracted text, save documents, and export or share your results.\n'
                              '• View your document history and manage deleted files in Trash.',
                        ),
                        _buildHelpBox(
                          '5. Contact & Support',
                          '• For any issues or feedback, please contact support via email.\n'
                              '• We continuously update the app with new features and improved OCR.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
