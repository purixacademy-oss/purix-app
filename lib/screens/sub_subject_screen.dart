import 'package:flutter/material.dart';
import '../services/sheet_service.dart';
import 'chapter_screen.dart'; // Nayi file ko link kiya

class SubSubjectScreen extends StatefulWidget {
  final String className;
  final String subjectName;
  final String mode;

  const SubSubjectScreen({super.key, required this.className, required this.subjectName, required this.mode});

  @override
  State<SubSubjectScreen> createState() => _SubSubjectScreenState();
}

class _SubSubjectScreenState extends State<SubSubjectScreen> {
  bool _isLoading = true;
  List<String> _uniqueSubSubjects = [];

  @override
  void initState() {
    super.initState();
    _loadSubSubjects();
  }

  Future<void> _loadSubSubjects() async {
    String prefix = widget.className.contains("9") ? "9th" : widget.className.contains("10") ? "10th" : "8th";
    String sheetName = widget.mode == 'mcq' ? '$prefix MCQ' : widget.mode == 'notes' ? '$prefix Notes' : '$prefix practice pdf';
    
    final data = await SheetService.fetchSheetData(sheetName);
    
    // Sirf Sub-Subjects (Physics, Chemistry) filter karna
    final Set<String> subSubs = {};
    for (var row in data) {
      final sub = (row['Subject'] ?? row['subject'] ?? '').toString().trim();
      if (sub.toLowerCase() == widget.subjectName.toLowerCase()) {
        final subSubject = (row['Sub-subject'] ?? row['sub-subject'] ?? '').toString().trim();
        if (subSubject.isNotEmpty) subSubs.add(subSubject);
      }
    }

    if (mounted) {
      setState(() {
        _uniqueSubSubjects = subSubs.toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1D), elevation: 0, iconTheme: const IconThemeData(color: Colors.white),
        title: Text("${widget.subjectName.toUpperCase()} - BRANCHES", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00F0FF)))
          : _uniqueSubSubjects.isEmpty
              ? const Center(child: Text("No branches found.", style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _uniqueSubSubjects.length,
                  itemBuilder: (context, index) {
                    final subSub = _uniqueSubSubjects[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: const Color(0xFF0B111E), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
                      child: ListTile(
                        title: Text(subSub.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                        onTap: () {
                          // Yahan se nayi chapter_screen par jayega
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChapterScreen(className: widget.className, subjectName: widget.subjectName, subSubjectName: subSub, mode: widget.mode),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}