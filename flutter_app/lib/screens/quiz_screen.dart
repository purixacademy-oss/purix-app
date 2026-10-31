import 'package:flutter/material.dart';

class QuizScreen extends StatefulWidget {
  final String chapterTitle;
  final int questionCount;

  const QuizScreen({
    super.key,
    required this.chapterTitle,
    required this.questionCount,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestionIndex = 0;
  int? _selectedOption;
  int _score = 0;
  bool _isAnswered = false;

  final List<Map<String, dynamic>> _dummyQuestions = [
    {
      'question': 'Which of the following is a displacement reaction?',
      'options': [
        'CaO + H2O → Ca(OH)2',
        'Fe + CuSO4 → FeSO4 + Cu',
        '2H2O → 2H2 + O2',
        'CaCO3 → CaO + CO2',
      ],
      'correct': 1,
      'explanation': 'Iron (Fe) is more reactive than copper (Cu) and displaces copper from copper sulfate.',
    },
    {
      'question': 'What is the pH value of pure distilled water at 25°C?',
      'options': ['0', '7', '14', '1'],
      'correct': 1,
      'explanation': 'Pure water has an equal concentration of H+ and OH- ions, resulting in a neutral pH of 7.',
    },
    {
      'question': 'Which plant hormone promotes cell division actively in fruits and seeds?',
      'options': ['Auxin', 'Gibberellin', 'Cytokinin', 'Abscisic Acid'],
      'correct': 2,
      'explanation': 'Cytokinins promote cell division and are present in greater concentrations in rapid cell division areas.',
    },
    {
      'question': 'The focal length of a spherical mirror with radius of curvature 32 cm is:',
      'options': ['32 cm', '64 cm', '16 cm', '8 cm'],
      'correct': 2,
      'explanation': 'Focal length f = R / 2 = 32 / 2 = 16 cm.',
    },
  ];

  void _submitAnswer(int index) {
    if (_isAnswered) return;
    setState(() {
      _selectedOption = index;
      _isAnswered = true;
      if (index == _dummyQuestions[_currentQuestionIndex % _dummyQuestions.length]['correct']) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex + 1 < widget.questionCount) {
      setState(() {
        _currentQuestionIndex++;
        _selectedOption = null;
        _isAnswered = false;
      });
    } else {
      _showResultDialog();
    }
  }

  void _showResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'TEST COMPLETED',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Final Score: $_score / ${widget.questionCount}',
              style: const TextStyle(
                color: Color(0xFF38BDF8),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Accuracy: ${((_score / widget.questionCount) * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('RETURN TO CHAPTERS',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQ =
        _dummyQuestions[_currentQuestionIndex % _dummyQuestions.length];
    final options = currentQ['options'] as List<String>;
    final correctIdx = currentQ['correct'] as int;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.chapterTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Question ${_currentQuestionIndex + 1} of ${widget.questionCount}',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Text(
                currentQ['question'] as String,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Options List
            Expanded(
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (context, idx) {
                  final isSelected = _selectedOption == idx;
                  final isCorrect = idx == correctIdx;

                  Color borderColor = const Color(0xFF334155);
                  Color bgColor = const Color(0xFF1E293B);

                  if (_isAnswered) {
                    if (isCorrect) {
                      borderColor = const Color(0xFF10B981);
                      bgColor = const Color(0xFF10B981).withValues(alpha: 0.15);
                    } else if (isSelected) {
                      borderColor = const Color(0xFFEF4444);
                      bgColor = const Color(0xFFEF4444).withValues(alpha: 0.15);
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => _submitAnswer(idx),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF0F172A),
                                border: Border.all(color: borderColor),
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(65 + idx),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                options[idx],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_isAnswered) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Text(
                  'Explanation: ${currentQ['explanation']}',
                  style: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 12, height: 1.3),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _nextQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    _currentQuestionIndex + 1 < widget.questionCount
                        ? 'NEXT QUESTION'
                        : 'SUBMIT TEST',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
