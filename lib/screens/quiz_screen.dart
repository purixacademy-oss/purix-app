import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sheet_service.dart';

class QuizScreen extends StatefulWidget {
  final String selectedClass;
  final String subject;
  final String chapter;
  final int quizSetNumber;

  const QuizScreen({
    super.key,
    String? selectedClass,
    String? className,
    String? subject,
    String? subjectName,
    String? chapter,
    String? chapterName,
    int? quizSetNumber,
    int? setNumber,
  })  : selectedClass = selectedClass ?? className ?? 'Class 10th',
        subject = subjectName ?? subject ?? 'Science',
        chapter = chapterName ?? chapter ?? 'Chapter 1',
        quizSetNumber = setNumber ?? quizSetNumber ?? 1;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  bool _isLoading = true;
  bool _isHindi = true; // भाषा टॉगल (हिंदी / English)
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  String? _selectedOptionLetter; // 'A', 'B', 'C', 'D'
  int _score = 0;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  String _getTargetSheetName() {
    String prefix = "8th";
    if (widget.selectedClass.contains("9")) {
      prefix = "9th";
    } else if (widget.selectedClass.contains("10")) {
      prefix = "10th";
    }
    return '$prefix MCQ';
  }

  Future<void> _fetchQuestions() async {
    setState(() => _isLoading = true);

    final sheetName = _getTargetSheetName();
    final data = await SheetService.fetchSheetData(sheetName);

    // सब्जेक्ट और चैप्टर के आधार पर फ़िल्टर करना
    final filtered = data.where((row) {
      final rSub = (row['Subject'] ?? row['subject'] ?? '').toString().trim().toLowerCase();
      final rChap = (row['Chapter'] ?? row['chapter'] ?? '').toString().trim().toLowerCase();
      
      final targetSub = widget.subject.trim().toLowerCase();
      final targetChap = widget.chapter.trim().toLowerCase();

      return (rSub == targetSub || targetSub.isEmpty) &&
             (rChap == targetChap || targetChap.isEmpty);
    }).toList();

    // अगर बिल्कुल मैच न मिले तो उस शीट का सारा डेटा दिखा दें (सेफ़्टी फ़ॉलबैक)
    final finalQuestions = filtered.isNotEmpty ? filtered : data;

    // --- 20 QUESTIONS PER SET KA LOGIC ---
    const int questionsPerSet = 20;
    
    final int startIndex = (widget.quizSetNumber - 1) * questionsPerSet;
    final int endIndex = startIndex + questionsPerSet;

    List<Map<String, dynamic>> paginatedQuestions = [];

    if (startIndex < finalQuestions.length) {
      paginatedQuestions = finalQuestions.sublist(
        startIndex,
        endIndex > finalQuestions.length ? finalQuestions.length : endIndex,
      );
    }
    // --------------------------------------

    if (mounted) {
      setState(() {
        _questions = paginatedQuestions; // Sirf slice kiye hue questions hi load honge
        _isLoading = false;
      });
    }
  }

  void _checkAnswer(String optionLetter) {
    if (_answered || _questions.isEmpty) return;

    final correctAns = (_questions[_currentIndex]['Answer'] ?? 
                        _questions[_currentIndex]['answer'] ?? 
                        'A').toString().trim().toUpperCase();

    setState(() {
      _selectedOptionLetter = optionLetter;
      _answered = true;
      if (optionLetter.toUpperCase() == correctAns) {
        _score++;
      }
    });
  }

  void _nextQuestion() async {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOptionLetter = null;
        _answered = false;
      });
    } else {
      // Test complete hone par local storage me save kar lo
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('quiz_${widget.selectedClass}_${widget.subject}_${widget.chapter}_set_${widget.quizSetNumber}_completed', true);
        await prefs.setBool('chapter_completed_${widget.selectedClass}_${widget.subject}_${widget.chapter}', true);
      } catch (e) {
        debugPrint("Error saving quiz completion status: $e");
      }

      _showResultDialog();
    }
  }

  void _showResultDialog() {
    const neonCyan = Color(0xFF00F0FF);
    const neonGreen = Color(0xFF00FF66);

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0B111E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: neonCyan, width: 1.5),
        ),
        title: const Column(
          children: [
            Icon(Icons.military_tech, color: neonGreen, size: 44),
            SizedBox(height: 8),
            Text(
              '// SIMULATION COMPLETE',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                letterSpacing: 2,
                color: neonCyan,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SET 0${widget.quizSetNumber} EVALUATION',
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: neonGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: neonGreen.withOpacity(0.5)),
              ),
              child: Text(
                '$_score / ${_questions.length}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: neonGreen,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _score == _questions.length
                  ? 'PERFECT MATRIX OVERRIDE! 🎯'
                  : 'GOOD EFFORT • RE-SIMULATE FOR 100%',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Do baar pop taaki wapas list par chala jaye
            },
            child: const Text('EXIT', style: TextStyle(color: Colors.white60, fontFamily: 'monospace')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: neonCyan.withOpacity(0.2),
              foregroundColor: neonCyan,
              side: const BorderSide(color: neonCyan),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentIndex = 0;
                _selectedOptionLetter = null;
                _answered = false;
                _score = 0;
              });
            },
            child: const Text('RE-ENGAGE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const darkVoid = Color(0xFF070B14);
    const neonCyan = Color(0xFF00F0FF);
    const neonGreen = Color(0xFF00FF66);
    const neonRed = Color(0xFFFF0055);
    const neonGold = Color(0xFFFFD700);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: darkVoid,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: neonCyan),
              SizedBox(height: 16),
              Text("LOADING QUESTIONS FROM NODE...", style: TextStyle(color: neonCyan, fontFamily: 'monospace', fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: darkVoid,
        appBar: AppBar(backgroundColor: const Color(0xFF0A0F1D), elevation: 0),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, color: neonGold, size: 48),
              const SizedBox(height: 12),
              const Text("NO QUESTIONS FOUND", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("Please check ${_getTargetSheetName()} in Google Sheets", style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final currentQ = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;

    // शीट के कॉलम के अनुसार प्रश्न और विकल्प उठाना
    final questionText = _isHindi
        ? (currentQ['MCQ hin'] ?? currentQ['MCQ_hin'] ?? currentQ['MCQ eng'] ?? '').toString()
        : (currentQ['MCQ eng'] ?? currentQ['MCQ_eng'] ?? currentQ['MCQ hin'] ?? '').toString();

    final options = [
      {
        'letter': 'A',
        'text': _isHindi
            ? (currentQ['Option A hin'] ?? currentQ['Option_A_hin'] ?? currentQ['option A hin'] ?? currentQ['Option A eng'] ?? '').toString()
            : (currentQ['Option A eng'] ?? currentQ['Option_A_eng'] ?? currentQ['Option A hin'] ?? '').toString(),
      },
      {
        'letter': 'B',
        'text': _isHindi
            ? (currentQ['Option B hin'] ?? currentQ['Option_B_hin'] ?? currentQ['Option B eng'] ?? '').toString()
            : (currentQ['Option B eng'] ?? currentQ['Option_B_eng'] ?? currentQ['Option B hin'] ?? '').toString(),
      },
      {
        'letter': 'C',
        'text': _isHindi
            ? (currentQ['Option C hin'] ?? currentQ['Option_C_hin'] ?? currentQ['Option C eng'] ?? '').toString()
            : (currentQ['Option C eng'] ?? currentQ['Option_C_eng'] ?? currentQ['Option C hin'] ?? '').toString(),
      },
      {
        'letter': 'D',
        'text': _isHindi
            ? (currentQ['Option D hin'] ?? currentQ['Option_D_hin'] ?? currentQ['Option D eng'] ?? '').toString()
            : (currentQ['Option D eng'] ?? currentQ['Option_D_eng'] ?? currentQ['Option D hin'] ?? '').toString(),
      },
    ];

    final correctLetter = (currentQ['Answer'] ?? currentQ['answer'] ?? 'A').toString().trim().toUpperCase();
    final explanation = _isHindi
        ? (currentQ['Explanation hin'] ?? currentQ['Explanation_hin'] ?? '').toString()
        : (currentQ['Explanation eng'] ?? currentQ['Explanation_eng'] ?? '').toString();

    return Scaffold(
      backgroundColor: darkVoid,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1D),
        elevation: 0,
        iconTheme: const IconThemeData(color: neonCyan),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '// ${widget.subject.toUpperCase()}',
                  style: const TextStyle(color: neonCyan, fontSize: 11, fontFamily: 'monospace', letterSpacing: 1.2),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: neonGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: neonGreen.withOpacity(0.4)),
                  ),
                  child: Text(
                    'SET 0${widget.quizSetNumber}',
                    style: const TextStyle(color: neonGreen, fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              widget.chapter,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // भाषा टॉगल बटन (HIN / ENG)
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ActionChip(
              backgroundColor: const Color(0xFF101726),
              side: const BorderSide(color: neonCyan, width: 1),
              label: Text(
                _isHindi ? "HIN 🇮🇳" : "ENG 🌐",
                style: const TextStyle(color: neonCyan, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                setState(() {
                  _isHindi = !_isHindi;
                });
              },
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linear Progress HUD
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PHASE 0${_currentIndex + 1} / 0${_questions.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: neonCyan,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'SCORE: $_score',
                  style: const TextStyle(
                    fontSize: 11,
                    color: neonGreen,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation<Color>(neonCyan),
              ),
            ),
            const SizedBox(height: 20),

            // Question Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1524),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: neonCyan.withOpacity(0.35), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: neonCyan.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '// QUERY MATRIX',
                    style: TextStyle(
                      color: neonCyan.withOpacity(0.7),
                      fontSize: 10,
                      fontFamily: 'monospace',
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    questionText.isNotEmpty ? questionText : "Question text not available in selected language.",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Options List
            Expanded(
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final opt = options[index];
                  final letter = opt['letter']!;
                  final text = opt['text']!;

                  Color cardBg = const Color(0xFF0B111E);
                  Color borderColor = Colors.white12;
                  Color textColor = Colors.white;
                  Color badgeColor = neonCyan;

                  if (_answered) {
                    if (letter == correctLetter) {
                      cardBg = neonGreen.withOpacity(0.12);
                      borderColor = neonGreen;
                      badgeColor = neonGreen;
                      textColor = Colors.white;
                    } else if (letter == _selectedOptionLetter) {
                      cardBg = neonRed.withOpacity(0.12);
                      borderColor = neonRed;
                      badgeColor = neonRed;
                      textColor = Colors.white;
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 1.2),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _checkAnswer(letter),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: badgeColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: badgeColor.withOpacity(0.4)),
                                ),
                                child: Text(
                                  letter,
                                  style: TextStyle(
                                    color: badgeColor,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  text,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (_answered && letter == correctLetter)
                                const Icon(Icons.check_circle_rounded, color: neonGreen, size: 20),
                              if (_answered && letter == _selectedOptionLetter && letter != correctLetter)
                                const Icon(Icons.cancel_rounded, color: neonRed, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Explanation Box
            if (_answered && explanation.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF101726),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: neonGold.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: neonGold, size: 16),
                        SizedBox(width: 6),
                        Text(
                          "EXPLANATION / समाधान",
                          style: TextStyle(color: neonGold, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      explanation,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],

            // Next Question Button
            if (_answered)
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _nextQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: neonCyan.withOpacity(0.2),
                    foregroundColor: neonCyan,
                    side: const BorderSide(color: neonCyan, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentIndex == _questions.length - 1 ? 'TERMINATE SIMULATION' : 'PROCEED TO NEXT QUERY',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'monospace'),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}