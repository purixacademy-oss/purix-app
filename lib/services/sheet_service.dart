import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SheetService {
  // ==============================================================
  // 🏛️ CENTRAL URLs  (4 alag deployments)
  // ==============================================================
  // User spreadsheet (login, plan, students data)
  static const String studentDataUrl =
      "https://script.google.com/macros/s/AKfycbxW1tu6jkT29VBflDapForv8tLdV56-XfMeFjqX9xd-Q3hhwuwsNz_IJTexO4hEsoDTOA/exec";

  static const String biharBoardUrl =
      "https://script.google.com/macros/s/AKfycbwNSja_UzoISlT4hb8ESpgUls_0Vw1VqpkibIRaVo56L2dCMIF3bJ4NjcB6aOUvZomn/exec";
  static const String cbseBoardUrl =
      "https://script.google.com/macros/s/AKfycbxrukMQn5IFkfaAkCr9EzKjv1QI7eTm1C6H7DoTT3ABEYcim1TPgOA92l2XxDcKNRBUSQ/exec";
  static const String jharkhandBoardUrl =
      "https://script.google.com/macros/s/AKfycbxji5Af2_gwCwWS3j-qoapuwncAD9VIw7nztICi8RPoWiZ7HsbvSnuReAAGyGbNFmGa/exec";

  static String getTodayDateKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  static String _safe(String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

  static String _normalizePlan(String raw) {
    final p = raw.trim().toUpperCase();
    return (p == 'PRO' || p == 'VERIFIED') ? 'PRO' : 'FREE';
  }

  static Future<String> getScriptUrlForSheet(String sheetName, {String? board}) async {
    final cleanSheet = sheetName.trim().toLowerCase();
    if (cleanSheet.contains('user') || cleanSheet.contains('student')) {
      return studentDataUrl;
    }

    final activeBoard = (board ?? '').trim();
    final cleanBoard = activeBoard.toLowerCase();

    if (activeBoard.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final customUrl = prefs.getString('custom_script_url_$activeBoard');
        if (customUrl != null && customUrl.trim().isNotEmpty) {
          return customUrl.trim();
        }
      } catch (_) {}
    }

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
    String? className, // jaise "10" ya "Class 10"
    bool forceRefresh = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cls = (className ?? prefs.getString('user_class') ?? '').trim();
      final activeBoard = board ?? prefs.getString('user_board') ?? 'Bihar Board (BSEB)';
      final targetScriptUrl = await getScriptUrlForSheet(sheetName, board: activeBoard);
      final todayDateKey = getTodayDateKey();

      final cacheKey = 'cache_data_${_safe(activeBoard)}_${_safe(cls)}_${_safe(sheetName)}';
      final cacheDateKey = 'cache_date_${_safe(activeBoard)}_${_safe(cls)}_${_safe(sheetName)}';

      if (!forceRefresh) {
        final cachedDate = prefs.getString(cacheDateKey);
        final cachedString = prefs.getString(cacheKey);
        if (cachedDate == todayDateKey && cachedString != null && cachedString.isNotEmpty) {
          try {
            final decoded = jsonDecode(cachedString);
            if (decoded is List && decoded.isNotEmpty) {
              return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            }
          } catch (_) {}
        }
      }

      final isUserSheet = targetScriptUrl == studentDataUrl;
      final classQuery = (!isUserSheet && cls.isNotEmpty) ? "&class=${Uri.encodeComponent(cls)}" : "";
      final fetchUri = Uri.parse("$targetScriptUrl?sheet=${Uri.encodeComponent(sheetName)}$classQuery");
      final response = await http.get(fetchUri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          final data = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          // Khali list cache nahi karte, warna poora din khali dikhega
          if (data.isNotEmpty) {
            await prefs.setString(cacheKey, jsonEncode(data));
            await prefs.setString(cacheDateKey, todayDateKey);
          }
          return data;
        }
      }
    } catch (_) {}
    return [];
  }

  // 1b. Sirf ek user ki row (Phone, UniqueID, Plan, Status) - cache nahi, hamesha fresh
  static Future<Map<String, dynamic>?> fetchUserByPhone(String phone) async {
    try {
      final uri = Uri.parse(
          "$studentDataUrl?sheet=${Uri.encodeComponent('User ID')}&phone=${Uri.encodeComponent(phone.trim())}");
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          return Map<String, dynamic>.from(decoded.first as Map);
        }
      }
    } catch (_) {}
    return null;
  }

  // 2. Sync User Profile. Returns 'ACTIVE' or 'DEACTIVE'.
  //    Plan (PRO/FREE) prefs me 'user_sub' me save hota hai.
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
        final savedStatus = (prefs.getString('user_status') ?? 'ACTIVE').toUpperCase();
        if (savedStatus == 'DEACTIVE' || savedStatus == 'BANNED' || savedStatus == 'BLOCKED') {
          return 'DEACTIVE';
        }
        return 'ACTIVE';
      }

      final finalPurixId = purixId.isNotEmpty ? purixId : (prefs.getString('user_uid') ?? '');
      final finalBoard =
          selectedBoard.isNotEmpty ? selectedBoard : (prefs.getString('user_board') ?? 'Bihar Board (BSEB)');

      String finalDevice = deviceInfo;
      if (finalDevice.isEmpty) {
        try {
          finalDevice = "${Platform.operatingSystem.toUpperCase()} Device";
        } catch (_) {
          finalDevice = "Android Mobile";
        }
      }

      await http
          .post(
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
          )
          .timeout(const Duration(seconds: 15));

      final row = await fetchUserByPhone(phone);
      if (row != null) {
        final status = (row['Status'] ?? row['status'] ?? 'ACTIVE').toString().trim().toUpperCase();
        final plan = _normalizePlan((row['Plan'] ?? row['plan'] ?? 'FREE').toString());
        final uid = (row['Unique ID'] ?? row['UniqueID'] ?? row['Purix ID'] ?? row['User ID'] ?? '').toString().trim();

        await prefs.setString('user_sub', plan);
        await prefs.setString('user_status', status);
        await prefs.setString(statusDateKey, todayDateKey);
        if (uid.isNotEmpty) await prefs.setString('user_uid', uid);

        if (status == 'DEACTIVE' || status == 'BANNED' || status == 'BLOCKED') return 'DEACTIVE';
        return 'ACTIVE';
      }
    } catch (_) {}
    return 'ACTIVE';
  }
}