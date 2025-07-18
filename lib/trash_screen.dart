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
  String userName = 'Guest';
  bool isLoadingUser = true;

  static const Color cobaltBlue = Color(0xFF0047AB);
  static const Color cobaltRed = Colors.red;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadTrash();
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
      await supabase.from('scans').update({'deleted': false}).eq('id', scan['id']);

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
                      onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                    ),
                    const SizedBox(width: 8),

                    // Title - expanded to fill available space
                    Expanded(
                      child: Center(
                        child: isLoadingUser
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Loading...',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                '$userName\'s Trash',
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: cobaltBlue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Text(
                    'Deleted Items',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : trashedScans.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Trash is empty',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: trashedScans.length,
                            itemBuilder: (context, index) {
                              final scan = trashedScans[index];
                              final createdAt = DateTime.parse(scan['created_at']);
                              final formattedDate =
                                  '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.delete_forever,
                                      color: Colors.red,
                                      size: 24,
                                    ),
                                  ),
                                  title: Text(
                                    scan['description'] ?? 'Untitled',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text(
                                    formattedDate,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: cobaltBlue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.restore,
                                              color: cobaltBlue, size: 20),
                                          tooltip: 'Restore',
                                          onPressed: () => _restoreScan(scan),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: IconButton(
                                          icon:
                                              const Icon(Icons.delete, color: Colors.red, size: 20),
                                          tooltip: 'Delete permanently',
                                          onPressed: () => _permanentlyDeleteScan(scan),
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () => _openScan(scan),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
