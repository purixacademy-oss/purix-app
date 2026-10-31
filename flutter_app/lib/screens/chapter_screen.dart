import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'quiz_screen.dart';
import 'pdf_viewer_screen.dart';

class ChapterScreen extends StatefulWidget {
  final String subjectName;
  final IconData subjectIcon;
  final String selectedClass;
  final String? selectedBoard;

  const ChapterScreen({
    super.key,
    required this.subjectName,
    required this.subjectIcon,
    required this.selectedClass,
    this.selectedBoard,
  });

  @override
  State<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends State<ChapterScreen> {
  bool _isClassroomVerified = false;
  int _selectedFilterIndex = 0; // 0: All, 1: Demo Only, 2: Classroom Only

  @override
  void initState() {
    super.initState();
    _checkStudentVerification();
  }

  Future<void> _checkStudentVerification() async {
    final prefs = await SharedPreferences.getInstance();
    final plan = (prefs.getString('user_plan') ?? 'FREE').toUpperCase();
    setState(() {
      _isClassroomVerified =
          (plan == 'PRO' || plan == 'VERIFIED' || plan == 'ENROLLED');
    });
  }

  List<Map<String, dynamic>> _getChaptersForSubject() {
    return [
      {
        'id': 'ch_01',
        'title': 'Chemical Reactions and Equations',
        'subTitle': 'रासायानिक अभिक्रियाएँ एवं समीकरण',
        'isDemo': true,
        'pdfUrl': 'https://example.com/ch1_notes.pdf',
        'sets': [
          {'name': 'Set 1 (Demo)', 'isDemo': true, 'count': 25},
          {'name': 'Set 2 (Demo)', 'isDemo': true, 'count': 25},
          {'name': 'Set 3 (Classroom)', 'isDemo': false, 'count': 30},
          {'name': 'Set 4 (Classroom)', 'isDemo': false, 'count': 30},
        ],
      },
      {
        'id': 'ch_02',
        'title': 'Acids, Bases and Salts',
        'subTitle': 'अम्ल, क्षारक एवं लवण',
        'isDemo': false,
        'pdfUrl': 'https://example.com/ch2_notes.pdf',
        'sets': [
          {'name': 'Set 1 (Classroom)', 'isDemo': false, 'count': 25},
          {'name': 'Set 2 (Classroom)', 'isDemo': false, 'count': 25},
        ],
      },
      {
        'id': 'ch_03',
        'title': 'Metals and Non-metals',
        'subTitle': 'धातु एवं अधातु',
        'isDemo': false,
        'pdfUrl': 'https://example.com/ch3_notes.pdf',
        'sets': [
          {'name': 'Set 1 (Classroom)', 'isDemo': false, 'count': 25},
          {'name': 'Set 2 (Classroom)', 'isDemo': false, 'count': 30},
        ],
      },
      {
        'id': 'ch_04',
        'title': 'Life Processes',
        'subTitle': 'जैव प्रक्रम',
        'isDemo': true,
        'pdfUrl': 'https://example.com/ch4_notes.pdf',
        'sets': [
          {'name': 'Set 1 (Demo)', 'isDemo': true, 'count': 25},
          {'name': 'Set 2 (Classroom)', 'isDemo': false, 'count': 30},
        ],
      },
      {
        'id': 'ch_05',
        'title': 'Light - Reflection and Refraction',
        'subTitle': 'प्रकाश - परावर्तन तथा अपवर्तन',
        'isDemo': false,
        'pdfUrl': 'https://example.com/ch5_notes.pdf',
        'sets': [
          {'name': 'Set 1 (Classroom)', 'isDemo': false, 'count': 30},
        ],
      },
    ];
  }

  void _onSetSelected(
      BuildContext context, Map<String, dynamic> chapter, Map<String, dynamic> set) {
    final isSetDemo = set['isDemo'] as bool;
    if (!isSetDemo && !_isClassroomVerified) {
      _showLockedDialog(context);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(
          chapterTitle: '${chapter['title']} - ${set['name']}',
          questionCount: set['count'] as int,
        ),
      ),
    );
  }

  void _onPdfSelected(BuildContext context, Map<String, dynamic> chapter) {
    final isDemo = chapter['isDemo'] as bool;
    if (!isDemo && !_isClassroomVerified) {
      _showLockedDialog(context);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(
          title: chapter['title'] as String,
          pdfUrl: chapter['pdfUrl'] as String,
        ),
      ),
    );
  }

  void _showLockedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock, color: Color(0xFFF59E0B), size: 22),
            SizedBox(width: 10),
            Text(
              'CLASSROOM ONLY',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: const Text(
          'This module is reserved for Enrolled Classroom Cadets. Your enrollment is automatically synced from the institution roster.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('DISMISS', style: TextStyle(color: Color(0xFF38BDF8))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allChapters = _getChaptersForSubject();
    final chapters = allChapters.where((ch) {
      if (_selectedFilterIndex == 1) return ch['isDemo'] == true;
      if (_selectedFilterIndex == 2) return ch['isDemo'] == false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            Icon(widget.subjectIcon, color: const Color(0xFF38BDF8), size: 20),
            const SizedBox(width: 10),
            Text(
              widget.subjectName.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                _buildFilterChip('ALL CHAPTERS', 0),
                const SizedBox(width: 8),
                _buildFilterChip('DEMO', 1),
                const SizedBox(width: 8),
                _buildFilterChip('CLASSROOM ONLY', 2),
              ],
            ),
          ),

          // Chapter List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: chapters.length,
              itemBuilder: (context, index) {
                final ch = chapters[index];
                final isDemo = ch['isDemo'] as bool;
                final sets = ch['sets'] as List<Map<String, dynamic>>;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDemo
                          ? const Color(0xFF38BDF8).withValues(alpha: 0.3)
                          : const Color(0xFF334155),
                    ),
                  ),
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDemo
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : const Color(0xFF64748B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isDemo ? Icons.play_circle_outline : Icons.lock_outline,
                        color: isDemo
                            ? const Color(0xFF10B981)
                            : const Color(0xFF94A3B8),
                        size: 22,
                      ),
                    ),
                    title: Text(
                      ch['title'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          ch['subTitle'],
                          style: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDemo
                                ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                : const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isDemo ? 'DEMO' : 'CLASSROOM ONLY',
                            style: TextStyle(
                              color: isDemo
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF94A3B8),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(color: Color(0xFF334155)),
                            const SizedBox(height: 6),
                            const Text(
                              'AVAILABLE MCQ SETS:',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: sets.map((s) {
                                final setDemo = s['isDemo'] as bool;
                                return ActionChip(
                                  backgroundColor: setDemo
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF0F172A),
                                  side: BorderSide(
                                    color: setDemo
                                        ? const Color(0xFF38BDF8)
                                        : const Color(0xFF334155),
                                  ),
                                  avatar: Icon(
                                    setDemo ? Icons.check_circle : Icons.lock,
                                    size: 14,
                                    color: setDemo
                                        ? const Color(0xFF38BDF8)
                                        : const Color(0xFF64748B),
                                  ),
                                  label: Text(
                                    '${s['name']} (${s['count']}Q)',
                                    style: TextStyle(
                                      color: setDemo
                                          ? const Color(0xFF38BDF8)
                                          : const Color(0xFF94A3B8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () => _onSetSelected(context, ch, s),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => _onPdfSelected(context, ch),
                              icon: const Icon(Icons.picture_as_pdf,
                                  size: 16, color: Color(0xFF38BDF8)),
                              label: const Text(
                                'VIEW CHAPTER NOTES (PDF)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF38BDF8),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF38BDF8)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilterIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
