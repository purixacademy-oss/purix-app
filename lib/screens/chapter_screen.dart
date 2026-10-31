import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'pdf_viewer_screen.dart';
import 'quiz_screen.dart';

class ChapterScreen extends StatefulWidget {
  final String className;
  final String subjectName;
  final String subSubjectName;
  final String mode; // 'mcq', 'practice', or 'notes'

  const ChapterScreen({
    super.key,
    required this.className,
    required this.subjectName,
    required this.subSubjectName,
    required this.mode,
  });

  @override
  State<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends State<ChapterScreen> {
  bool _isLoading = true;
  String _userSubscription = 'FREE'; // 'PRO' means Classroom Verified
  Map<String, List<dynamic>> _groupedChapters = {};
  List<String> _chapterNames = [];

  static const String studentDataUrl =
      "https://script.google.com/macros/s/AKfycbxW1tu6jkT29VBflDapForv8tLdV56-XfMeFjqX9xd-Q3hhwuwsNz_IJTexO4hEsoDTOA/exec";

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  bool _isItemMarkedFree(dynamic row) {
    if (row == null || row is! Map) return false;
    final val = (row['Access Type'] ?? row['access_type'] ?? row['Access'] ?? row['Is-free'] ?? row['Type'] ?? '').toString().trim().toUpperCase();
    return val == 'FREE' || val == 'YES' || val == 'TRUE' || val == 'DEMO';
  }

  Future<void> _loadChapters() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    _userSubscription = prefs.getString('user_sub') ?? 'FREE';

    String prefix = "8th";
    if (widget.className.contains("9")) {
      prefix = "9th";
    } else if (widget.className.contains("10") || widget.className.toLowerCase().contains("board")) {
      prefix = "10th";
    }

    String sheetName = widget.mode == 'mcq'
        ? "$prefix MCQ"
        : widget.mode == 'notes'
            ? "$prefix Notes"
            : "$prefix practice pdf";

    try {
      final url = "$studentDataUrl?sheet=${Uri.encodeComponent(sheetName)}";
      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          final Map<String, List<dynamic>> tempGrouped = {};
          final List<String> tempNames = [];

          for (final item in data) {
            final chapter = (item['Chapter'] ?? item['chapter'] ?? 'General Chapter').toString().trim();
            if (!tempGrouped.containsKey(chapter)) {
              tempGrouped[chapter] = [];
              tempNames.push(chapter);
            }
            tempGrouped[chapter]!.add(item);
          }

          setState(() {
            _groupedChapters = tempGrouped;
            _chapterNames = tempNames;
          });
        }
      }
    } catch (_) {}

    setState(() => _isLoading = false);
  }

  void _showRestrictedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0E1626),
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text("Classroom Access", style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Text(
          "यह सामग्री केवल नामांकित (Classroom Verified) छात्रों के लिए उपलब्ध है। अपने केंद्र से संपर्क करें।",
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Color(0xFF00F0FF))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnrolled = _userSubscription == 'PRO';

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1626),
        title: Text(
          "${widget.subSubjectName} - Chapters",
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00F0FF)))
          : _chapterNames.isEmpty
              ? const Center(child: Text("कोई अध्याय नहीं मिला", style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _chapterNames.length,
                  itemBuilder: (context, index) {
                    final chapterName = _chapterNames[index];
                    final items = _groupedChapters[chapterName] ?? [];
                    final isFreeItem = items.isNotEmpty && _isItemMarkedFree(items.first);
                    final hasAccess = isEnrolled || isFreeItem;

                    return Card(
                      color: const Color(0xFF0E1626),
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: hasAccess ? const Color(0xFF00F0FF).withOpacity(0.3) : Colors.white10,
                        ),
                      ),
                      child: ListTile(
                        leading: Icon(
                          widget.mode == 'mcq' ? Icons.quiz : Icons.menu_book,
                          color: hasAccess ? const Color(0xFF00F0FF) : Colors.white24,
                        ),
                        title: Text(
                          chapterName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          "${items.length} Questions / Sets",
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: hasAccess ? Colors.teal.withOpacity(0.2) : Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            hasAccess
                                ? (isEnrolled ? "FULL ACCESS" : "DEMO")
                                : "CLASSROOM ONLY",
                            style: TextStyle(
                              color: hasAccess ? const Color(0xFF00F0FF) : Colors.orangeAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        onTap: () {
                          if (!hasAccess) {
                            _showRestrictedDialog();
                            return;
                          }

                          if (widget.mode == 'mcq') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => QuizScreen(
                                  chapterName: chapterName,
                                  className: widget.className,
                                  subjectName: widget.subjectName,
                                ),
                              ),
                            );
                          } else {
                            final pdfUrl = (items.first['PDF Link'] ?? items.first['pdf_link'] ?? items.first['Link'] ?? '').toString();
                            if (pdfUrl.contains("http")) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PdfViewerScreen(
                                    pdfUrl: pdfUrl,
                                    title: chapterName,
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("दस्तावेज़ लिंक उपलब्ध नहीं है")),
                              );
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

extension on List<String> {
  void push(String element) => add(element);
}