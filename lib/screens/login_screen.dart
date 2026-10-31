import 'dart:math';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../services/sheet_service.dart';
import 'board_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  final TextEditingController _mobileController = TextEditingController();

  // 👇 Apni logo file ka path yahan likho (pubspec.yaml me bhi add karna zaroori hai)
  static const String _logoPath = 'assets/images/logo.png';

  String get scriptUrl => SheetService.studentDataUrl;

  Future<String> _getDeviceInfo() async {
    try {
      return "${Platform.operatingSystem.toUpperCase()} Device";
    } catch (e) {
      return "Android Mobile";
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);
      final GoogleSignInAccount? account = await googleSignIn.signIn();

      if (account != null) {
        setState(() => _isLoading = false);
        _showMobileNumberPopup(account.displayName ?? 'Student', account.email);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (error) {
      setState(() => _isLoading = false);
      _showErrorSnackBar("Google Sign-In error: $error");
    }
  }

  void _showMobileNumberPopup(String name, String email) {
    const neonCyan = Color(0xFF00F0FF);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0B111E),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16), side: const BorderSide(color: neonCyan)),
          title: const Text('PURIX CADET REGISTRATION',
              style: TextStyle(color: neonCyan, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome Cadet, $name!',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('Enter 10-digit WhatsApp number to link your progress report.',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
              const SizedBox(height: 16),
              TextField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                style: const TextStyle(color: Colors.white, letterSpacing: 2),
                decoration: InputDecoration(
                  counterText: "",
                  prefixText: "+91 ",
                  prefixStyle: const TextStyle(color: neonCyan, fontWeight: FontWeight.bold),
                  hintText: "9876543210",
                  hintStyle: const TextStyle(color: Colors.white30, letterSpacing: 0),
                  filled: true,
                  fillColor: const Color(0xFF040814),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: neonCyan)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: neonCyan.withOpacity(0.2),
                  foregroundColor: neonCyan,
                  side: const BorderSide(color: neonCyan)),
              onPressed: () {
                if (_mobileController.text.length == 10) {
                  Navigator.pop(context);
                  _processUserAndLogin(name, email, _mobileController.text);
                } else {
                  _showErrorSnackBar("Please enter a valid 10-digit number");
                }
              },
              child: const Text('VERIFY & ENTER', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processUserAndLogin(String name, String email, String mobile) async {
    setState(() => _isLoading = true);

    try {
      final String currentDevice = await _getDeviceInfo();
      final String currentDateTime = DateTime.now().toString().substring(0, 16);

      // 🔒 Sirf is phone ki row (poori user list nahi), hamesha fresh
      final userRow = await SheetService.fetchUserByPhone(mobile);

      final bool isOldUser = userRow != null;
      String finalPurixId = '';
      String accountStatus = 'ACTIVE';
      String planStatus = 'FREE';

      if (userRow != null) {
        finalPurixId = (userRow['UniqueID'] ?? '').toString().trim();
        planStatus = (userRow['Plan'] ?? 'FREE').toString().trim().toUpperCase();
        accountStatus = (userRow['Status'] ?? 'ACTIVE').toString().trim().toUpperCase();
      }

      if (isOldUser && (accountStatus == 'DEACTIVE' || accountStatus == 'BANNED')) {
        setState(() => _isLoading = false);
        GoogleSignIn().signOut();
        _showErrorSnackBar("🔒 ACCOUNT SUSPENDED: Please contact Purix Academy support.");
        return;
      }

      // Purana user hai par sheet me Unique ID khali ho to bhi naya bana lo
      if (finalPurixId.isEmpty) {
        finalPurixId = _generatePurixId();
      }

      final response = await http.post(
        Uri.parse(scriptUrl),
        body: json.encode({
          "name": name,
          "phone": mobile,
          "email": email,
          "purix_id": finalPurixId,
          "selected_class": "",
          "device_info": currentDevice,
          "login_time": currentDateTime
        }),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200 || response.statusCode == 302) {
        try {
          var responseData = json.decode(response.body);
          if (responseData['subscription'] != null) {
            planStatus = responseData['subscription'];
          }
        } catch (e) {}
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);
      await prefs.setString('user_email', email);
      await prefs.setString('user_phone', mobile);
      await prefs.setString('user_uid', finalPurixId);
      await prefs.setString('user_sub', planStatus);
      await prefs.setBool('is_logged_in', true);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BoardScreen(userName: name)),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar("Network matrix error. Please try again.");
    }
  }

  String _generatePurixId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    String randomStr =
        String.fromCharCodes(Iterable.generate(5, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    return 'PRX-$randomStr';
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    const darkVoid = Color(0xFF070B14);
    const goldAccent = Color(0xFFD4AF37);
    const neonCyan = Color(0xFF00F0FF);

    return Scaffold(
      backgroundColor: darkVoid,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // ================= LOGO =================
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: neonCyan, width: 2),
                    boxShadow: [
                      BoxShadow(color: neonCyan.withOpacity(0.3), blurRadius: 20, spreadRadius: 2),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      _logoPath,
                      fit: BoxFit.cover,
                      // Logo file na mile to purana "P" dikhega
                      errorBuilder: (context, error, stack) => const Center(
                        child: Text(
                          'P',
                          style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: goldAccent,
                              fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'PURIX ACADEMY',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'NEW WAY OF LEARNING',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: neonCyan.withOpacity(0.8),
                      fontFamily: 'monospace'),
                ),
              ),
              const Spacer(),
              if (_isLoading)
                const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(neonCyan)))
              else
                ElevatedButton(
                  onPressed: _handleGoogleSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E1626),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: neonCyan, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 8,
                    shadowColor: neonCyan.withOpacity(0.4),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.g_mobiledata_rounded, size: 28, color: neonCyan),
                      SizedBox(width: 8),
                      Text('SIGN IN WITH GOOGLE',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    ],
                  ),
                ),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  'SECURE GATEWAY • DEDICATED BOARD ACCESS',
                  style: TextStyle(
                      fontSize: 9, color: Colors.white.withOpacity(0.4), letterSpacing: 1.5, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}