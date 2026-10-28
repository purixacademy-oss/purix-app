import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/sheet_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  final String? savedClass = prefs.getString('user_class');
  final String? savedBoard = prefs.getString('user_board');
  final String? userName = prefs.getString('user_name');

  runApp(PurixApp(
    isLoggedIn: isLoggedIn,
    savedClass: savedClass,
    savedBoard: savedBoard,
    userName: userName,
  ));
}

class PurixApp extends StatefulWidget {
  final bool isLoggedIn;
  final String? savedClass;
  final String? savedBoard;
  final String? userName;

  const PurixApp({
    super.key,
    required this.isLoggedIn,
    this.savedClass,
    this.savedBoard,
    this.userName,
  });

  @override
  State<PurixApp> createState() => _PurixAppState();
}

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLiveStatus();
    }
  }

  Future<void> _checkLiveStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isLog = prefs.getBool('is_logged_in') ?? false;
    
    if (!isLog) return;

    final lastCheckStr = prefs.getString('last_live_check_time');
    if (lastCheckStr != null) {
      final diffHours = DateTime.now().difference(DateTime.parse(lastCheckStr)).inHours;
      if (diffHours < 12) {
        return; 
      }
    }

    final phone = prefs.getString('user_phone') ?? '';
    final name = prefs.getString('user_name') ?? '';
    final email = prefs.getString('user_email') ?? 'N/A';
    final userClass = prefs.getString('user_class') ?? '';
    final userBoard = prefs.getString('user_board') ?? 'Bihar Board (BSEB)';

    if (phone.isNotEmpty) {
      try {
        final status = await SheetService.syncUserProfile(
          name: name,
          phone: phone,
          email: email,
          selectedClass: userClass,
          selectedBoard: userBoard,
        );

        await prefs.setString('last_live_check_time', DateTime.now().toIso8601String());
        
        if (status.toUpperCase() == 'DEACTIVE' || status.toUpperCase() == 'BANNED') {
          await prefs.clear(); 
          
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
          
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
          await prefs.setString('user_sub', status);
        }
      } catch (e) {
        // Safe ignore
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, 
      title: 'Purix Academy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF070B14)),
      home: (widget.isLoggedIn && widget.savedClass != null) 
          ? DashboardScreen(
              selectedClass: widget.savedClass!,
              userName: widget.userName ?? 'Student',
              selectedBoard: widget.savedBoard ?? 'Bihar Board (BSEB)',
            ) 
          : const LoginScreen(),
    );
  }
}