import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String _selectedLanguage = '';
  String? _avatarUrl;

  int uploadedDocs = 0;
  int usageTime = 0;
  bool isLoading = true;
  bool isUploadingAvatar = false;

  DateTime? _sessionStart;

  // Animation controllers
  late final List<AnimationController> _controllers;
  late final List<Animation<Offset>> _animations;

  static const Color cobaltBlue = Color(0xFF0047AB);

  // 22 Indian languages
  final List<String> _indicLanguages = [
    'Hindi',
    'Bengali',
    'Telugu',
    'Marathi',
    'Tamil',
    'Gujarati',
    'Urdu',
    'Kannada',
    'Odia',
    'Malayalam',
    'Punjabi',
    'Assamese',
    'Maithili',
    'Santali',
    'Kashmiri',
    'Nepali',
    'Konkani',
    'Sindhi',
    'Dogri',
    'Manipuri',
    'Bodo',
    'Sanskrit'
  ];

  @override
  void initState() {
    super.initState();
    _sessionStart = DateTime.now();
    _initializeAnimations();
    _loadProfile();
  }

  void _initializeAnimations() {
    _controllers = List.generate(
        8, (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 600)));
    _animations = _controllers
        .map((c) => Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeOut)))
        .toList();
    _startAnimations();
  }

  Future<void> _startAnimations() async {
    for (int i = 0; i < _controllers.length; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) _controllers[i].forward();
    }
  }

  Future<void> _loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();

      if (profile != null) {
        _nameController.text = profile['name'] ?? '';
        _ageController.text = profile['age']?.toString() ?? '';
        _avatarUrl = profile['avatar_url'];
        _selectedLanguage = _findMatchingLanguage(profile['preferred_language'] ?? '');
        usageTime = profile['usage_time'] ?? 0;
      }

      final scans = await supabase.from('scans').select().eq('user_id', user.id);
      uploadedDocs = scans.length;
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }

    setState(() => isLoading = false);
  }

  String _findMatchingLanguage(String dbLanguage) {
    if (dbLanguage.isEmpty) return '';
    if (_indicLanguages.contains(dbLanguage)) return dbLanguage;
    for (String lang in _indicLanguages) {
      if (lang.toLowerCase() == dbLanguage.toLowerCase()) return lang;
    }
    return '';
  }

  Future<void> _pickAndUploadAvatar() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 70,
      );

      if (image == null) return;
      setState(() => isUploadingAvatar = true);

      final imageFile = File(image.path);
      final fileName = '${user.id}-${DateTime.now().millisecondsSinceEpoch}.jpg';

      final response = await supabase.storage.from('avatars').upload(fileName, imageFile);

      if (response.isNotEmpty) {
        final avatarUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
        await supabase.from('profiles').upsert({
          'id': user.id,
          'avatar_url': avatarUrl,
        }, onConflict: 'id');

        setState(() => _avatarUrl = avatarUrl);
        _showSnackBar('✅ Avatar updated successfully!', Colors.green);
      }
    } catch (e) {
      _showSnackBar('❌ Failed to upload avatar: $e', Colors.red);
    } finally {
      setState(() => isUploadingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase.from('profiles').upsert({
        'id': user.id,
        'avatar_url': null,
      }, onConflict: 'id');

      setState(() => _avatarUrl = null);
      _showSnackBar('✅ Avatar removed successfully!', Colors.green);
    } catch (e) {
      _showSnackBar('❌ Failed to remove avatar: $e', Colors.red);
    }
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Profile Picture',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cobaltBlue)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.photo_library, color: cobaltBlue),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadAvatar();
              },
            ),
            if (_avatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Picture'),
                onTap: () {
                  Navigator.pop(context);
                  _removeAvatar();
                },
              ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.grey),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    int? age = int.tryParse(_ageController.text.trim());

    try {
      await supabase.from('profiles').upsert({
        'id': user.id,
        'name': _nameController.text.trim(),
        'age': age,
        'preferred_language': _selectedLanguage,
      }, onConflict: 'id');
      _showSnackBar('✅ Profile updated!', Colors.green);
    } catch (e) {
      _showSnackBar('❌ Failed: $e', Colors.red);
    }
  }

  Future<void> _updateUsageTime() async {
    final sessionSeconds = DateTime.now().difference(_sessionStart!).inSeconds;
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        await supabase.from('profiles').upsert({
          'id': user.id,
          'usage_time': usageTime + sessionSeconds,
        }, onConflict: 'id');
      } catch (e) {
        debugPrint('Error updating usage time: $e');
      }
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  void _navigateToResetPassword() {
    Navigator.pushNamed(context, '/reset');
  }

  void _showSnackBar(String message, Color color) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message), backgroundColor: color, duration: const Duration(seconds: 3)));
  }

  String _formatNumber(int number) => NumberFormat.decimalPattern().format(number);

  String _formatDuration(int seconds) {
    if (seconds == 0) return '0 min';
    if (seconds < 60) return '$seconds sec';
    if (seconds < 3600) return '${seconds ~/ 60} min';
    final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m} min';
  }

  @override
  void dispose() {
    _updateUsageTime();
    _controllers.forEach((c) => c.dispose());
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Widget _buildSection(String title, Widget child, int animationIndex) => SlideTransition(
        position: _animations[animationIndex],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        ),
      );

  Widget _buildProfilePicture() => Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade200,
              border: Border.all(color: cobaltBlue, width: 3),
            ),
            child: isUploadingAvatar
                ? const Center(child: CircularProgressIndicator(color: cobaltBlue))
                : _avatarUrl != null
                    ? ClipOval(
                        child: Image.network(_avatarUrl!,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.person, size: 60, color: cobaltBlue)))
                    : const Icon(Icons.person, size: 60, color: cobaltBlue),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _showAvatarOptions,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: cobaltBlue, shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      );

  Widget _buildProfileFieldRow(String label, Widget field) => Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
                width: 120,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600, color: cobaltBlue))),
            const SizedBox(width: 16),
            Expanded(child: field),
          ],
        ),
      );

  Widget _buildStatCard(
          {required String title,
          required String value,
          required IconData icon,
          required Color color}) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: cobaltBlue,
        elevation: 0,
        title: const Text('My Profile',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        leading: IconButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
            icon: const Icon(Icons.arrow_back, color: Colors.white)),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: cobaltBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Profile Details Section
                  _buildSection(
                      '👤 Profile Information',
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 5,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildProfilePicture(),
                            const SizedBox(height: 12),
                            const Text('Tap to change picture',
                                style: TextStyle(color: Colors.grey, fontSize: 14)),
                            const SizedBox(height: 20),

                            // Name Field
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(
                                    width: 120,
                                    child: Text('Your Name',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: cobaltBlue))),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    controller: _nameController,
                                    decoration: InputDecoration(
                                      hintText: 'Enter your name',
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide.none),
                                      contentPadding:
                                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Age Field
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(
                                    width: 120,
                                    child: Text('Your Age',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: cobaltBlue))),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    controller: _ageController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: 'Enter your age',
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide.none),
                                      contentPadding:
                                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Language Dropdown
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(
                                    width: 120,
                                    child: Text('Language',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: cobaltBlue))),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedLanguage.isEmpty ? null : _selectedLanguage,
                                        hint: const Text('Select language'),
                                        isExpanded: true,
                                        items: _indicLanguages.map((String language) {
                                          return DropdownMenuItem<String>(
                                            value: language,
                                            child: Text(language),
                                          );
                                        }).toList(),
                                        onChanged: (String? newValue) {
                                          setState(() => _selectedLanguage = newValue ?? '');
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Save Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: cobaltBlue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: cobaltBlue, width: 2),
                                  ),
                                  elevation: 2,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                onPressed: _saveProfile,
                                child: const Text('Save Profile',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      0),

                  const SizedBox(height: 32),

                  // Stats Section
                  _buildSection(
                      '📊 Your Stats',
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.1,
                        children: [
                          _buildStatCard(
                            title: 'Documents Uploaded',
                            value: _formatNumber(uploadedDocs),
                            icon: Icons.cloud_upload_outlined,
                            color: const Color(0xFF4ECDC4),
                          ),
                          _buildStatCard(
                            title: 'Time Spent',
                            value: _formatDuration(usageTime),
                            icon: Icons.access_time_outlined,
                            color: const Color(0xFFFF6B6B),
                          ),
                        ],
                      ),
                      1),

                  const SizedBox(height: 40),

                  // Action Buttons
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 200,
                          height: 45,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cobaltBlue,
                              foregroundColor: Colors.white,
                              shape:
                                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _navigateToResetPassword,
                            icon: const Icon(Icons.lock_reset, size: 20),
                            label: const Text('Reset Password'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: 200,
                          height: 45,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape:
                                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _logout,
                            icon: const Icon(Icons.logout, size: 20),
                            label: const Text('Log Out'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
