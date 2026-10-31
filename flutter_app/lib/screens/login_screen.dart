import 'dart:convert';
import 'dart:io' show Platform;
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
  final _mobileController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  static const String studentDataUrl =
      'https://script.google.com/macros/s/AKfycbz_d_p5Wz4mR0aD7YvD31Vl-6kY2R4F_yK8h4wX3/exec';

  @override
  void dispose() {
    _mobileController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // Silent device detection (model / OS)
  String _detectDeviceModel() {
    try {
      if (Platform.isAndroid) {
        return 'Android Device (${Platform.operatingSystemVersion})';
      } else if (Platform.isIOS) {
        return 'iOS Device (${Platform.operatingSystemVersion})';
      }
      return 'Mobile Cadet Device';
    } catch (_) {
      return 'Mobile Cadet Device';
    }
  }

  Future<void> _handleLogin() async {
    final rawMobile = _mobileController.text.trim();
    final cadetName = _nameController.text.trim();

    final cleanMobile = rawMobile.replaceAll(RegExp(r'\D'), '');

    if (cleanMobile.length != 10) {
      _showToast('Please enter a valid 10-digit mobile number.', isError: true);
      return;
    }

    if (cadetName.isEmpty || cadetName.toLowerCase() == 'student') {
      _showToast('Please enter your full real name.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final deviceModel = _detectDeviceModel();
      final syncEmail = '$cleanMobile@purixacademy.in';

      // Send telemetry and student registration to Google Sheet
      final uri = Uri.parse(
        '$studentDataUrl?action=registerOrSync'
        '&mobile=${Uri.encodeComponent(cleanMobile)}'
        '&name=${Uri.encodeComponent(cadetName)}'
        '&email=${Uri.encodeComponent(syncEmail)}'
        '&device=${Uri.encodeComponent(deviceModel)}',
      );

      String planStatus = 'FREE';

      try {
        final response =
            await http.get(uri).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data != null && data['status'] == 'success') {
            final rawPlan =
                (data['plan'] ?? 'FREE').toString().toUpperCase();
            planStatus = (rawPlan == 'PRO' || rawPlan == 'VERIFIED')
                ? 'PRO'
                : 'FREE';
          }
        }
      } catch (_) {
        // Fallback to local session if network times out
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_mobile', cleanMobile);
      await prefs.setString('user_name', cadetName);
      await prefs.setString('user_email', syncEmail);
      await prefs.setString('user_plan', planStatus);
      await prefs.setString('user_device', deviceModel);

      if (!mounted) return;

      _showToast('Welcome aboard, $cadetName!');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } catch (e) {
      _showToast('Failed to authenticate. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Avatar
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF38BDF8), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.school, color: Color(0xFF38BDF8), size: 40),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'PURIX ACADEMY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Cadet Enrollment Portal',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 36),

                // Card Container
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FULL NAME',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Enter your full name',
                          hintStyle: const TextStyle(color: Color(0xFF64748B)),
                          prefixIcon: const Icon(Icons.person,
                              color: Color(0xFF38BDF8), size: 20),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF334155)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF38BDF8)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'MOBILE NUMBER (10 DIGITS)',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '9876543210',
                          hintStyle: const TextStyle(color: Color(0xFF64748B)),
                          prefixIcon: const Icon(Icons.phone_android,
                              color: Color(0xFF38BDF8), size: 20),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF334155)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF38BDF8)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF38BDF8),
                            foregroundColor: const Color(0xFF0F172A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Color(0xFF0F172A),
                                  ),
                                )
                              : const Text(
                                  'ENTER ACADEMY',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Compliant with Indus Appstore Cadet Guidelines',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
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
