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
  List<dynamic> _freeItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFreeContent();
  }

  Future<void> _fetchFreeContent() async {
    try {
      // Class ke hisab se exact sheet ka naam set karna (e.g. '10th Notes')
      String prefix = widget.selectedClass.contains("9") ? "9th" : widget.selectedClass.contains("10") ? "10th" : "8th";
      final sheetName = "$prefix Notes";
      
      final data = await SheetService.fetchSheetData(sheetName);

      // Notes sheet me se sirf unhe filter karna jinka Access Type "FREE" hai
      final freeFiltered = data.where((item) {
        final access = (item['Access Type'] ?? item['Is-free'] ?? item['is_free'] ?? '').toString().trim();
        return access.toUpperCase() == 'FREE';
      }).toList();

      if (!mounted) return;
      setState(() {
        _freeItems = freeFiltered;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openPdf(String url, String title) {
    // STRICT CHECK: Agar URL khali h, N/A h, ya usme http nahi h, to mana kar do
    if (url.trim().isEmpty || url.trim().toUpperCase() == 'N/A' || !url.contains('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF link not available for this resource.')),
      );
      return;
    }
    
    // Naye PDF Viewer me bhej dein
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(
          pdfUrl: url.trim(),
          title: title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const neonCyan = Color(0xFF00F0FF);
    const darkVoid = Color(0xFF070B14);

    return Scaffold(
      backgroundColor: darkVoid,
      appBar: AppBar(
        title: Text('${widget.selectedClass} - Free Matrix', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0A0F1D),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: neonCyan))
          : _freeItems.isEmpty
              ? const Center(
                  child: Text(
                    'No Free Content Available Yet.\n(Ensure Google Sheet has "Access Type" = "FREE")',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 13, fontFamily: 'monospace'),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _freeItems.length,
                  itemBuilder: (context, index) {
                    final item = _freeItems[index];
                    final chapterName = item['Chapter'] ?? item['chapter'] ?? 'Free Resource';
                    final subjectName = item['Subject'] ?? item['subject'] ?? 'General';
                    
                    // PDF link uthana
                    final pdfLinkHin = item['Drive-link-hin'] ?? item['Drive_link_hin'] ?? '';
                    final pdfLinkEng = item['Drive-link-eng'] ?? item['Drive_link_eng'] ?? '';
                    final pdfLink = pdfLinkEng.isNotEmpty ? pdfLinkEng : pdfLinkHin;

                    return Card(
                      color: const Color(0xFF0B111E),
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: neonCyan.withValues(alpha: 0.3), width: 1),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: const CircleAvatar(
                          backgroundColor: Colors.redAccent,
                          child: Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
                        ),
                        title: Text(
                          chapterName,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Subject: $subjectName (FREE ACCESS)',
                          style: TextStyle(color: neonCyan.withValues(alpha: 0.8), fontSize: 11, fontFamily: 'monospace'),
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