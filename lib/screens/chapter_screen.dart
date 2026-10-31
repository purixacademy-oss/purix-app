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
  Set<String> _completedQuizKeys = {};
  String? _expandedChapter;

  static const String studentDataUrl =
      "https://script.google.com/macros/s/AKfycbxW1tu6jkT29VBflDapForv8tLdV56-XfMeFjqX9xd-Q3hhwuwsNz_IJTexO4hEsoDTOA/exec";
  static const String supportPhone = "+919508774890";

  @override
  void initState() {
    super.initState();
    _loadChaptersAndStatus();
  }

  bool _isItemMarkedFree(dynamic row) {
    if (row == null || row is! Map) return false;
    final val = (row['Access Type'] ??
            row['access_type'] ??
            row['Access'] ??
            row['Is-free'] ??
            row['Type'] ??
            '')
        .toString()
        .trim()
        .toUpperCase();
    return val == 'FREE' || val == 'YES' || val == 'TRUE' || val == 'DEMO';
  }

  Future<void> _loadChaptersAndStatus() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    _userSubscription = prefs.getString('user_sub') ?? 'FREE';

    // Load completed quiz sets
    final keys = prefs.getKeys();
    final completed = <String>{};
    for (final k in keys) {
      if (k.startsWith("quiz_${widget.className}_${widget.subjectName}_") &&
          prefs.getBool(k) == true) {
        completed.add(k);
      }
    }
    _completedQuizKeys = completed;

    String prefix = "8th";
    if (widget.className.contains("9")) {
      prefix = "9th";
    } else if (widget.className.contains("10") ||
        widget.className.toLowerCase().contains("board")) {
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
            final chapter = (item['Chapter'] ?? item['chapter'] ?? 'General Chapter')
                .toString()
                .trim();
            if (!tempGrouped.containsKey(chapter)) {
              tempGrouped[chapter] = [];
              tempNames.add(chapter);
            }
            tempGrouped[chapter]!.add(item);
          }

          setState(() {
            _groupedChapters = tempGrouped;
            _chapterNames = tempNames;
            if (tempNames.isNotEmpty) {
              _expandedChapter = tempNames.first;
            }
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text("Classroom Access", style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "यह टेस्ट/नोट्स केवल नामांकित (Classroom Verified) छात्रों के लिए उपलब्ध है।",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            SizedBox(height: 10),
            Text(
              "नामांकन सत्यापित कराने के लिए अपने पुरीक्स एकेडमी केंद्र प्रशासन से संपर्क करें।",
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CLOSE", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.call, size: 14),
            label: const Text("CALL CENTER"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
            ),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${widget.subjectName} Chapters",
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              widget.className,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isEnrolled ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isEnrolled ? Colors.green : Colors.orange),
            ),
            child: Row(
              children: [
                Icon(isEnrolled ? Icons.verified : Icons.lock, size: 14, color: isEnrolled ? Colors.greenAccent : Colors.orangeAccent),
                const SizedBox(width: 4),
                Text(
                  isEnrolled ? "ENROLLED" : "STANDARD",
                  style: TextStyle(color: isEnrolled ? Colors.greenAccent : Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
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
                    final isFreeChapter = items.isNotEmpty && _isItemMarkedFree(items.first);
                    final isExpanded = _expandedChapter == chapterName;

                    return Card(
                      color: const Color(0xFF0E1626),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: (isEnrolled || isFreeChapter)
                              ? const Color(0xFF00F0FF).withOpacity(0.3)
                              : Colors.white10,
                        ),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: (isEnrolled || isFreeChapter)
                                  ? const Color(0xFF00F0FF).withOpacity(0.15)
                                  : Colors.white.withOpacity(0.05),
                              child: Text("${index + 1}", style: TextStyle(color: (isEnrolled || isFreeChapter) ? const Color(0xFF00F0FF) : Colors.white38, fontWeight: FontWeight.bold)),
                            ),
                            title: Text(
                              chapterName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: Text(
                              "${items.length} Questions / Practice sets",
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (isEnrolled || isFreeChapter)
                                        ? Colors.teal.withOpacity(0.2)
                                        : Colors.red.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    (isEnrolled || isFreeChapter) ? "DEMO" : "CLASSROOM ONLY",
                                    style: TextStyle(
                                      color: (isEnrolled || isFreeChapter) ? const Color(0xFF00F0FF) : Colors.orangeAccent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.white54),
                              ],
                            ),
                            onTap: () {
                              setState(() {
                                _expandedChapter = isExpanded ? null : chapterName;
                              });
                            },
                          ),

                          // Expandable Question Sets / PDF Viewer
                          if (isExpanded) ...[
                            const Divider(color: Colors.white10, height: 1),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  if (widget.mode == 'mcq') ...[
                                    // Multi-Set Quiz Grid
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: List.generate(items.length > 4 ? 4 : (items.isEmpty ? 1 : items.length), (setIdx) {
                                        final setNumber = setIdx + 1;
                                        final isSetFree = setNumber == 1 || isFreeChapter;
                                        final canTake = isEnrolled || isSetFree;
                                        final key = "quiz_${widget.className}_${widget.subjectName}_${chapterName}_set_$setNumber";
                                        final isDone = _completedQuizKeys.contains(key);

                                        return ActionChip(
                                          backgroundColor: canTake ? const Color(0xFF070B14) : Colors.white.withOpacity(0.04),
                                          side: BorderSide(color: canTake ? const Color(0xFF00F0FF).withOpacity(0.4) : Colors.white10),
                                          avatar: Icon(
                                            isDone ? Icons.check_circle : (canTake ? Icons.play_arrow : Icons.lock),
                                            size: 16,
                                            color: isDone ? Colors.greenAccent : (canTake ? const Color(0xFF00F0FF) : Colors.white24),
                                          ),
                                          label: Text(
                                            "SET $setNumber ${isSetFree ? '(DEMO)' : ''}",
                                            style: TextStyle(
                                              color: canTake ? Colors.white : Colors.white38,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          onPressed: () {
                                            if (!canTake) {
                                              _showRestrictedDialog();
                                              return;
                                            }
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
                                          },
                                        );
                                      }),
                                    ),
                                  ] else ...[
                                    // PDF Viewer Button
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          if (!isEnrolled && !isFreeChapter) {
                                            _showRestrictedDialog();
                                            return;
                                          }
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
                                              const SnackBar(content: Text("दस्तावेज़ लिंक सर्वर पर अपडेट हो रहा है")),
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                                        label: Text(
                                          (isEnrolled || isFreeChapter) ? "OPEN STUDY DOCUMENT" : "CLASSROOM LOCKED",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: (isEnrolled || isFreeChapter) ? const Color(0xFFD4AF37) : Colors.white12,
                                          foregroundColor: (isEnrolled || isFreeChapter) ? Colors.black : Colors.white38,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}