import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'chapter_screen.dart';
import 'free_content_screen.dart';
import 'class_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String? selectedBoard;
  const DashboardScreen({super.key, this.selectedBoard});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  String _studentName = 'Cadet';
  String _studentEmail = '';
  String _plan = 'FREE';
  String _currentClass = 'Class 10';
  String _currentBoard = 'Bihar Board (BSEB)';
  bool _isLoading = true;

  static const String studentDataUrl =
      'https://script.google.com/macros/s/AKfycbz_d_p5Wz4mR0aD7YvD31Vl-6kY2R4F_yK8h4wX3/exec';
  static const String syllabusUrl =
      'https://script.google.com/macros/s/AKfycbx_SYLLABUS_ENDPOINT_HERE/exec';

  @override
  void initState() {
    super.initState();
    _loadLocalProfile();
    _checkMidnightCacheAndPreload();
  }

  Future<void> _loadLocalProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _studentName = prefs.getString('user_name') ?? 'Cadet';
      _studentEmail = prefs.getString('user_email') ?? '';
      _plan = prefs.getString('user_plan') ?? 'FREE';
      _currentClass = prefs.getString('user_class') ?? 'Class 10';
      _currentBoard = widget.selectedBoard ??
          prefs.getString('user_board') ??
          'Bihar Board (BSEB)';
      _isLoading = false;
    });
    _verifyStudentStatus();
  }

  // 12:00 AM Midnight Cache Logic
  Future<void> _checkMidnightCacheAndPreload() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCacheTimeStr = prefs.getString('cache_timestamp_midnight');
    final now = DateTime.now();
    bool shouldRefresh = true;

    if (lastCacheTimeStr != null) {
      final lastCacheDate = DateTime.tryParse(lastCacheTimeStr);
      if (lastCacheDate != null) {
        if (lastCacheDate.year == now.year &&
            lastCacheDate.month == now.month &&
            lastCacheDate.day == now.day) {
          shouldRefresh = false;
        }
      }
    }

    if (shouldRefresh) {
      await _preloadClassContent(_currentClass);
      await prefs.setString(
          'cache_timestamp_midnight', now.toIso8601String());
    }
  }

  Future<void> _preloadClassContent(String className) async {
    try {
      final url = Uri.parse('$syllabusUrl?action=getClassData&class=$className');
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_syllabus_$className', res.body);
      }
    } catch (_) {
      // Offline fallback
    }
  }

  Future<void> _verifyStudentStatus() async {
    if (_studentEmail.isEmpty) return;
    try {
      final uri =
          Uri.parse('$studentDataUrl?action=checkStatus&email=$_studentEmail');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['status'] == 'success') {
          final serverPlan = (data['plan'] ?? 'FREE').toString().toUpperCase();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_plan', serverPlan);
          if (mounted) {
            setState(() {
              _plan = serverPlan;
            });
          }
        }
      }
    } catch (_) {}
  }

  bool get _isClassroomVerified =>
      _plan == 'PRO' || _plan == 'VERIFIED' || _plan == 'ENROLLED';

  void _openProfileModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFF3B82F6),
                    child: Text(
                      _studentName.isNotEmpty
                          ? _studentName[0].toUpperCase()
                          : 'C',
                      style: const TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _studentName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _studentEmail,
                          style: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF334155), height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Classroom Status:',
                      style: TextStyle(color: Color(0xFF94A3B8))),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isClassroomVerified
                          ? const Color(0xFF10B981).withValues(alpha: 0.2)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isClassroomVerified
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                      ),
                    ),
                    child: Text(
                      _isClassroomVerified ? 'VERIFIED' : 'DEMO MODE',
                      style: TextStyle(
                        color: _isClassroomVerified
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Enrolled Class:',
                      style: TextStyle(color: Color(0xFF94A3B8))),
                  Text(
                    _currentClass,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Board:',
                      style: TextStyle(color: Color(0xFF94A3B8))),
                  Text(
                    _currentBoard,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text('LOGOUT',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onBottomNavTap(int index) {
    if (index == _currentIndex) return;

    if (index == 0) {
      setState(() => _currentIndex = 0);
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChapterScreen(
            subjectName: 'Science',
            subjectIcon: Icons.science,
            selectedClass: _currentClass,
            selectedBoard: _currentBoard,
          ),
        ),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChapterScreen(
            subjectName: 'Mathematics',
            subjectIcon: Icons.calculate,
            selectedClass: _currentClass,
            selectedBoard: _currentBoard,
          ),
        ),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChapterScreen(
            subjectName: 'Social Science',
            subjectIcon: Icons.public,
            selectedClass: _currentClass,
            selectedBoard: _currentBoard,
          ),
        ),
      );
    } else if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FreeContentScreen(selectedClass: _currentClass),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PURIX ACADEMY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              '$_currentClass | $_currentBoard',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle,
                color: Color(0xFF38BDF8), size: 28),
            onPressed: _openProfileModal,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting & Status Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'WELCOME, ${_studentName.toUpperCase()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _isClassroomVerified
                                    ? const Color(0xFF10B981)
                                        .withValues(alpha: 0.2)
                                    : const Color(0xFFF59E0B)
                                        .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _isClassroomVerified
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFF59E0B),
                                ),
                              ),
                              child: Text(
                                _isClassroomVerified ? 'VERIFIED' : 'DEMO ACCESS',
                                style: TextStyle(
                                  color: _isClassroomVerified
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFF59E0B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Daily target: Complete 2 Demo Quizzes and review PDF syllabus before 12:00 AM reset.',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Non-clickable Stat Cards
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TESTS COMPLETED',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                '12',
                                style: TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TARGET GOAL',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                '95%',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Section Title
                  const Text(
                    'SUBJECT DIRECTORY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subject List
                  _buildSubjectTile(
                    title: 'Science (विज्ञान)',
                    subtitle: 'Physics, Chemistry, Biology Modules',
                    icon: Icons.science,
                    color: const Color(0xFF3B82F6),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChapterScreen(
                          subjectName: 'Science',
                          subjectIcon: Icons.science,
                          selectedClass: _currentClass,
                          selectedBoard: _currentBoard,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSubjectTile(
                    title: 'Mathematics (गणित)',
                    subtitle: 'Formula Matrix & Practice Sets',
                    icon: Icons.calculate,
                    color: const Color(0xFF10B981),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChapterScreen(
                          subjectName: 'Mathematics',
                          subjectIcon: Icons.calculate,
                          selectedClass: _currentClass,
                          selectedBoard: _currentBoard,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSubjectTile(
                    title: 'Social Science (सामाजिक विज्ञान)',
                    subtitle: 'History, Civics, Geography Notes',
                    icon: Icons.public,
                    color: const Color(0xFFF59E0B),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChapterScreen(
                          subjectName: 'Social Science',
                          subjectIcon: Icons.public,
                          selectedClass: _currentClass,
                          selectedBoard: _currentBoard,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSubjectTile(
                    title: 'Hindi & English (भाषा)',
                    subtitle: 'Grammar & Prose Questions',
                    icon: Icons.menu_book,
                    color: const Color(0xFF8B5CF6),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChapterScreen(
                          subjectName: 'Languages',
                          subjectIcon: Icons.menu_book,
                          selectedClass: _currentClass,
                          selectedBoard: _currentBoard,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: const Color(0xFF38BDF8),
        unselectedItemColor: const Color(0xFF94A3B8),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.quiz),
            label: 'MCQ Test',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Practice',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Notes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view),
            label: 'Free Matrix',
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF64748B), size: 20),
          ],
        ),
      ),
    );
  }
}
