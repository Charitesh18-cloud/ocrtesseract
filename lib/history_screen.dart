import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'document_preview_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> allScans = [];
  bool isLoading = true;

  static const Color cobaltBlue = Color(0xFF0047AB);

  @override
  void initState() {
    super.initState();
    _loadAllScans();
  }

  Future<void> _loadAllScans() async {
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
          .eq('deleted', false) // ✅ Only show active scans
          .order('created_at', ascending: false);

      setState(() {
        allScans = response;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading all scans: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _moveToTrash(Map scan) async {
    try {
      await supabase.from('scans').update({'deleted': true}).eq('id', scan['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Moved to Trash')),
      );

      _loadAllScans(); // Refresh
    } catch (e) {
      debugPrint('Error moving to trash: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to move to Trash: $e')),
      );
    }
  }

  void _openScan(Map scan) {
    final imagePath = scan['document_url'].replaceFirst('documents/', '');
    final textPath = scan['extracted_file_url'].replaceFirst('extractedfiles/', '');

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

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final userName = user?.email ?? 'Guest';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FC),
      appBar: AppBar(
        backgroundColor: cobaltBlue,
        title: Text(
          '$userName\'s History',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white, // White appbar text
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : allScans.isEmpty
                ? const Center(child: Text('No scans found.'))
                : ListView.builder(
                    itemCount: allScans.length,
                    itemBuilder: (context, index) {
                      final scan = allScans[index];
                      final createdAt = DateTime.parse(scan['created_at']);
                      final formattedDate =
                          '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          // Removed border here, keeping only subtle shadow
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
                            const Icon(Icons.history, color: cobaltBlue, size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _openScan(scan),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      scan['description'] ?? 'Untitled',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
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
                              onPressed: () => _moveToTrash(scan),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios,
                                  size: 16, color: cobaltBlue),
                              onPressed: () => _openScan(scan),
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
