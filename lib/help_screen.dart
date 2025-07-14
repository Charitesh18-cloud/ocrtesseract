import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const Color cobaltBlue = Color(0xFF0047AB);
  static const Color lightCobaltBlue = Color(0xFFE8F0FF); // lightest shade

  Widget _buildHelpBox(String title, String content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightCobaltBlue,
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
              color: cobaltBlue,
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
      backgroundColor: Colors.white, // screen background pure white
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cobaltBlue,
        centerTitle: true,
        title: const Text(
          'Help & FAQs',
          style: TextStyle(
            color: Colors.white, // white title text
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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
    );
  }
}
