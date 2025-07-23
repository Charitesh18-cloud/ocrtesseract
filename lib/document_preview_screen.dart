import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class DocumentPreviewScreen extends StatefulWidget {
  final String imageUrl;
  final String textUrl;

  const DocumentPreviewScreen({
    super.key,
    required this.imageUrl,
    required this.textUrl,
  });

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  String userName = 'Guest';
  bool isLoadingUser = true;
  String? extractedText;
  bool isLoadingText = true;

  // Animation controllers
  late final List<AnimationController> _controllers;
  late final List<Animation<Offset>> _animations;

  static const Color cobaltBlue = Color(0xFF0047AB);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
    _loadExtractedText();
  }

  void _initializeAnimations() {
    _controllers = List.generate(
        3, // Image, text section, and action buttons
        (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 600)));
    _animations = _controllers
        .map((c) => Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeOut)))
        .toList();
    _startAnimations();
  }

  Future<void> _startAnimations() async {
    for (int i = 0; i < _controllers.length; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) _controllers[i].forward();
    }
  }

  Future<void> _loadUserData() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => isLoadingUser = false);
      return;
    }

    try {
      final profile = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();

      if (profile != null &&
          profile['name'] != null &&
          profile['name'].toString().trim().isNotEmpty) {
        userName = profile['name'];
      } else {
        userName = user.email ?? 'Guest';
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }

    setState(() {
      isLoadingUser = false;
    });
  }

  Future<void> _loadExtractedText() async {
    try {
      final response = await http.get(Uri.parse(widget.textUrl));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final decoded = utf8.decode(bytes);

        // Try to decode JSON first
        try {
          final jsonData = json.decode(decoded);
          if (jsonData is Map && jsonData.containsKey('text')) {
            extractedText = jsonData['text'] ?? 'No text found in JSON.';
          } else {
            extractedText = 'Invalid JSON format.';
          }
        } catch (_) {
          // Fallback to plain text if not JSON
          extractedText = decoded.trim().isEmpty ? 'Text file is empty.' : decoded;
        }
      } else {
        throw Exception('Failed to fetch text. Status code: ${response.statusCode}');
      }
    } catch (e) {
      extractedText = 'Error loading text: $e';
    }

    setState(() {
      isLoadingText = false;
    });
  }

  void _copyToClipboard() {
    if (extractedText != null && extractedText!.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: extractedText!));
      _showSnackBar('✅ Text copied to clipboard!', Colors.green);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
  }

  Widget _buildSection(String title, Widget child, int animationIndex) => SlideTransition(
        position: _animations[animationIndex],
        child: FadeTransition(
          opacity: _controllers[animationIndex],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cobaltBlue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(title,
                      style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      );

  @override
  void dispose() {
    _controllers.forEach((c) => c.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: cobaltBlue,
        elevation: 0,
        title: isLoadingUser
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text('$userName\'s Document',
                style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white)),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
        actions: [
          if (!isLoadingText && extractedText != null && extractedText!.isNotEmpty)
            IconButton(
              onPressed: _copyToClipboard,
              icon: const Icon(Icons.copy, color: Colors.white),
              tooltip: 'Copy text',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Document Image Section
            _buildSection(
              '📷 Document Image',
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        height: 300,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: cobaltBlue.withOpacity(0.2), width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Hero(
                            tag: 'document_image',
                            child: InteractiveViewer(
                              panEnabled: true,
                              minScale: 1,
                              maxScale: 5,
                              child: Image.network(
                                widget.imageUrl,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: cobaltBlue,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) => Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image, size: 60, color: Colors.grey),
                                      SizedBox(height: 8),
                                      Text('Failed to load image',
                                          style: TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Pinch to zoom • Drag to pan',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              0,
            ),

            const SizedBox(height: 32),

            // Extracted Text Section
            _buildSection(
              '📝 Extracted Text',
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Text content
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 200, maxHeight: 400),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cobaltBlue.withOpacity(0.1)),
                        ),
                        child: isLoadingText
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(color: cobaltBlue),
                                    SizedBox(height: 16),
                                    Text('Loading extracted text...',
                                        style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              )
                            : SingleChildScrollView(
                                child: SelectableText(
                                  extractedText ?? 'No extracted text found.',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.5,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                      ),

                      if (!isLoadingText && extractedText != null && extractedText!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        // Text stats
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cobaltBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: cobaltBlue),
                              const SizedBox(width: 8),
                              Text(
                                '${extractedText!.split(' ').length} words • ${extractedText!.length} characters',
                                style: TextStyle(
                                  color: cobaltBlue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              1,
            ),

            const SizedBox(height: 32),

            // Action Buttons Section
            _buildSection(
              '⚡ Actions',
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Copy Text Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cobaltBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        onPressed:
                            (!isLoadingText && extractedText != null && extractedText!.isNotEmpty)
                                ? _copyToClipboard
                                : null,
                        icon: const Icon(Icons.copy, size: 20),
                        label: const Text('Copy Text to Clipboard',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Back Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: cobaltBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: cobaltBlue, width: 2),
                          ),
                          elevation: 1,
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, size: 20),
                        label: const Text('Back to Documents',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
              2,
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
