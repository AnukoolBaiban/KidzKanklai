import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/config/app_config.dart';
import 'package:flutter_application_1/globals.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

// --- Data Models ---

class User {
  final int id;
  final String username;
  final String email;
  final int level;
  final int exp;
  final int coins;
  final int tickets;
  final int vouchers;
  final String bio;
  final int soundBGM;
  final int soundSFX;
  final String equippedSkin;
  final String equippedHair;
  final String equippedFace;
  final String equippedOutfit;
  final int statIntellect;
  final int statStrength;
  final int statCreativity;
  final String bodyType; // 'KID', 'TEEN', 'ADULT'

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.level,
    required this.exp,
    required this.coins,
    required this.tickets,
    required this.vouchers,
    required this.bio,
    required this.soundBGM,
    required this.soundSFX,
    required this.equippedSkin,
    required this.equippedHair,
    required this.equippedFace,
    this.equippedOutfit = '',
    required this.statIntellect,
    required this.statStrength,
    required this.statCreativity,
    required this.bodyType,
  });

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _parseInt(json['id']),
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      level: _parseInt(json['level']),
      exp: _parseInt(json['exp']),
      coins: _parseInt(json['coins']),
      tickets: _parseInt(json['tickets']),
      vouchers: _parseInt(json['vouchers']),
      bio: json['bio'] ?? '',
      soundBGM: _parseInt(json['sound_bgm']),
      soundSFX: _parseInt(json['sound_sfx']),
      equippedSkin: json['equipped_skin'] ?? '',
      equippedHair: json['equipped_hair'] ?? '',
      equippedFace: json['equipped_face'] ?? '',
      equippedOutfit: json['equipped_outfit'] ?? '',
      statIntellect: _parseInt(json['stat_intellect']),
      statStrength: _parseInt(json['stat_strength']),
      statCreativity: _parseInt(json['stat_creativity']),
      bodyType: (json['body_type'] as String?) ?? 'KID',
    );
  }
}

class InventoryItem {
  final String type;
  final String id;
  final String name;
  final String category;
  final String imagePath;
  final int riveId;

  InventoryItem({
    required this.type,
    required this.id,
    this.name = '',
    this.category = '',
    this.imagePath = '',
    this.riveId = 0,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    String name = json['name'] ?? '';
    int parseRiveId(String n) {
      if (n.isEmpty) return 0;

      // Try splitting by _ first (Format: Name_ID)
      if (n.contains('_')) {
        try {
          var parts = n.split('_');
          // Ensure the last part is actually a number
          return int.parse(parts.last);
        } catch (e) {
          // Fallback or ignore
        }
      }

      // Try splitting by space (Format: Name ID)
      if (n.contains(' ')) {
        try {
          var parts = n.split(' ');
          return int.parse(parts.last);
        } catch (e) {}
      }

      // Try identifying if the whole string is a number? Unlikely but possible for IDs
      try {
        return int.parse(n);
      } catch (e) {}

      // Log warning for dev (print is okay here for debug)
      print(
        "Warning: Could not parse RiveID from item name: '$n'. Defaulting to 0.",
      );
      return 0;
    }

    // Backend /inventory returns "category", /equipped returns "type"
    final category = (json['category'] ?? json['type'] ?? '') as String;
    return InventoryItem(
      type: category,
      id: json['id'].toString(),
      name: name,
      category: category,
      imagePath: json['image'] ?? '',
      riveId: parseRiveId(name),
    );
  }
}

// --- API Service ---

class ApiService {
  // Use 10.0.2.2 for Android Emulator, localhost for iOS/Web
  static const String baseUrl = '${AppConfig.baseUrl}';
  static String? authToken; // Token for Authentication
  // --- Token Validation Helper ---
  static void _checkUnauthorized(int statusCode) {
    if (statusCode == 401) {
      print("🚨 Token หมดอายุ หรือไม่ได้รับอนุญาต (401). บังคับ Logout...");
      Supabase.instance.client.auth.signOut();
      authToken = null;
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }


  static Map<String, String> get _headers => {
    "Content-Type": "application/json",
    if (authToken != null) "Authorization": "Bearer $authToken",
  };

  // Auth
  static Future<User?> login(String email, String password) async {
    // Note: Login is handled by Supabase Client directly in LoginScreen.
    // This method is for custom backend login if needed.
    return null;
  }

  // Profile
  static Future<User?> getProfile(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/me'),
        headers: _headers,
      );
      ApiService._checkUnauthorized(response.statusCode);
      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      print("Get Profile Error: $e");
    }
    return null;
  }

  // Inventory
  static Future<List<InventoryItem>> getInventory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/inventory'),
        headers: _headers,
      );
      ApiService._checkUnauthorized(response.statusCode);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list =
            (data['inventory'] as List?) ?? []; // Handle null inventory
        return list.map((e) => InventoryItem.fromJson(e)).toList();
      }
    } catch (e) {
      print("Get Inventory Error: $e");
    }
    return [];
  }

  // Equipped
  static Future<List<InventoryItem>> getEquipped() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/equipped'),
        headers: _headers,
      );
      ApiService._checkUnauthorized(response.statusCode);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['equipped'] as List?) ?? []; // Handle null equipped
        return list.map((e) => InventoryItem.fromJson(e)).toList();
      }
    } catch (e) {
      print("Get Equipped Error: $e");
    }
    return [];
  }

  // Equip
  static Future<bool> equipItem(String itemId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/equip'),
        headers: _headers,
        body: jsonEncode({"item_id": int.parse(itemId)}),
      );
      ApiService._checkUnauthorized(response.statusCode);
      if (response.statusCode != 200) {
        print("Equip Failed (${response.statusCode}): ${response.body}");
      }
      return response.statusCode == 200;
    } catch (e) {
      print("Equip Error: $e");
      return false;
    }
  }

  // ฟังก์ชันเคลมโบนัสล็อกอินรายวัน/รายสัปดาห์
  static Future<List<dynamic>> claimLoginBonus() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rewards/login-bonus'),
        headers: _headers, // ใช้ _headers ที่มี Authorization Token อยู่แล้ว
      );

      ApiService._checkUnauthorized(response.statusCode);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['rewards'] != null) {
          // ถ้ามีของรางวัลส่งกลับมา จะคืนค่าเป็น List กลับไป
          return data['rewards'];
        }
      }
    } catch (e) {
      print("Claim Login Bonus Error: $e");
    }
    return []; // ถ้าไม่ได้อะไรเลย หรือเกิด Error ให้คืนค่า List ว่าง
  }

  // ฟังก์ชันสำหรับทดสอบเพิ่มเหรียญ 7,500 เหรียญ + เช็ค Achievement
  static Future<Map<String, dynamic>?> addTestCoins() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rewards/add-coins'),
        headers: _headers,
      );

      ApiService._checkUnauthorized(response.statusCode);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data; // คืนค่ากลับไปทั้งหมด (มี added_coin, total_coins)
        }
      } else {
        print(
          "Add Test Coins Failed: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print("Add Test Coins Error: $e");
    }
    return null; // คืนค่า null ถ้าเกิด Error
  }

  // ฟังก์ชันกดรับรางวัลจาก Achievement
  // 🌟 เปลี่ยนจาก Future<List<dynamic>> เป็น Future<List<dynamic>?> (ใส่ ?)
  static Future<List<dynamic>?> claimAchievementReward(
    int achievementId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rewards/claim-achievement'),
        headers: _headers,
        body: jsonEncode({"achievement_id": achievementId}),
      );

      ApiService._checkUnauthorized(response.statusCode);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // ถ้าสำเร็จ คืนค่าลิสต์ของรางวัลกลับไป (ถ้าไม่มีของจะคืน [] ไม่ใช่ null)
          return data['rewards'] ?? [];
        }
      } else {
        print(
          "Claim Achievement Failed: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print("Claim Achievement Error: $e");
    }
    // 🌟 คืนค่า null กรณีเกิด Error เท่านั้น
    return null;
  }

  // ฟังก์ชันดึงคำทักทายจาก AI (Groq)
  static Future<String?> generateGreeting() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai/dialogue'),
        headers: _headers,
      );
      ApiService._checkUnauthorized(response.statusCode);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['dialogue'] as String?;
      } else {
        print(
          "Generate Greeting Failed: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print("Generate Greeting Error: $e");
    }
    return null;
  }

  // --- นำเข้า dart:io เพิ่มเติมที่ด้านบนของไฟล์ด้วยนะครับ ---
  // ฟังก์ชันสร้างภารกิจทั่วไป (รองรับการอัปโหลดรูป)
  static Future<bool> createNormalQuest({
    required String name,
    required String detail,
    required DateTime dueDate,
    File? imageFile, // รับเป็น File จริงๆ
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/quests/create'),
      );

      // ใส่ Token เผื่อ Backend ต้องการ
      if (authToken != null) {
        request.headers['Authorization'] = 'Bearer $authToken';
      }

      // ใส่ข้อมูลแบบ Text
      request.fields['name'] = name;
      request.fields['detail'] = detail;

      // แปลงวันที่ให้อยู่ในรูปแบบ ISO8601 ที่ Backend ต้องการ (เช่น 2026-10-05T00:00:00.000)
      // 🌟 แก้ให้ตัดเอาเฉพาะส่วนวันที่ (YYYY-MM-DD) ส่งไปให้ Backend
      request.fields['due_date'] = dueDate.toIso8601String().split('T')[0];

      // แนบไฟล์รูปภาพถ้ามี
      if (imageFile != null) {
        var pic = await http.MultipartFile.fromPath('image', imageFile.path);
        request.files.add(pic);
      }

      var response = await request.send();

      ApiService._checkUnauthorized(response.statusCode);
      if (response.statusCode == 200) {
        return true;
      } else {
        // อ่านข้อความ Error จาก Backend
        final responseData = await response.stream.bytesToString();
        print("Create Quest Failed: ${response.statusCode} - $responseData");
        return false;
      }
    } catch (e) {
      print("Create Quest Error: $e");
      return false;
    }
  }

  // --- ฟังก์ชันรับรางวัลจากเควสทั่วไป ---
  // คืนค่าทั้งก้อน response (มี rewards, leveled_up, base_level, new_level)
  static Future<Map<String, dynamic>?> completeNormalQuest(int questId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/quests/complete'),
        headers: _headers,
        body: jsonEncode({"quest_id": questId}),
      );

      ApiService._checkUnauthorized(response.statusCode);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) return data;
      } else {
        final errorData = jsonDecode(response.body);
        print(
          "Complete Quest Failed: ${response.statusCode} - ${errorData['error']}",
        );
      }
    } catch (e) {
      print("Complete Quest Error: $e");
    }
    return null;
  }

  // --- ฟังก์ชันยอมแพ้ภารกิจ (Cancel Quest) ---
  static Future<bool> cancelQuest(int questId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/quests/cancel'),
        headers: _headers,
        body: jsonEncode({"quest_id": questId}),
      );

      ApiService._checkUnauthorized(response.statusCode);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return true; // ยอมแพ้สำเร็จ
        }
      } else {
        // อ่านข้อความ Error จาก Backend
        final errorData = jsonDecode(response.body);
        print(
          "Cancel Quest Failed: ${response.statusCode} - ${errorData['error']}",
        );
      }
    } catch (e) {
      print("Cancel Quest Error: $e");
    }

    return false; // ยอมแพ้ไม่สำเร็จ หรือเกิด Error
  }

  // --- ฟังก์ชันเริ่มภารกิจทันที (Start Instant Quest) ---
  // คืนค่าเป็น Map ที่มี quest_id และ due_date กลับไปให้ UI ใช้ตั้งเวลานับถอยหลัง
  static Future<Map<String, dynamic>?> startInstantQuest({
    required String name,
    required int durationMinutes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/quests/instant/start'),
        headers: _headers,
        body: jsonEncode({"name": name, "duration_minutes": durationMinutes}),
      );

      ApiService._checkUnauthorized(response.statusCode);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data; // คืนค่าข้อมูลทั้งหมดกลับไป (เช่น data['quest_id'], data['due_date'])
        }
      } else {
        // อ่านข้อความ Error จาก Backend
        final errorData = jsonDecode(response.body);
        print(
          "Start Instant Quest Failed: ${response.statusCode} - ${errorData['error']}",
        );
      }
    } catch (e) {
      print("Start Instant Quest Error: $e");
    }
    return null; // คืนค่า null กรณีเกิด Error หรือตั๋วไม่พอ
  }

  // --- ฟังก์ชันส่งเควสทันทีและรับรางวัล (Complete Instant Quest) ---
  // คืนค่าทั้งก้อน response (มี rewards, leveled_up, base_level, new_level)
  static Future<Map<String, dynamic>?> completeInstantQuest(int questId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/quests/instant/complete'),
        headers: _headers,
        body: jsonEncode({"quest_id": questId}),
      );

      ApiService._checkUnauthorized(response.statusCode);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) return data;
      } else {
        final errorData = jsonDecode(response.body);
        print(
          "Complete Instant Quest Failed: ${response.statusCode} - ${errorData['error']}",
        );
      }
    } catch (e) {
      print("Complete Instant Quest Error: $e");
    }
    return null;
  }

  // --- ฟังก์ชันสร้างเควสระบบเริ่มต้นให้ผู้ใช้ ---
  static Future<void> initSystemQuests() async {
    try {
      await http.post(
        Uri.parse('$baseUrl/quests/system/init'),
        headers: _headers,
      );
    } catch (e) {
      print("Init System Quests Error: $e");
    }
  }

  // 6. API: รับรางวัลเควสระบบ
  static Future<Map<String, dynamic>?> completeSystemQuest(int questId) async {
    try {
      final url = Uri.parse('$baseUrl/quests/system/complete');
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({'quest_id': questId}),
      );

      ApiService._checkUnauthorized(response.statusCode);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        print("Failed to complete system quest: ${response.body}");
        return null;
      }
    } catch (e) {
      print("API Error (completeSystemQuest): $e");
      return null;
    }
  }

  // 7. API: เปลี่ยนร่างตัวละคร
  static Future<bool> changeBodyType(String bodyType) async {
    try {
      final url = Uri.parse('$baseUrl/profile/body-type');
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode({'body_type': bodyType}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['body_type'] == bodyType;
      }
      return false;
    } catch (e) {
      print("API Error (changeBodyType): $e");
      return false;
    }
  }
  // --- ฟังก์ชันฝึกฝนในสถานที่ต่างๆ (Location Action) ---
  // คืนค่าเป็น Map ที่มี success, message, stamina_change, stat_gained
  static Future<Map<String, dynamic>?> performLocationAction(String location) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/locations/action'),
        headers: _headers,
        body: jsonEncode({
          "location": location, // "library", "gym", "amusement_park", "park"
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data; // คืนค่าทั้งหมดไปให้ UI เอาไปโชว์
      } else {
        final errorData = jsonDecode(response.body);
        print("Location Action Failed: ${response.statusCode} - ${errorData['error']}");
        
        // คืนค่า Error กลับไปเป็น Map แทน null เพื่อให้แอปนำไปใช้แสดง Popup เตือนได้
        return {
          "success": false,
          "message": errorData['error'] ?? "เกิดข้อผิดพลาดในการเชื่อมต่อ",
        };
      }
    } catch (e) {
      print("Location Action Error: $e");
      return {
        "success": false,
        "message": "ข้อผิดพลาดระบบ: $e",
      };
    }
  }

  // --- ฟังก์ชันสร้างข้อสอบประจำสัปดาห์ ---
  // คืนค่า true ถ้าสร้างสำเร็จ (หรือมีอยู่แล้ว) และ false ถ้าเกิดข้อผิดพลาด
  static Future<bool> generateWeeklyExams() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/exams/generate-weekly'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // แจ้งให้ Console ทราบว่าสร้างข้อสอบประเภทอะไร (หรือแจ้งว่าสร้างไปแล้ว)
          print("Weekly Exam Status: ${data['message']} (Type: ${data['type'] ?? 'N/A'})");
          return true;
        }
      } else {
        final errorData = jsonDecode(response.body);
        print("Generate Weekly Exams Failed: ${response.statusCode} - ${errorData['error']}");
      }
    } catch (e) {
      print("Generate Weekly Exams Error: $e");
    }
    return false; // เกิด Error
  }

  // --- ฟังก์ชันเริ่มสอบ (Start Exam) ---
  // คืนค่ากลับเป็น Map ที่บอกว่า ผ่าน/ไม่ผ่าน, โอกาสผ่านเท่าไหร่ และได้ของรางวัลอะไรบ้าง
  static Future<Map<String, dynamic>?> startExam(int examId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/exams/start'),
        headers: _headers,
        body: jsonEncode({
          "exam_id": examId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data; // คืนค่าทั้งหมดกลับไปให้ UI จัดการต่อ
      } else {
        final errorData = jsonDecode(response.body);
        print("Start Exam Failed: ${response.statusCode} - ${errorData['error']}");
        return {"error": errorData['error']}; // คืนค่า Error กลับไปให้โชว์ Popup ได้
      }
    } catch (e) {
      print("Start Exam Error: $e");
      return null;
    }
  }
  // --- ฟังก์ชันดึง Notification ทั้งหมดของ user ---
  static Future<List<NotificationModel>> getNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications'),
        headers: _headers,
      );
      ApiService._checkUnauthorized(response.statusCode);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['notifications'] as List?) ?? [];
        return list.map((e) => NotificationModel.fromJson(e)).toList();
      } else {
        print(
          "Get Notifications Failed: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print("Get Notifications Error: $e");
    }
    return [];
  }

  // --- ฟังก์ชัน Mark Notification ว่าอ่านแล้ว ---
  static Future<bool> markNotificationRead(int notificationId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/$notificationId/read'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Mark Notification Read Error: $e");
      return false;
    }
  }

  // --- ฟังก์ชันลบ Notification รายการเดียว ---
  static Future<bool> deleteNotification(int notificationId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/notifications/$notificationId'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Delete Notification Error: $e");
      return false;
    }
  }

  // --- ฟังก์ชันลบ Notification ทั้งหมด ---
  static Future<bool> deleteAllNotifications() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/notifications'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Delete All Notifications Error: $e");
      return false;
    }
  }
}

// --- Notification Model ---

class NotificationModel {
  final int id;
  final String title;
  final String detail;
  final String type;
  final String image;
  final DateTime startDate;
  final DateTime dueDate;
  final DateTime? readDate;
  bool isRead; // map จาก status == 'read'

  NotificationModel({
    required this.id,
    required this.title,
    required this.detail,
    required this.type,
    required this.image,
    required this.startDate,
    required this.dueDate,
    this.readDate,
    this.isRead = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? 'unread';
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(
        json['start_date'] as String? ?? '',
      ).toLocal();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    DateTime parsedDueDate;
    try {
      parsedDueDate = DateTime.parse(
        json['due_date'] as String? ?? '',
      ).toLocal();
    } catch (_) {
      parsedDueDate = parsedDate.add(const Duration(days: 30));
    }

    DateTime? parsedReadDate;
    try {
      final rdStr = json['read_date'] as String?;
      if (rdStr != null) parsedReadDate = DateTime.parse(rdStr).toLocal();
    } catch (_) {}

    return NotificationModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      type: json['type'] as String? ?? '',
      image: json['image'] as String? ?? '',
      startDate: parsedDate,
      dueDate: parsedDueDate,
      readDate: parsedReadDate,
      isRead: status == 'read',
    );
  }

  /// แปลง timestamp เป็นข้อความภาษาไทยแบบยาว เช่น "การแจ้งเตือนเกิดขึ้นเมื่อ 5 นาทีที่แล้ว"
  String get relativeTime {
    final diff = DateTime.now().difference(startDate);
    if (diff.inMinutes < 1) return 'การแจ้งเตือนเพิ่งเกิดขึ้น';
    if (diff.inMinutes < 60)
      return 'การแจ้งเตือนเกิดขึ้นเมื่อ ${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24)
      return 'การแจ้งเตือนเกิดขึ้นเมื่อ ${diff.inHours} ชั่วโมงที่แล้ว';
    if (diff.inDays < 30)
      return 'การแจ้งเตือนเกิดขึ้นเมื่อ ${diff.inDays} วันที่แล้ว';
    return 'การแจ้งเตือนเกิดขึ้นเมื่อ ${(diff.inDays / 30).floor()} เดือนที่แล้ว';
  }

  /// แปลง timestamp เป็นข้อความภาษาไทยแบบสั้น เช่น "5 นาทีที่แล้ว"
  String get shortRelativeTime {
    final diff = DateTime.now().difference(startDate);
    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
    if (diff.inDays < 30) return '${diff.inDays} วันที่แล้ว';
    return '${(diff.inDays / 30).floor()} เดือนที่แล้ว';
  }

  /// วันที่จะถูกลบอัตโนมัติ (formatted)
  String get autoDeletionText {
    final d = dueDate;
    return 'การแจ้งเตือนนี้จะถูกลบอัตโนมัติในวันที่ '
        '${d.day}/${d.month}/${d.year}';
  }

  /// วันและเวลาที่อ่าน (formatted)
  String? get readAtText {
    if (readDate == null) return null;
    final d = readDate!;
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return 'การแจ้งเตือนนี้ถูกอ่านเมื่อ ${d.day}/${d.month}/${d.year} เวลา $h:$m น.';
  }

  /// ไอคอนประจำประเภท notification
  String get iconPath {
    switch (type) {
      case 'achievement':
        return 'assets/images/icon/iconAchievement.png';
      case 'quest':
        return 'assets/images/icon/trophy.png';
      case 'club':
        return 'assets/images/icon/communication.png';
      case 'exam':
        return 'assets/images/icon/education.png';
      default:
        return image.isNotEmpty
            ? image
            : 'assets/images/icon/iconAchievement.png';
    }
  }
}
