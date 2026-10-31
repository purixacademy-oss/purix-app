import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/sheet_service.dart';
import 'board_screen.dart';
import 'class_screen.dart';
import 'free_content_screen.dart';
import 'login_screen.dart';
import 'subject_screen.dart';

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

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  static const String supportPhone = "+919508774890";

  // ---- Design tokens (same palette as the web design) ----
  static const bg = Color(0xFF040814);
  static const cardBg = Color(0xFF0A1324);
  static const modalBg = Color(0xFF0B111E);
  static const fieldBg = Color(0xFF101726);
  static const cyan = Color(0xFF00F0FF);
  static const gold = Color(0xFFFFB800);
  static const gold2 = Color(0xFFFFD700);
  static const green = Color(0xFF00FF88);
  static const purple = Color(0xFFBF00FF);
  static const blue = Color(0xFF0099FF);
  static const amber = Color(0xFFFCD34D);

  late final AnimationController _pulse;

  late String _name;
  late String _class;
  late String _board;
  String _phone = '';
  String _email = '';
  String _uid = 'FETCHING...';
  String _sub = 'FREE';
  int _completedQuizzes = 0;
  bool _checking = false;

  bool get _verified => _sub == 'PRO' || _sub == 'VERIFIED';

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _name = widget.userName.isEmpty ? 'Student' : widget.userName;
    _class = widget.selectedClass;
    _board = widget.selectedBoard ?? 'Bihar Board (BSEB)';
    _loadLocal();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  // =====================================================================
  // LOGIC (unchanged behaviour)
  // =====================================================================
  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    int count = 0;
    for (final key in prefs.getKeys()) {
      if (key.startsWith('quiz_') && key.endsWith('_completed') && prefs.getBool(key) == true) {
        count++;
      }
    }
    if (!mounted) return;
    setState(() {
      _phone = prefs.getString('user_phone') ?? '';
      _email = prefs.getString('user_email') ?? '';
      _sub = (prefs.getString('user_sub') ?? 'FREE').toUpperCase();
      final uid = prefs.getString('user_uid');
      if (uid != null && uid.isNotEmpty) _uid = uid;
      final savedName = prefs.getString('user_name');
      if (savedName != null && savedName.isNotEmpty) _name = savedName;
      _completedQuizzes = count;
    });

    _backgroundSync();

    if (_phone.length < 10 || _name.toLowerCase() == 'student' || _email.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showEditDialog();
      });
    }
  }

  Future<void> _backgroundSync() async {
    if (_phone.length != 10 || _name.toLowerCase() == 'student') return;
    final result = await SheetService.syncUserProfile(
      name: _name,
      phone: _phone,
      email: _email.isEmpty ? 'N/A' : _email,
      selectedClass: _class,
      selectedBoard: _board,
    );
    if (!mounted) return;
    if (result == 'DEACTIVE') {
      _msg("Your account has been deactivated by Admin.", type: 'error');
      await _logout();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _sub = (prefs.getString('user_sub') ?? 'FREE').toUpperCase();
      final uid = prefs.getString('user_uid');
      if (uid != null && uid.isNotEmpty) _uid = uid;
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _msg(String text, {String type = 'success'}) {
    final color = type == 'error' ? Colors.redAccent : (type == 'info' ? Colors.blueGrey : Colors.teal);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  Future<void> _liveSync({VoidCallback? onUpdate}) async {
    if (_phone.isEmpty) {
      _msg("No registered phone number found to sync.", type: 'error');
      return;
    }
    setState(() => _checking = true);
    onUpdate?.call();
    try {
      final row = await SheetService.fetchUserByPhone(_phone);
      final plan = (row?['Plan'] ?? row?['plan'] ?? 'FREE').toString().trim().toUpperCase();
      final clean = (plan == 'PRO' || plan == 'VERIFIED') ? 'PRO' : 'FREE';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_sub', clean);
      if (!mounted) return;
      setState(() => _sub = clean);
      _msg(
        clean == 'PRO'
            ? "✅ CLASSROOM STATUS: VERIFIED (Enrolled in Purix Academy)"
            : "ℹ️ CLASSROOM STATUS: UNVERIFIED (Contact Classroom Center to enroll)",
        type: clean == 'PRO' ? 'success' : 'info',
      );
    } catch (_) {
      if (mounted) _msg("Could not sync verification status with Google Sheet.", type: 'error');
    } finally {
      if (mounted) setState(() => _checking = false);
      onUpdate?.call();
    }
  }

  void _openModule(String mode) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SubjectScreen(selectedClass: _class, mode: mode)));
  }

  void _openFree() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => FreeContentScreen(selectedClass: _class)));
  }

  Future<void> _switchClass() async {
    final chosen = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ClassScreen(userName: _name, currentClass: _class, selectedBoard: _board, isSwitching: true),
      ),
    );
    if (chosen != null && chosen.isNotEmpty && mounted) setState(() => _class = chosen);
  }

  Future<void> _switchBoard() async {
    final chosen = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => BoardScreen(userName: _name, currentBoard: _board, isSwitching: true)),
    );
    if (chosen != null && chosen.isNotEmpty && mounted) setState(() => _board = chosen);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _copyNumber() {
    Clipboard.setData(const ClipboardData(text: supportPhone));
    _msg("Number copied: $supportPhone");
  }

  // =====================================================================
  // DESIGN HELPERS
  // =====================================================================
  TextStyle _mono(double size, Color color, {FontWeight weight = FontWeight.normal, double spacing = 0}) =>
      TextStyle(fontFamily: 'monospace', fontSize: size, color: color, fontWeight: weight, letterSpacing: spacing);

  Widget _modalShell({
    required Color border,
    required Widget child,
    double borderWidth = 1,
    double radius = 16,
    EdgeInsets padding = const EdgeInsets.all(20),
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 448),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: modalBg,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: border, width: borderWidth),
            boxShadow: [BoxShadow(color: border.withOpacity(0.2), blurRadius: 30)],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _glowCircle(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withOpacity(0.10), color.withOpacity(0.0)]),
        ),
      ),
    );
  }

  Widget _iconBox(IconData icon, Color color, {double size = 40, double iconSize = 20, double radius = 12, bool circle = false}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
        border: Border.all(color: color.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 12)],
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }

  Widget _pill(String text, Color color, {double size = 9, FontWeight weight = FontWeight.bold, double bgAlpha = 0.10}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(bgAlpha),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(text, style: _mono(size, color, weight: weight)),
    );
  }

  // =====================================================================
  // DIALOGS (Profile / Edit / Classroom)
  // =====================================================================
  void _showProfileModal() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final statusColor = _verified ? green : amber;
          return _modalShell(
            border: cyan.withOpacity(0.5),
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cyan.withOpacity(0.15),
                          border: Border.all(color: cyan.withOpacity(0.4)),
                          boxShadow: [BoxShadow(color: cyan.withOpacity(0.25), blurRadius: 15)],
                        ),
                        child: Text(_initial, style: const TextStyle(color: cyan, fontWeight: FontWeight.bold, fontSize: 20)),
                      ),
                      const SizedBox(height: 8),
                      Text(_name.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text("CLASS: $_class • $_board", style: _mono(11, Colors.white70)),
                      const SizedBox(height: 2),
                      Text("CADET ID: $_uid", style: _mono(12, cyan, weight: FontWeight.bold)),
                      if (_phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text("PHONE: +91 $_phone", style: _mono(10, Colors.white54)),
                      ],
                      const SizedBox(height: 14),

                      // Classroom status
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                              child: Icon(_verified ? Icons.check_circle_outline : Icons.shield_outlined, color: statusColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("CLASSROOM STATUS", style: _mono(9, Colors.white54, weight: FontWeight.bold, spacing: 1.5)),
                                  Text(_verified ? 'VERIFIED' : 'UNVERIFIED',
                                      style: _mono(12, statusColor, weight: FontWeight.bold, spacing: 0.5)),
                                  Text(_verified ? 'Monthly Classroom Batch Active' : 'Monthly Admission Required',
                                      style: _mono(9, Colors.white60)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _pill(_verified ? 'VERIFIED' : 'UNVERIFIED', statusColor, size: 10, bgAlpha: 0.2),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: _checking ? null : () => _liveSync(onUpdate: () {
                                        if (ctx.mounted) setSt(() {});
                                      }),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _checking
                                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: cyan))
                                          : const Icon(Icons.refresh, size: 12, color: cyan),
                                      const SizedBox(width: 4),
                                      Text(_checking ? 'Syncing...' : 'Live Sync', style: _mono(10, cyan)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Enrollment card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: gold2.withOpacity(0.4)),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF121A2A), Color(0xFF0E1522), Color(0xFF1A180E)],
                          ),
                          boxShadow: [BoxShadow(color: gold2.withOpacity(0.10), blurRadius: 20)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: gold2.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: gold2.withOpacity(0.5)),
                                  ),
                                  child: const Icon(Icons.school, color: gold2, size: 16),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("CLASSROOM ENROLLMENT", style: _mono(12, gold2, weight: FontWeight.w900, spacing: 1)),
                                      Text("Syllabus Node: $_class (${_board.split(' ').first})", style: _mono(9, Colors.white60)),
                                    ],
                                  ),
                                ),
                                _pill(_verified ? 'ACTIVE CADET 🎓' : 'NOT ENROLLED', statusColor, bgAlpha: 0.15),
                              ],
                            ),
                            const SizedBox(height: 10),
                            for (final t in const [
                              'Full Chapter Test Question Banks',
                              'Handwritten Formula & PDF Material',
                              'High-Yield Board Revision Drills',
                              'Direct Mentor Guidance at Institute Center',
                            ])
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline, size: 12, color: Color(0xFF00FF66)),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(t, style: _mono(10, Colors.white.withOpacity(0.8)))),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: gold2,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showClassroomDialog();
                                },
                                icon: const Icon(Icons.verified_user, size: 16),
                                label: Text(_verified ? 'VIEW CLASSROOM DETAILS' : 'INQUIRE AT CLASSROOM CENTER',
                                    style: _mono(11, Colors.black, weight: FontWeight.w900, spacing: 1)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Actions
                      _actionTile(Icons.school, gold, "Switch Target Class", "Current: $_class", () {
                        Navigator.pop(ctx);
                        _switchClass();
                      }),
                      _actionTile(Icons.apartment, cyan, "Switch Education Board", _board, () {
                        Navigator.pop(ctx);
                        _switchBoard();
                      }),
                      _actionTile(Icons.edit_outlined, Colors.white70, "Edit Cadet Details", "Update phone, email or name", () {
                        Navigator.pop(ctx);
                        _showEditDialog();
                      }),
                      _actionTile(Icons.logout, Colors.redAccent, "Terminate Session (Logout)", "Clear local session data", () {
                        Navigator.pop(ctx);
                        _logout();
                      }, danger: true),
                    ],
                  ),
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _actionTile(IconData icon, Color color, String title, String sub, VoidCallback onTap, {bool danger = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: danger ? Colors.red.withOpacity(0.3) : Colors.white10),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: danger ? Colors.red.withOpacity(0.15) : color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: danger ? Colors.redAccent : color, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: danger ? Colors.redAccent : Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: danger ? Colors.red.shade200.withOpacity(0.6) : Colors.white54, fontSize: 10)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, size: 16, color: danger ? Colors.redAccent.withOpacity(0.4) : Colors.white30),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog() {
    final nameC = TextEditingController(text: _name.toLowerCase() == 'student' ? '' : _name);
    final emailC = TextEditingController(text: _email);
    final phoneC = TextEditingController(text: _phone);

    Widget field(String label, TextEditingController c, IconData icon, String hint,
        {TextInputType? type, int? maxLength}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: _mono(11, Colors.white60)),
            const SizedBox(height: 4),
            TextField(
              controller: c,
              keyboardType: type,
              maxLength: maxLength,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                counterText: '',
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: Icon(icon, color: gold2, size: 16),
                filled: true,
                fillColor: fieldBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: gold2)),
              ),
            ),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => _modalShell(
        border: gold2,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, color: gold2, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text("CADET PROFILE VERIFICATION", style: _mono(13, gold2, weight: FontWeight.bold, spacing: 1))),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Valid Name, Email, and 10-digit WhatsApp number are required to maintain access to test simulations and synced records.",
                style: _mono(11, Colors.white70),
              ),
              const SizedBox(height: 20),
              field("Cadet Name (Mandatory)", nameC, Icons.person_outline, "Enter your name"),
              field("Email Address (Mandatory)", emailC, Icons.mail_outline, "student@purix.edu", type: TextInputType.emailAddress),
              field("WhatsApp Mobile (10 Digits)", phoneC, Icons.phone_outlined, "9876543210", type: TextInputType.phone, maxLength: 10),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold2,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final n = nameC.text.trim();
                    final p = phoneC.text.replaceAll(RegExp(r'\D'), '');
                    final e = emailC.text.trim();
                    if (n.isEmpty || n.toLowerCase() == 'student') {
                      _msg("Valid Cadet name is mandatory.", type: 'error');
                      return;
                    }
                    if (p.length != 10) {
                      _msg("Valid 10-digit mobile number is mandatory.", type: 'error');
                      return;
                    }
                    if (e.isEmpty || !e.contains('@')) {
                      _msg("Valid email address is mandatory.", type: 'error');
                      return;
                    }
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('user_name', n);
                    await prefs.setString('user_phone', p);
                    await prefs.setString('user_email', e);
                    if (!mounted) return;
                    setState(() {
                      _name = n;
                      _phone = p;
                      _email = e;
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    SheetService.syncUserProfile(
                      name: n,
                      phone: p,
                      email: e,
                      selectedClass: _class,
                      selectedBoard: _board,
                      forceRefresh: true,
                    ).then((_) => _backgroundSyncLocalRefresh());
                    _msg("Cadet profile synced successfully!");
                  },
                  child: Text("CONFIRM & SAVE DETAILS", style: _mono(12, Colors.black, weight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _backgroundSyncLocalRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _sub = (prefs.getString('user_sub') ?? 'FREE').toUpperCase();
      final uid = prefs.getString('user_uid');
      if (uid != null && uid.isNotEmpty) _uid = uid;
    });
  }

  void _showClassroomDialog() {
    Widget row(String k, String v, Color vc, {bool last = false}) {
      return Container(
        padding: EdgeInsets.only(bottom: last ? 0 : 8, top: last ? 4 : 0),
        margin: EdgeInsets.only(bottom: last ? 0 : 12),
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Colors.white10))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: _mono(12, Colors.white60)),
            const SizedBox(width: 12),
            Flexible(child: Text(v, textAlign: TextAlign.right, style: _mono(12, vc, weight: FontWeight.bold))),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => _modalShell(
        border: gold2,
        borderWidth: 2,
        radius: 24,
        padding: const EdgeInsets.all(24),
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: gold2.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: gold2.withOpacity(0.5)),
                      boxShadow: [BoxShadow(color: gold2.withOpacity(0.3), blurRadius: 20)],
                    ),
                    child: const Icon(Icons.shield_outlined, color: gold2, size: 24),
                  ),
                  const SizedBox(height: 8),
                  Text("CLASSROOM STUDENTS ONLY",
                      textAlign: TextAlign.center, style: _mono(16, gold2, weight: FontWeight.w900, spacing: 1)),
                  const SizedBox(height: 4),
                  const Text(
                    "This section is exclusively for registered students of Purix Academy. Access is provided at our classroom center upon enrollment.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        row("Center Node:", "Purix Classroom Center", Colors.white),
                        row("Cadet ID:", _uid, gold2),
                        row("Batch Material:", "$_class Syllabus", green),
                        row("Education Board:", _board, Colors.white, last: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _copyNumber();
                      },
                      icon: const Icon(Icons.phone, size: 16),
                      label: Text("CONTACT CENTER: $supportPhone",
                          style: _mono(11, Colors.black, weight: FontWeight.w900, spacing: 0.5)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.10),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _copyNumber();
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 16, color: green),
                      label: Text("INQUIRE VIA WHATSAPP", style: _mono(11, Colors.white, weight: FontWeight.bold, spacing: 0.5)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text("CLOSE", style: _mono(12, Colors.white38)),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -10,
              right: -10,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _initial => _name.isNotEmpty ? _name.trim()[0].toUpperCase() : 'C';

  // =====================================================================
  // HOME SCREEN WIDGETS
  // =====================================================================
  PreferredSizeWidget _buildHeader() {
    return AppBar(
      backgroundColor: const Color(0xF2040814),
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      toolbarHeight: 60,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.white.withOpacity(0.05)),
      ),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.4),
              border: Border.all(color: gold.withOpacity(0.5)),
              boxShadow: [BoxShadow(color: gold.withOpacity(0.25), blurRadius: 12)],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('PA', style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text.rich(TextSpan(children: [
                TextSpan(text: "PURIX ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                TextSpan(text: "ACADEMY", style: TextStyle(color: gold, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
              ])),
              const SizedBox(height: 2),
              Text("NEW WAY OF LEARNING", style: _mono(8, Colors.white54, weight: FontWeight.w600, spacing: 1.6)),
            ],
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: GestureDetector(
            onTap: _showProfileModal,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A253A),
                border: Border.all(color: blue),
                boxShadow: [BoxShadow(color: blue.withOpacity(0.35), blurRadius: 12)],
              ),
              child: Text(_initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: blue.withOpacity(0.4)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1D38), Color(0xFF091326), Color(0xFF040812)],
        ),
        boxShadow: [BoxShadow(color: blue.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$_greeting,", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text("$_name!",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: gold, fontWeight: FontWeight.w900, fontSize: 28, letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Text(
                  "\"Every question practiced today is an exam mark secured tomorrow.\"",
                  style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12, fontStyle: FontStyle.italic, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              Transform.rotate(
                angle: -0.105,
                child: const Text("Keep Going ~",
                    style: TextStyle(color: gold2, fontSize: 12, fontFamily: 'serif', fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Container(
                        width: 64 + 8 * _pulse.value,
                        height: 64 + 8 * _pulse.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: gold.withOpacity(0.12 + 0.13 * _pulse.value),
                          boxShadow: [BoxShadow(color: gold.withOpacity(0.25), blurRadius: 18)],
                        ),
                      ),
                    ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: gold, width: 2),
                        gradient: const LinearGradient(
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                          colors: [Color(0xFF1A1305), Color(0xFF2A1D07), Color(0xFF120E04)],
                        ),
                        boxShadow: [BoxShadow(color: gold.withOpacity(0.4), blurRadius: 25)],
                      ),
                      child: const Icon(Icons.gps_fixed, color: gold, size: 36),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: green,
                        boxShadow: [BoxShadow(color: green, blurRadius: 8)],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCardTests() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: green.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _iconBox(Icons.emoji_events_outlined, green),
                _pill("ACTIVE", green),
              ],
            ),
            const SizedBox(height: 12),
            Text("TESTS COMPLETED", style: _mono(10, Colors.white54, weight: FontWeight.bold, spacing: 0.8)),
            const SizedBox(height: 4),
            Text("$_completedQuizzes",
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 12, color: green),
                const SizedBox(width: 4),
                Text("Simulations Done", style: _mono(10, Colors.white38)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCardGoal() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cyan.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _iconBox(Icons.gps_fixed, cyan),
                _pill("GOAL", cyan),
              ],
            ),
            const SizedBox(height: 12),
            Text("TARGET GOAL", style: _mono(10, Colors.white54, weight: FontWeight.bold, spacing: 0.8)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text("95%+", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1)),
                const SizedBox(width: 6),
                Flexible(child: Text("Board Exam", overflow: TextOverflow.ellipsis, style: _mono(10, Colors.white54))),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF050912),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.8,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [cyan, blue]),
                      boxShadow: [BoxShadow(color: cyan.withOpacity(0.5), blurRadius: 8)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moduleCard(IconData icon, Color iconColor, Color borderColor, String title, String sub, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor.withOpacity(0.5)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: borderColor.withOpacity(0.2),
                    border: Border.all(color: borderColor.withOpacity(0.4)),
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)),
                  child: const Icon(Icons.chevron_right, color: Colors.white38, size: 14),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                Text(sub, style: _mono(9, Colors.white54)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withOpacity(0.4)),
        gradient: const LinearGradient(colors: [Color(0xFF2A200B), Color(0xFF1D1708), Color(0xFF120E04)]),
        boxShadow: [BoxShadow(color: gold.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: gold.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: gold.withOpacity(0.4)),
            ),
            child: const Icon(Icons.description_outlined, color: gold, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Need Help?", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                Text("Academic support & classroom center inquiry", style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: Colors.black,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _showClassroomDialog,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Ask Us", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Icon(Icons.chevron_right, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, Color hoverColor, VoidCallback onTap, {bool active = false}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: BoxDecoration(
            color: active ? Colors.white.withOpacity(0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: active ? cyan : Colors.white60),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _mono(9, active ? cyan : Colors.white.withOpacity(0.8), weight: FontWeight.bold)),
              if (active) ...[
                const SizedBox(height: 2),
                Container(width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, color: cyan)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF2040814),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 512),
            child: Row(
              children: [
                _navItem(Icons.home_outlined, "Home", cyan, () {}, active: true),
                const SizedBox(width: 4),
                _navItem(Icons.layers_outlined, "MCQ Test", const Color(0xFF00A2FF), () => _openModule('mcq')),
                const SizedBox(width: 4),
                _navItem(Icons.edit_note, "Practice", green, () => _openModule('practice')),
                const SizedBox(width: 4),
                _navItem(Icons.menu_book_outlined, "Notes", purple, () => _openModule('notes')),
                const SizedBox(width: 4),
                _navItem(Icons.explore_outlined, "Free Matrix", gold, _openFree),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: _buildHeader(),
      bottomNavigationBar: _buildBottomNav(),
      body: Stack(
        children: [
          // Ambient sci-fi glows
          Positioned(top: -100, right: -150, child: _glowCircle(cyan, 420)),
          Positioned(top: 260, left: -200, child: _glowCircle(purple, 420)),

          SafeArea(
            top: false,
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 672),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _buildHero(),
                    const SizedBox(height: 16),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _statCardTests(),
                          const SizedBox(width: 12),
                          _statCardGoal(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, c) {
                        final cols = c.maxWidth >= 600 ? 4 : 2;
                        return GridView.count(
                          crossAxisCount: cols,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: cols == 4 ? 1.35 : 1.6,
                          children: [
                            _moduleCard(Icons.bolt, const Color(0xFF00A2FF), blue, "MCQ SPRINT", "Timed Tests", () => _openModule('mcq')),
                            _moduleCard(Icons.edit_note, green, green, "PRACTICE", "PDF Sets & Papers", () => _openModule('practice')),
                            _moduleCard(Icons.description_outlined, const Color(0xFFD946EF), purple, "PURIX NOTES", "Core Theory", () => _openModule('notes')),
                            _moduleCard(Icons.explore_outlined, gold, gold, "FREE MATRIX", "PYQ & Model Sets", _openFree),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildHelpBanner(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}