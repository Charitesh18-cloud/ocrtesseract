import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'document_preview_screen.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final supabase = Supabase.instimport 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'document_preview_screen.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  List<dynamic> trashedScans = [];
  bool isLoading = true;
  String userName = 'Guest';

  // Animation controllers
  late final List<AnimationController> _controllers;
  late final List<Animation<Offset>> _animations;

  static const Color cobaltRed = Color(0xFFDC143C);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserDataAndTrash();
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
        trashedScans.length > _controllers.length ? _controllers.length : trashedScans.length;

    for (int i = 0; i < animationCount; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) _controllers[i].forward();
    }
  }

  // Updated method to load both user data and trash
  Future<void> _loadUserDataAndTrash() async {
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

      // Load trash
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

      // Start animations after data is loaded
      _startAnimations();
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _restoreScan(Map scan) async {
    try {
      await supabase.from('scans').update({'deleted': false}).eq('id', scan['id']);

      _showSnackBar('✅ Restored Successfully', Colors.green);

      await _loadUserDataAndTrash(); // Refresh data
    } catch (e) {
      debugPrint('Restore error: $e');
      _showSnackBar('❌ Error: $e', Colors.red);
    }
  }

  Future<void> _permanentlyDeleteScan(Map scan) async {
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

      _showSnackBar('✅ Deleted Permanently', Colors.red);

      await _loadUserDataAndTrash(); // Refresh data
    } catch (e) {
      debugPrint('Permanent delete error: $e');
      _showSnackBar('❌ Error: $e', Colors.red);
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

  Future<void> _confirmAndRestore(Map scan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Restore Document',
            style: TextStyle(fontWeight: FontWeight.bold, color: cobaltRed)),
        content: const Text('Are you sure you want to restore this document?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _restoreScan(scan);
    }
  }

  Future<void> _confirmAndPermanentlyDelete(Map scan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Permanently',
            style: TextStyle(fontWeight: FontWeight.bold, color: cobaltRed)),
        content: const Text(
            'Are you sure? This action cannot be undone and will permanently delete this document.'),
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
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _permanentlyDeleteScan(scan);
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
              color: cobaltRed,
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

  Widget _buildTrashCard(Map scan, int index) {
    final createdAt = DateTime.parse(scan['created_at']);
    final formattedDate =
        '${createdAt.day.toString().padLeft(2, '0')}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.year}';

    // Use animation only if index is within controller range
    if (index < _controllers.length) {
      return SlideTransition(
        position: _animations[index],
        child: _buildTrashCardContent(scan, formattedDate),
      );
    } else {
      return _buildTrashCardContent(scan, formattedDate);
    }
  }

  Widget _buildTrashCardContent(Map scan, String formattedDate) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Document thumbnail
          GestureDetector(
            onTap: () => _openScan(scan),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cobaltRed.withOpacity(0.2)),
                color: Colors.grey.shade50,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    Image.network(
                      supabase.storage.from('documents').getPublicUrl(
                            scan['document_url']?.replaceFirst('documents/', '') ?? '',
                          ),
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 70,
                        height: 70,
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.delete_forever, size: 30, color: cobaltRed),
                      ),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 70,
                          height: 70,
                          color: Colors.grey.shade100,
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: cobaltRed,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // Overlay to prevent any watermarks
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Document details
          Expanded(
            child: GestureDetector(
              onTap: () => _openScan(scan),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    scan['description'] ?? 'Untitled Document',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.delete_outline, size: 12, color: cobaltRed),
                      const SizedBox(width: 4),
                      Text(
                        'In Trash',
                        style: TextStyle(
                          color: cobaltRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Action buttons
          Column(
            children: [
              // Restore button
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.restore, color: Colors.green, size: 18),
                  onPressed: () => _confirmAndRestore(scan),
                  tooltip: 'Restore',
                  padding: EdgeInsets.zero,
                ),
              ),
              // Permanent delete button
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red, size: 18),
                  onPressed: () => _confirmAndPermanentlyDelete(scan),
                  tooltip: 'Delete forever',
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
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
        backgroundColor: cobaltRed,
        elevation: 0,
        title: Text('$userName\'s Trash',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white)),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: cobaltRed))
          : trashedScans.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Trash is empty',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Deleted documents will appear here',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildSection(
                        '🗑️ Deleted Items (${trashedScans.length})',
                        Column(
                          children: List.generate(
                            trashedScans.length,
                            (index) => _buildTrashCard(trashedScans[index], index),
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
ance.client;
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
