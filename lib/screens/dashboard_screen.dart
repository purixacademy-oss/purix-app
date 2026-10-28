import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/sheet_service.dart';
import 'board_screen.dart';
import 'class_screen.dart';
import 'subject_screen.dart';
import 'free_content_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;
  final String selectedClass;
  final String? selectedBoard;

  const DashboardScreen({
    super.key,
    required this.userName,
    required this.selectedClass,
    this.selectedBoard,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late String currentClass;
  late String currentBoard;
  late String currentName;
  String currentPhone = '';
  String currentEmail = '';
  String currentUid = 'FETCHING...';
  String subscriptionStatus = 'SYNCING...';

  final String supportWhatsAppNumber = "919508774890";

  // Progress metrics
  bool isLoadingProgress = true;
  List<Map<String, dynamic>> subjectProgressList = [];
  int overallPercentage = 0;
  int totalCompletedChapters = 0;
  int totalSyllabusChapters = 0;
  int completedQuizCount = 0;

  @override
  void initState() {
    super.initState();
    currentClass = widget.selectedClass;
    currentBoard = widget.selectedBoard ?? 'Bihar Board (BSEB)';
    currentName = widget.userName;
    _loadUserDataAndCheckProfile();
    _loadLearningProgress(forceRefresh: false);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getDailyQuote() {
    return "Every question practiced today is an exam mark secured tomorrow.";
  }

  String _calculateLevelName(int pct) {
    if (pct >= 80) return 'Level 4 • Master';
    if (pct >= 50) return 'Level 3 • Advanced';
    if (pct >= 20) return 'Level 2 • Intermediate';
    return 'Level 1 • Beginner';
  }

  Color _getLevelColor(int pct) {
    if (pct >= 80) return const Color(0xFF00FF88);
    if (pct >= 50) return const Color(0xFF00F0FF);
    if (pct >= 20) return const Color(0xFFFFB800);
    return Colors.white54;
  }

  Future<void> _loadLearningProgress({bool forceRefresh = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      int quizCount = 0;
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('quiz_') && key.endsWith('_completed') && prefs.getBool(key) == true) {
          quizCount++;
        }
      }
      completedQuizCount = quizCount;

      String prefix = "8th";
      if (currentClass.contains("9")) {
        prefix = "9th";
      } else if (currentClass.contains("10") || currentClass.toLowerCase().contains("board")) {
        prefix = "10th";
      }

      final mcqData = await SheetService.fetchSheetData("${prefix} MCQ", board: currentBoard, forceRefresh: forceRefresh);

      final Map<String, Set<String>> grouped = {};
      for (final row in mcqData) {
        final rawSub = (row['Subject'] ?? row['subject'] ?? row['SUBJECT'] ?? '').toString().trim();
        final rawChap = (row['Chapter'] ?? row['chapter'] ?? row['CHAPTER'] ?? '').toString().trim();

        if (rawSub.isEmpty || rawChap.isEmpty) continue;

        String sub = rawSub;
        if (sub.toLowerCase() == 'sst') sub = 'Social Science';
        if (sub.toLowerCase() == 'math' || sub.toLowerCase() == 'maths') sub = 'Mathematics';
        if (sub.toLowerCase() == 'sci') sub = 'Science';
        if (sub.toLowerCase() == 'hin') sub = 'Hindi';
        if (sub.toLowerCase() == 'san') sub = 'Sanskrit';

        grouped.putIfAbsent(sub, () => <String>{});
        grouped[sub]!.add(rawChap);
      }

      final List<Map<String, dynamic>> computed = [];
      int totalAllChaps = 0;
      int totalDoneChaps = 0;

      for (final entry in grouped.entries) {
        final subName = entry.key;
        final chaps = entry.value;
        final totalC = chaps.length;
        int doneC = 0;

        for (final chap in chaps) {
          final directKey = "chapter_completed_${currentClass}_${subName}_$chap";
          final isDirect = prefs.getBool(directKey) ?? false;
          if (isDirect) {
            doneC++;
          } else {
            final quizKey = "quiz_${currentClass}_${subName}_${chap}_set_1_completed";
            if (prefs.getBool(quizKey) == true) {
              doneC++;
            }
          }
        }

        final int pct = totalC > 0 ? ((doneC / totalC) * 100).round() : 0;
        totalAllChaps += totalC;
        totalDoneChaps += doneC;

        computed.add({
          'subject': subName,
          'total': totalC,
          'completed': doneC,
          'percentage': pct,
          'level': _calculateLevelName(pct),
          'color': _getLevelColor(pct),
        });
      }

      if (computed.isEmpty) {
        computed.add({
          'subject': 'Science',
          'total': 14,
          'completed': 0,
          'percentage': 0,
          'level': 'Level 1 • Beginner',
          'color': Colors.white54,
        });
        computed.add({
          'subject': 'Social Science',
          'total': 20,
          'completed': 0,
          'percentage': 0,
          'level': 'Level 1 • Beginner',
          'color': Colors.white54,
        });
        totalAllChaps = 34;
      }

      final overallPct = totalAllChaps > 0 ? ((totalDoneChaps / totalAllChaps) * 100).round() : 0;

      if (!mounted) return;
      setState(() {
        subjectProgressList = computed;
        overallPercentage = overallPct;
        totalCompletedChapters = totalDoneChaps;
        totalSyllabusChapters = totalAllChaps;
        isLoadingProgress = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingProgress = false;
        });
      }
    }
  }

  Future<void> _loadUserDataAndCheckProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      currentPhone = prefs.getString('user_phone') ?? '';
      currentEmail = prefs.getString('user_email') ?? '';
      currentUid = prefs.getString('user_uid') ?? 'ID-NOT-FOUND';
      subscriptionStatus = prefs.getString('user_sub') ?? 'SYNCING...';
      currentName = prefs.getString('user_name') ?? widget.userName;
      currentBoard = prefs.getString('user_board') ?? currentBoard;
    });

    final lastSyncStr = prefs.getString('user_last_sync_time');
    final bool shouldSync = lastSyncStr == null ||
        DateTime.now().difference(DateTime.parse(lastSyncStr)).inHours >= 12;

    if (shouldSync && currentPhone.isNotEmpty && currentName.toLowerCase() != 'student') {
      SheetService.syncUserProfile(
        name: currentName,
        phone: currentPhone,
        email: currentEmail.isNotEmpty ? currentEmail : "N/A",
        selectedClass: currentClass,
        selectedBoard: currentBoard,
      ).then((sub) async {
        if (!mounted) return;

        final cleanSub = sub.trim().toLowerCase();
        if (cleanSub == 'deactive' || cleanSub == 'inactive' || cleanSub == 'blocked' || cleanSub == 'false') {
          await prefs.clear();
          if (!mounted) return;

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
          );
          return;
        }

        prefs.setString('user_sub', sub);
        prefs.setString('user_last_sync_time', DateTime.now().toIso8601String());
        setState(() {
          subscriptionStatus = sub;
        });
      });
    }
  }

  void _openWhatsApp({String? message}) async {
    final text = message ??
        "Hello Purix Academy! I am Cadet $currentName ($currentClass). I need assistance with my learning modules.";
    final cleanPhone = supportWhatsAppNumber.replaceAll(RegExp(r'\D'), '');
    final encodedText = Uri.encodeComponent(text);

    final nativeUri = Uri.parse("whatsapp://send?phone=$cleanPhone&text=$encodedText");
    final webUri = Uri.parse("https://wa.me/$cleanPhone?text=$encodedText");
    final apiUri = Uri.parse("https://api.whatsapp.com/send?phone=$cleanPhone&text=$encodedText");

    bool launched = false;
    try {
      if (await canLaunchUrl(nativeUri)) {
        launched = await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    if (!launched) {
      try {
        if (await canLaunchUrl(webUri)) {
          launched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}
    }

    if (!launched) {
      try {
        launched = await launchUrl(apiUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }

    if (!launched && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0A0F1D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFFFB800), width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.support_agent_rounded, color: Color(0xFFFFB800), size: 26),
              SizedBox(width: 10),
              Text("Purix Help Desk", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Connect directly with Purix Academy Support:", style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF101726),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone_rounded, color: Color(0xFFFFB800), size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text("+91 9508774890", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(const ClipboardData(text: "+919508774890"));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Support Number copied!"), backgroundColor: Color(0xFF00FF88), duration: Duration(seconds: 2)),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00F0FF).withAlpha(38),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF00F0FF).withAlpha(100)),
                        ),
                        child: const Text("COPY", style: TextStyle(color: Color(0xFF00F0FF), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("CLOSE", style: TextStyle(color: Colors.white54, fontSize: 11)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB800),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () async {
                final telUri = Uri.parse("tel:+919508774890");
                try {
                  await launchUrl(telUri, mode: LaunchMode.externalApplication);
                } catch (_) {}
                if (ctx.mounted) Navigator.pop(ctx);
              },
              icon: const Icon(Icons.call_rounded, color: Colors.black, size: 15),
              label: const Text("CALL SUPPORT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ],
        ),
      );
    }
  }

  // Indus App Store Policy Compliant Dialog (No Price, No Payment, Only Contact Center)
  void _showPaymentDialog() {
    const neonCyan = Color(0xFF00F0FF);
    const neonGold = Color(0xFFFFB800);

    showDialog(
      context: context,
      builder: (dialogContext) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        Text("Center Node:", style: TextStyle(color: Colors.white60, fontSize: 11)),
                        Text("Purix Classroom Center", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Cadet ID:", style: TextStyle(color: Colors.white60, fontSize: 11)),
                        Text(currentUid, style: const TextStyle(color: neonGold, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'monospace')),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Batch Material:", style: TextStyle(color: Colors.white60, fontSize: 11)),
                        Text("$currentClass Syllabus", style: const TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 11)),
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
                      Navigator.pop(dialogContext);
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
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("CLOSE", style: TextStyle(color: Colors.white38, fontSize: 11)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _changeBoard() async {
    final newBoard = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => BoardScreen(
          userName: currentName,
          currentBoard: currentBoard,
          isSwitching: true,
        ),
      ),
    );

    if (newBoard != null && newBoard.isNotEmpty && newBoard != currentBoard) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_board', newBoard);
      setState(() {
        currentBoard = newBoard;
      });
      SheetService.syncUserProfile(
        name: currentName,
        phone: currentPhone,
        email: currentEmail.isNotEmpty ? currentEmail : "student@purix.edu",
        selectedClass: currentClass,
        selectedBoard: newBoard,
      );
      _loadLearningProgress(forceRefresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Switched to $newBoard • Content updated"),
            backgroundColor: const Color(0xFF00FF88),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _changeClass() async {
    final newClass = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => ClassScreen(
          userName: currentName,
          currentClass: currentClass,
          selectedBoard: currentBoard,
          isSwitching: true,
        ),
      ),
    );

    if (newClass != null && newClass.isNotEmpty && newClass != currentClass) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_class', newClass);
      setState(() {
        currentClass = newClass;
      });
      _loadLearningProgress(forceRefresh: true);
    }
  }

  void _navigateToModule(String mode) {
    if (mode == 'free') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FreeContentScreen(selectedClass: currentClass),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SubjectScreen(selectedClass: currentClass, mode: mode),
        ),
      ).then((_) => _loadLearningProgress(forceRefresh: false));
    }
  }

  // Edit Profile Dialog (Warning free, neonCyan unused removed)
  void _showEditProfileDialog() {
    const neonGold = Color(0xFFFFB800);

    final nameCtrl = TextEditingController(text: currentName);
    final phoneCtrl = TextEditingController(text: currentPhone);
    final emailCtrl = TextEditingController(text: currentEmail);
    String selectedDialogBoard = currentBoard;
    String selectedDialogClass = currentClass;
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    final availableBoards = [
      'Bihar Board (BSEB)',
      'CBSE Board',
      'Jharkhand Board (JAC)',
    ];

    final availableClasses = [
      'Class 8',
      'Class 9',
      'Class 10th',
      'Board Special',
    ];

    if (!availableBoards.contains(selectedDialogBoard)) {
      selectedDialogBoard = availableBoards.first;
    }
    if (!availableClasses.contains(selectedDialogClass)) {
      selectedDialogClass = availableClasses[2];
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0B111E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: neonGold, width: 1.5),
              ),
              title: const Row(
                children: [
                  Icon(Icons.shield_rounded, color: neonGold, size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "CADET PROFILE DETAILS",
                      style: TextStyle(
                        color: neonGold,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Update your name, 10-digit WhatsApp number, email, board, and class to maintain synced progress.",
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(height: 16),
                      const Text("Cadet Name", style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: nameCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person_rounded, color: neonGold, size: 18),
                          hintText: "Enter full name",
                          hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF101726),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: neonGold)),
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty) ? "Name cannot be empty" : null,
                      ),
                      const SizedBox(height: 12),
                      const Text("WhatsApp Number (10 Digits)", style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          counterText: "",
                          prefixIcon: const Icon(Icons.phone_rounded, color: neonGold, size: 18),
                          hintText: "10-digit mobile number",
                          hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF101726),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: neonGold)),
                        ),
                        validator: (val) {
                          final clean = (val ?? '').replaceAll(RegExp(r'\D'), '');
                          return clean.length != 10 ? "Enter a valid 10-digit phone number" : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text("Email Address", style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.email_rounded, color: neonGold, size: 18),
                          hintText: "student@purix.edu",
                          hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF101726),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: neonGold)),
                        ),
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty && !val.contains('@')) {
                            return "Enter a valid email address";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text("Education Board", style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101726),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedDialogBoard,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF0F172A),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            icon: const Icon(Icons.arrow_drop_down_rounded, color: neonGold),
                            items: availableBoards.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedDialogBoard = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text("Cadet Class", style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101726),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedDialogClass,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF0F172A),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            icon: const Icon(Icons.arrow_drop_down_rounded, color: neonGold),
                            items: availableClasses.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedDialogClass = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text("CANCEL", style: TextStyle(color: Colors.white54, fontSize: 11)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: neonGold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSaving = true);

                          final newName = nameCtrl.text.trim();
                          final newPhone = phoneCtrl.text.trim();
                          final newEmail = emailCtrl.text.trim();

                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('user_name', newName);
                          await prefs.setString('user_phone', newPhone);
                          await prefs.setString('user_email', newEmail);
                          await prefs.setString('user_board', selectedDialogBoard);
                          await prefs.setString('user_class', selectedDialogClass);

                          SheetService.syncUserProfile(
                            name: newName,
                            phone: newPhone,
                            email: newEmail.isNotEmpty ? newEmail : "student@purix.edu",
                            selectedClass: selectedDialogClass,
                            selectedBoard: selectedDialogBoard,
                            forceRefresh: true,
                          );

                          if (mounted) {
                            setState(() {
                              currentName = newName;
                              currentPhone = newPhone;
                              currentEmail = newEmail;
                              currentBoard = selectedDialogBoard;
                              currentClass = selectedDialogClass;
                            });
                            _loadLearningProgress(forceRefresh: true);
                          }

                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Cadet Profile Updated Successfully"),
                                backgroundColor: Color(0xFF00FF88),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Icon(Icons.check_rounded, color: Colors.black, size: 16),
                  label: Text(
                    isSaving ? "SAVING..." : "SAVE DETAILS",
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openProfileSheet() {
    const neonCyan = Color(0xFF00F0FF);
    const neonGreen = Color(0xFF00FF88);
    const neonGold = Color(0xFFFFB800);
    final bool isProOrActive = subscriptionStatus.toUpperCase() == "PRO" || subscriptionStatus.toUpperCase() == "ACTIVE";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B111E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: neonCyan, width: 1.2),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: const Color(0xFF1A253A),
                    child: Text(
                      currentName.isNotEmpty ? currentName[0].toUpperCase() : 'A',
                      style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    currentName.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'BOARD: $currentBoard  |  CLASS: $currentClass',
                    style: const TextStyle(color: neonGreen, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'UID: $currentUid',
                    style: const TextStyle(color: neonCyan, fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  ),
                  if (currentPhone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'PHONE: $currentPhone',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Classroom Status Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF121A2A), Color(0xFF0E1522), Color(0xFF1A180E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: neonGold.withAlpha(100)),
                      boxShadow: [
                        BoxShadow(color: neonGold.withAlpha(20), blurRadius: 15),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.shield_rounded, color: neonGold, size: 20),
                                SizedBox(width: 6),
                                Text(
                                  "CLASSROOM ENROLLMENT",
                                  style: TextStyle(color: neonGold, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: neonGold.withAlpha(38),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: neonGold.withAlpha(100)),
                              ),
                              child: Text(
                                isProOrActive ? 'ACTIVE CADET' : 'BATCH MATERIAL',
                                style: const TextStyle(color: neonGold, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "• All Chapter Tests & Question Banks Unlocked\n• Handwritten Formula Sheets & PDF Notes\n• 100% Ad-Free Rapid Revision Access\n• Direct Mentor Guidance at Center",
                          style: TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.45),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: neonGold,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _showPaymentDialog();
                            },
                            icon: const Icon(Icons.school_rounded, color: Colors.black, size: 16),
                            label: Text(
                              isProOrActive ? "CLASSROOM STATUS: VERIFIED" : "VISIT INSTITUTE / CONTACT CENTER",
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 1. Edit Cadet Details Button
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF101726),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.edit_note_rounded, color: neonCyan, size: 22),
                      title: const Text("Edit Cadet Details", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Update Name, Mobile, Email & Settings", style: TextStyle(color: Colors.white54, fontSize: 10.5)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _showEditProfileDialog();
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 2. Edit Board Button
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF101726),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.account_balance_rounded, color: Color(0xFF00FF88), size: 20),
                      title: Text("Change Education Board ($currentBoard)", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Switch Bihar, CBSE or Jharkhand Board", style: TextStyle(color: Colors.white54, fontSize: 10.5)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _changeBoard();
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 3. Edit Class Button
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF101726),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.school_rounded, color: neonCyan, size: 20),
                      title: Text("Switch Class ($currentClass)", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Switch Class 8, 9, 10th or Board Special", style: TextStyle(color: Colors.white54, fontSize: 10.5)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _changeClass();
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 4. Purix Classroom Center Support
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF101726),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.support_agent_rounded, color: neonGold, size: 22),
                      title: const Text("Contact Purix Center", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Talk to teachers & mentors directly", style: TextStyle(color: Colors.white54, fontSize: 10.5)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _openWhatsApp();
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Logout Button
                  TextButton.icon(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      if (sheetContext.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 16),
                    label: const Text("LOGOUT CADET SESSION", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _getSubjectIcon(String subName) {
    final s = subName.toLowerCase();
    if (s.contains('sci')) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: const Color(0xFF0088FF).withAlpha(50), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.science_rounded, color: Color(0xFF00A2FF), size: 18),
      );
    }
    if (s.contains('soc') || s.contains('sst')) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: const Color(0xFFBF00FF).withAlpha(50), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.public_rounded, color: Color(0xFFD946EF), size: 18),
      );
    }
    if (s.contains('math')) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: const Color(0xFF00FF88).withAlpha(50), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.calculate_rounded, color: Color(0xFF00FF88), size: 18),
      );
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: const Color(0xFFFFB800).withAlpha(50), borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.translate_rounded, color: Color(0xFFFFB800), size: 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    const neonCyan = Color(0xFF00F0FF);
    const neonGreen = Color(0xFF00FF88);
    const neonGold = Color(0xFFFFB800);
    const darkVoid = Color(0xFF040814);

    return Scaffold(
      backgroundColor: darkVoid,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF040814),
          border: Border(top: BorderSide(color: Colors.white.withAlpha(25), width: 1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(200), blurRadius: 20, offset: const Offset(0, -6)),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {},
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.home_rounded, color: neonGold, size: 22),
                          const SizedBox(height: 2),
                          const Text("Home", style: TextStyle(color: neonGold, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Container(width: 18, height: 2, decoration: BoxDecoration(color: neonGold, borderRadius: BorderRadius.circular(2))),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _bottomNavItem(
                    title: 'MCQ Test',
                    secCode: 'SEC.01',
                    icon: Icons.rocket_launch_rounded,
                    color: neonCyan,
                    onTap: () => _navigateToModule('mcq'),
                  ),
                ),
                Expanded(
                  child: _bottomNavItem(
                    title: 'Practice',
                    secCode: 'SEC.02',
                    icon: Icons.menu_book_rounded,
                    color: neonGold,
                    onTap: () => _navigateToModule('practice'),
                  ),
                ),
                Expanded(
                  child: _bottomNavItem(
                    title: 'Notes',
                    secCode: 'SEC.03',
                    icon: Icons.description_rounded,
                    color: const Color(0xFFBF00FF),
                    onTap: () => _navigateToModule('notes'),
                  ),
                ),
                Expanded(
                  child: _bottomNavItem(
                    title: 'Free Matrix',
                    secCode: 'SEC.04',
                    icon: Icons.explore_rounded,
                    color: const Color(0xFF00FF88),
                    onTap: () => _navigateToModule('free'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xFF040814),
        elevation: 0,
        titleSpacing: 10,
        title: Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1A1305),
                    border: Border.all(color: neonGold),
                  ),
                  child: const Center(
                    child: Text("P", style: TextStyle(color: neonGold, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("PURIX ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5)),
                        Text("ACADEMY", style: TextStyle(color: neonGold, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5)),
                      ],
                    ),
                    Text(
                      "NEW WAY OF LEARNING",
                      style: TextStyle(color: Colors.white.withAlpha(128), fontSize: 7.5, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Pure Circular Cadet Avatar Button (No text label as requested)
          InkWell(
            onTap: _openProfileSheet,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: neonCyan,
                child: Text(
                  currentName.isNotEmpty ? currentName.trim().substring(0, 1).toUpperCase() : 'A',
                  style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Executive Hero Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F1D38), Color(0xFF091326), Color(0xFF040812)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF0099FF).withAlpha(100)),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF0099FF).withAlpha(30), blurRadius: 25),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${_getGreeting()},", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        Text("$currentName!", style: const TextStyle(color: neonGold, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        const SizedBox(height: 6),
                        Text("\"${_getDailyQuote()}\"", style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Metrics Row (Both cards pure stats cards, arrow-free)
            Row(
              children: [
                // Card 1: TESTS COMPLETED
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1324),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: neonGreen.withAlpha(100)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: neonGreen.withAlpha(38)),
                                child: const Icon(Icons.emoji_events_rounded, color: neonGreen, size: 18),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text("TESTS COMPLETED", style: TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold)),
                                    ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text("$completedQuizCount", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                                    ),
                                    const Text("/ 0", style: TextStyle(color: Colors.white38, fontSize: 9)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Card 2: TARGET GOAL (Arrow completely removed)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1324),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: neonCyan.withAlpha(100)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: neonCyan.withAlpha(38)),
                                child: const Icon(Icons.adjust_rounded, color: neonCyan, size: 20),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("TARGET GOAL", style: TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold)),
                                    Row(
                                      children: [
                                        const Text("95%+", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                                        const SizedBox(width: 4),
                                        Text("Board", style: TextStyle(color: Colors.white.withAlpha(128), fontSize: 9)),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: Container(
                                        height: 3,
                                        width: double.infinity,
                                        color: Colors.black45,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(width: 60, color: neonCyan),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3. Three Module Shortcut Cards Row
            Row(
              children: [
                Expanded(
                  child: _quickShortcutCard(
                    title: 'MCQ SPRINT',
                    subtitle: 'Timed Tests',
                    icon: Icons.flash_on_rounded,
                    color: const Color(0xFF0099FF),
                    onTap: () => _navigateToModule('mcq'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _quickShortcutCard(
                    title: 'PURIX NOTES',
                    subtitle: 'Core Theory',
                    icon: Icons.description_rounded,
                    color: const Color(0xFFBF00FF),
                    onTap: () => _navigateToModule('notes'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _quickShortcutCard(
                    title: 'FREE MATRIX',
                    subtitle: 'PYQ & Blueprints',
                    icon: Icons.explore_rounded,
                    color: neonGold,
                    onTap: () => _navigateToModule('free'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 4. LEARNING PROGRESS Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF08101E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: neonCyan.withAlpha(50)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(128), blurRadius: 20),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.bar_chart_rounded, color: neonCyan, size: 18),
                          SizedBox(width: 6),
                          Text("LEARNING PROGRESS", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF121C2F),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.workspace_premium_rounded, color: neonGold, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              _calculateLevelName(overallPercentage),
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "$totalCompletedChapters of $totalSyllabusChapters chapters mastered",
                        style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace'),
                      ),
                      Text(
                        "$overallPercentage% COMPLETE",
                        style: const TextStyle(color: neonGreen, fontSize: 11, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: overallPercentage > 0 ? (overallPercentage / 100.0) : 0.02,
                      minHeight: 6,
                      backgroundColor: const Color(0xFF050912),
                      valueColor: const AlwaysStoppedAnimation<Color>(neonGreen),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // SCROLLABLE SUBJECT LIST
                  SizedBox(
                    height: 180,
                    child: isLoadingProgress
                        ? const Center(child: CircularProgressIndicator(color: neonCyan, strokeWidth: 2))
                        : ListView.builder(
                            itemCount: subjectProgressList.length,
                            physics: const BouncingScrollPhysics(),
                            itemBuilder: (context, index) {
                              final sub = subjectProgressList[index];
                              final String sName = sub['subject'];
                              final int pct = sub['percentage'];
                              final int doneC = sub['completed'];
                              final int totalC = sub['total'];
                              final String level = sub['level'];
                              final Color col = sub['color'];

                              return InkWell(
                                onTap: () => _navigateToModule('mcq'),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0A1324),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                _getSubjectIcon(sName),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    sName,
                                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withAlpha(15),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(level, style: const TextStyle(color: Colors.white70, fontSize: 8), maxLines: 1),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text("$pct%", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                              const SizedBox(width: 3),
                                              Text("($doneC/$totalC)", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                              const SizedBox(width: 2),
                                              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 10),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: pct > 0 ? (pct / 100.0) : 0.02,
                                          minHeight: 3.5,
                                          backgroundColor: Colors.black45,
                                          valueColor: AlwaysStoppedAnimation<Color>(col),
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
            const SizedBox(height: 12),

            // 5. Help Desk Banner
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openWhatsApp(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2A200B), Color(0xFF1D1708), Color(0xFF120E04)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: neonGold.withAlpha(100)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: neonGold.withAlpha(50), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.support_agent_rounded, color: neonGold, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Need Help?", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          Text("Get instant support for your queries.", style: TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: neonGold,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => _openWhatsApp(),
                      icon: const Icon(Icons.chat_bubble_rounded, color: Colors.black, size: 14),
                      label: const Text("HELP DESK", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _quickShortcutCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1324),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(100)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color.withAlpha(38)),
                  child: Icon(icon, color: color, size: 18),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(15)),
                  child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 10),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 9, fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }

  Widget _bottomNavItem({
    required String title,
    required String secCode,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 2),
            Text(title, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 1),
            Text(secCode, style: TextStyle(color: color.withAlpha(128), fontSize: 7, fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }
}