import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/sheet_service.dart'; // 🚀 NAYA FIX: Background check ke liye import

// Global Navigator Key: Taki hum background se forcibly screen change kar sakein
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  final String? savedClass = prefs.getString('user_class');
  final String? userName = prefs.getString('user_name');

  // runApp ko stateful widget me bhej diya
  runApp(PurixApp(
    isLoggedIn: isLoggedIn,
    savedClass: savedClass,
    userName: userName,
  ));
}

class PurixApp extends StatefulWidget {
  final bool isLoggedIn;
  final String? savedClass;
  final String? userName;

  const PurixApp({super.key, required this.isLoggedIn, this.savedClass, this.userName});

  @override
  State<PurixApp> createState() => _PurixAppState();
}

// 🚀 NAYA FIX: WidgetsBindingObserver lagaya (App Lifecycle track karne ke liye)
class _PurixAppState extends State<PurixApp> with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Jaise hi student app ko wapas open karega (background se)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLiveStatus();
    }
  }

  // 🚀 NAYA FIX: Live Checker Function
  Future<void> _checkLiveStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isLog = prefs.getBool('is_logged_in') ?? false;
    
    if (!isLog) return; // Agar login nahi hai toh check mat karo

    // Strict 12-hour throttling to save Google Sheets daily execution quota
    final lastCheckStr = prefs.getString('last_live_check_time');
    if (lastCheckStr != null) {
      final diffHours = DateTime.now().difference(DateTime.parse(lastCheckStr)).inHours;
      if (diffHours < 12) {
        return; // Already verified within 12 hours - zero API calls made
      }
    }

    final phone = prefs.getString('user_phone') ?? '';
    final name = prefs.getString('user_name') ?? '';
    final email = prefs.getString('user_email') ?? 'N/A';
    final userClass = prefs.getString('user_class') ?? '';

    if (phone.isNotEmpty) {
      try {
        // Bina UI disturb kiye throttled sync call
        final status = await SheetService.syncUserProfile(
          name: name,
          phone: phone,
          email: email,
          selectedClass: userClass,
        );

        await prefs.setString('last_live_check_time', DateTime.now().toIso8601String());
        
        // Agar admin ne deactivate kar diya hai
        if (status.toUpperCase() == 'DEACTIVE' || status.toUpperCase() == 'BANNED') {
          await prefs.clear(); // Saara cache turant delete
          
          // Force Logout - Sidha Login Screen par fenk do
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
          
          // Alert message dikhao
          if (navigatorKey.currentContext != null) {
            ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
              const SnackBar(
                content: Text("Access Revoked: Your account has been deactivated by Admin."),
                backgroundColor: Colors.redAccent,
                duration: Duration(seconds: 4),
              ),
            );
          }
        } else {
          // Instant Activation: Agar free ya pro hai, toh local memory me live update kardo
          await prefs.setString('user_sub', status);
        }
      } catch (e) {
        // Ignore errors (jaise internet na hona) taaki app freeze na ho
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // 🚀 NAYA FIX: Navigator attach kiya
      title: 'Purix Academy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF070B14)),
      home: (widget.isLoggedIn && widget.savedClass != null) 
          ? DashboardScreen(selectedClass: widget.savedClass!, userName: widget.userName ?? 'Student') 
          : const LoginScreen(),
    );
  }
}