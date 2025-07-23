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

class _EditTextScreenState extends State<EditTextScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final List<TextEditingController> _textControllers = [];
  final List<String> _imagePaths = [];
  final List<String> _tempImagePaths = [];

  PDFViewController? _pdfViewController;
  String? _pdfPath;
  String _language = 'eng';
  String _type = 'images';
  int _currentPage = 0;
  int _totalPDFPages = 0;
  bool _isSaving = false;
  bool _isProcessing = false;
  bool _isPdfReady = false;

  static const Color cobaltBlue = Color(0xFF0047AB);

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late List<AnimationController> _slideControllers;
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  void _setupAnimations() {
    _fadeController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_fadeController);

    _slideControllers = List.generate(
      5,
      (i) => AnimationController(duration: const Duration(milliseconds: 450), vsync: this),
    );

    _slideAnimations = _slideControllers
        .map((c) => Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: c, curve: Curves.easeOut)))
        .toList();

    _fadeController.forward();
    _startStagger();
  }

  Future<void> _startStagger() async {
    for (final ctrl in _slideControllers) {
      await Future.delayed(const Duration(milliseconds: 90));
      if (mounted) ctrl.forward();
    }
  }

  Future<void> _initialize() async {
    if (widget.imagePath != null && widget.ocrText != null) {
      _imagePaths.add(widget.imagePath!);
      _textControllers.add(TextEditingController(text: widget.ocrText!));
      setState(() {
        _type = 'images';
        _language = 'eng';
      });
      return;
    }
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args == null) {
      _showErrorAndExit('No data provided');
      return;
    }
    setState(() {
      _language = args['language'] ?? 'eng';
      _type = args['type'] ?? 'images';
    });
    if (_type == 'pdf') {
      _pdfPath = args['pdfPath'];
      setState(() => _isProcessing = true);
    } else {
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
      _textControllers.clear();
      for (int i = 0; i < _imagePaths.length; i++) {
        final text = await _extractText(_imagePaths[i]);
        _textControllers.add(TextEditingController(text: text));
      }
      if (_textControllers.isEmpty) {
        _textControllers.add(TextEditingController(text: 'No text extracted'));
      }
    } catch (e) {
      _showSnackBar('Error processing images: $e');
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
          duration: const Duration(milliseconds: 330), curve: Curves.easeInOut);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 330), curve: Curves.easeInOut);
    }
  }

  Widget _buildPageContent(int index) {
    if (_textControllers.isEmpty || index >= _textControllers.length) {
      return const Center(child: CircularProgressIndicator());
    }
    return SlideTransition(
      position: _slideAnimations[3],
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Guidelines container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: const Text(
                'Edit your texts and save all to documents',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Larger Image preview box
            Container(
              height: 260,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: cobaltBlue, width: 1.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
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
            const SizedBox(height: 20),

            // OCR Text editor box with copy icon top right
            Container(
              height: 320,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: cobaltBlue.withOpacity(0.9)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12, left: 14, right: 14, bottom: 14),
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        child: TextField(
                          controller: _textControllers[index],
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          style: const TextStyle(fontSize: 17, height: 1.4),
                          decoration: const InputDecoration.collapsed(
                            hintText: 'Your OCR text will appear here...',
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Positioned copy icon button top right inside editing box
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Tooltip(
                      message: 'Copy Text',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _copyToClipboard,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: cobaltBlue,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: const Icon(Icons.copy, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
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

  Widget _buildProgressIndicator(int totalPages) {
    return SlideTransition(
      position: _slideAnimations[1],
      child: Container(
        height: 8,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          children: List.generate(totalPages, (index) {
            return Expanded(
              child: Container(
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: index == _currentPage ? cobaltBlue : Colors.grey[300],
                  borderRadius: BorderRadius.circular(4.5),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildNavigationAndSaveBar(int totalPages) {
    return SlideTransition(
      position: _slideAnimations[4],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        child: Row(
          children: [
            // Previous arrow button
            ElevatedButton(
              onPressed: _currentPage > 0 ? _previousPage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[600],
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(50, 45),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            ),

            const SizedBox(width: 10),

            // Save all button, flexible width
            Expanded(
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
                    : const Icon(Icons.save, color: Colors.white, size: 21),
                label: Text(
                  _isSaving ? 'Saving...' : 'Save All',
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cobaltBlue,
                  disabledBackgroundColor: cobaltBlue.withOpacity(0.65),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 5,
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Next arrow button
            ElevatedButton(
              onPressed: _currentPage < totalPages - 1 ? _nextPage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[600],
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(50, 45),
              ),
              child: const Icon(Icons.arrow_forward, color: Colors.white, size: 22),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = _textControllers.length;
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimations[0],
            child: Container(
              decoration: const BoxDecoration(
                color: cobaltBlue,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 25),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Center(
                          child: Text(
                            totalPages == 1
                                ? 'Edit OCR Text'
                                : 'Edit OCR Text (${_currentPage + 1}/$totalPages)',
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
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
                  SizedBox(height: 22),
                  Text('Processing OCR...', style: TextStyle(fontSize: 15)),
                ],
              ),
            )
          : totalPages == 0
              ? const Center(child: Text('No content to display'))
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      if (totalPages > 1) _buildProgressIndicator(totalPages),
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
                      if (totalPages > 1) _buildNavigationAndSaveBar(totalPages),
                      if (totalPages == 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
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
                                    : const Icon(Icons.save, color: Colors.white, size: 21),
                                label: Text(
                                  _isSaving ? 'Saving...' : 'Save',
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cobaltBlue,
                                  disabledBackgroundColor: cobaltBlue.withOpacity(0.65),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 36,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 5,
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

  @override
  void dispose() {
    _fadeController.dispose();
    for (final ctrl in _slideControllers) {
      ctrl.dispose();
    }
    _pageController.dispose();
    for (var controller in _textControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
