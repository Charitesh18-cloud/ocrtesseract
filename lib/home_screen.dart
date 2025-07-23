import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'document_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  List<dynamic> recentScans = [];
  bool isLoading = true;
  String userName = 'Guest';
  bool _isGuestMode = false;
  static const Color cobaltBlue = Color(0xFF0047AB);

  late List<AnimationController> _controllers;
  late List<Animation<Offset>> _animations;
  bool _animationsInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndScans();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUserDataAndScans() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        isLoading = false;
        _isGuestMode = true;
        userName = 'Guest';
      });
      _initializeAnimations();
      _startAnimations();
      return;
    }
    setState(() => _isGuestMode = false);
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
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    final total = 4 + recentScans.length;
    _controllers = List.generate(
      total,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );
    _animations = _controllers
        .map((c) => Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeOut)))
        .toList();
    _animationsInitialized = true;
  }

  Future<void> _startAnimations() async {
    if (_controllers.isEmpty) return;
    for (int i = 0; i < _controllers.length; i++) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (mounted) _controllers[i].forward();
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

  void _showGuestModeDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Login Required', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Please login to access $feature feature.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/');
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(_isGuestMode ? 'Go to Login' : 'Logout Confirmation'),
          content: Text(
            _isGuestMode ? 'Go to login screen?' : 'Do you want to logout?',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                _isGuestMode ? 'Go to Login' : 'Yes',
                style: const TextStyle(
                  color: cobaltBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (result == true) {
      if (!_isGuestMode) {
        try {
          await supabase.auth.signOut();
        } catch (e) {
          debugPrint('Error signing out: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logout failed: $e')),
          );
          return;
        }
      }
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  Widget _buildMainButton({
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
    required int animationIndex,
  }) {
    final button = Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: cobaltBlue),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
    return (_animationsInitialized && animationIndex < _animations.length)
        ? SlideTransition(position: _animations[animationIndex], child: button)
        : button;
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM dd').format(date);
  }

  Widget _buildRecentScanItem(Map scan, int animationIndex) {
    final scanWidget = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _openScan(scan),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                supabase.storage.from('documents').getPublicUrl(
                      scan['document_url'].replaceFirst('documents/', ''),
                    ),
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scan['description'] ?? 'Untitled Document',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(scan['created_at']),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              onPressed: () => _moveToTrash(scan),
              tooltip: 'Move to Trash',
            ),
          ],
        ),
      ),
    );
    return (_animationsInitialized && animationIndex < _animations.length)
        ? SlideTransition(position: _animations[animationIndex], child: scanWidget)
        : scanWidget;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _showLogoutConfirmation();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: cobaltBlue,
          leading: IconButton(
            onPressed: () => _isGuestMode
                ? _showGuestModeDialog('Settings')
                : Navigator.pushNamed(context, '/settings'),
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Settings',
          ),
          title: const Text(
            'Tesseract OCR',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          actions: [
            IconButton(
              onPressed: _showLogoutConfirmation,
              icon: Icon(
                _isGuestMode ? Icons.login : Icons.logout,
                color: Colors.white,
              ),
              tooltip: _isGuestMode ? 'Login' : 'Logout',
            ),
            IconButton(
              onPressed: () => _isGuestMode
                  ? _showGuestModeDialog('Profile')
                  : Navigator.pushNamed(context, '/profile'),
              icon: const Icon(Icons.person_outline, color: Colors.white),
              tooltip: 'Profile',
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Welcome, $userName',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'What would you like to scan today?',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),

                // Guest Mode Banner
                if (_isGuestMode)
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F7FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cobaltBlue.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.info_outline, size: 32, color: cobaltBlue),
                        const SizedBox(height: 12),
                        const Text(
                          'Guest Mode',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: cobaltBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Login to save documents and access all features.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cobaltBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Login Now',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Main Action Buttons
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildMainButton(
                      title: 'New Scan',
                      icon: Icons.camera_alt,
                      onPressed: () => Navigator.pushNamed(context, '/scan'),
                      animationIndex: 0,
                    ),
                    _buildMainButton(
                      title: 'About Developer',
                      icon: Icons.person,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutDevelopersScreen()),
                      ),
                      animationIndex: 1,
                    ),
                    _buildMainButton(
                      title: 'My Documents',
                      icon: Icons.folder,
                      onPressed: _isGuestMode
                          ? () => _showGuestModeDialog('My Documents')
                          : () => Navigator.pushNamed(context, '/documents'),
                      animationIndex: 2,
                    ),
                    _buildMainButton(
                      title: 'Trash',
                      icon: Icons.delete_outline,
                      onPressed: _isGuestMode
                          ? () => _showGuestModeDialog('Trash')
                          : () => Navigator.pushNamed(context, '/trash'),
                      animationIndex: 3,
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Recent Scans Section
                if (!_isGuestMode) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Scans',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/documents'),
                        child: const Text(
                          'View All',
                          style: TextStyle(color: cobaltBlue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(color: cobaltBlue),
                      ),
                    )
                  else if (recentScans.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.document_scanner_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No documents yet',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start by scanning your first document',
                            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  else
                    ...List.generate(
                      recentScans.length,
                      (i) => _buildRecentScanItem(recentScans[i], 4 + i),
                    ),
                ],
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.pushNamed(context, '/scan'),
          backgroundColor: cobaltBlue,
          child: const Icon(Icons.camera_alt, color: Colors.white),
          tooltip: 'New Scan',
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// ---------------  AboutDevelopersScreen (as requested)  -------------------
// --------------------------------------------------------------------------

class AboutDevelopersScreen extends StatefulWidget {
  const AboutDevelopersScreen({super.key});
  @override
  State<AboutDevelopersScreen> createState() => _AboutDevelopersScreenState();
}

class _AboutDevelopersScreenState extends State<AboutDevelopersScreen>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<Offset>> _animations;

  final List<Map<String, dynamic>> _developers = [
    {
      'name': 'Charitesh',
      'role': 'Developer',
      'description':
          'Passionate about building open, efficient, and delightful mobile experiences. Loves Flutter, AI, and problem solving. For queries: charitesh25@gmail.com',
      'avatar': 'C',
      'color': const Color(0xFF0047AB),
    },
  ];

  final List<Map<String, String>> aboutAppFeatures = [
    {
      'heading': 'OCR Technology',
      'body': 'Accurate text extraction from PDFs and images using Flutter Tesseract OCR.'
    },
    {
      'heading': 'Indian Languages',
      'body': 'Supports all major Indian languages (Hindi, Telugu, Tamil, Bengali, and more).'
    },
    {'heading': 'Document Support', 'body': 'Scan from camera, single/multiple images, or PDFs.'},
    {
      'heading': 'Document Cloud',
      'body': 'Your documents and text are securely stored on cloud using Supabase.'
    },
    {
      'heading': 'User Features',
      'body': 'Profile management, usage analytics, password reset, and time tracking.'
    },
    {
      'heading': 'Modern Design',
      'body': 'Animated, friendly and responsive user interface built fully in Flutter.'
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    final totalAnimations = 15;
    _controllers = List.generate(totalAnimations, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
    });
    _animations = _controllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
    }).toList();
  }

  Future<void> _startAnimations() async {
    for (int i = 0; i < _controllers.length; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        _controllers[i].forward();
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _buildDeveloperCard(Map<String, dynamic> developer, int animationIndex) {
    return SlideTransition(
      position: _animations[animationIndex],
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: developer['color'],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  developer['avatar'],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    developer['name'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    developer['role'],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: developer['color'],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    developer['description'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureBox(String heading, String body, int animationIndex) {
    return SlideTransition(
      position: _animations[animationIndex],
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              heading,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color cobaltBlue = Color(0xFF0047AB);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: cobaltBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: SlideTransition(
          position: _animations[0],
          child: const Text(
            'About Developer',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // App Name & Icon Section
              SlideTransition(
                position: _animations[1],
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: cobaltBlue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.document_scanner,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tesseract OCR',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Meet the Developer Section
              SlideTransition(
                position: _animations[2],
                child: const Text(
                  'Meet the Developer',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildDeveloperCard(_developers[0], 3),

              const SizedBox(height: 32),

              // About Tesseract OCR Features
              SlideTransition(
                position: _animations[4],
                child: const Text(
                  'About Tesseract OCR',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              for (int i = 0; i < aboutAppFeatures.length; i++)
                _buildFeatureBox(
                  aboutAppFeatures[i]['heading']!,
                  aboutAppFeatures[i]['body']!,
                  5 + i,
                ),

              const SizedBox(height: 10),
              SlideTransition(
                position: _animations[11],
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Contact: charitesh25@gmail.com',
                    style: TextStyle(
                      fontSize: 13,
                      color: cobaltBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Thank You and Love Section
              SlideTransition(
                position: _animations[12],
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cobaltBlue.withOpacity(0.09),
                        const Color(0xFF4ECDC4).withOpacity(0.09),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.favorite,
                        size: 32,
                        color: Colors.red[400],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Thank You!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Hope you enjoy using this app as much as I enjoyed building it!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
