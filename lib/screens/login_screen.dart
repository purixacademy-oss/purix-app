import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  static const String studentDataUrl =
      "https://script.google.com/macros/s/AKfycbxW1tu6jkT29VBflDapForv8tLdV56-XfMeFjqX9xd-Q3hhwuwsNz_IJTexO4hEsoDTOA/exec";

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // Silent Device Brand and Model Detection
  String _detectDeviceModel() {
    try {
      if (Platform.isAndroid) {
        return "Android Device (${Platform.operatingSystemVersion})";
      } else if (Platform.isIOS) {
        return "Apple iPhone (${Platform.operatingSystemVersion})";
      } else if (Platform.isWindows) {
        return "Windows PC";
      } else if (Platform.isMacOS) {
        return "Apple Mac";
      } else if (Platform.isLinux) {
        return "Linux Device";
      }
    } catch (_) {}
    return "Mobile Terminal";
  }

  // Purix Random 5-Character Unique ID Generator
  String _generatePurixId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final code = String.fromCharCodes(
      Iterable.generate(5, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
    return 'PRX-$code';
  }

  Future<void> _handleLogin() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    if (phone.length != 10) {
      _showSnackbar("कृपया 10 अंकों का वैध मोबाइल नंबर दर्ज करें", isError: true);
      return;
    }

    if (name.isEmpty || name.toLowerCase() == 'student') {
      _showSnackbar("कृपया अपना पूरा और सही नाम दर्ज करें", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceModel = _detectDeviceModel();
      final nowTime = DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ');

      // 1. Check existing record in User ID sheet by phone
      String existingUid = '';
      String userPlan = 'FREE';
      String userStatus = 'ACTIVE';

      try {
        final queryUrl = "$studentDataUrl?sheet=User%20ID&phone=$phone";
        final checkRes = await http.get(Uri.parse(queryUrl));
        if (checkRes.statusCode == 200) {
          final data = jsonDecode(checkRes.body);
          if (data is List && data.isNotEmpty) {
            final row = data[0];
            existingUid = (row['Unique ID'] ?? row['UniqueID'] ?? '').toString().trim();
            final rawPlan = (row['Plan'] ?? row['plan'] ?? row['Subscription'] ?? 'FREE').toString().trim().toUpperCase();
            userStatus = (row['Status'] ?? row['status'] ?? 'ACTIVE').toString().trim().toUpperCase();
            userPlan = (rawPlan == 'PRO' || rawPlan == 'VERIFIED') ? 'PRO' : 'FREE';
          }
        }
      } catch (_) {}

      // Admin suspension check
      if (userStatus == 'DEACTIVE' || userStatus == 'BANNED' || userStatus == 'BLOCKED') {
        setState(() => _isLoading = false);
        _showSnackbar("🔒 आपका खाता व्यवस्थापक द्वारा निष्क्रिय कर दिया गया है।", isError: true);
        return;
      }

      final finalPurixId = existingUid.isNotEmpty ? existingUid : _generatePurixId();

      // 2. Secretly sync device model, phone and login time to Google Apps Script
      try {
        final syncPayload = {
          'name': name,
          'phone': phone,
          'email': email.isEmpty ? 'N/A' : email,
          'purix_id': finalPurixId,
          'selected_class': prefs.getString('user_class') ?? 'Class 10th',
          'selected_board': prefs.getString('user_board') ?? 'Bihar Board (BSEB)',
          'device_info': deviceModel,
          'device': deviceModel,
          'model': deviceModel,
          'login_time': nowTime,
        };

        await http.post(
          Uri.parse(studentDataUrl),
          headers: {'Content-Type': 'text/plain;charset=utf-8'},
          body: jsonEncode(syncPayload),
        );
      } catch (_) {}

      // 3. Save local persistent session
      await prefs.setString('user_name', name);
      await prefs.setString('user_phone', phone);
      await prefs.setString('user_email', email.isEmpty ? 'N/A' : email);
      await prefs.setString('user_uid', finalPurixId);
      await prefs.setString('user_sub', userPlan);
      await prefs.setString('user_status', userStatus);
      await prefs.setBool('is_logged_in', true);

      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(
            userName: name,
            selectedClass: prefs.getString('user_class') ?? 'Class 10th',
            selectedBoard: prefs.getString('user_board') ?? 'Bihar Board (BSEB)',
          ),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackbar("नेटवर्क त्रुटि। कृपया इंटरनेट कनेक्शन जांचें।", isError: true);
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF00F0FF),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: SafeArea(
        child: Stack(
          children: [
            // Background Sci-Fi Ambient Glows
            Positioned(
              top: -100,
              left: MediaQuery.of(context).size.width / 2 - 150,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD4AF37).withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              right: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00F0FF).withOpacity(0.06),
                ),
              ),
            ),

            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Glowing Animated Academy Logo
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 105,
                        height: 105,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD4AF37), Color(0xFFFFD700), Color(0xFF00F0FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD4AF37).withOpacity(0.4),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(3.5),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xFF0E1626),
                                alignment: Alignment.center,
                                child: const Text(
                                  "PA",
                                  style: TextStyle(
                                    color: Color(0xFFD4AF37),
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    const Text(
                      "PURIX ACADEMY",
                      style: TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "ADVANCED LEARNING MATRIX",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Name Input
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1626),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.person_outline, color: Color(0xFF00F0FF), size: 20),
                          hintText: "Student Full Name",
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Phone Input
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1626),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.phone_android, color: Color(0xFF00F0FF), size: 20),
                          hintText: "10-Digit Mobile Number",
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Email Input
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1626),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF00F0FF), size: 20),
                          hintText: "Email Address (Optional)",
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Primary Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          shape: BorderRadius.circular(12),
                          elevation: 6,
                          shadowColor: const Color(0xFFD4AF37).withOpacity(0.4),
                        ),
                        child: _isLoading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    "CONNECTING MATRIX...",
                                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              )
                            : const Text(
                                "ENTER ACADEMY",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 1.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Continue with Google Button (With Google colored Logo)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          backgroundColor: const Color(0xFF0E1626).withOpacity(0.5),
                          shape: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Multi-color Google G Icon
                            Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'G',
                                style: TextStyle(
                                  color: Color(0xFF4285F4),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              "Continue with Google",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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