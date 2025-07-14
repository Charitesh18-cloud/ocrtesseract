import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String _selectedLanguage = '';

  int uploadedDocs = 0;
  int usageTime = 0;
  bool isLoading = true;

  DateTime? _sessionStart;

  static const Color cobaltBlue = Color(0xFF0047AB);

  // 22 Indian languages - ensure no duplicates and consistent casing
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
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();

      if (profile != null) {
        _nameController.text = profile['name'] ?? '';
        _ageController.text = profile['age']?.toString() ?? '';

        // Handle case-insensitive language matching
        String dbLanguage = profile['preferred_language'] ?? '';
        _selectedLanguage = _findMatchingLanguage(dbLanguage);

        usageTime = profile['usage_time'] ?? 0;
      }

      final scans = await supabase.from('scans').select().eq('user_id', user.id);
      uploadedDocs = scans.length;
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }

    setState(() {
      isLoading = false;
    });
  }

  // Helper method to find matching language (case-insensitive)
  String _findMatchingLanguage(String dbLanguage) {
    if (dbLanguage.isEmpty) return '';

    // First try exact match
    if (_indicLanguages.contains(dbLanguage)) {
      return dbLanguage;
    }

    // Try case-insensitive match
    for (String lang in _indicLanguages) {
      if (lang.toLowerCase() == dbLanguage.toLowerCase()) {
        return lang;
      }
    }

    // If no match found, return empty string
    return '';
  }

  Future<void> _saveProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    int? age = int.tryParse(_ageController.text.trim());

    final updates = {
      'id': user.id,
      'name': _nameController.text.trim(),
      'age': age,
      'preferred_language': _selectedLanguage,
    };

    try {
      await supabase.from('profiles').upsert(updates, onConflict: 'id');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Profile updated!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error saving profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

  @override
  void dispose() {
    _updateUsageTime();
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  String _formatNumber(int number) {
    return NumberFormat.decimalPattern().format(number);
  }

  Widget _buildProfileField(String label, Widget field) {
    return Container(
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
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cobaltBlue,
            ),
          ),
          const SizedBox(height: 12),
          field,
        ],
      ),
    );
  }

  Widget _buildStatsCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cobaltBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: cobaltBlue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cobaltBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  void _navigateToResetPassword() {
    Navigator.pushNamed(context, '/reset');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: cobaltBlue,
        centerTitle: true,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: cobaltBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Section
                  const Text(
                    'Profile Information',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: cobaltBlue,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Name Field
                  _buildProfileField(
                    'Your Name',
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Enter your name',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),

                  // Age Field
                  _buildProfileField(
                    'Your Age',
                    TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter your age',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),

                  // Language Dropdown
                  _buildProfileField(
                    'Preferred Language',
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLanguage.isEmpty ? null : _selectedLanguage,
                          hint: const Text('Select your preferred language'),
                          isExpanded: true,
                          items: _indicLanguages.map((String language) {
                            return DropdownMenuItem<String>(
                              value: language,
                              child: Text(language),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedLanguage = newValue ?? '';
                            });
                          },
                        ),
                      ),
                    ),
                  ),

                  // Save Button
                  Container(
                    width: double.infinity,
                    height: 50,
                    margin: const EdgeInsets.only(bottom: 40),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: cobaltBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: cobaltBlue, width: 2),
                        ),
                        elevation: 2,
                      ),
                      onPressed: _saveProfile,
                      child: const Text(
                        'Save Profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // Stats Section
                  Center(
                    child: Text(
                      'Your Stats',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: cobaltBlue,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildStatsCard(
                    'Documents Uploaded',
                    _formatNumber(uploadedDocs),
                    Icons.cloud_upload_outlined,
                  ),
                  _buildStatsCard(
                    'Time Spent',
                    '${(usageTime / 60).toStringAsFixed(1)} minutes',
                    Icons.access_time_outlined,
                  ),

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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
