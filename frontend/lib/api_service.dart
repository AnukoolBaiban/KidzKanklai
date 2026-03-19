import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/config/app_config.dart';
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
  final int statIntellect;
  final int statStrength;
  final int statCreativity;

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
    this.equippedCloth = '',
    this.equippedShoes = '',
    this.equippedBody = '',
    required this.statIntellect,
    required this.statStrength,
    required this.statCreativity,
  });

  final String equippedCloth;
  final String equippedShoes;
  final String equippedBody;

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
      equippedCloth: json['equipped_cloth'] ?? '',
      equippedShoes: json['equipped_shoes'] ?? '',
      equippedBody: json['equipped_body'] ?? '',
      statIntellect: _parseInt(json['stat_intellect']),
      statStrength: _parseInt(json['stat_strength']),
      statCreativity: _parseInt(json['stat_creativity']),
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

    return InventoryItem(
      type: json['category'] ?? '',
      id: json['id'].toString(),
      name: name,
      category: json['category'] ?? '',
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
  static Future<List<dynamic>?> completeNormalQuest(int questId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/quests/complete'),
        headers: _headers,
        body: jsonEncode({
          "quest_id": questId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // ถ้าสำเร็จ คืนค่าก้อนของรางวัลกลับไปให้หน้า UI โชว์
          return data['rewards'] ?? [];
        }
      } else {
        // อ่านข้อความ Error จาก Backend มาโชว์ใน Console
        final errorData = jsonDecode(response.body);
        print("Complete Quest Failed: ${response.statusCode} - ${errorData['error']}");
      }
    } catch (e) {
      print("Complete Quest Error: $e");
    }
    // คืนค่า null กรณีเกิด Error หรือส่งไปแล้วแต่ถูกเตะกลับ
    return null;
  }

  // --- ฟังก์ชันยอมแพ้ภารกิจ (Cancel Quest) ---
  static Future<bool> cancelQuest(int questId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/quests/cancel'),
        headers: _headers,
        body: jsonEncode({
          "quest_id": questId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return true; // ยอมแพ้สำเร็จ
        }
      } else {
        // อ่านข้อความ Error จาก Backend
        final errorData = jsonDecode(response.body);
        print("Cancel Quest Failed: ${response.statusCode} - ${errorData['error']}");
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
        body: jsonEncode({
          "name": name,
          "duration_minutes": durationMinutes,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data; // คืนค่าข้อมูลทั้งหมดกลับไป (เช่น data['quest_id'], data['due_date'])
        }
      } else {
        // อ่านข้อความ Error จาก Backend
        final errorData = jsonDecode(response.body);
        print("Start Instant Quest Failed: ${response.statusCode} - ${errorData['error']}");
      }
    } catch (e) {
      print("Start Instant Quest Error: $e");
    }
    return null; // คืนค่า null กรณีเกิด Error หรือตั๋วไม่พอ
  }

  // --- ฟังก์ชันส่งเควสทันทีและรับรางวัล (Complete Instant Quest) ---
  // คืนค่าเป็น List ของรางวัลคล้ายๆ completeNormalQuest
  static Future<List<dynamic>?> completeInstantQuest(int questId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/quests/instant/complete'),
        headers: _headers,
        body: jsonEncode({
          "quest_id": questId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // ถ้าสำเร็จ คืนค่าก้อนของรางวัลกลับไปให้หน้า UI โชว์
          return data['rewards'] ?? [];
        }
      } else {
        // อ่านข้อความ Error จาก Backend มาโชว์ใน Console (เช่น กรณีกดส่งก่อนเวลาหมด)
        final errorData = jsonDecode(response.body);
        print("Complete Instant Quest Failed: ${response.statusCode} - ${errorData['error']}");
      }
    } catch (e) {
      print("Complete Instant Quest Error: $e");
    }
    // คืนค่า null กรณีเกิด Error หรือส่งไปแล้วแต่ถูกเตะกลับเพราะยังไม่หมดเวลา
    return null;
  }
}
