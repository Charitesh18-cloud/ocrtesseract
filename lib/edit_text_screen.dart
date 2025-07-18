import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class EditTextScreen extends StatefulWidget {
  final String? imagePath;
  final String? ocrText;

  const EditTextScreen({
    super.key,
    this.imagePath,
    this.ocrText,
  });

  @override
  State<EditTextScreen> createState() => _EditTextScreenState();
}

class _EditTextScreenState extends State<EditTextScreen> {
  final PageController _pageController = PageController();
  final List<TextEditingController> _textControllers = [];
  final List<String> _imagePaths = [];
  final List<String> _tempImagePaths = [];

  PDFViewController? _pdfViewController;
  String? _pdfPath;
  String _language = 'eng';
  String _languageName = 'English';
  String _type = 'images';
  int _currentPage = 0;
  int _totalPDFPages = 0;
  bool _isSaving = false;
  bool _isProcessing = false;
  bool _isPdfReady = false;

  static const Color cobaltBlue = Color(0xFF0047AB);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    // Check if constructor parameters are provided first
    if (widget.imagePath != null && widget.ocrText != null) {
      // Handle constructor parameters (from main.dart route)
      _imagePaths.add(widget.imagePath!);
      _textControllers.add(TextEditingController(text: widget.ocrText!));
      setState(() {
        _type = 'images';
        _language = 'eng';
        _languageName = 'English';
      });
      return;
    }

    // Fallback to route arguments (existing functionality)
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args == null) {
      _showErrorAndExit('No data provided');
      return;
    }

    setState(() {
      _language = args['language'] ?? 'eng';
      _languageName = args['languageName'] ?? 'English';
      _type = args['type'] ?? 'images';
    });

    if (_type == 'pdf') {
      _pdfPath = args['pdfPath'];
      setState(() => _isProcessing = true);
    } else {
      // Handle all image types (single/multiple/camera)
      final imagePaths = args['imagePaths'] as List<String>?;
      if (imagePaths != null && imagePaths.isNotEmpty) {
        _imagePaths.addAll(imagePaths);
        await _processAllImages();
      } else {
        _showErrorAndExit('No images provided');
      }
    }
  }

  Future<void> _processAllImages() async {
    setState(() => _isProcessing = true);
    try {
      // Clear any existing controllers
      _textControllers.clear();

      // Process each image and create a text controller for each
      for (int i = 0; i < _imagePaths.length; i++) {
        final text = await _extractText(_imagePaths[i]);
        _textControllers.add(TextEditingController(text: text));
      }

      // Ensure we have at least one page
      if (_textControllers.isEmpty) {
        _textControllers.add(TextEditingController(text: 'No text extracted'));
      }
    } catch (e) {
      _showSnackBar('Error processing images: $e');
      // Add empty controller so we don't show "no pages"
      if (_textControllers.isEmpty) {
        _textControllers.add(TextEditingController(text: 'Error processing OCR: $e'));
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<String> _extractText(String imagePath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final text = await FlutterTesseractOcr.extractText(
        imagePath,
        language: _language,
        args: {"tessdata": '${appDir.path}/tessdata', "psm": "6"},
      );
      return text.replaceAll(RegExp(r'\s+'), ' ').trim();
    } catch (e) {
      return 'Error extracting text: $e';
    }
  }

  Future<void> _onPDFViewReady(PDFViewController controller) async {
    _pdfViewController = controller;
    try {
      final pageCount = await controller.getPageCount();
      setState(() {
        _totalPDFPages = pageCount ?? 0;
        _isPdfReady = true;
      });
      await _convertPDFPagesToImages();
    } catch (e) {
      _showSnackBar('Error loading PDF: $e');
    }
  }

  Future<void> _convertPDFPagesToImages() async {
    if (_pdfViewController == null || _totalPDFPages == 0) return;

    setState(() => _isProcessing = true);
    try {
      final tempDir = await getTemporaryDirectory();
      _tempImagePaths.clear();
      _textControllers.clear();

      for (int i = 0; i < _totalPDFPages; i++) {
        await _pdfViewController!.setPage(i);
        await Future.delayed(const Duration(milliseconds: 500));

        final tempFile = File('${tempDir.path}/pdf_page_${i + 1}.png');
        _tempImagePaths.add(tempFile.path);

        // Placeholder for actual PDF to image conversion
        await tempFile.writeAsBytes(Uint8List(0));

        final placeholderText = 'OCR processing for PDF page ${i + 1} - Implementation needed';
        _textControllers.add(TextEditingController(text: placeholderText));
      }
    } catch (e) {
      _showSnackBar('Error converting PDF: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _copyToClipboard() {
    if (_textControllers.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _textControllers[_currentPage].text));
    _showSnackBar('Copied to clipboard!');
  }

  Future<void> _saveAllPages() async {
    if (!_validateSave()) return;

    final baseName = await _getBaseName();
    if (baseName == null) return;

    await _executeSave(() async {
      for (int i = 0; i < _textControllers.length; i++) {
        final pageName = _textControllers.length == 1 ? baseName : '${baseName}_Page_${i + 1}';
        await _savePageToSupabase(pageName, i);
      }
    });
    _showSnackBar('All ${_textControllers.length} page(s) saved!');
    Navigator.pop(context);
  }

  bool _validateSave() {
    if (_textControllers.isEmpty) return false;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showSnackBar('User not logged in!');
      return false;
    }
    return true;
  }

  Future<void> _executeSave(Future<void> Function() saveFunction) async {
    setState(() => _isSaving = true);
    try {
      await saveFunction();
    } catch (e) {
      _showSnackBar('Error saving: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _savePageToSupabase(String name, int pageIndex) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser!;
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    String imagePath = _type == 'pdf' ? _tempImagePaths[pageIndex] : _imagePaths[pageIndex];
    final documentFile = File(imagePath);
    final documentStoragePath = '${user.id}/${timestamp}_page_${pageIndex + 1}.jpg';

    await supabase.storage.from('documents').upload(documentStoragePath, documentFile);

    final cleanedText = _textControllers[pageIndex].text.replaceAll(RegExp(r'[\n\r]'), ' ').trim();
    final jsonContent = jsonEncode({'text': cleanedText});

    final extractedFileName = '${timestamp}_page_${pageIndex + 1}.json';
    final dir = await getTemporaryDirectory();
    final localExtractedFile = File('${dir.path}/$extractedFileName');
    await localExtractedFile.writeAsString(jsonContent, encoding: utf8);

    final extractedFilePath = '${user.id}/$extractedFileName';
    await supabase.storage.from('extractedfiles').upload(
          extractedFilePath,
          localExtractedFile,
          fileOptions:
              const FileOptions(upsert: true, contentType: 'application/json; charset=utf-8'),
        );

    await supabase.from('scans').insert({
      'user_id': user.id,
      'document_url': 'documents/$documentStoragePath',
      'extracted_file_url': 'extractedfiles/$extractedFilePath',
      'description': name,
    });
  }

  Future<String?> _getBaseName() {
    final title = _textControllers.length == 1 ? 'Name Document' : 'Name All Pages';
    final hint = _textControllers.length == 1
        ? 'Enter name for this document'
        : 'Enter base name (pages will be numbered)';
    return _showNameDialog(title, hint);
  }

  Future<String?> _showNameDialog(String title, String hint) async {
    final controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showErrorAndExit(String message) {
    _showSnackBar(message);
    Navigator.pop(context);
  }

  void _nextPage() {
    if (_currentPage < _textControllers.length - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Widget _buildPageContent(int index) {
    if (_textControllers.isEmpty || index >= _textControllers.length) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Image preview
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: cobaltBlue, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _type == 'pdf'
                  ? _buildPDFViewer(index)
                  : _imagePaths.isNotEmpty && index < _imagePaths.length
                      ? InteractiveViewer(
                          panEnabled: true,
                          minScale: 1,
                          maxScale: 5,
                          child: Image.file(File(_imagePaths[index]), fit: BoxFit.contain),
                        )
                      : const Center(child: Text('Image not available')),
            ),
          ),
          const SizedBox(height: 16),
          // Text editor
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: cobaltBlue),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _textControllers[index],
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  decoration: const InputDecoration.collapsed(
                      hintText: 'Your OCR text will appear here...'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Copy button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: _copyToClipboard,
              icon: const Icon(Icons.copy, color: Colors.white),
              label: const Text('Copy Text', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: cobaltBlue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPDFViewer(int pageIndex) {
    if (_pdfPath == null) return const Center(child: Text('No PDF loaded'));

    return PDFView(
      filePath: _pdfPath!,
      enableSwipe: false,
      swipeHorizontal: false,
      autoSpacing: false,
      pageFling: false,
      pageSnap: false,
      defaultPage: pageIndex,
      fitPolicy: FitPolicy.WIDTH,
      onRender: (pages) {
        if (!_isPdfReady) {
          setState(() {
            _totalPDFPages = pages ?? 0;
            _isPdfReady = true;
          });
          _convertPDFPagesToImages();
        }
      },
      onViewCreated: _onPDFViewReady,
      onError: (error) => print('PDF Error: $error'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = _textControllers.length;

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
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),

                    // Edit Text title - expanded to fill available space
                    Expanded(
                      child: Center(
                        child: Text(
                          totalPages == 1
                              ? 'Edit OCR Text'
                              : 'Edit OCR Text (${_currentPage + 1}/$totalPages)',
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
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: cobaltBlue),
                  SizedBox(height: 16),
                  Text('Processing OCR...'),
                ],
              ),
            )
          : totalPages == 0
              ? const Center(child: Text('No content to display'))
              : Column(
                  children: [
                    // OCR Language Info Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cobaltBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          'OCR Language: $_languageName',
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    // Progress indicator for multiple pages
                    if (totalPages > 1) _buildProgressIndicator(totalPages),

                    // Main content area
                    Expanded(
                      child: totalPages == 1
                          ? _buildPageContent(0)
                          : PageView.builder(
                              controller: _pageController,
                              onPageChanged: (index) {
                                setState(() => _currentPage = index);
                                if (_type == 'pdf' && _pdfViewController != null) {
                                  _pdfViewController!.setPage(index);
                                }
                              },
                              itemCount: totalPages,
                              itemBuilder: (context, index) => _buildPageContent(index),
                            ),
                    ),

                    // Navigation controls (only show if more than 1 page)
                    if (totalPages > 1) _buildNavigationControls(totalPages),
                  ],
                ),
      // Full-width Save All Pages button at bottom
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveAllPages,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save, color: Colors.white, size: 22),
              label: Text(
                _isSaving ? 'Saving...' : 'Save All Pages',
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: cobaltBlue,
                disabledBackgroundColor: cobaltBlue.withOpacity(0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(int totalPages) {
    return Container(
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(totalPages, (index) {
          return Expanded(
            child: Container(
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: index == _currentPage ? cobaltBlue : Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavigationControls(int totalPages) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(
            onPressed: _currentPage > 0 ? _previousPage : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[600],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, color: Colors.white),
                SizedBox(width: 4),
                Text('Previous', style: TextStyle(color: Colors.white))
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _currentPage < totalPages - 1 ? _nextPage : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[600],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Next', style: TextStyle(color: Colors.white)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, color: Colors.white)
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _textControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
