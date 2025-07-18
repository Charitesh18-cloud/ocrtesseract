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
  String userName = 'Guest'; // Add userName variable

  static const Color cobaltBlue = Color(0xFF0047AB);

  @override
  void initState() {
    super.initState();
    _loadUserDataAndDocuments(); // Load both user data and documents
  }

  // Updated method to load both user data and documents
  Future<void> _loadUserDataAndDocuments() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      // Load user profile data
      final profile = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();

      if (profile != null &&
          profile['name'] != null &&
          profile['name'].toString().trim().isNotEmpty) {
        userName = profile['name'];
      } else {
        userName = user.email ?? 'Guest';
      }

      // Load documents
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
      debugPrint('Error loading data: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _moveToTrash(Map doc) async {
    try {
      await supabase.from('scans').update({'deleted': true}).eq('id', doc['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Moved to Trash')),
      );

      await _loadUserDataAndDocuments(); // Refresh data
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
                        child: Text(
                          '$userName\'s Documents',
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
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: cobaltBlue))
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
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  supabase.storage.from('documents').getPublicUrl(
                                        doc['document_url'].replaceFirst('documents/', ''),
                                      ),
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                                ),
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
