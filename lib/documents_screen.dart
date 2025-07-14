import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'document_preview_screen.dart'; // Shared logic for preview

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> documents = [];
  bool isLoading = true;

  static const Color cobaltBlue = Color(0xFF0047AB);

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final response = await supabase
          .from('scans')
          .select()
          .eq('user_id', user.id)
          .eq('deleted', false)
          .order('created_at', ascending: false);

      setState(() {
        documents = response;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading documents: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _moveToTrash(Map doc) async {
    try {
      await supabase.from('scans').update({'deleted': true}).eq('id', doc['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Moved to Trash')),
      );

      await _loadDocuments();
    } catch (e) {
      debugPrint('Trash error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _openDocument(Map doc) {
    final imagePath = doc['document_url'].replaceFirst('documents/', '');
    final textPath = doc['extracted_file_url'].replaceFirst('extractedfiles/', '');

    final imageUrl = supabase.storage.from('documents').getPublicUrl(imagePath);
    final textUrl = supabase.storage.from('extractedfiles').getPublicUrl(textPath);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentPreviewScreen(
          imageUrl: imageUrl,
          textUrl: textUrl,
        ),
      ),
    );
  }

  Future<void> _confirmAndDelete(Map doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to Trash'),
        content: const Text('Are you sure you want to move this document to Trash?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Move', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _moveToTrash(doc);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final userName = user?.email ?? 'Guest';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FC),
      appBar: AppBar(
        backgroundColor: cobaltBlue,
        title: Text(
          '$userName\'s Documents',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : documents.isEmpty
                ? const Center(child: Text('No documents found.'))
                : ListView.builder(
                    itemCount: documents.length,
                    itemBuilder: (context, index) {
                      final doc = documents[index];
                      final createdAt = DateTime.parse(doc['created_at']);
                      final formattedDate =
                          '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => _openDocument(doc),
                              child: Image.network(
                                supabase.storage.from('documents').getPublicUrl(
                                  doc['document_url'].replaceFirst('documents/', ''),
                                ),
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _openDocument(doc),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      doc['description'] ?? 'Untitled',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formattedDate,
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmAndDelete(doc),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
