import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

class SheetService {
  // ⚠️ APNA GOOGLE APP SCRIPT URL ⚠️
  static const String scriptUrl = "https://script.google.com/macros/s/AKfycbyMCVQQB7BkbRxxvociPZL56LWryYz7zSEF3hKxxK6zxDsApHXE_VEoRsTS0GmU7VDMSA/exec";

  static Future<List<Map<String, dynamic>>> fetchSheetData(String sheetName, {bool forceRefresh = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'cache_data_$sheetName';
      final timeKey = 'cache_time_$sheetName';

      if (!forceRefresh) {
        final cachedString = prefs.getString(cacheKey);
        final cachedTimeStr = prefs.getString(timeKey);
        if (cachedString != null && cachedTimeStr != null) {
          if (DateTime.now().difference(DateTime.parse(cachedTimeStr)).inHours < 12) {
            return List<Map<String, dynamic>>.from(jsonDecode(cachedString));
          }
        }
      }

      final response = await http.get(Uri.parse("$scriptUrl?sheet=$sheetName"));
      if (response.statusCode == 200) {
        final data = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        await prefs.setString(cacheKey, jsonEncode(data));
        await prefs.setString(timeKey, DateTime.now().toIso8601String());
        return data;
      }
    } catch (e) {
      return [];
    }
    return [];
  }

  // 🚀 FOOLPROOF SYNC: Naye parameters ko 'Optional' kar diya gaya hai
  static Future<String> syncUserProfile({
    required String name,
    required String phone,
    required String email, 
    required String selectedClass,
    String purixId = "",    // Ab ye Dashboard ke liye compulsory nahi hai
    String deviceInfo = "", // Ab ye Dashboard ke liye compulsory nahi hai
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Agar purixId nahi aayi, to seedha local storage se utha lo
      String finalPurixId = purixId.isNotEmpty ? purixId : (prefs.getString('purix_id') ?? '');

      // Agar device info nahi aayi, to khud nikal lo
      String finalDevice = deviceInfo;
      if (finalDevice.isEmpty) {
        try {
          final DeviceInfoPlugin plugin = DeviceInfoPlugin();
          if (Platform.isAndroid) {
            var androidInfo = await plugin.androidInfo;
            finalDevice = "${androidInfo.brand} ${androidInfo.model}";
          } else if (Platform.isIOS) {
            var iosInfo = await plugin.iosInfo;
            finalDevice = "${iosInfo.name} ${iosInfo.model}";
          }
        } catch (e) {
          finalDevice = "Unknown Device";
        }
      }

      // 1. Data Sheet par bhejna
      await http.post(
        Uri.parse(scriptUrl),
        body: jsonEncode({
          "name": name,
          "phone": phone,
          "email": email,
          "purix_id": finalPurixId,
          "selected_class": selectedClass,
          "device_info": finalDevice
        }),
        headers: {"Content-Type": "application/json"},
      );
      
      // 2. Sheet se 100% correct PRO status mangwana
      final response = await http.get(Uri.parse("$scriptUrl?sheet=User ID"));
      if (response.statusCode == 200) {
        final List<dynamic> rawData = jsonDecode(response.body);
        for (var item in rawData) {
          final sheetPhone = item['Phone']?.toString() ?? item['phone']?.toString() ?? '';
          if (sheetPhone == phone) {
            return item['Plan']?.toString().toUpperCase() ?? 'FREE';
          }
        }
      }
    } catch (e) {
      return 'FREE';
    }
    return 'FREE';
  }
}