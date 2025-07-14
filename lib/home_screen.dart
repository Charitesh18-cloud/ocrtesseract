import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/quick_action_card.dart';
import 'document_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> recentScans = [];
  bool isLoading = true;
  int _currentIndex = 0;
  String userName = 'Guest';
  static const Color cobaltBlue = Color(0xFF0047AB);

  @override
  void initState() {
    super.initState();
    _loadUserDataAndScans();
  }

  Future<void> _loadUserDataAndScans() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
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

      final response = await supabase
          .from('scans')
          .select()
          .eq('user_id', user.id)
          .eq('deleted', false)
          .order('created_at', ascending: false)
          .limit(5);

      setState(() {
        recentScans = response;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _moveToTrash(Map scan) async {
    try {
      final response =
          await supabase.from('scans').update({'deleted': true}).eq('id', scan['id']).select();

      if (response == null || response.isEmpty) {
        throw Exception('Trash update failed.');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Moved to Trash')),
      );

      await _loadUserDataAndScans();
    } catch (e) {
      debugPrint('Trash error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
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

  void _onBottomNavTapped(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.pushNamed(context, '/scan');
        break;
      case 2:
        Navigator.pushNamed(context, '/trash');
        break;
      case 3:
        Navigator.pushNamed(context, '/profile');
        break;
    }
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cobaltBlue, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: cobaltBlue, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: cobaltBlue,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Hello, $userName!',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, size: 28, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildQuickAction(
                    icon: Icons.camera_alt,
                    label: 'New Scan',
                    onTap: () => Navigator.pushNamed(context, '/scan'),
                  ),
                  _buildQuickAction(
                    icon: Icons.history,
                    label: 'Recent Scans',
                    onTap: () => Navigator.pushNamed(context, '/history'),
                  ),
                  _buildQuickAction(
                    icon: Icons.folder,
                    label: 'My Documents',
                    onTap: () => Navigator.pushNamed(context, '/documents'),
                  ),
                  _buildQuickAction(
                    icon: Icons.delete,
                    label: 'Trash',
                    onTap: () => Navigator.pushNamed(context, '/trash'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Recent Scans',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cobaltBlue,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : recentScans.isEmpty
                        ? const Center(child: Text('No recent scans found.'))
                        : ListView.builder(
                            itemCount: recentScans.length,
                            itemBuilder: (context, index) {
                              final scan = recentScans[index];
                              final createdAt = DateTime.parse(scan['created_at']);
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
                                      onTap: () => _openScan(scan),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          supabase.storage.from('documents').getPublicUrl(
                                                scan['document_url'].replaceFirst('documents/', ''),
                                              ),
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.broken_image),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _openScan(scan),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              scan['description'] ?? 'Untitled',
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
                                      onPressed: () => _moveToTrash(scan),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: cobaltBlue,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: _onBottomNavTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.delete), label: 'Trash'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
