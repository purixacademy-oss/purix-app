import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  static const String studentDataUrl =
      "https://script.google.com/macros/s/AKfycbxW1tu6jkT29VBflDapForv8tLdV56-XfMeFjqX9xd-Q3hhwuwsNz_IJTexO4hEsoDTOA/exec";

  // Phone Brand and Model silently captured in background
  String getDeviceModel() {
    try {
      if (Platform.isAndroid) {
        return "Android Device (${Platform.operatingSystemVersion})";
      } else if (Platform.isIOS) {
        return "Apple iOS (${Platform.operatingSystemVersion})";
      }
    } catch (_) {}
    return "Mobile Client";
  }

  Future<void> _handleLogin() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    if (phone.length != 10) {
      _showMessage("कृपया 10 अंकों का मोबाइल नंबर दर्ज करें", isError: true);
      return;
    }

    if (name.isEmpty || name.toLowerCase() == 'student') {
      _showMessage("कृपया अपना सही नाम दर्ज करें", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceModel = getDeviceModel();
      final nowTime = DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ');

      // 1. Silent sync to Google Sheet (Saves mobile model in background without prompt)
      try {
        await http.post(
          Uri.parse(studentDataUrl),
          headers: {'Content-Type': 'text/plain;charset=utf-8'},
          body: jsonEncode({
            'name': name,
            'phone': phone,
            'email': email.isEmpty ? 'N/A' : email,
            'device_info': deviceModel,
            'device': deviceModel,
            'model': deviceModel,
            'login_time': nowTime,
          }),
        );
      } catch (_) {}

      // 2. Fetch User Record to verify Classroom / PRO status
      String userPlan = 'FREE';
      String userStatus = 'ACTIVE';

      try {
        final res = await http.get(Uri.parse("$studentDataUrl?sheet=User%20ID&phone=$phone"));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is List && data.isNotEmpty) {
            final row = data[0];
            final rawPlan = (row['Plan'] ?? row['plan'] ?? 'FREE').toString().trim().toUpperCase();
            userStatus = (row['Status'] ?? row['status'] ?? 'ACTIVE').toString().trim().toUpperCase();
            userPlan = (rawPlan == 'PRO' || rawPlan == 'VERIFIED') ? 'PRO' : 'FREE';
          }
        }
      } catch (_) {}

      if (userStatus == 'DEACTIVE' || userStatus == 'BANNED' || userStatus == 'BLOCKED') {
        setState(() => _isLoading = false);
        _showMessage("🔒 आपका खाता व्यवस्थापक द्वारा निष्क्रिय कर दिया गया है।", isError: true);
        return;
      }

      // Save credentials in local storage
      await prefs.setString('user_name', name);
      await prefs.setString('user_phone', phone);
      await prefs.setString('user_email', email);
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
      _showMessage("नेटवर्क त्रुटि। कृपया पुनः प्रयास करें।", isError: true);
    }
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.teal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo with Aura
                Container(
                  width: 105,
                  height: 105,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD4AF37), Color(0xFF00F0FF)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withOpacity(0.35),
                        blurRadius: 25,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3.0),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const CircleAvatar(
                          backgroundColor: Color(0xFF0E1626),
                          child: Text('PA', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 24, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  "PURIX ACADEMY",
                  style: TextStyle(color: Color(0xFFD4AF37), fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
                const Text(
                  "SECURE LEARNING MATRIX",
                  style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.5),
                ),
                const SizedBox(height: 32),

                // Name Field
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF00F0FF)),
                    labelText: "Student Name",
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: const Color(0xFF0E1626),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),

                // Phone Field
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.phone_android, color: Color(0xFF00F0FF)),
                    labelText: "10-Digit Mobile Number",
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: const Color(0xFF0E1626),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),

                // Email Field
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF00F0FF)),
                    labelText: "Email ID (Optional)",
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: const Color(0xFF0E1626),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 22),

                // Enter Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text("ENTER ACADEMY", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                ),
                const SizedBox(height: 16),

                // Continue with Google Button with Logo
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                          child: Image.network(
                            'https://developers.google.com/identity/images/g-logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text('G', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text("Continue with Google", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}