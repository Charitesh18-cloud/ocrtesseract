import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DocumentPreviewScreen extends StatelessWidget {
  final String imageUrl;
  final String textUrl;

  static const Color cobaltBlue = Color(0xFF0047AB);

  const DocumentPreviewScreen({
    super.key,
    required this.imageUrl,
    required this.textUrl,
  });

  Future<String> _fetchExtractedText() async {
    try {
      final response = await http.get(Uri.parse(textUrl));

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
      backgroundColor: const Color(0xFFF8F5FC),
      appBar: AppBar(
        backgroundColor: cobaltBlue,
        title: const Text(
          'Document Preview',
          style: TextStyle(
            color: Colors.white, // White text here
            fontWeight: FontWeight.w600,
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
                    imageUrl,
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
                      return const Center(child: CircularProgressIndicator());
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
