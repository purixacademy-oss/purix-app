import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'chapter_screen.dart';
import 'free_content_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;
  final String selectedClass;
  final String selectedBoard;

  const DashboardScreen({
    super.key,
    required this.userName,
    required this.selectedClass,
    required this.selectedBoard,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentTabIndex = 0;
  late String _currentName;
  late String _currentClass;
  late String _currentBoard;
  String _subscriptionStatus = 'FREE'; // 'PRO' means Classroom Verified
  int _completedTestsCount = 0;
  bool _isCheckingVerification = false;

  static const String studentDataUrl =
      "https://script.google.com/macros/s/AKfycbxW1tu6jkT29VBflDapForv8tLdV56-XfMeFjqX9xd-Q3hhwuwsNz_IJTexO4hEsoDTOA/exec";
  static const String supportPhone = "+919508774890";

  final List<Map<String, dynamic>> _subjects = [
    {"name": "Science", "icon": Icons.biotech, "color": const Color(0xFF00F0FF)},
    {"name": "Mathematics", "icon": Icons.calculate, "color": const Color(0xFFD4AF37)},
    {"name": "Social Science", "icon": Icons.public, "color": Colors.purpleAccent},
    {"name": "Hindi", "icon": Icons.translate, "color": Colors.orangeAccent},
    {"name": "English", "icon": Icons.menu_book, "color": Colors.pinkAccent},
    {"name": "Sanskrit", "icon": Icons.auto_stories, "color": Colors.tealAccent},
  ];

  @override
  void initState() {
    super.initState();
    _currentName = widget.userName;
    _currentClass = widget.selectedClass;
    _currentBoard = widget.selectedBoard;
    _loadLocalUserData();
    _checkMidnightCacheAndPreload();
  }

  Future<void> _loadLocalUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentName = prefs.getString('user_name') ?? widget.userName;
      _currentClass = prefs.getString('user_class') ?? widget.selectedClass;
      _currentBoard = prefs.getString('user_board') ?? widget.selectedBoard;
      _subscriptionStatus = prefs.getString('user_sub') ?? 'FREE';
      _completedTestsCount = prefs.getInt('completed_tests_count') ?? 0;
    });
  }

  // 12:00 AM Midnight Cache Logic
  // At midnight 00:00 AM, the calendar date changes, invalidating cache so fresh content loads for today!
  Future<void> _checkMidnightCacheAndPreload() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCacheDate = prefs.getString('cache_date_stamp') ?? '';
    final todayDate = DateTime.now().toIso8601String().substring(0, 10);

    if (lastCacheDate != todayDate) {
      // Date changed past midnight: flush yesterday's cache and preload fresh data
      await prefs.setString('cache_date_stamp', todayDate);
      _preloadClassContent();
    }
  }

  Future<void> _preloadClassContent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String prefix = "8th";
      if (_currentClass.contains("9")) {
        prefix = "9th";
      } else if (_currentClass.contains("10") || _currentClass.toLowerCase().contains("board")) {
        prefix = "10th";
      }

      final url = "$studentDataUrl?sheet=${Uri.encodeComponent('$prefix MCQ')}";
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        await prefs.setString('cached_mcq_${prefix}', res.body);
      }
    } catch (_) {}
  }

  // Live Sheet Check for Classroom Status (Pro vs Unverified)
  Future<void> _checkLiveVerification() async {
    setState(() => _isCheckingVerification = true);
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('user_phone') ?? '';

    if (phone.isEmpty) {
      setState(() => _isCheckingVerification = false);
      _showSnack("कोई पंजीकृत फ़ोन नंबर नहीं मिला।", isError: true);
      return;
    }

    try {
      final res = await http.get(Uri.parse("$studentDataUrl?sheet=User%20ID&phone=$phone"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List && data.isNotEmpty) {
          final rawPlan = (data[0]['Plan'] ?? data[0]['plan'] ?? 'FREE').toString().trim().toUpperCase();
          final isPro = (rawPlan == 'PRO' || rawPlan == 'VERIFIED');
          final finalStatus = isPro ? 'PRO' : 'FREE';

          await prefs.setString('user_sub', finalStatus);
          setState(() {
            _subscriptionStatus = finalStatus;
          });

          if (isPro) {
            _showSnack("✅ CLASSROOM STATUS: VERIFIED (Enrolled in Purix Academy)");
          } else {
            _showSnack("ℹ️ CLASSROOM STATUS: UNVERIFIED (Contact Classroom Center to Enroll)");
          }
        }
      }
    } catch (_) {
      _showSnack("Google Sheet से सत्यापन स्थिति सिंक नहीं हो सकी।", isError: true);
    } finally {
      setState(() => _isCheckingVerification = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF00F0FF),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showProfileModal() {
    final isVerified = _subscriptionStatus == 'PRO';
    final prefsFuture = SharedPreferences.getInstance();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E1626),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FutureBuilder<SharedPreferences>(
          future: prefsFuture,
          builder: (context, snapshot) {
            final phone = snapshot.data?.getString('user_phone') ?? 'N/A';
            final email = snapshot.data?.getString('user_email') ?? 'N/A';
            final uid = snapshot.data?.getString('user_uid') ?? 'PRX-00000';

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFF070B14),
                            child: Icon(Icons.person, color: Color(0xFF00F0FF)),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_currentName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              Text("ID: $uid", style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 11, fontFamily: 'monospace')),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white54),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 24),

                  // Classroom Status Badge
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isVerified ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isVerified ? Colors.green : Colors.orange),
                    ),
                    child: Row(
                      children: [
                        Icon(isVerified ? Icons.verified : Icons.lock_outline, size: 20, color: isVerified ? Colors.greenAccent : Colors.orangeAccent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isVerified ? "CLASSROOM STATUS: VERIFIED" : "CLASSROOM STATUS: UNVERIFIED",
                                style: TextStyle(
                                  color: isVerified ? Colors.greenAccent : Colors.orangeAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                isVerified ? "Enrolled Cadet (Full Academy Access)" : "Standard Access (Contact center to verify)",
                                style: const TextStyle(color: Colors.white54, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Info Rows
                  _buildProfileRow("Class", _currentClass, Icons.school, () => _showClassPicker()),
                  _buildProfileRow("Board", _currentBoard, Icons.account_balance, () => _showBoardPicker()),
                  _buildProfileRow("Mobile", phone, Icons.phone, null),
                  _buildProfileRow("Email", email, Icons.email, null),

                  const SizedBox(height: 16),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isCheckingVerification ? null : () {
                            Navigator.pop(context);
                            _checkLiveVerification();
                          },
                          icon: const Icon(Icons.sync, size: 16),
                          label: Text(_isCheckingVerification ? "Checking..." : "Sync Status"),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF00F0FF)),
                            foregroundColor: const Color(0xFF00F0FF),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.clear();
                            if (!mounted) return;
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                              (route) => false,
                            );
                          },
                          icon: const Icon(Icons.logout, size: 16),
                          label: const Text("Logout"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.withOpacity(0.8),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProfileRow(String label, String value, IconData icon, VoidCallback? onEdit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.white38),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          ),
          Row(
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              if (onEdit != null) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: onEdit,
                  child: const Icon(Icons.edit, size: 14, color: Color(0xFF00F0FF)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showClassPicker() {
    final classes = ["Class 8th", "Class 9th", "Class 10th (Matric)"];
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: const Color(0xFF0E1626),
        title: const Text("Select Class", style: TextStyle(color: Colors.white)),
        children: classes.map((c) {
          return SimpleDialogOption(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('user_class', c);
              setState(() => _currentClass = c);
              Navigator.pop(context);
              Navigator.pop(context);
              _preloadClassContent();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(c, style: TextStyle(color: _currentClass == c ? const Color(0xFF00F0FF) : Colors.white70)),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showBoardPicker() {
    final boards = ["Bihar Board (BSEB)", "CBSE Board", "Jharkhand Board (JAC)"];
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: const Color(0xFF0E1626),
        title: const Text("Select Examination Board", style: TextStyle(color: Colors.white)),
        children: boards.map((b) {
          return SimpleDialogOption(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('user_board', b);
              setState(() => _currentBoard = b);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(b, style: TextStyle(color: _currentBoard == b ? const Color(0xFF00F0FF) : Colors.white70)),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _navigateToModule(String mode, String subject) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChapterScreen(
          className: _currentClass,
          subjectName: subject,
          subSubjectName: "Chapters",
          mode: mode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVerified = _subscriptionStatus == 'PRO';

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1626),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_currentName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            Text("$_currentClass • $_currentBoard", style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, color: Color(0xFF00F0FF), size: 30),
            onPressed: _showProfileModal,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stat Cards (Non-clickable clean display cards)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E1626),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("TESTS COMPLETED", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.assignment_turned_in, size: 20, color: Color(0xFF00F0FF)),
                            const SizedBox(width: 8),
                            Text("$_completedTestsCount", style: const TextStyle(color: Color(0xFF00F0FF), fontSize: 24, fontWeight: FontWeight.bold)),
                          ],
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
                      color: const Color(0xFF0E1626),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("TARGET GOAL", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.flag, size: 20, color: Color(0xFFD4AF37)),
                            SizedBox(width: 8),
                            Text("100%", style: TextStyle(color: Color(0xFFD4AF37), fontSize: 24, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Study Modules Grid
            const Text("STUDY MODULES", style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: [
                InkWell(
                  onTap: () => _navigateToModule("mcq", "Science"),
                  borderRadius: BorderRadius.circular(14),
                  child: _buildModuleCard("MCQ Tests", Icons.quiz, const Color(0xFF00F0FF), "DEMO AVAILABLE"),
                ),
                InkWell(
                  onTap: () => _navigateToModule("practice", "Science"),
                  borderRadius: BorderRadius.circular(14),
                  child: _buildModuleCard("Practice Sets", Icons.assignment, const Color(0xFFD4AF37), isVerified ? "FULL ACCESS" : "CLASSROOM ONLY"),
                ),
                InkWell(
                  onTap: () => _navigateToModule("notes", "Science"),
                  borderRadius: BorderRadius.circular(14),
                  child: _buildModuleCard("Study Notes", Icons.menu_book, Colors.purpleAccent, isVerified ? "FULL ACCESS" : "DEMO"),
                ),
                InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FreeContentScreen())),
                  borderRadius: BorderRadius.circular(14),
                  child: _buildModuleCard("Free Matrix", Icons.dashboard_customize, Colors.tealAccent, "OPEN ACCESS"),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Subject Browser
            const Text("SUBJECT CURRICULUM", style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 12),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _subjects.length,
              itemBuilder: (context, index) {
                final sub = _subjects[index];
                final Color col = sub['color'] as Color;

                return Card(
                  color: const Color(0xFF0E1626),
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.white10),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: col.withOpacity(0.15),
                      child: Icon(sub['icon'] as IconData, color: col),
                    ),
                    title: Text(sub['name'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text("Syllabus & Tests • $_currentClass", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white38),
                    onTap: () => _navigateToModule("mcq", sub['name'] as String),
                  ),
                );
              },
            ),
          ],
        ),
      ),

      // 5 Bottom Navigation Bar Items
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() => _currentTabIndex = index);
          if (index == 1) _navigateToModule("mcq", "Science");
          if (index == 2) _navigateToModule("practice", "Science");
          if (index == 3) _navigateToModule("notes", "Science");
          if (index == 4) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const FreeContentScreen()));
          }
        },
        backgroundColor: const Color(0xFF0E1626),
        selectedItemColor: const Color(0xFF00F0FF),
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.quiz), label: "MCQ Test"),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: "Practice"),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: "Notes"),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: "Free Matrix"),
        ],
      ),
    );
  }

  Widget _buildModuleCard(String title, IconData icon, Color color, String badgeText) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1626),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(badgeText, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}