import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'class_screen.dart';

class BoardScreen extends StatefulWidget {
  final String userName;
  final String? currentBoard;
  final bool isSwitching; // True if opened from profile to change board

  const BoardScreen({
    super.key,
    required this.userName,
    this.currentBoard,
    this.isSwitching = false,
  });

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  String? _selected;

  // 🏛️ Currently 3 Active Boards
  final List<Map<String, dynamic>> _boards = [
    {
      'name': 'Bihar Board (BSEB)',
      'code': 'BSEB',
      'icon': Icons.account_balance_rounded,
      'color': const Color(0xFF00F0FF),
      'tag': 'Hindi & English Medium',
      'desc': 'NCERT/SCERT Syllabus, High-Yield Model Sets & Formula Bank',
    },
    {
      'name': 'CBSE Board',
      'code': 'CBSE',
      'icon': Icons.school_rounded,
      'color': const Color(0xFFFFB800),
      'tag': 'All India NCERT',
      'desc': 'Competency Based Questions, Case Studies & Chapter Notes',
    },
    {
      'name': 'Jharkhand Board (JAC)',
      'code': 'JAC',
      'icon': Icons.menu_book_rounded,
      'color': const Color(0xFF00FF88),
      'tag': 'JAC Board Target',
      'desc': 'JAC Board NCERT Pattern, Model Question Papers & Practice',
    },
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.currentBoard ?? 'Bihar Board (BSEB)';
  }

  Future<void> _proceedWithBoard(String boardName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_board', boardName);

    if (!mounted) return;

    if (widget.isSwitching) {
      // Return selected board to Profile / Dashboard
      Navigator.pop(context, boardName);
    } else {
      // Move to Class Selection Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ClassScreen(
            userName: widget.userName,
            selectedBoard: boardName,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const darkVoid = Color(0xFF070B14);
    const cardBg = Color(0xFF0D1424);
    const goldAccent = Color(0xFFD4AF37);
    const neonCyan = Color(0xFF00F0FF);

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
          'SELECT EDUCATION BOARD',
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
              // Welcome Header Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: neonCyan.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: neonCyan.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.hub_rounded, color: neonCyan, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Cadet ${widget.userName}",
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Select your board to load dedicated questions & study sheets.",
                            style: TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              const Text(
                "CHOOSE YOUR BOARD",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Board Cards (3 Boards: Bihar, CBSE, Jharkhand)
              Expanded(
                child: ListView.separated(
                  itemCount: _boards.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _boards[index];
                    final String name = item['name'];
                    final String code = item['code'];
                    final IconData icon = item['icon'];
                    final Color color = item['color'];
                    final String tag = item['tag'];
                    final String desc = item['desc'];
                    final bool isCurrent = _selected == name;

                    return InkWell(
                      onTap: () {
                        setState(() => _selected = name);
                        _proceedWithBoard(name);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrent ? color : Colors.white12,
                            width: isCurrent ? 2.0 : 1.0,
                          ),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: color.withOpacity(0.2),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: color.withOpacity(0.4)),
                              ),
                              child: Icon(icon, color: color, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: color.withOpacity(0.4)),
                                        ),
                                        child: Text(
                                          code,
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 9,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tag,
                                    style: TextStyle(
                                      color: color.withOpacity(0.85),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    desc,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10.5,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isCurrent ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                              color: isCurrent ? color : Colors.white30,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Daily cache status note
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    "⚡ Dedicated Board Database • Cached till 12:00 AM Midnight",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 9.5,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
