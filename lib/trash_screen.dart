import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'document_preview_screen.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> trashedScans = [];
  bool isLoading = true;

  static const Color cobaltBlue = Color(0xFF0047AB);
  static const Color cobaltRed = Colors.red;

  @override
  void initState() {
    super.initState();
    _loadTrash();
  }

  Future<void> _loadTrash() async {
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
          .eq('deleted', true)
          .order('created_at', ascending: false);

      setState(() {
        trashedScans = response;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading trash: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _restoreScan(Map scan) async {
    try {
      await supabase
          .from('scans')
          .update({'deleted': false})
          .eq('id', scan['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restored successfully')),
      );
      _loadTrash();
    } catch (e) {
      debugPrint('Error restoring scan: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to restore: $e')),
      );
    }
  }

  Future<void> _permanentlyDeleteScan(Map scan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Permanently'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final docPath = scan['document_url']?.replaceFirst('documents/', '') ?? '';
      final textPath = scan['extracted_file_url']?.replaceFirst('extractedfiles/', '') ?? '';

      if (docPath.isNotEmpty) {
        await supabase.storage.from('documents').remove([docPath]);
      }
      if (textPath.isNotEmpty) {
        await supabase.storage.from('extractedfiles').remove([textPath]);
      }

      await supabase.from('scans').delete().eq('id', scan['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleted permanently')),
      );
      _loadTrash();
    } catch (e) {
      debugPrint('Permanent delete error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  void _openScan(Map scan) {
    final imagePath = scan['document_url']?.replaceFirst('documents/', '') ?? '';
    final textPath = scan['extracted_file_url']?.replaceFirst('extractedfiles/', '') ?? '';

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
          '$userName\'s Trash',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : trashedScans.isEmpty
                ? const Center(child: Text('Trash is empty.'))
                : ListView.builder(
                    itemCount: trashedScans.length,
                    itemBuilder: (context, index) {
                      final scan = trashedScans[index];
                      final createdAt = DateTime.parse(scan['created_at']);
                      final formattedDate =
                          '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cobaltRed, width: 0.4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.delete_forever, color: Colors.red, size: 32),
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
                              icon: const Icon(Icons.restore, color: cobaltBlue),
                              tooltip: 'Restore',
                              onPressed: () => _restoreScan(scan),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Delete permanently',
                              onPressed: () => _permanentlyDeleteScan(scan),
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
