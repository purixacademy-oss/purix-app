import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sheet_service.dart';
import 'dashboard_screen.dart';
import 'board_screen.dart';

class ClassScreen extends StatefulWidget {
  final String userName;
  final String? currentClass;
  final String? selectedBoard;
  final bool isSwitching;

  const ClassScreen({
    super.key,
    required this.userName,
    this.currentClass,
    this.selectedBoard,
    this.isSwitching = false,
  });

  @override
  State<ClassScreen> createState() => _ClassScreenState();
}

class _ClassScreenState extends State<ClassScreen> {
  late String _board;

  @override
  void initState() {
    super.initState();
    _board = widget.selectedBoard ?? 'Bihar Board (BSEB)';
    _loadBoardFromPrefs();
  }

  Future<void> _loadBoardFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('user_board');
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() => _board = saved);
    }
  }

  Future<void> _selectClass(BuildContext context, String selectedClass) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('user_class', selectedClass);
    await prefs.setString('user_board', _board);

    final phone = prefs.getString('user_phone') ?? '';
    final email = prefs.getString('user_email') ?? 'student@purix.edu';
    if (phone.isNotEmpty) {
      SheetService.syncUserProfile(
        name: widget.userName,
        phone: phone,
        email: email,
        selectedClass: selectedClass,
        selectedBoard: _board,
      );
    }

    if (!context.mounted) return;

    if (widget.isSwitching) {
      Navigator.pop(context, selectedClass);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(
            selectedClass: selectedClass,
            userName: widget.userName,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const darkVoid = Color(0xFF070B14);
    const goldAccent = Color(0xFFD4AF37);
    const neonCyan = Color(0xFF00F0FF);
    const cardBg = Color(0xFF0E1626);

    final classes = [
      {'name': 'Class 8', 'desc': 'Foundations & Concepts', 'icon': Icons.lightbulb_outline},
      {'name': 'Class 9', 'desc': 'Core Syllabus & Concepts', 'icon': Icons.menu_book},
      {'name': 'Class 10th', 'desc': 'Board Target & Mock Drills', 'icon': Icons.school},
      {'name': 'Board Special', 'desc': 'Crash Course & High-Yield', 'icon': Icons.star_border},
    ];

    return Scaffold(
      backgroundColor: darkVoid,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: widget.isSwitching
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'SELECT CADET CLASS',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: goldAccent,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: neonCyan.withAlpha(76)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_rounded, color: neonCyan, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("ACTIVE BOARD", style: TextStyle(color: Colors.white38, fontSize: 9, fontFamily: 'monospace')),
                          Text(_board, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final chosen = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BoardScreen(userName: widget.userName, currentBoard: _board, isSwitching: true),
                          ),
                        );
                        if (chosen != null && chosen.isNotEmpty) {
                          setState(() => _board = chosen);
                        }
                      },
                      child: const Text("CHANGE", style: TextStyle(color: neonCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'TARGET CLASS',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: classes.length,
                  itemBuilder: (context, index) {
                    final item = classes[index];
                    final isSelected = widget.currentClass == item['name'];

                    return InkWell(
                      onTap: () => _selectClass(context, item['name'] as String),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? neonCyan : Colors.white12,
                            width: isSelected ? 2.0 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(color: neonCyan.withAlpha(50), blurRadius: 16)]
                              : [],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              item['icon'] as IconData,
                              size: 36,
                              color: isSelected ? neonCyan : goldAccent,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              item['name'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['desc'] as String,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}