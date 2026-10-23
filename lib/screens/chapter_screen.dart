import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _isHindiLanguage = false;
  String _userSubscription = 'FREE';

  // NAYA: Questions ko Chapter ke hisaab se group karne ke liye
  List<String> _chapterNames = [];
  Map<String, List<Map<String, dynamic>>> _groupedChapters = {};
  
  // NAYA FIX: Quiz completed sets ko track karne ke liye
  Set<String> _completedQuizSets = {};

  @override
  void initState() {
    super.initState();
    _loadChaptersAndUserStatus();
  }

  Future<void> _loadChaptersAndUserStatus() async {
    // 1. Check local status (FREE ya PRO) & Completed Quizzes
    final prefs = await SharedPreferences.getInstance();
    _userSubscription = prefs.getString('user_sub') ?? 'FREE';

    Set<String> completed = {};
    for (String key in prefs.getKeys()) {
      // Local storage me saved quizzes check karna
      if (key.startsWith('quiz_${widget.className}_${widget.subjectName}_') && prefs.getBool(key) == true) {
        completed.add(key);
      }
    }

    // 2. Fetch sheet data
    String prefix = widget.className.contains("9") ? "9th" : widget.className.contains("10") ? "10th" : "8th";
    String sheetName = widget.mode == 'mcq' ? '$prefix MCQ' : widget.mode == 'notes' ? '$prefix Notes' : '$prefix practice pdf';
    final data = await SheetService.fetchSheetData(sheetName);

    // 3. Subject aur Sub-Subject ke hisaab se filter karein
    final filtered = data.where((item) {
      final sub = (item['Subject'] ?? item['subject'] ?? '').toString().trim().toLowerCase();
      final subSub = (item['Sub-subject'] ?? item['sub-subject'] ?? '').toString().trim().toLowerCase();
      return sub == widget.subjectName.toLowerCase() && subSub == widget.subSubjectName.toLowerCase();
    }).toList();

    // 4. GROUPING LOGIC: Har ek question ko uske Chapter me pack karna
    Map<String, List<Map<String, dynamic>>> tempGrouped = {};
    List<String> tempNames = [];

    for (var item in filtered) {
      final chapterName = (item['Chapter'] ?? item['chapter'] ?? 'Unknown Chapter').toString().trim();
      
      if (!tempGrouped.containsKey(chapterName)) {
        tempGrouped[chapterName] = [];
        tempNames.add(chapterName); // Chapter ka naam sirf ek baar list me aayega
      }
      tempGrouped[chapterName]!.add(item);
    }

    if (mounted) {
      setState(() {
        _completedQuizSets = completed; // Mark completed
        _groupedChapters = tempGrouped;
        _chapterNames = tempNames;
        _isLoading = false;
      });
    }
  }

  // VALIDATION: PDF Open karne se pehle check
  void _openPdfLink(String url, String title, bool isFreeContent) {
    if (!isFreeContent && _userSubscription != 'PRO') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🔒 PRO CONTENT: Please upgrade to Purix PRO from dashboard."),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 3),
        ),
      );
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

  // VALIDATION: Quiz start karne se pehle check
  void _startQuiz(String chapterName, bool isFreeContent, int setNumber) async {
    if (!isFreeContent && _userSubscription != 'PRO') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🔒 PRO QUIZ: Please upgrade to Purix PRO from dashboard."),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // QuizScreen pe bhejenge aur aane ka wait karenge (await)
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(
          selectedClass: widget.className,
          subject: widget.subjectName,
          chapter: chapterName,
          quizSetNumber: setNumber,
        ),
      ),
    );
    
    // Quiz complete karke wapas aane par screen reload karo taaki ✅ Tick dikh jaye
    _loadChaptersAndUserStatus();
  }

  @override
  Widget build(BuildContext context) {
    const neonCyan = Color(0xFF00F0FF);
    const neonGreen = Color(0xFF00FF66);

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1D),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "${widget.subSubjectName.toUpperCase()} - CHAPTERS",
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          ActionChip(
            backgroundColor: neonCyan.withOpacity(0.15),
            label: Text(
              _isHindiLanguage ? "HIN 🇮🇳" : "ENG 🌐",
              style: const TextStyle(color: neonCyan, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            onPressed: () => setState(() => _isHindiLanguage = !_isHindiLanguage),
          ),
          const SizedBox(width: 8)
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: neonCyan))
          : _chapterNames.isEmpty
              ? const Center(child: Text("No content found.", style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _chapterNames.length,
                  itemBuilder: (context, index) {
                    final chapterName = _chapterNames[index];
                    final chapterItems = _groupedChapters[chapterName]!;
                    final firstItem = chapterItems.first;
                    
                    // Access Type check (Poore chapter ke liye pehle item se padhna)
                    final accessType = (firstItem['Access Type'] ?? firstItem['Is-free'] ?? firstItem['is_free'] ?? 'PAID').toString().trim().toUpperCase();
                    final bool isFreeContent = accessType == 'FREE';
                    final bool hasAccess = isFreeContent || _userSubscription == 'PRO';

                    // Math: Calculate Sets
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
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent), // Hides the annoying line
                        child: ExpansionTile(
                          iconColor: neonCyan,
                          collapsedIconColor: Colors.white54,
                          leading: Icon(
                            hasAccess ? Icons.check_circle_outline : Icons.lock_outline,
                            color: hasAccess ? neonCyan : Colors.redAccent,
                            size: 24,
                          ),
                          title: Text(
                            chapterName,
                            style: TextStyle(
                              color: hasAccess ? Colors.white : Colors.white60,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
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
                            
                            // Agar MCQ Mode hai, to Sets dikhayein
                            if (widget.mode == 'mcq')
                              ...List.generate(totalSets, (setIndex) {
                                int setNumber = setIndex + 1;
                                int qInThisSet = (setNumber == totalSets && totalQuestions % 20 != 0) 
                                    ? totalQuestions % 20 
                                    : 20;

                                // 🚀 COMPLETE CHECK: Kya user ne ye set diya hai?
                                String setKey = 'quiz_${widget.className}_${widget.subjectName}_${chapterName}_set_${setNumber}_completed';
                                bool isCompleted = _completedQuizSets.contains(setKey);

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                                  title: Row(
                                    children: [
                                      Text(
                                        "SET 0$setNumber",
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      if (isCompleted) ...[
                                        const SizedBox(width: 8),
                                        const Icon(Icons.check_circle_rounded, color: neonGreen, size: 16),
                                        const SizedBox(width: 4),
                                        const Text("COMPLETED", style: TextStyle(color: neonGreen, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                                      ]
                                    ],
                                  ),
                                  subtitle: Text(
                                    "$qInThisSet Questions",
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                  trailing: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: hasAccess ? neonGreen : Colors.grey[800],
                                      minimumSize: const Size(80, 32),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                    onPressed: () => _startQuiz(chapterName, isFreeContent, setNumber),
                                    child: Text(
                                      hasAccess ? (isCompleted ? "RETRY" : "START") : "LOCKED",
                                      style: TextStyle(
                                        color: hasAccess ? Colors.black : Colors.white54,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                );
                              })
                              
                            // Agar PDF/Notes Mode hai, to Document link dikhayein
                            else
                              ...List.generate(chapterItems.length, (itemIndex) {
                                final item = chapterItems[itemIndex];
                                final pdfLinkHin = item['Drive-link-hin'] ?? item['Drive_link_hin'] ?? '';
                                final pdfLinkEng = item['Drive-link-eng'] ?? item['Drive_link_eng'] ?? '';
                                final selectedPdfLink = _isHindiLanguage 
                                    ? (pdfLinkHin.isNotEmpty ? pdfLinkHin : pdfLinkEng) 
                                    : (pdfLinkEng.isNotEmpty ? pdfLinkEng : pdfLinkHin);
                                
                                String partName = chapterItems.length > 1 ? "Part ${itemIndex + 1}" : "View Document";

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                                  title: Text(
                                    partName,
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      hasAccess ? (widget.mode == 'notes' ? Icons.menu_book : Icons.picture_as_pdf) : Icons.lock,
                                      color: hasAccess ? neonCyan : Colors.redAccent,
                                    ),
                                    onPressed: () => _openPdfLink(selectedPdfLink, "$chapterName - $partName", isFreeContent),
                                  ),
                                );
                              })
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}