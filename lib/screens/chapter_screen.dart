import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/sheet_service.dart';
import 'quiz_screen.dart';
import 'pdf_viewer_screen.dart';

class ChapterScreen extends StatefulWidget {
  final String className;
  final String subjectName;
  final String subSubjectName;
  final String mode;

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
  String _userSubscription = 'FREE';

  List<String> _chapterNames = [];
  Map<String, List<Map<String, dynamic>>> _groupedChapters = {};
  Set<String> _completedQuizSets = {};

  @override
  void initState() {
    super.initState();
    _loadChaptersAndUserStatus();
  }

  Future<void> _loadChaptersAndUserStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _userSubscription = prefs.getString('user_sub') ?? 'FREE';

    Set<String> completed = {};
    for (String key in prefs.getKeys()) {
      if (key.startsWith('quiz_${widget.className}_${widget.subjectName}_') && prefs.getBool(key) == true) {
        completed.add(key);
      }
    }

    String prefix = widget.className.contains("9") ? "9th" : widget.className.contains("10") ? "10th" : "8th";
    String sheetName = widget.mode == 'mcq' ? '$prefix MCQ' : widget.mode == 'notes' ? '$prefix Notes' : '$prefix practice pdf';
    final data = await SheetService.fetchSheetData(sheetName);

    final filtered = data.where((item) {
      final sub = (item['Subject'] ?? item['subject'] ?? '').toString().trim().toLowerCase();
      final subSub = (item['Sub-subject'] ?? item['sub-subject'] ?? '').toString().trim().toLowerCase();
      return sub == widget.subjectName.toLowerCase() && subSub == widget.subSubjectName.toLowerCase();
    }).toList();

    Map<String, List<Map<String, dynamic>>> tempGrouped = {};
    List<String> tempNames = [];

    for (var item in filtered) {
      final chapterName = (item['Chapter'] ?? item['chapter'] ?? 'Unknown Chapter').toString().trim();
      
      if (!tempGrouped.containsKey(chapterName)) {
        tempGrouped[chapterName] = [];
        tempNames.add(chapterName);
      }
      tempGrouped[chapterName]!.add(item);
    }

    if (mounted) {
      setState(() {
        _completedQuizSets = completed;
        _groupedChapters = tempGrouped;
        _chapterNames = tempNames;
        _isLoading = false;
      });
    }
  }

  // Indus App Store Compliant Dialog Popup
  void _showClassroomStudentsDialog() {
    const neonCyan = Color(0xFF00F0FF);
    const neonGold = Color(0xFFFFB800);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A0F1D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: neonGold, width: 1.5),
          ),
          title: const Column(
            children: [
              Icon(Icons.shield_rounded, color: neonGold, size: 36),
              SizedBox(height: 8),
              Text(
                "Classroom Students Only",
                style: TextStyle(color: neonGold, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "This section is exclusively for registered students of Purix Academy. Access is provided at our classroom center upon enrollment.",
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF101726),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Center:", style: TextStyle(color: Colors.white60, fontSize: 11)),
                        Text("Purix Classroom Center", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Batch Material:", style: TextStyle(color: Colors.white60, fontSize: 11)),
                        Text("${widget.className} • ${widget.subjectName}", style: const TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: neonCyan,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      Navigator.pop(dialogCtx);
                      try {
                        await launchUrl(Uri.parse("tel:+919508774890"), mode: LaunchMode.externalApplication);
                      } catch (_) {}
                    },
                    icon: const Icon(Icons.phone_rounded, size: 16),
                    label: const Text(
                      "CONTACT CENTER",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text("CLOSE", style: TextStyle(color: Colors.white38, fontSize: 11)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _openPdfLink(String url, String title, bool isFreeContent) {
    if (!isFreeContent && _userSubscription != 'PRO') {
      _showClassroomStudentsDialog();
      return;
    }

    if (url.trim().isEmpty || url.trim() == 'N/A') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link not available.")));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(
          pdfUrl: url,
          title: title,
        ),
      ),
    );
  }

  void _startQuiz(String chapterName, bool isFreeContent, int setNumber) async {
    if (!isFreeContent && _userSubscription != 'PRO') {
      _showClassroomStudentsDialog();
      return;
    }

    final allQuestions = _groupedChapters[chapterName] ?? [];
    int startIndex = (setNumber - 1) * 20;
    int endIndex = startIndex + 20;
    if (endIndex > allQuestions.length) endIndex = allQuestions.length;

    final setQuestions = allQuestions.sublist(startIndex, endIndex);

    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(
          className: widget.className,
          subjectName: widget.subjectName,
          subSubjectName: widget.subSubjectName,
          chapterName: chapterName,
          questions: setQuestions,
          setNumber: setNumber,
        ),
      ),
    );

    if (completed == true) {
      _loadChaptersAndUserStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    const darkVoid = Color(0xFF070B14);
    const neonCyan = Color(0xFF00F0FF);
    const neonGreen = Color(0xFF00FF88);

    return Scaffold(
      backgroundColor: darkVoid,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.subSubjectName.toUpperCase(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Color(0xFFD4AF37),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: neonCyan))
          : _chapterNames.isEmpty
              ? const Center(
                  child: Text(
                    "No chapters found for this subject.",
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _chapterNames.length,
                  itemBuilder: (context, index) {
                    final chapterName = _chapterNames[index];
                    final chapterItems = _groupedChapters[chapterName]!;
                    final firstItem = chapterItems.first;
                    
                    final accessType = (firstItem['Access Type'] ?? firstItem['Is-free'] ?? firstItem['is_free'] ?? 'PAID').toString().trim().toUpperCase();
                    // Rule: Har class me pehle 2 chapters par "Free Demo" open rehta hai
                    final bool isFreeContent = accessType == 'FREE' || index < 2;
                    final bool hasAccess = isFreeContent || _userSubscription == 'PRO';

                    int totalQuestions = chapterItems.length;
                    int totalSets = (totalQuestions / 20).ceil();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B111E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: hasAccess ? Colors.white12 : Colors.redAccent.withOpacity(0.3),
                        ),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          iconColor: neonCyan,
                          collapsedIconColor: Colors.white54,
                          leading: Icon(
                            hasAccess ? Icons.check_circle_outline : Icons.lock_outline,
                            color: hasAccess ? neonCyan : Colors.redAccent,
                            size: 24,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  chapterName,
                                  style: TextStyle(
                                    color: hasAccess ? Colors.white : Colors.white60,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isFreeContent) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: neonGreen.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: neonGreen.withOpacity(0.4)),
                                  ),
                                  child: const Text(
                                    "FREE DEMO",
                                    style: TextStyle(color: neonGreen, fontSize: 8.5, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: widget.mode == 'mcq'
                              ? Text(
                                  "$totalQuestions Questions • $totalSets Sets",
                                  style: TextStyle(color: neonCyan.withOpacity(0.7), fontSize: 11, fontFamily: 'monospace'),
                                )
                              : Text(
                                  "PDF Material",
                                  style: TextStyle(color: neonCyan.withOpacity(0.7), fontSize: 11, fontFamily: 'monospace'),
                                ),
                          children: [
                            const Divider(color: Colors.white10, height: 1),
                            if (widget.mode == 'mcq')
                              ...List.generate(totalSets, (setIndex) {
                                int setNumber = setIndex + 1;
                                int qInThisSet = (setNumber == totalSets && totalQuestions % 20 != 0) 
                                    ? totalQuestions % 20 
                                    : 20;

                                String setKey = 'quiz_${widget.className}_${widget.subjectName}_${chapterName}_set_${setNumber}_completed';
                                bool isCompleted = _completedQuizSets.contains(setKey);

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                                  title: Row(
                                    children: [
                                      Text("Set $setNumber", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                      const SizedBox(width: 8),
                                      if (isCompleted)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: neonGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                          child: const Text("COMPLETED", style: TextStyle(color: neonGreen, fontSize: 9, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text("$qInThisSet Questions", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                  trailing: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: hasAccess ? neonCyan.withOpacity(0.15) : Colors.redAccent.withOpacity(0.15),
                                      foregroundColor: hasAccess ? neonCyan : Colors.redAccent,
                                      side: BorderSide(color: hasAccess ? neonCyan : Colors.redAccent),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      minimumSize: Size.zero,
                                    ),
                                    onPressed: () => _startQuiz(chapterName, isFreeContent, setNumber),
                                    child: Text(hasAccess ? "START TEST" : "ENROLL", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                );
                              })
                            else
                              ...chapterItems.map((item) {
                                final pdfTitle = (item['Title'] ?? item['title'] ?? 'Study Notes').toString().trim();
                                final pdfLink = (item['Link'] ?? item['link'] ?? '').toString().trim();

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                                  leading: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFD4AF37), size: 20),
                                  title: Text(pdfTitle, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                  trailing: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: hasAccess ? const Color(0xFFD4AF37).withOpacity(0.15) : Colors.redAccent.withOpacity(0.15),
                                      foregroundColor: hasAccess ? const Color(0xFFD4AF37) : Colors.redAccent,
                                      side: BorderSide(color: hasAccess ? const Color(0xFFD4AF37) : Colors.redAccent),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      minimumSize: Size.zero,
                                    ),
                                    onPressed: () => _openPdfLink(pdfLink, pdfTitle, isFreeContent),
                                    child: Text(hasAccess ? "VIEW PDF" : "ENROLL", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}