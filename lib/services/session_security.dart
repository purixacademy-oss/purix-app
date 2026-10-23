import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'sheet_service.dart';
import '../screens/login_screen.dart'; // Apna path check kar lijiyega

class SessionSecurity {
  // Ye function app khulte hi check karega ki phone original hai ya nahi
  static Future<void> verifyDeviceSession(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final mobile = prefs.getString('user_mobile') ?? '';
    if (mobile.isEmpty) return;

    // 1. Current Phone ka model nikalo
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String currentDevice = "Unknown Device";
    try {
      if (Platform.isAndroid) {
        var androidInfo = await deviceInfo.androidInfo;
        currentDevice = "${androidInfo.brand} ${androidInfo.model}";
      } else if (Platform.isIOS) {
        var iosInfo = await deviceInfo.iosInfo;
        currentDevice = "${iosInfo.name} ${iosInfo.model}";
      }
    } catch (e) {
      currentDevice = "Unknown Device";
    }

    // 2. Google Sheet se fresh data mangwao
    // Dhyan dein: forceRefresh true rakha hai taaki hamesha latest data aaye
    final usersData = await SheetService.fetchSheetData('User ID', forceRefresh: true);
    
    for (var row in usersData) {
      String sheetPhone = (row['Phone'] ?? '').toString().trim();
      
      if (sheetPhone == mobile) {
        String sheetDevice = (row['Device Info'] ?? '').toString().trim();
        String accountStatus = (row['Status'] ?? 'ACTIVE').toString().trim().toUpperCase();

        // BLOCK 1: Agar Admin ne Sheet se DEACTIVE kar diya hai
        if (accountStatus == 'DEACTIVE') {
          _forceLogout(context, "🔒 ACCOUNT SUSPENDED: Please contact Admin.");
          return;
        }

        // BLOCK 2: THE KICK-OUT (Agar sheet me naya phone update ho chuka hai)
        if (sheetDevice.isNotEmpty && sheetDevice != currentDevice && sheetDevice != 'Unknown Device') {
          _forceLogout(context, "⚠️ Session Expired: Logged in from another device.");
          return;
        }
        break;
      }
    }
  }

  // Zabardasti Logout karke Login page par phekne ka function
  static void _forceLogout(BuildContext context, String message) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Saara local data delete
    await GoogleSignIn().signOut(); // Google se bhi sign out
    
    if (!context.mounted) return;
    
    // Laal rang ka alert message dikhao
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 5),
      ),
    );
    
    // Wapas Login Screen par bhej do aur pichli saari screens band kar do
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }
}