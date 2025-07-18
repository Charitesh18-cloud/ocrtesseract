import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image_picker/image_picker.dart';

class OCRScreen extends StatefulWidget {
  const OCRScreen({super.key});

  @override
  State<OCRScreen> createState() => _OCRScreenState();
}

class _OCRScreenState extends State<OCRScreen> {
  bool _isProcessing = false;
  String _selectedLanguage = 'eng';
  bool _filesReady = false;
  final ImagePicker _picker = ImagePicker();

  static const Color cobaltBlue = Color(0xFF0047AB);

  static const Map<String, Map<String, String>> indicLanguages = {
    'eng': {'name': 'English', 'script': 'Latin'},
    'asm': {'name': 'Assamese', 'script': 'Bengali'},
    'ben': {'name': 'Bengali', 'script': 'Bengali'},
    'guj': {'name': 'Gujarati', 'script': 'Gujarati'},
    'gur': {'name': 'Gurmukhi (Punjabi)', 'script': 'Gurmukhi'},
    'hin': {'name': 'Hindi', 'script': 'Devanagari'},
    'kan': {'name': 'Kannada', 'script': 'Kannada'},
    'mal': {'name': 'Malayalam', 'script': 'Malayalam'},
    'mar': {'name': 'Marathi', 'script': 'Devanagari'},
    'nep': {'name': 'Nepali', 'script': 'Devanagari'},
    'ori': {'name': 'Oriya (Odia)', 'script': 'Oriya'},
    'pan': {'name': 'Panjabi', 'script': 'Gurmukhi'},
    'san': {'name': 'Sanskrit', 'script': 'Devanagari'},
    'sin': {'name': 'Sinhala', 'script': 'Sinhala'},
    'tam': {'name': 'Tamil', 'script': 'Tamil'},
    'tel': {'name': 'Telugu', 'script': 'Telugu'},
    'urd': {'name': 'Urdu', 'script': 'Arabic'},
    'bod': {'name': 'Tibetan', 'script': 'Tibetan'},
    'dzo': {'name': 'Dzongkha', 'script': 'Tibetan'},
    'mni': {'name': 'Manipuri', 'script': 'Meetei Mayek'},
    'sat': {'name': 'Santali', 'script': 'Ol Chiki'},
    'bho': {'name': 'Bhojpuri', 'script': 'Devanagari'},
  };

  static const Map<String, List<String>> scriptGroups = {
    'Devanagari': ['hin', 'mar', 'nep', 'san', 'bho'],
    'Bengali': ['ben', 'asm'],
    'Dravidian': ['tam', 'tel', 'kan', 'mal'],
    'Gurmukhi': ['gur', 'pan'],
    'Others': ['guj', 'ori', 'sin', 'urd', 'bod', 'dzo', 'mni', 'sat'],
  };

  @override
  void initState() {
    super.initState();
    _initializeOCR();
  }

  Future<void> _initializeOCR() async {
    await _copyTrainedData();
    if (mounted) {
      setState(() => _filesReady = true);
    }
  }

  Future<void> _copyTrainedData() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final tessdataDir = Directory('${appDir.path}/tessdata');
      if (!await tessdataDir.exists()) {
        await tessdataDir.create(recursive: true);
      }

      final allLanguages = indicLanguages.keys.toList();
      int copiedCount = 0;

      for (final langCode in allLanguages) {
        final targetFile = File('${tessdataDir.path}/$langCode.traineddata');
        if (await targetFile.exists()) {
          await targetFile.delete();
        }

        try {
          final byteData = await rootBundle.load('assets/tessdata/$langCode.traineddata');
          await targetFile.writeAsBytes(byteData.buffer.asUint8List());
          copiedCount++;
        } catch (e) {
          debugPrint('⚠️ Could not copy $langCode.traineddata: $e');
        }
      }
      debugPrint('📋 Successfully copied $copiedCount/${allLanguages.length} language files');
    } catch (e) {
      debugPrint('❌ Error copying traineddata files: $e');
    }
  }

  String _getLanguageDisplayName(String langCode) {
    final lang = indicLanguages[langCode];
    return lang == null ? langCode : '${lang['name']} (${lang['script']})';
  }

  String _getLanguageEmoji(String langCode) {
    const emojis = {
      'hin': '🇮🇳',
      'ben': '🇧🇩',
      'tam': '🇮🇳',
      'tel': '🇮🇳',
      'kan': '🇮🇳',
      'mal': '🇮🇳',
      'guj': '🇮🇳',
      'mar': '🇮🇳',
      'pan': '🇮🇳',
      'ori': '🇮🇳',
      'asm': '🇮🇳',
      'urd': '🇵🇰',
      'nep': '🇳🇵',
      'sin': '🇱🇰',
      'san': '🕉️',
      'bod': '🇨🇳',
      'dzo': '🇧🇹',
      'mni': '🇮🇳',
      'sat': '🇮🇳',
      'bho': '🇮🇳',
      'gur': '🇮🇳',
      'eng': '🇬🇧',
    };
    return emojis[langCode] ?? '🌍';
  }

  List<DropdownMenuItem<String>> _buildDropdownItems() {
    List<DropdownMenuItem<String>> items = [
      DropdownMenuItem(
        value: 'eng',
        child: Text('${_getLanguageEmoji('eng')} ${_getLanguageDisplayName('eng')}'),
      )
    ];

    for (final script in ['Devanagari', 'Bengali', 'Dravidian', 'Gurmukhi', 'Others']) {
      final languages = scriptGroups[script] ?? [];
      if (languages.isNotEmpty) {
        items.add(DropdownMenuItem(
          value: '__header_$script',
          enabled: false,
          child: Text(
            '── $script Script ──',
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ));
        for (final langCode in languages) {
          items.add(DropdownMenuItem(
            value: langCode,
            child: Text('${_getLanguageEmoji(langCode)} ${_getLanguageDisplayName(langCode)}'),
          ));
        }
      }
    }
    return items;
  }

  // Common method for processing single image (both camera and gallery)
  Future<void> _processSingleImage(String imagePath) async {
    if (mounted) {
      final arguments = {
        'imagePaths': [imagePath],
        'language': _selectedLanguage,
        'languageName': _getLanguageDisplayName(_selectedLanguage),
        'type': 'single_image', // Same type for both camera and gallery
      };

      Navigator.pushNamed(context, '/edit', arguments: arguments);
    }
  }

  Future<void> _pickAndRecognizeImage() async {
    if (!_filesReady) {
      _showSnackBar('OCR files are still being prepared. Please wait.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result?.files.single.path != null) {
        final imagePath = result!.files.single.path!;
        await _processSingleImage(imagePath);
      } else {
        _showSnackBar('No image selected.');
      }
    } catch (e) {
      _showSnackBar('Error processing image: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _captureImage() async {
    if (!_filesReady) {
      _showSnackBar('OCR files are still being prepared. Please wait.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );

      if (image != null) {
        // Use the same processing logic as single image OCR
        await _processSingleImage(image.path);
      } else {
        _showSnackBar('No image captured.');
      }
    } catch (e) {
      _showSnackBar('Error capturing image: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _pickMultipleImages() async {
    if (!_filesReady) {
      _showSnackBar('OCR files are still being prepared. Please wait.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final images = await _picker.pickMultiImage();

      if (images.isEmpty) {
        _showSnackBar('No images selected.');
        return;
      }

      final imagePaths = images.map((image) => image.path).toList();

      if (mounted) {
        // Navigate to PDF screen for multiple images
        final arguments = {
          'imagePaths': imagePaths,
          'language': _selectedLanguage,
          'languageName': _getLanguageDisplayName(_selectedLanguage),
          'type': 'multiple_images',
        };

        Navigator.pushNamed(context, '/pdf', arguments: arguments);
      }
    } catch (e) {
      _showSnackBar('Error selecting images: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _pickPDF() async {
    if (!_filesReady) {
      _showSnackBar('OCR files are still being prepared. Please wait.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result?.files.single.path != null) {
        final pdfPath = result!.files.single.path!;
        final file = File(pdfPath);

        if (!await file.exists()) {
          _showSnackBar('Selected PDF file does not exist.');
          return;
        }

        final fileSizeInMB = (await file.length()) / (1024 * 1024);
        if (fileSizeInMB > 50) {
          _showSnackBar('PDF file is too large. Please select a smaller file.');
          return;
        }

        if (mounted) {
          // Navigate to PDF screen for PDF files
          final arguments = {
            'pdfPath': pdfPath,
            'language': _selectedLanguage,
            'languageName': _getLanguageDisplayName(_selectedLanguage),
            'type': 'pdf',
          };

          Navigator.pushNamed(context, '/pdf', arguments: arguments);
        }
      } else {
        _showSnackBar('No PDF selected.');
      }
    } catch (e) {
      _showSnackBar('Error selecting PDF: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: cobaltBlue),
            SizedBox(width: 8),
            Text('OCR Information'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Language Support Section
              const Text(
                '📱 Language Support',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cobaltBlue,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Supports 22 languages including Devanagari, Dravidian, Bengali scripts\n'
                '• Includes Hindi, Tamil, Telugu, Bengali, Gujarati, Marathi, and more\n'
                '• English language support for international text',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),

              // OCR Options Section
              const Text(
                '🔧 OCR Options',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cobaltBlue,
                ),
              ),
              const SizedBox(height: 8),

              // Capture with Camera
              const Text(
                '📸 Capture with Camera:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const Text(
                '• Scan only 1 image at a time\n'
                '• Real-time camera capture\n'
                '• Immediate OCR processing\n'
                '• High quality image capture for better accuracy',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),

              // Single Image OCR
              const Text(
                '🖼️ Single Image OCR:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const Text(
                '• Select 1 image from gallery\n'
                '• Process existing photos\n'
                '• Edit and save extracted text\n'
                '• Support for JPG, PNG, and other image formats',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),

              // Multiple Images OCR
              const Text(
                '📚 Multiple Images OCR:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const Text(
                '• Select multiple images from gallery\n'
                '• Batch OCR processing\n'
                '• ✅ Checkbox selection for batch processing on screen\n'
                '• Combine results into single document or PDF\n'
                '• Progress tracking for each image',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),

              // PDF OCR
              const Text(
                '📄 PDF OCR:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const Text(
                '• Upload PDF files up to 50MB\n'
                '• Extract text from PDF pages\n'
                '• ✅ Checkbox selection for batch processing on screen\n'
                '• Page-by-page processing\n'
                '• Export results as text or new PDF',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Features Section
              const Text(
                '⚡ Features',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cobaltBlue,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '• High accuracy OCR engine\n'
                '• Text editing and formatting\n'
                '• Copy to clipboard functionality\n'
                '• Save extracted text as files\n'
                '• Share results with other apps\n'
                '• Batch processing for multiple files',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),

              // Tips Section
              const Text(
                '💡 Tips for Better Results',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cobaltBlue,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Ensure good lighting when capturing images\n'
                '• Keep text straight and avoid skewed angles\n'
                '• Use high resolution images for better accuracy\n'
                '• Select appropriate language before processing\n'
                '• Clean backgrounds improve recognition quality',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: cobaltBlue,
            ),
            child: const Text(
              'Got it',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String text, IconData icon, Color color, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6), // Changed from 12 to 6 to match app bar
          ),
          padding: const EdgeInsets.symmetric(vertical: 16), // Increased padding
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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

                    // OCR title - expanded to fill available space
                    const Expanded(
                      child: Center(
                        child: Text(
                          'OCR Digitization',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Info button
                    IconButton(
                      icon: const Icon(Icons.info_outline, color: Colors.white, size: 22),
                      onPressed: _showInfoDialog,
                    ),
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
              // App logo section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Replace icon with OCR image
                    Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/ocr.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback to icon if image not found
                            return Container(
                              decoration: BoxDecoration(
                                color: cobaltBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.text_fields,
                                color: Colors.white,
                                size: 30,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'OCR Scanner',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: cobaltBlue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Language Selection
              DropdownButtonFormField<String>(
                value: _selectedLanguage,
                decoration: const InputDecoration(
                  labelText: 'Select OCR Language',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
                items: _buildDropdownItems(),
                onChanged: (value) {
                  if (value != null && !value.startsWith('__header_')) {
                    setState(() => _selectedLanguage = value);
                  }
                },
              ),
              const SizedBox(height: 12),

              // Status indicator
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: !_filesReady
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Preparing OCR files...',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Ready: ${_getLanguageDisplayName(_selectedLanguage)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      _buildButton(
                        'Capture with Camera',
                        Icons.camera_alt,
                        cobaltBlue,
                        (_isProcessing || !_filesReady) ? null : _captureImage,
                      ),
                      const SizedBox(height: 12),
                      _buildButton(
                        'Single Image OCR',
                        Icons.photo,
                        cobaltBlue,
                        (_isProcessing || !_filesReady) ? null : _pickAndRecognizeImage,
                      ),
                      const SizedBox(height: 12),
                      _buildButton(
                        'Multiple Images OCR',
                        Icons.photo_library,
                        cobaltBlue,
                        (_isProcessing || !_filesReady) ? null : _pickMultipleImages,
                      ),
                      const SizedBox(height: 12),
                      _buildButton(
                        'PDF OCR',
                        Icons.picture_as_pdf,
                        cobaltBlue,
                        (_isProcessing || !_filesReady) ? null : _pickPDF,
                      ),
                      const SizedBox(height: 16),

                      // Processing indicator
                      if (_isProcessing)
                        const Column(
                          children: [
                            CircularProgressIndicator(color: cobaltBlue),
                            SizedBox(height: 8),
                            Text(
                              'Processing...',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
