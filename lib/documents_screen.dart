import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'document_preview_screen.dart'; // Shared logic for preview

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  List<dynamic> documents = [];
  bool isLoading = true;
  String userName = 'Guest';

  // Animation controllers
  late final List<AnimationController> _controllers;
  late final List<Animation<Offset>> _animations;

  static const Color cobaltBlue = Color(0xFF0047AB);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserDataAndDocuments();
  }

  void _initializeAnimations() {
    // Create animation controllers for each document card
    _controllers = List.generate(
        10, // Max 10 animations for performance
        (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 600)));
    _animations = _controllers
        .map((c) => Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeOut)))
        .toList();
  }

  Future<void> _startAnimations() async {
    final animationCount =
        documents.length > _controllers.length ? _controllers.length : documents.length;

    for (int i = 0; i < animationCount; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) _controllers[i].forward();
    }
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

      // Start animations after data is loaded
      _startAnimations();
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _moveToTrash(Map doc) async {
    try {
      await supabase.from('scans').update({'deleted': true}).eq('id', doc['id']);

      _showSnackBar('✅ Moved to Trash', Colors.green);

      await _loadUserDataAndDocuments(); // Refresh data
    } catch (e) {
      debugPrint('Trash error: $e');
      _showSnackBar('❌ Error: $e', Colors.red);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Move to Trash',
            style: TextStyle(fontWeight: FontWeight.bold, color: cobaltBlue)),
        content: const Text('Are you sure you want to move this document to Trash?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Move'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _moveToTrash(doc);
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

  Widget _buildSection(String title, Widget child) => Column(
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
      );

  Widget _buildDocumentCard(Map doc, int index) {
    final createdAt = DateTime.parse(doc['created_at']);
    final formattedDate =
        '${createdAt.day.toString().padLeft(2, '0')}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.year}';

    // Use animation only if index is within controller range
    if (index < _controllers.length) {
      return SlideTransition(
        position: _animations[index],
        child: _buildDocumentCardContent(doc, formattedDate),
      );
    } else {
      return _buildDocumentCardContent(doc, formattedDate);
    }
  }

  Widget _buildDocumentCardContent(Map doc, String formattedDate) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Row(
        children: [
          // Document thumbnail
          GestureDetector(
            onTap: () => _openDocument(doc),
            child: Hero(
              tag: 'doc_${doc['id']}',
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cobaltBlue.withOpacity(0.2)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    supabase.storage.from('documents').getPublicUrl(
                          doc['document_url'].replaceFirst('documents/', ''),
                        ),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade100,
                      child: const Icon(Icons.description, size: 40, color: cobaltBlue),
                    ),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: cobaltBlue,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Document details
          Expanded(
            child: GestureDetector(
              onTap: () => _openDocument(doc),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc['description'] ?? 'Untitled Document',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.description, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Tap to view',
                        style: TextStyle(
                          color: cobaltBlue.withOpacity(0.8),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Delete button
          Container(
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
              onPressed: () => _confirmAndDelete(doc),
              tooltip: 'Move to trash',
            ),
          ),
        ],
      ),
    );
  }

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
        title: Text('$userName\'s Documents',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white)),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: cobaltBlue))
          : documents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No documents found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your uploaded documents will appear here',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildSection(
                        '📄 Your Documents (${documents.length})',
                        Column(
                          children: List.generate(
                            documents.length,
                            (index) => _buildDocumentCard(documents[index], index),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }
}
