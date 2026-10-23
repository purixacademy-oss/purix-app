import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/sheet_service.dart';
import 'class_screen.dart';
import 'subject_screen.dart';
import 'free_content_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;
  final String selectedClass;

  const DashboardScreen({
    super.key,
    required this.userName,
    required this.selectedClass,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late String currentClass;
  late String currentName;
  String currentPhone = '';
  String currentEmail = '';
  String currentUid = 'FETCHING...';
  String subscriptionStatus = 'SYNCING...';

  final String supportWhatsAppNumber = "919508774890";
  final String academyUPI = "6201161834@ptyes";

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
    currentName = widget.userName;
    _loadUserDataAndCheckProfile();
    _loadLearningProgress(forceRefresh: false); // Strict 12-hour cache
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

  // Load progress strictly from 12-hour cache (Zero API calls if already cached)
  Future<void> _loadLearningProgress({bool forceRefresh = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Count completed quizzes locally
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

      // Fetch ONLY from MCQ sheet to prevent chapter duplicates
      final mcqData = await SheetService.fetchSheetData("${prefix} MCQ", forceRefresh: forceRefresh);

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

  // 12-Hour Throttled Profile Sync (Avoids calling Google Sheet on every single app open)
  Future<void> _loadUserDataAndCheckProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      currentPhone = prefs.getString('user_phone') ?? '';
      currentEmail = prefs.getString('user_email') ?? '';
      currentUid = prefs.getString('user_uid') ?? 'ID-NOT-FOUND';
      subscriptionStatus = prefs.getString('user_sub') ?? 'SYNCING...';
      currentName = prefs.getString('user_name') ?? widget.userName;
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

    // 1. Try native WhatsApp direct intent first
    try {
      if (await canLaunchUrl(nativeUri)) {
        launched = await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    // 2. Try wa.me URL in external browser/app
    if (!launched) {
      try {
        if (await canLaunchUrl(webUri)) {
          launched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}
    }

    // 3. Try direct api.whatsapp.com without strict canLaunch check
    if (!launched) {
      try {
        launched = await launchUrl(apiUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }

    // 4. Try platform default launcher
    if (!launched) {
      try {
        launched = await launchUrl(webUri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }

    // 5. Fallback dialog if device has restricted links or no WhatsApp app installed
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
              Text(
                "Purix Help Desk",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Connect directly with Purix Academy Support:",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
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
                      child: Text(
                        "+91 9508774890",
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(const ClipboardData(text: "+919508774890"));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Support Number copied!"),
                            backgroundColor: Color(0xFF00FF88),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00F0FF).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF00F0FF).withOpacity(0.4)),
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
              label: const Text(
                "CALL SUPPORT",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _showPaymentDialog() {
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
              Icon(Icons.workspace_premium_rounded, color: neonGold, size: 40),
              SizedBox(height: 8),
              Text(
                "PURIX PRO VIP PASS",
                style: TextStyle(color: neonGold, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Unlock all Chapter Test Sets, Formula Sheets & WhatsApp Mentor Support.",
                style: TextStyle(color: Colors.white70, fontSize: 12),
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
                        Text("Fee:", style: TextStyle(color: Colors.white60, fontSize: 12)),
                        Text("₹599 (Full Syllabus)", style: TextStyle(color: neonGold, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("UPI ID:", style: TextStyle(color: Colors.white60, fontSize: 12)),
                        Text(academyUPI, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("CANCEL", style: TextStyle(color: Colors.white54, fontSize: 11)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: neonGold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                _openWhatsApp(
                  message: "Hello Purix Admin, I want to activate PURIX PRO PASS (₹599) for Cadet $currentName ($currentClass, UID: $currentUid, Phone: $currentPhone).",
                );
              },
              icon: const Icon(Icons.chat_bubble_rounded, color: Colors.black, size: 16),
              label: const Text(
                "PAY & NOTIFY",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ],
        );
      },
    );
  }

  void _changeClass() async {
    final newClass = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ClassScreen(userName: currentName)),
    );

    if (newClass != null && newClass is String && newClass != currentClass) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_class', newClass);
      setState(() {
        currentClass = newClass;
      });
      _loadLearningProgress(forceRefresh: false);
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

  void _showEditProfileDialog() {
    const neonCyan = Color(0xFF00F0FF);
    const neonGold = Color(0xFFFFB800);

    final nameCtrl = TextEditingController(text: currentName);
    final phoneCtrl = TextEditingController(text: currentPhone);
    final emailCtrl = TextEditingController(text: currentEmail);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

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
                        "Update your name, 10-digit WhatsApp number and email to maintain synced progress and verification.",
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(height: 16),
                      // Cadet Name Field
                      const Text(
                        "Cadet Name",
                        style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: neonGold),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return "Name cannot be empty";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      // WhatsApp Phone Field
                      const Text(
                        "WhatsApp Number (10 Digits)",
                        style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: neonGold),
                          ),
                        ),
                        validator: (val) {
                          final clean = (val ?? '').replaceAll(RegExp(r'\D'), '');
                          if (clean.length != 10) {
                            return "Enter a valid 10-digit phone number";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      // Email Field
                      const Text(
                        "Email Address",
                        style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: neonGold),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return "Email cannot be empty";
                          }
                          if (!val.contains('@') || !val.contains('.')) {
                            return "Enter a valid email address";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                  child: const Text("CANCEL", style: TextStyle(color: Colors.white54, fontSize: 11)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: neonGold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

                          if (mounted) {
                            setState(() {
                              currentName = newName;
                              currentPhone = newPhone;
                              currentEmail = newEmail;
                            });
                          }

                          // Sync to Google Sheet in background
                          SheetService.syncUserProfile(
                            name: newName,
                            phone: newPhone,
                            email: newEmail,
                            selectedClass: currentClass,
                          ).then((status) {
                            if (mounted) {
                              setState(() {
                                subscriptionStatus = status;
                              });
                            }
                          }).catchError((_) {});

                          if (mounted) {
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
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                        )
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
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
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
                    'NODE: $currentClass  |  STATUS: $subscriptionStatus',
                    style: const TextStyle(color: neonGreen, fontSize: 11, fontFamily: 'monospace'),
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

                  // VIP Purix PRO Pass Card Inside Profile Sheet
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
                      border: Border.all(color: neonGold.withOpacity(0.4)),
                      boxShadow: [
                        BoxShadow(color: neonGold.withOpacity(0.08), blurRadius: 15),
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
                                Icon(Icons.workspace_premium_rounded, color: neonGold, size: 20),
                                SizedBox(width: 6),
                                Text(
                                  "PURIX PRO PASS",
                                  style: TextStyle(color: neonGold, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: neonGold.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: neonGold.withOpacity(0.4)),
                              ),
                              child: Text(
                                isProOrActive ? 'ACTIVE 👑' : '₹599 PASS',
                                style: const TextStyle(color: neonGold, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "• All Chapter Tests & Question Banks Unlocked\n• Handwritten Formula Sheets & PDF Notes\n• 100% Ad-Free Rapid Revision Access\n• Direct WhatsApp Mentor Guidance",
                          style: TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.45),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 38,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: neonGold,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _showPaymentDialog();
                            },
                            icon: const Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 16),
                            label: Text(
                              isProOrActive ? "VIEW MEMBERSHIP DETAILS" : "UPGRADE TO PRO PASS (₹599)",
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 1. Edit Cadet Details Button (Restored!)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF101726),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.edit_note_rounded, color: neonCyan, size: 22),
                      title: const Text('Edit Cadet Details', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Update name, phone number or email', style: TextStyle(color: Colors.white54, fontSize: 10)),
                      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 12),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _showEditProfileDialog();
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 2. Switch Target Class Button
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF101726),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.refresh_rounded, color: neonCyan, size: 20),
                      title: const Text('Switch Target Class', style: TextStyle(color: Colors.white, fontSize: 12)),
                      subtitle: Text('Current: $currentClass', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 12),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _changeClass();
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 3. Help Desk & WhatsApp Support
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF101726),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.support_agent_rounded, color: neonGold, size: 22),
                      title: const Text('Purix Help Desk & Support', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Chat on WhatsApp or Call +91 9508774890', style: TextStyle(color: Colors.white54, fontSize: 10)),
                      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 12),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _openWhatsApp();
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Logout Button
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF101726),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                      title: const Text('Logout Session', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 12),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();
                        if (!mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
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
        decoration: BoxDecoration(
          color: const Color(0xFF0088FF).withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.science_rounded, color: Color(0xFF00A2FF), size: 18),
      );
    }
    if (s.contains('soc') || s.contains('sst')) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFBF00FF).withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.public_rounded, color: Color(0xFFD946EF), size: 18),
      );
    }
    if (s.contains('math')) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF00FF88).withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.calculate_rounded, color: Color(0xFF00FF88), size: 18),
      );
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFFFB800).withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
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
      // 5-Tab Fixed Bottom Navigation Bar matching Reference Image
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF040814),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.8),
              blurRadius: 20,
              offset: const Offset(0, -6),
            )
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Row(
              children: [
                // Tab 1: Home (Active with gold line underneath)
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
                          const Text(
                            "Home",
                            style: TextStyle(color: neonGold, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Container(width: 18, height: 2, decoration: BoxDecoration(color: neonGold, borderRadius: BorderRadius.circular(2))),
                        ],
                      ),
                    ),
                  ),
                ),
                // Tab 2: MCQ Test (Rocket)
                Expanded(
                  child: _bottomNavItem(
                    title: 'MCQ Test',
                    secCode: 'SEC.01',
                    icon: Icons.rocket_launch_rounded,
                    color: neonCyan,
                    onTap: () => _navigateToModule('mcq'),
                  ),
                ),
                // Tab 3: Practice (Open Book)
                Expanded(
                  child: _bottomNavItem(
                    title: 'Practice',
                    secCode: 'SEC.02',
                    icon: Icons.menu_book_rounded,
                    color: neonGold,
                    onTap: () => _navigateToModule('practice'),
                  ),
                ),
                // Tab 4: Notes (Document)
                Expanded(
                  child: _bottomNavItem(
                    title: 'Notes',
                    secCode: 'SEC.03',
                    icon: Icons.description_rounded,
                    color: const Color(0xFFBF00FF),
                    onTap: () => _navigateToModule('notes'),
                  ),
                ),
                // Tab 5: Free Matrix (Compass)
                Expanded(
                  child: _bottomNavItem(
                    title: 'Free Matrix',
                    secCode: 'SEC.04',
                    icon: Icons.explore_rounded,
                    color: neonCyan,
                    onTap: () => _navigateToModule('free'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // Top AppBar matching reference image (Logo + PURIX ACADEMY + Class Selector + Avatar)
      appBar: AppBar(
        backgroundColor: const Color(0xFF040814),
        elevation: 0,
        titleSpacing: 10,
        title: Row(
          children: [
            // User requested Logo Image on left of Purix Academy
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
                        const Text(
                          "PURIX ",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
                        ),
                        Text(
                          "ACADEMY",
                          style: TextStyle(color: neonGold, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    Text(
                      "NEW WAY OF LEARNING",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 7.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Class Selector Pill
          InkWell(
            onTap: _changeClass,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1729),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.school_rounded, color: neonCyan, size: 13),
                  const SizedBox(width: 3),
                  Text(
                    currentClass,
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 1),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 13),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // User Avatar Initial Button
          InkWell(
            onTap: _openProfileSheet,
            borderRadius: BorderRadius.circular(20),
            child: CircleAvatar(
              radius: 15,
              backgroundColor: const Color(0xFF1A253A),
              child: Text(
                currentName.isNotEmpty ? currentName[0].toUpperCase() : 'A',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      // Pure Scrollview without refresh indicator to prevent accidental API calls
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Executive Hero Banner (Matches Reference Image)
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
                border: Border.all(color: const Color(0xFF0099FF).withOpacity(0.4)),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF0099FF).withOpacity(0.12), blurRadius: 25),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${_getGreeting()},",
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "$currentName!",
                          style: const TextStyle(color: neonGold, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "\"${_getDailyQuote()}\"",
                          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 10.5, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Target Board Graphic + "Keep Going"
                  Column(
                    children: [
                      const Text(
                        "Keep Going ~",
                        style: TextStyle(color: neonGold, fontSize: 12, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1A1305),
                          border: Border.all(color: neonGold, width: 2),
                          boxShadow: [
                            BoxShadow(color: neonGold.withOpacity(0.35), blurRadius: 18),
                          ],
                        ),
                        child: const Icon(Icons.track_changes_rounded, color: neonGold, size: 34),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Metrics Row (2 Cards: TESTS COMPLETED & TARGET GOAL)
            Row(
              children: [
                // Card 1: TESTS COMPLETED
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1324),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: neonGreen.withOpacity(0.4)),
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
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: neonGreen.withOpacity(0.15),
                                ),
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
                                      child: Text(
                                        "TESTS COMPLETED",
                                        style: TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        "$completedQuizCount",
                                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                    const Text(
                                      "/ 0",
                                      style: TextStyle(color: Colors.white38, fontSize: 9),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 12),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Card 2: TARGET GOAL
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1324),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: neonCyan.withOpacity(0.4)),
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
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: neonCyan.withOpacity(0.15),
                                ),
                                child: const Icon(Icons.adjust_rounded, color: neonCyan, size: 20),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "TARGET GOAL",
                                      style: TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold),
                                    ),
                                    Row(
                                      children: [
                                        const Text(
                                          "95%+",
                                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Board",
                                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9),
                                        ),
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
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 12),
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

            // 4. LEARNING PROGRESS Card (With Scrollable Subject List as Requested!)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF08101E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: neonCyan.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.bar_chart_rounded, color: neonCyan, size: 18),
                          SizedBox(width: 6),
                          Text(
                            "LEARNING PROGRESS",
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                          ),
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
                  const SizedBox(height: 12),

                  // Overall Syllabus Progress Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Overall Syllabus Done",
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                      Text(
                        "$overallPercentage% ($totalCompletedChapters/$totalSyllabusChapters Chapters)",
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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

                  // SCROLLABLE SUBJECT LIST (Supports Science, Social Science, Math, Hindi, Sanskrit & more!)
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
                                                    color: Colors.white.withOpacity(0.06),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    level,
                                                    style: const TextStyle(color: Colors.white70, fontSize: 8),
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                "$pct%",
                                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                "($doneC/$totalC)",
                                                style: const TextStyle(color: Colors.white38, fontSize: 10),
                                              ),
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
                  const SizedBox(height: 8),

                  // Bottom Motivational Banner
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1324),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.track_changes_rounded, color: neonGold, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Small steps everyday lead to big results.",
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "You're doing great! Keep it up!",
                                style: TextStyle(color: Colors.white54, fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 5. Need Help? Help Desk Banner (Matches Reference Image)
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
                  border: Border.all(color: neonGold.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: neonGold.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.support_agent_rounded, color: neonGold, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Need Help?",
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "Get instant support for your queries.",
                            style: TextStyle(color: Colors.white70, fontSize: 10),
                          ),
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
                      label: const Text(
                        "HELP DESK",
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10),
                      ),
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
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.2),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.3), size: 10),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                maxLines: 1,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                subtitle,
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 8),
                maxLines: 1,
              ),
            ),
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
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600),
            ),
            Text(
              secCode,
              style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }
}