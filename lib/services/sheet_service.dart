import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SheetService {
  // ==============================================================
  // 🏛️ CENTRAL URLs
  // ==============================================================
  static const String studentDataUrl =
      "https://script.google.com/macros/s/AKfycbyMCVQQB7BkbRxxvociPZL56LWryYz7zSEF3hKxxK6zxDsApHXE_VEoRsTS0GmU7VDMSA/exec";

  static const String biharBoardUrl =
      "https://script.google.com/macros/s/AKfycbyMCVQQB7BkbRxxvociPZL56LWryYz7zSEF3hKxxK6zxDsApHXE_VEoRsTS0GmU7VDMSA/exec";

  static const String cbseBoardUrl =
      "https://script.google.com/macros/s/AKfycbyMCVQQB7BkbRxxvociPZL56LWryYz7zSEF3hKxxK6zxDsApHXE_VEoRsTS0GmU7VDMSA/exec";

  static const String jharkhandBoardUrl =
      "https://script.google.com/macros/s/AKfycbyMCVQQB7BkbRxxvociPZL56LWryYz7zSEF3hKxxK6zxDsApHXE_VEoRsTS0GmU7VDMSA/exec";

  static String getTodayDateKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  static Future<String> getScriptUrlForSheet(String sheetName, {String? board}) async {
    final cleanSheet = sheetName.trim().toLowerCase();
    if (cleanSheet.contains('user') || cleanSheet.contains('student')) {
      return studentDataUrl;
    }

    final cleanBoard = (board ?? '').trim().toLowerCase();
    try {
      final prefs = await SharedPreferences.getInstance();
      final customUrl = prefs.getString('custom_script_url_$board');
      if (customUrl != null && customUrl.trim().isNotEmpty) {
        return customUrl.trim();
      }
    } catch (_) {}

    if (cleanBoard.contains('cbse')) {
      return cbseBoardUrl;
    } else if (cleanBoard.contains('jharkhand') || cleanBoard.contains('jac')) {
      return jharkhandBoardUrl;
    } else {
      return biharBoardUrl;
    }
  }

  // 1. Fetch Sheet Data with optional board & forceRefresh
  static Future<List<Map<String, dynamic>>> fetchSheetData(
    String sheetName, {
    String? board,
    bool forceRefresh = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeBoard = board ?? prefs.getString('user_board') ?? 'Bihar Board (BSEB)';
      final targetScriptUrl = await getScriptUrlForSheet(sheetName, board: activeBoard);
      final todayDateKey = getTodayDateKey();

      final safeBoard = activeBoard.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final safeSheet = sheetName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final cacheKey = 'cache_data_${safeBoard}_$safeSheet';
      final cacheDateKey = 'cache_date_${safeBoard}_$safeSheet';

      if (!forceRefresh) {
        final cachedDate = prefs.getString(cacheDateKey);
        final cachedString = prefs.getString(cacheKey);
        if (cachedDate == todayDateKey && cachedString != null && cachedString.isNotEmpty) {
          try {
            final List<dynamic> list = jsonDecode(cachedString);
            return List<Map<String, dynamic>>.from(list);
          } catch (_) {}
        }
      }

      final fetchUri = Uri.parse("$targetScriptUrl?sheet=${Uri.encodeComponent(sheetName)}");
      final response = await http.get(fetchUri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        await prefs.setString(cacheKey, jsonEncode(data));
        await prefs.setString(cacheDateKey, todayDateKey);
        return data;
      }
    } catch (_) {}
    return [];
  }

  // 2. Sync User Profile with selectedBoard support
  static Future<String> syncUserProfile({
    required String name,
    required String phone,
    required String email,
    required String selectedClass,
    String selectedBoard = "Bihar Board (BSEB)",
    String purixId = "",
    String deviceInfo = "",
    bool forceRefresh = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayDateKey = getTodayDateKey();
      const statusDateKey = 'user_status_last_sync_date';

      if (!forceRefresh && prefs.getString(statusDateKey) == todayDateKey) {
        final savedSub = prefs.getString('user_sub');
        if (savedSub != null && savedSub.isNotEmpty) return savedSub;
      }

      String finalPurixId = purixId.isNotEmpty ? purixId : (prefs.getString('user_uid') ?? '');
      String finalBoard = selectedBoard.isNotEmpty
          ? selectedBoard
          : (prefs.getString('user_board') ?? 'Bihar Board (BSEB)');

      String finalDevice = deviceInfo;
      if (finalDevice.isEmpty) {
        try {
          finalDevice = "${Platform.operatingSystem.toUpperCase()} Device";
        } catch (_) {
          finalDevice = "Android Mobile";
        }
      }

      await http.post(
        Uri.parse(studentDataUrl),
        body: jsonEncode({
          "name": name,
          "phone": phone,
          "email": email,
          "purix_id": finalPurixId,
          "selected_class": selectedClass,
          "selected_board": finalBoard,
          "device_info": finalDevice,
          "login_time": DateTime.now().toString().substring(0, 16),
        }),
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 15));

      final response = await http
          .get(Uri.parse("$studentDataUrl?sheet=User ID"))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> rawData = jsonDecode(response.body);
        for (var item in rawData) {
          final sheetPhone = (item['Phone'] ?? item['phone'] ?? '').toString().trim();
          if (sheetPhone == phone.trim()) {
            final status = (item['Status'] ?? 'ACTIVE').toString().toUpperCase();
            await prefs.setString('user_sub', 'ACTIVE');
            await prefs.setString('user_status', status);
            await prefs.setString(statusDateKey, todayDateKey);
            if (status == 'DEACTIVE' || status == 'BANNED') return 'DEACTIVE';
            return 'ACTIVE';
          }
        }
      }
      await prefs.setString(statusDateKey, todayDateKey);
    } catch (_) {}
    return 'ACTIVE';
  }
}