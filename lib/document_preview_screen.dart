import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

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

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  final supabase = Supabase.instance.client;
  String userName = 'Guest';
  bool isLoadingUser = true;

  static const Color cobaltBlue = Color(0xFF0047AB);

  @override
  void initState() {
    super.initState();
    _loadUserData();
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

  Future<String> _fetchExtractedText() async {
    try {
      final response = await http.get(Uri.parse(widget.textUrl));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final decoded = utf8.decode(bytes);

        // Try to decode JSON first
        try {
          final jsonData = json.decode(decoded);
          if (jsonData is Map && jsonData.containsKey('text')) {
            return jsonData['text'] ?? 'No text found in JSON.';
          } else {
            return 'Invalid JSON format.';
          }
        } catch (_) {
          // Fallback to plain text if not JSON
          return decoded.trim().isEmpty ? 'Text file is empty.' : decoded;
        }
      } else {
        throw Exception('Failed to fetch text. Status code: ${response.statusCode}');
      }
    } catch (e) {
      return 'Error loading text: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cobaltBlue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    // Back button
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),

                    // Title with username - expanded to fill available space
                    Expanded(
                      child: Center(
                        child: isLoadingUser
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                '$userName\'s Document',
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Empty space to balance the back button
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            /// Document image preview
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: cobaltBlue, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 1,
                  maxScale: 5,
                  child: Image.network(
                    widget.imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Center(child: Text('Failed to load image.')),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            /// Extracted text preview
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: cobaltBlue),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FutureBuilder<String>(
                  future: _fetchExtractedText(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: cobaltBlue));
                    }
                    if (snapshot.hasError) {
                      return SelectableText(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      );
                    }
                    return SingleChildScrollView(
                      child: SelectableText(
                        snapshot.data ?? 'No extracted text found.',
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
