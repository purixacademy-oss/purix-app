import 'package:flutter/material.dart';
import '../services/sheet_service.dart';
import 'pdf_viewer_screen.dart';

class FreeContentScreen extends StatefulWidget {
  final String selectedClass;

  const FreeContentScreen({super.key, required this.selectedClass});

  @override
  State<FreeContentScreen> createState() => _FreeContentScreenState();
}

class _FreeContentScreenState extends State<FreeContentScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _freeItems = [];

  @override
  void initState() {
    super.initState();
    _loadFreeContent();
  }

  Future<void> _loadFreeContent() async {
    setState(() => _isLoading = true);

    String prefix = "8th";
    if (widget.selectedClass.contains("9")) {
      prefix = "9th";
    } else if (widget.selectedClass.contains("10")) {
      prefix = "10th";
    }

    final data = await SheetService.fetchSheetData('$prefix practice pdf');

    final List<Map<String, dynamic>> freeList = [];
    for (var item in data) {
      final access = (item['Access Type'] ?? item['Is-free'] ?? item['is_free'] ?? '').toString().trim().toUpperCase();
      if (access == 'FREE') {
        freeList.add(item);
      }
    }

    if (mounted) {
      setState(() {
        _freeItems = freeList;
        _isLoading = false;
      });
    }
  }

  void _openPdf(String url, String title) {
    if (url.trim().isEmpty || url.trim() == 'N/A') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link not available.")));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(pdfUrl: url, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const darkVoid = Color(0xFF070B14);
    const neonCyan = Color(0xFF00F0FF);
    const neonGold = Color(0xFFFFB800);

    return Scaffold(
      backgroundColor: darkVoid,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "FREE MATRIX • OPEN SYLLABUS",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: neonGold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: neonCyan))
          : _freeItems.isEmpty
              ? const Center(
                  child: Text(
                    "No free preview items listed in sheet.",
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _freeItems.length,
                  itemBuilder: (context, index) {
                    final item = _freeItems[index];
                    final chapterName = (item['Chapter'] ?? item['chapter'] ?? 'Chapter').toString().trim();
                    final subjectName = (item['Subject'] ?? item['subject'] ?? 'Subject').toString().trim();
                    final pdfLink = (item['Link'] ?? item['link'] ?? '').toString().trim();

                    return Card(
                      color: const Color(0xFF0B111E),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: neonCyan.withOpacity(0.3), width: 1),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: const CircleAvatar(
                          backgroundColor: Colors.redAccent,
                          child: Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
                        ),
                        title: Text(chapterName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Subject: $subjectName (FREE ACCESS)',
                          style: TextStyle(color: neonCyan.withOpacity(0.8), fontSize: 11, fontFamily: 'monospace'),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: neonCyan,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onPressed: () => _openPdf(pdfLink, chapterName),
                          child: const Text('View PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}