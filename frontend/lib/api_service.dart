import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/config/app_config.dart';

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
      print("Warning: Could not parse RiveID from item name: '$n'. Defaulting to 0.");
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
      final response = await http.get(Uri.parse('$baseUrl/me'), headers: _headers);
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
      final response = await http.get(Uri.parse('$baseUrl/inventory'), headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['inventory'] as List?) ?? []; // Handle null inventory
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
      final response = await http.get(Uri.parse('$baseUrl/equipped'), headers: _headers);
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
        body: jsonEncode({
          "item_id": int.parse(itemId) 
        }),
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
}
