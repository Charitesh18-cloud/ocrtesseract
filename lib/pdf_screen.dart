import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:screenshot/screenshot.dart';

class PDFScreen extends StatefulWidget {
  const PDFScreen({super.key});
  @override
  State<PDFScreen> createState() => _PDFScreenState();
}

class _PDFScreenState extends State<PDFScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final ScreenshotController _screenshotController = ScreenshotController();
  final GlobalKey _pdfKey = GlobalKey();

  int _currentPage = 0;
  bool _isProcessing = false;
  bool _selectionMode = false;
  Set<int> _selectedPages = <int>{};

  List<String> _imagePaths = [];
  String? _pdfPath;
  PDFViewController? _pdfViewController;
  int _totalPages = 0;
  bool _isPdfReady = false;

  String _language = 'eng';
  String _languageName = 'English';
  String _type = 'images';

  static const Color cobaltBlue = Color(0xFF0047AB);

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late List<AnimationController> _slideControllers;
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadArguments());
  }

  void _initAnimations() {
    _fadeController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_fadeController);

    int animCount = 8;
    _slideControllers = List.generate(
      animCount,
      (i) => AnimationController(duration: const Duration(milliseconds: 450), vsync: this),
    );

    _slideAnimations = _slideControllers
        .map((ctrl) => Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOut)))
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

  void _loadArguments() {
    final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (arguments != null) {
      setState(() {
        _language = arguments['language'] ?? 'eng';
        _languageName = arguments['languageName'] ?? 'English';
        _type = arguments['type'] ?? 'images';
        _pdfPath = arguments['pdfPath'];
        _imagePaths = List<String>.from(arguments['imagePaths'] ?? []);
      });
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectedPages.clear();
    });
  }

  void _togglePageSelection(int index) {
    setState(() {
      if (_selectedPages.contains(index)) {
        _selectedPages.remove(index);
      } else {
        _selectedPages.add(index);
      }
    });
  }

  void _selectAllPages() {
    setState(() {
      _selectedPages = Set<int>.from(List.generate(_totalPages, (i) => i));
    });
  }

  void _deselectAllPages() {
    setState(() {
      _selectedPages.clear();
    });
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      if (_type == 'pdf') {
        _pdfViewController?.setPage(_currentPage + 1);
      } else {
        _pageController.nextPage(
            duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      if (_type == 'pdf') {
        _pdfViewController?.setPage(_currentPage - 1);
      } else {
        _pageController.previousPage(
            duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    }
  }

  Future<void> _processCurrentPage() async {
    if (_type == 'pdf') {
      await _processPDFPages([_currentPage]);
    } else {
      await _processImagePages([_currentPage]);
    }
  }

  Future<void> _processSelectedPages() async {
    if (_selectedPages.isEmpty) {
      _showSnackBar('Please select at least one page');
      return;
    }
    List<int> sorted = _selectedPages.toList()..sort();
    if (_type == 'pdf') {
      await _processPDFPages(sorted);
    } else {
      await _processImagePages(sorted);
    }
  }

  Future<void> _processPDFPages(List<int> pageIndices) async {
    setState(() => _isProcessing = true);
    try {
      List<String> captured = [];
      for (int pageIndex in pageIndices) {
        await _pdfViewController?.setPage(pageIndex);
        await Future.delayed(const Duration(milliseconds: 500));
        String? imagePath = await _capturePDFPage(pageIndex);
        if (imagePath != null) captured.add(imagePath);
      }
      if (captured.isNotEmpty) {
        _navigateToEditScreen(captured);
      } else {
        _showSnackBar('No pages were processed successfully');
      }
    } catch (e) {
      _showSnackBar('Error processing PDF pages: $e');
    } finally {
      setState(() {
        _isProcessing = false;
        _selectionMode = false;
        _selectedPages.clear();
      });
    }
  }

  Future<void> _processImagePages(List<int> pageIndices) async {
    setState(() => _isProcessing = true);
    try {
      List<String> selected = [];
      for (int idx in pageIndices) {
        if (idx < _imagePaths.length) selected.add(_imagePaths[idx]);
      }
      if (selected.isNotEmpty) {
        _navigateToEditScreen(selected);
      } else {
        _showSnackBar('No images were processed successfully');
      }
    } catch (e) {
      _showSnackBar('Error processing image pages: $e');
    } finally {
      setState(() {
        _isProcessing = false;
        _selectionMode = false;
        _selectedPages.clear();
      });
    }
  }

  Future<String?> _capturePDFPage(int pageNumber) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/pdf_page_${pageNumber + 1}_${DateTime.now().millisecondsSinceEpoch}.png');
      await Future.delayed(const Duration(milliseconds: 300));
      final imageBytes = await _screenshotController.capture();
      if (imageBytes != null) {
        await tempFile.writeAsBytes(imageBytes);
        return tempFile.path;
      }
    } catch (_) {}
    return null;
  }

  void _navigateToEditScreen(List<String> imagePaths) {
    Navigator.pushNamed(
      context,
      '/edit',
      arguments: {
        'imagePaths': imagePaths,
        'language': _language,
        'languageName': _languageName,
        'type': 'images',
        'isMultiplePages': imagePaths.length > 1,
      },
    );
  }

  void _showSnackBar(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Widget _buildPDFView() {
    if (_pdfPath == null) return const Center(child: Text('No PDF selected'));
    return SlideTransition(
      position: _slideAnimations[2],
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Screenshot(
                controller: _screenshotController,
                child: RepaintBoundary(
                  key: _pdfKey,
                  child: GestureDetector(
                    onHorizontalDragEnd: (details) {
                      if (details.primaryVelocity! > 0) {
                        _previousPage();
                      } else if (details.primaryVelocity! < 0) {
                        _nextPage();
                      }
                    },
                    child: Container(
                      color: Colors.white,
                      child: PDFView(
                        filePath: _pdfPath!,
                        enableSwipe: false,
                        swipeHorizontal: false,
                        autoSpacing: false,
                        pageFling: false,
                        pageSnap: false,
                        defaultPage: _currentPage,
                        fitPolicy: FitPolicy.BOTH,
                        preventLinkNavigation: true,
                        backgroundColor: Colors.white,
                        onRender: (pages) {
                          setState(() {
                            _totalPages = pages ?? 0;
                            _isPdfReady = true;
                          });
                        },
                        onError: (error) => _showSnackBar('PDF Error: $error'),
                        onPageError: (page, error) => _showSnackBar('Page Error: $error'),
                        onViewCreated: (PDFViewController c) {
                          _pdfViewController = c;
                        },
                        onPageChanged: (int? page, int? total) {
                          if (page != null && mounted) {
                            setState(() => _currentPage = page);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
              if (_selectionMode) _buildSelectionOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageView() {
    if (_imagePaths.isEmpty) return const Center(child: Text('No images selected'));
    return SlideTransition(
      position: _slideAnimations[2],
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentPage = index),
        itemCount: _imagePaths.length,
        itemBuilder: (context, index) => _buildImagePage(index),
        scrollDirection: Axis.horizontal,
        reverse: true,
      ),
    );
  }

  Widget _buildImagePage(int index) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 1,
              maxScale: 3,
              child: Container(
                color: Colors.white,
                child: Image.file(
                  File(_imagePaths[index]),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red),
                        SizedBox(height: 8),
                        Text('Error loading image'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_selectionMode) _buildSelectionOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionOverlay() {
    return Positioned(
      top: 20,
      right: 20,
      child: GestureDetector(
        onTap: () => _togglePageSelection(_currentPage),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: Offset(0, 2))
            ],
          ),
          child: Icon(
            _selectedPages.contains(_currentPage) ? Icons.check_box : Icons.check_box_outline_blank,
            color: _selectedPages.contains(_currentPage) ? cobaltBlue : Colors.grey[600],
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionControls() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isProcessing
                ? null
                : () {
                    setState(() {
                      _selectionMode = false;
                      _selectedPages.clear();
                    });
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[600],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: const Text('Cancel', style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isProcessing || _selectedPages.isEmpty ? null : _processSelectedPages,
            style: ElevatedButton.styleFrom(
              backgroundColor: cobaltBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 23,
                    height: 23,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.1))
                : Text(
                    'Extract Selected (${_selectedPages.length})',
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Previous button: icon only
        Expanded(
          child: ElevatedButton(
            onPressed: _isProcessing || _currentPage <= 0 ? null : _previousPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[600],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 23),
          ),
        ),
        const SizedBox(width: 12),
        // Extract text button (with label)
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _processCurrentPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: cobaltBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 23,
                    height: 23,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.1))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.text_fields, color: Colors.white, size: 19),
                      SizedBox(width: 7),
                      Text('Extract Text', style: TextStyle(color: Colors.white, fontSize: 15))
                    ],
                  ),
          ),
        ),
        const SizedBox(width: 12),
        // Next button: icon only
        Expanded(
          child: ElevatedButton(
            onPressed: _isProcessing || _currentPage >= _totalPages - 1 ? null : _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[600],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: const Icon(Icons.arrow_forward, color: Colors.white, size: 23),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _totalPages = _type == 'pdf' ? _totalPages : _imagePaths.length;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            decoration: const BoxDecoration(
              color: cobaltBlue,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: cobaltBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      SlideTransition(
                        position: _slideAnimations[0],
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 23),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Center(
                          child: SlideTransition(
                            position: _slideAnimations[1],
                            child: Text(
                              _type == 'pdf' ? 'PDF Pages' : 'Multiple Images',
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_totalPages > 1)
                            SlideTransition(
                              position: _slideAnimations[1],
                              child: IconButton(
                                icon: Icon(
                                  _selectionMode ? Icons.close : Icons.checklist,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                onPressed: _toggleSelectionMode,
                              ),
                            ),
                          if (_selectionMode && _totalPages > 1)
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.white, size: 22),
                              onSelected: (value) {
                                if (value == 'selectAll') _selectAllPages();
                                if (value == 'deselectAll') _deselectAllPages();
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'selectAll',
                                  child: Row(
                                    children: [
                                      Icon(Icons.select_all),
                                      SizedBox(width: 8),
                                      Text('Select All')
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'deselectAll',
                                  child: Row(
                                    children: [
                                      Icon(Icons.deselect),
                                      SizedBox(width: 8),
                                      Text('Deselect All')
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Column(
            children: [
              SlideTransition(
                position: _slideAnimations[3],
                child: Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('OCR Language: $_languageName',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text(
                              _totalPages > 0
                                  ? 'Page ${_currentPage + 1} of $_totalPages'
                                  : 'Loading...',
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                            if (_selectionMode && _selectedPages.isNotEmpty)
                              Text(
                                '${_selectedPages.length} page${_selectedPages.length > 1 ? 's' : ''} selected',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cobaltBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: cobaltBlue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _type.toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_totalPages > 0)
                SlideTransition(
                  position: _slideAnimations[3],
                  child: Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: List.generate(_totalPages, (index) {
                        return Expanded(
                          child: Container(
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: _selectedPages.contains(index)
                                  ? Colors.green[400]
                                  : (index == _currentPage ? cobaltBlue : Colors.grey[300]),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: _type == 'pdf' ? _buildPDFView() : _buildImageView(),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: 10,
                  right: 10,
                  top: 10,
                  bottom: MediaQuery.of(context).viewInsets.bottom > 0
                      ? MediaQuery.of(context).viewInsets.bottom + 10
                      : MediaQuery.of(context).viewPadding.bottom + 10,
                ),
                child: SlideTransition(
                  position: _slideAnimations[4],
                  child: _selectionMode ? _buildSelectionControls() : _buildNavigationControls(),
                ),
              ),
            ],
          ),
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
    super.dispose();
  }
}
