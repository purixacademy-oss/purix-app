import 'dart:math';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import '../services/sheet_service.dart';
import 'class_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  final TextEditingController _mobileController = TextEditingController();
  
  // 🔴 AAPKA GOOGLE APPS SCRIPT WEB APP URL
  final String scriptUrl = "https://script.google.com/macros/s/AKfycbyMCVQQB7BkbRxxvociPZL56LWryYz7zSEF3hKxxK6zxDsApHXE_VEoRsTS0GmU7VDMSA/exec"; 

  // DEVICE INFO NIKALNE KA FUNCTION
  Future<String> _getDeviceInfo() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return "${androidInfo.brand} ${androidInfo.model}"; 
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return "${iosInfo.name} ${iosInfo.model}";
      }
    } catch (e) {
      return "Unknown Device";
    }
    return "Unknown Device";
  }

  // 1. GOOGLE SIGN-IN
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
      _showErrorSnackBar("Google Sign-In failed. Please try again.");
    }
  }

  // 2. MOBILE NUMBER POPUP
  void _showMobileNumberPopup(String name, String email) {
    const neonCyan = Color(0xFF00F0FF);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0B111E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: neonCyan, width: 1.5),
          ),
          title: const Text(
            '// VERIFICATION REQUIRED',
            style: TextStyle(fontSize: 14, fontFamily: 'monospace', letterSpacing: 1.5, color: neonCyan, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Welcome $name!\nEnter WhatsApp number to secure your Purix ID.", style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                style: const TextStyle(color: Colors.white, letterSpacing: 2),
                decoration: InputDecoration(
                  counterText: "",
                  hintText: "10-Digit Mobile Number",
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF070B14),
                  prefixIcon: const Icon(Icons.phone_android, color: neonCyan),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: neonCyan)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                GoogleSignIn().signOut();
              },
              child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: neonCyan.withOpacity(0.2), foregroundColor: neonCyan, side: const BorderSide(color: neonCyan)),
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

  // 3. MAIN LOGIC: CHECK EXISTING, BLOCK DEACTIVE, SEND POST REQUEST
  Future<void> _processUserAndLogin(String name, String email, String mobile) async {
    setState(() => _isLoading = true);

    try {
      final String currentDevice = await _getDeviceInfo();
      
      // 🚀 NAYA FIX: Current Time Generate karna sirf Verify Button par
      final String currentDateTime = DateTime.now().toString().substring(0, 16); 
      
      // Step A: Fetch Sheet Data to check if old user or blocked
      final usersData = await SheetService.fetchSheetData('User ID'); 
      
      bool isOldUser = false;
      String finalPurixId = '';
      String accountStatus = 'ACTIVE';
      String planStatus = 'FREE';

      for (var row in usersData) {
        String sheetPhone = (row['Phone'] ?? '').toString().trim();
        
        if (sheetPhone == mobile) {
          isOldUser = true;
          finalPurixId = (row['Unique ID'] ?? row['Unique ID '] ?? '').toString().trim();
          planStatus = (row['Plan'] ?? 'FREE').toString().trim().toUpperCase();
          accountStatus = (row['Status'] ?? 'ACTIVE').toString().trim().toUpperCase();
          break;
        }
      }

      // Step B: SECURITY BLOCK - Agar Admin ne DEACTIVE kiya hai
      if (isOldUser && accountStatus == 'DEACTIVE') {
        setState(() => _isLoading = false);
        GoogleSignIn().signOut();
        _showErrorSnackBar("🔒 ACCOUNT SUSPENDED: Please contact Purix Academy support.");
        return; 
      }

      // Step C: Naya User hai to ID generate karo
      if (!isOldUser) {
        finalPurixId = _generatePurixId();
      }

      // Step D: Send Data to Google Apps Script (Smart Update / Insert)
      final response = await http.post(
        Uri.parse(scriptUrl),
        body: json.encode({
          "name": name,
          "phone": mobile,
          "email": email,
          "purix_id": finalPurixId,
          "selected_class": "", 
          "device_info": currentDevice,
          "login_time": currentDateTime // 🚀 NAYA FIX: Ye value ab sheet me bheji jaa rahi hai
        }),
        headers: {"Content-Type": "application/json"},
      );

      // Extract updated Plan status from backend if available
      if (response.statusCode == 200 || response.statusCode == 302) {
        try {
          var responseData = json.decode(response.body);
          if (responseData['subscription'] != null) {
            planStatus = responseData['subscription'];
          }
        } catch (e) {
          // Ignore parsing error, rely on frontend fetch fallback
        }
      }

      // Step E: Local Storage me save karna (Fast Dashboard load ke liye)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);
      await prefs.setString('user_email', email);
      await prefs.setString('user_phone', mobile); // Fix: Consistent key used in dashboard
      await prefs.setString('user_uid', finalPurixId); // 🚀 NAYA FIX: Dashboard ke liye UID save kiya
      await prefs.setString('user_sub', planStatus);
      await prefs.setBool('is_logged_in', true);

      if (!mounted) return;

      // DONE! Class Screen (Dashboard) par bhejo
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ClassScreen(userName: name)),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar("Network matrix error. Please try again.");
    }
  }

  // PURIX ID GENERATOR
  String _generatePurixId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    String randomStr = String.fromCharCodes(Iterable.generate(5, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    return 'PRX-$randomStr';
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    const darkVoid = Color(0xFF070B14);
    const goldAccent = Color(0xFFD4AF37);
    const neonCyan = Color(0xFF00F0FF);

    return Scaffold(
      backgroundColor: darkVoid,
      body: Center(
        child: _isLoading 
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: neonCyan),
                  SizedBox(height: 16),
                  Text("SYNCING SECURE MATRIX...", style: TextStyle(color: neonCyan, fontFamily: 'monospace', letterSpacing: 2)),
                ],
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 140, height: 140,
                      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: goldAccent.withOpacity(0.35), blurRadius: 30, spreadRadius: 4)]),
                      child: ClipOval(child: Image.asset('assets/logo.png', fit: BoxFit.cover, filterQuality: FilterQuality.high)),
                    ),
                    const SizedBox(height: 24),
                    const Text('PURIX ACADEMY', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: goldAccent, letterSpacing: 2)),
                    const SizedBox(height: 8),
                    Text('NEW WAY OF LEARNING', style: TextStyle(fontSize: 12, fontFamily: 'monospace', letterSpacing: 2, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text('Access high-yield board question banks, simulations & notes', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.55), fontFamily: 'monospace')),
                    const SizedBox(height: 48),
                    
                    Container(
                      width: double.infinity, height: 52, constraints: const BoxConstraints(maxWidth: 380),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 4))]),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF1F1F1F), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        onPressed: _handleGoogleSignIn,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: 24, height: 24, alignment: Alignment.center, child: const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF4285F4)))),
                            const SizedBox(width: 12),
                            const Text('Continue with Google', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F), letterSpacing: 0.3)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, size: 14, color: neonCyan.withOpacity(0.6)),
                        const SizedBox(width: 6),
                        Text('SECURE BOARD LEARNING PORTAL', style: TextStyle(fontSize: 10, fontFamily: 'monospace', letterSpacing: 1.2, color: Colors.white.withOpacity(0.4))),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}