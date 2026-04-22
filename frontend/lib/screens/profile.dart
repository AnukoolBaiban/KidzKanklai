import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/lobby.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http; // เพิ่ม import นี้
import 'dart:convert'; // สำหรับ jsonEncode
import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:flutter_application_1/widgets/bottom_navigation_bar.dart';
import 'package:flutter_application_1/api_service.dart' as api;


import 'package:flutter_application_1/config/app_config.dart'; // [ADDED] สำหรับดึง baseUrl
import 'package:rive/rive.dart' hide LinearGradient, Image; // [ADDED] Rive
import 'package:flutter_application_1/api_service.dart' as api; // [ADDED] ApiService
import 'package:flutter_application_1/config/rive_cache.dart'; // [ADDED] RiveCache
import '../widgets/character_widget.dart';


class ProfileScreen extends StatefulWidget {
  final api.User? user;
  const ProfileScreen({super.key, this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  bool _isPressed = false;
  int _selectedIndex = 4; 

  // --- Profile Data ---
  String _displayName = "Loading...";
  String _displayBio = "กำลังโหลดข้อมูล...";
  String _uid = "Loading...";

  // --- Character Stats & Level Data ---
  int _level = 1;
  int _currentExp = 0; // EXP ที่เหลืออยู่ในเลเวลปัจจุบัน
  int _nextLevelExp = 40; // EXP ที่ต้องใช้เพื่อขึ้นเลเวลถัดไป
  double _expPercent = 0.0; // ค่า 0.0 - 1.0 สำหรับหลอดเลือด

  String _intStat = "10";
  String _strStat = "10";
  String _creStat = "10";


  // --- Rive State ---
  SMINumber? _poseInput;
  SMINumber? _hairInput;
  SMINumber? _faceInput;
  SMINumber? _skinInput;
  SMINumber? _clothInput;
  SMINumber? _armInput; // [ADDED]
  StateMachineController? _controller;
  api.User? _user; // Store full user profile
  bool _isRiveLoaded = false;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _fetchFullProfileForRive(); // Call this to get Rive data
  }

  // [UPDATED] ปรับ Logic ให้รับ Level จาก DB แล้วคำนวณแค่เศษ EXP สำหรับหลอด
  void _updateLevelUI(int dbLevel, int totalExp) {
    int remainingExp = totalExp;
    int requiredExpForNextLevel = 0;

    // วนลูปเพื่อหักลบ EXP ของเลเวลก่อนหน้าออกให้หมด
    // เพื่อให้เหลือแค่ "EXP ปัจจุบันในเลเวลนี้" (เช่น เลเวล 2 มี exp 10/80)
    for (int i = 1; i < dbLevel; i++) {
      int expUsed = 0;
      if (i < 6) {
        expUsed = 40 * i;
      } else {
        expUsed = 200 + (i * i);
      }
      remainingExp -= expUsed;
    }

    // คำนวณ Max EXP ของเลเวลปัจจุบัน (เพื่อเอาไปทำตัวหาร)
    if (dbLevel < 6) {
      requiredExpForNextLevel = 40 * dbLevel;
    } else {
      requiredExpForNextLevel = 200 + (dbLevel * dbLevel);
    }

    if (mounted) {
      setState(() {
        _level = dbLevel; // ใช้ Level จาก DB โดยตรง
        _currentExp = remainingExp; // EXP ที่หักลบแล้ว
        _nextLevelExp = requiredExpForNextLevel; // เป้าหมายเลเวลถัดไป
        
        // คำนวณ % หลอดเลือด
        _expPercent = (_nextLevelExp > 0)
            ? (_currentExp / _nextLevelExp).clamp(0.0, 1.0)
            : 0.0;
      });
    }
  }
  
  // --- ตัวแปรใหม่สำหรับ Achievement ---
  int _totalAchievements = 18; // ค่าเริ่มต้น สมมติมี 18 อัน (คุณปรับได้ตามจริง)
  int _unlockedAchievements = 0;
  List<String> _achievementImages = [];

  Future<void> _fetchUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      setState(() {
        _uid = user.id.substring(0, 8);
      });

      // 1. ดึงข้อมูล Profile
      final profileData = await _supabase
          .from('user_profiles')
          .select('name, detail')
          .eq('id', user.id)
          .maybeSingle();

      if (profileData != null) {
        setState(() {
          _displayName = profileData['name'] ?? "No Name";
          _displayBio = profileData['detail'] ?? "ยังไม่มีคำแนะนำตัว";
        });
      }

      // 2. ดึงข้อมูล Character
      final charData = await _supabase
          .from('characters')
          .select('level, experience, intelligence, strength, creative')
          .eq('user_id', user.id)
          .maybeSingle();

      if (charData != null) {
        setState(() {
          _intStat = charData['intelligence'].toString();
          _strStat = charData['strength'].toString();
          _creStat = charData['creative'].toString();
        });

        final dbLevel = charData['level'] as int? ?? 1;
        final totalExp = charData['experience'] as int? ?? 0;
        
        _updateLevelUI(dbLevel, totalExp); 
      }

      // 🌟 3. ดึงข้อมูล Achievement 🌟
      // นับจำนวน Achievement ทั้งหมดในระบบ
      final allAchResponse = await _supabase.from('achievements').select('id');
      final int totalAchCount = allAchResponse.length; 

      // 🌟 ใช้ตาราง 'attain' ตามโครงสร้าง DB จริงของคุณ
      final userAchResponse = await _supabase
          .from('attain') 
          .select('achievements ( image )') // Join ข้ามไปเอา image จากตาราง achievements
          .eq('user_id', user.id)
          .inFilter('status', ['completed', 'claimed']); // กรองเฉพาะที่สำเร็จแล้ว

      List<String> unlockedImages = [];
      for (var row in userAchResponse) {
        final achData = row['achievements'];
        // ตรวจสอบว่าดึงข้อมูลมาได้ และมีรูปภาพ
        if (achData != null && achData['image'] != null) {
          unlockedImages.add(achData['image']);
        }
      }

      if (mounted) {
        setState(() {
          _totalAchievements = totalAchCount;
          _unlockedAchievements = unlockedImages.length;
          _achievementImages = unlockedImages;
        });
      }

    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }

  // ✅ [ADDED] Fetch Full Profile for Rive
  Future<void> _fetchFullProfileForRive() async {
    // We use ID 0 because getProfile uses the token to identify the user
    final user = await api.ApiService.getProfile(0);
    if (user != null) {
      if (mounted) {
        setState(() {
          _user = user;
          _syncRiveToEquipped();
        });
      }
    }
  }

  // ✅ [ADDED] Rive Logic
  void _onRiveInit(Artboard artboard) {
    var controller = StateMachineController.fromArtboard(artboard, 'State Machine 1');
    if (controller == null && artboard.stateMachines.isNotEmpty) {
       controller = StateMachineController.fromArtboard(artboard, artboard.stateMachines.first.name);
    }

    if (controller != null) {
      artboard.addController(controller);
      _controller = controller;

      // Bind Inputs
       for (var input in controller.inputs) {
        if (input.name == 'Pose') _poseInput = input as SMINumber;
        if (input.name == 'HairID') _hairInput = input as SMINumber;
        if (input.name == 'FaceID') _faceInput = input as SMINumber;
        if (input.name == 'SkinID') _skinInput = input as SMINumber;
        if (input.name == 'OutfitID') _clothInput = input as SMINumber;
      }
      
      // Initial Sync
      _syncRiveToEquipped();

      // Force Pose to 2 (Peace Sign)
      if (_poseInput != null) {
         _poseInput!.value = 2.0; 
      }
    }
    if (mounted) setState(() => _isRiveLoaded = true);
  }

  String _getModelAsset() {
    if (_user != null) {
      final bt = _user!.bodyType.toUpperCase();
      if (bt == 'ADULT') return 'assets/animation/adult.riv';
      if (bt == 'TEEN') return 'assets/animation/teen.riv';
      return 'assets/animation/kid.riv';
    }
    int lvl = _user?.level ?? 1;
    if (lvl >= 30) return 'assets/animation/adult.riv';
    if (lvl >= 15) return 'assets/animation/teen.riv';
    return 'assets/animation/kid.riv';
  }

  double _parseId(String s) {
      if (s.isEmpty) return 0;
      if (s.contains('_')) {
         try { return double.parse(s.split('_').last); } catch (_) {}
      }
      if (s.contains(' ')) {
         try { return double.parse(s.split(' ').last); } catch (_) {}
      }
      try { return double.parse(s); } catch(_) { return 0; }
  }

  void _syncRiveToEquipped() {
     if (_controller == null || _user == null) return;
     
     try {
        if (_hairInput != null) _hairInput!.value = _parseId(_user!.equippedHair);
        if (_faceInput != null) _faceInput!.value = _parseId(_user!.equippedFace);
        if (_skinInput != null) _skinInput!.value = _parseId(_user!.equippedSkin);
        
        if (_clothInput != null) {
            _clothInput!.value = _parseId(_user!.equippedOutfit);
        }
        if (_armInput != null) {
            _armInput!.value = _parseId(_user!.equippedOutfit);
        }
        
        // Ensure Pose is set again just in case
        if (_poseInput != null) _poseInput!.value = 2.0;

     } catch (e) {
       print("Error syncing Rive Profile: $e");
     }
  }

  // ✅ [เพิ่มฟังก์ชันนี้] เพื่อยิงไปหา Go Backend
  Future<bool> _updateProfileViaApi(String column, String value) async {
    try {
      // 1. ดึง Token ของ User ปัจจุบันเพื่อยืนยันตัวตน
      final session = _supabase.auth.currentSession;
      if (session == null) return false;
      final token = session.accessToken;

      String endpoint = "";
      Map<String, String> body = {};

      // 2. เลือก Route และเตรียมข้อมูลให้ตรงกับที่ Go ต้องการ
      if (column == 'user_name') {
        endpoint = "/profile/name";
        body = {"name": value}; // Go struct: UpdateNameInput { Name }
      } else if (column == 'user_detail') {
        endpoint = "/profile/bio";
        body = {"bio": value};  // Go struct: UpdateBioInput { Bio }
      } else {
        return false;
      }

      // 3. ยิง Request
      final url = Uri.parse('${AppConfig.baseUrl}$endpoint');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // ส่ง Token ไปให้ Go ตรวจสอบ
        },
        body: jsonEncode(body),
      );

      // 4. เช็คผลลัพธ์ (200 OK)
      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint("API Error: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("Network Error: $e");
      return false;
    }
  }

  // 🔄 [แก้ไขฟังก์ชันนี้] เปลี่ยนจาก update supabase เป็นเรียก API แทน
  void _showEditDialog(String title, String currentValue, String columnToUpdate) {
    final TextEditingController controller = TextEditingController(text: currentValue);
    final int maxLength = columnToUpdate == 'user_name' ? 15 : 30;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFAAD7EA),
                width: 3,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "แก้ไข$title",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00385D),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLength: maxLength,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: "กรอก$titleใหม่",
                    counterStyle: const TextStyle(color: Colors.black54),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFAAD7EA), width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2374B5), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // ยกเลิก
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade400,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text("ยกเลิก", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // บันทึก
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF85D755), Color(0xFF34C759)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            final newValue = controller.text.trim();
                            // อนุญาตให้ Bio เป็นค่าว่างได้ แต่ชื่อห้ามว่าง
                            if (columnToUpdate == 'user_name' && newValue.isEmpty) return;

                            // ✅ เรียกใช้ฟังก์ชันยิง API
                            final success = await _updateProfileViaApi(columnToUpdate, newValue);

                            if (success) {
                               if (mounted) {
                                  setState(() {
                                    if (columnToUpdate == 'user_name') _displayName = newValue;
                                    if (columnToUpdate == 'user_detail') _displayBio = newValue;
                                  });
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('บันทึกข้อมูลเรียบร้อย')),
                                  );
                                }
                            } else {
                               if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก')),
                                  );
                               }
                            }
                          },
                          child: const Text("บันทึก", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      extendBody: true,
      body: Stack(
        children: [
          // Background Image
          SizedBox.expand(
            child: Image.asset(
              'assets/images/background/bg4.png',
              fit: BoxFit.cover,
            ),
          ),
          
          // Main layout wraps top bar and content to prevent overlaps
          Column(
            children: [
              _buildTopBar(),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 20, left: 12, right: 12, bottom: 120), // เว้น 120px ล่างสุดไม่ให้บางปุ่มเมนู
                  child: Column(
                    children: [
                      _buildProfileBox(),
                      const SizedBox(height: 20), // ระยะห่างเท่ากัน
                      _buildStatBox(),
                      const SizedBox(height: 20), // ระยะห่างเท่ากัน
                      _buildAchievementBox(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Bottom Navigation
          Positioned(
            left: 0,
            right: 0,
            bottom: 0, // ให้ติดขอบล่างของ SafeArea
            child: SafeArea( // ✅ เพิ่ม SafeArea ครอบเอาไว้
              top: false, // ป้องกันแค่ด้านล่าง ด้านบนไม่ต้อง
              child: CustomBottomNavigationBar(
                selectedIndex: _selectedIndex,
                onItemTapped: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });

                  switch (index) {
                    case 0:
                      Navigator.pushNamed(context, '/fashion');
                      break;
                    case 1:
                      Navigator.pushNamed(context, '/lobby');
                      break;
                    case 2:
                      Navigator.pushNamed(context, '/map');
                      break;
                    case 3:
                      Navigator.pushNamed(context, '/club');
                      break;
                  }
                },
                onAvatarTapped: () {
                  Navigator.pushNamed(context, '/profile');
                },
              ),
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          color: Colors.black.withOpacity(0.4),
          child: CustomTopBar(
            onNotificationTapped: () {
              Navigator.pushNamed(context, '/notification');
            },
            onSettingsTapped: () {
              Navigator.pushNamed(context, '/setting');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProfileBox() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10), 
        border: Border.all(color: const Color(0xFF9DD0E7), width: 2),
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            right: 0,
            child: Image.asset(
              'assets/images/design/design2.png',
              height: 180, 
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            top: 3,
            right: 3,
            child: Image.asset(
              'assets/images/design/design1.png',
              width: 50,
              fit: BoxFit.contain,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAvatarSection(),
                const SizedBox(width: 16),
                _buildUserInfoSection(),
              ],
            ),
          ),
        ], 
      ),
    );
  }

  Widget _buildAvatarSection() {
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(130, 130),
                painter: GradientCircularProgressPainter(
                  progress: _expPercent, // [UPDATED] ใช้ค่าจริง
                  gradient: const LinearGradient(
                    colors: [Color(0xFF88FF40), Color(0xFF66E0FF)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  strokeWidth: 8,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                child: Container(
                  width: 108,
                  height: 108,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: IgnorePointer(
                    child: Transform.translate(
                      offset: const Offset(2, 20), // เลื่อนตัวละครลงมาให้เห็นไหล่ และปรับแกน X ให้ตรงกลาง
                      child: Transform.scale(
                        scale: 1.6, // ซูมหน้า
                        child: RepaintBoundary( // แยก Layer ลดการวาดใหม่ของ UI
                          child: CharacterWidget(
                            user: _user,
                            isInteractive: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Colors.white, Color(0xFFE0E0E0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "$_level", // [UPDATED] แสดง Level จริง
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                      color: Colors.black,
                      height: 1,
                    ),
                  ),
                  const Text(
                    "Lv.",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.black54,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoSection() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(
                "UID : $_uid", // [UPDATED] แสดง UID จริง
                style: const TextStyle(
                  color: Color(0xFF00385D), 
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 5),
              Image.asset(
                'assets/images/icon/iconCopy.png',
                width: 16,
                height: 16,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoField(
            content: _displayName,
            columnName: 'user_name',
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black,
              overflow: TextOverflow.ellipsis,
            ),
            borderColor: const Color(0xFF9DD0E7),
            iconColor: const Color(0xFF1E5173),
            height: 35,
          ),
          const SizedBox(height: 6),
          _buildInfoField(
            content: _displayBio,
            columnName: 'user_detail',
            textStyle: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              overflow: TextOverflow.ellipsis,
            ),
            borderColor: const Color(0xFF9DD0E7),
            iconColor: const Color(0xFF1E5173),
            height: 30,
            iconSize: 14,
          ),
          const SizedBox(height: 8),
          _buildLinearExpBar(),
        ],
      ),
    );
  }

  Widget _buildInfoField({
    required String content,
    required String columnName,
    required TextStyle textStyle,
    required Color borderColor,
    required Color iconColor,
    double height = 35,
    double iconSize = 16,
  }) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(content, style: textStyle)),
          GestureDetector(
            onTap: () {
              _showEditDialog(
                columnName == 'user_name' ? 'ชื่อ' : 'แนะนำตัว',
                content,
                columnName
              );
            },
            child: Image.asset(
              'assets/images/icon/iconEdit.png',
              width: iconSize,
              height: iconSize,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinearExpBar() {
    return Column(
      children: [
        Row(
          children: [
            const Text(
              "EXP",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "$_currentExp/$_nextLevelExp", // [UPDATED] แสดง EXP จริง
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Container(
          height: 16,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(
                  height: 12,
                  color: const Color(0xFF535353),
                ),
                FractionallySizedBox(
                  widthFactor: _expPercent, // [UPDATED] ใช้ % จริง
                  child: Container(
                    height: 12,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF88FF40), Color(0xFF66E0FF)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox() {
    return Column(
      children: [
        _buildBoxHeader(
          iconPath: 'assets/images/icon/icon-white-loading.png',
          title: "ค่าความสามารถ",
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: _buildBoxDecoration(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // [UPDATED] Show Rive Character
              SizedBox(
                height: 160,
                width: 160,
                child: _user == null 
                  ? const Center(child: CircularProgressIndicator()) 
                  : Transform.translate(
                      offset: Offset(0, _user!.bodyType.toUpperCase() == 'KID' ? 20 : 0),
                      child: (RiveCache().getFile(_getModelAsset()) != null 
                          ? RiveAnimation.direct(
                              RiveCache().getFile(_getModelAsset())!,
                              fit: BoxFit.contain,
                              onInit: _onRiveInit,
                            )
                          : RiveAnimation.asset(
                              _getModelAsset(), 
                              fit: BoxFit.contain,
                              onInit: _onRiveInit,
                            )),
                    ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    // [UPDATED] ใช้ตัวแปร Stat ที่ดึงมาจาก DB
                    _buildStatRow('assets/images/profile/stat-int-img.png', "ความฉลาด", _intStat),
                    const SizedBox(height: 8),
                    _buildStatRow('assets/images/profile/stat-str-img.png', "ความแข็งแรง", _strStat),
                    const SizedBox(height: 8),
                    _buildStatRow('assets/images/profile/stat-cre-img.png', "ความคิดสร้างสรรค์", _creStat),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String iconPath, String label, String value) {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF2E4C6D),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(iconPath, fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
             value,
             style: const TextStyle(
               fontWeight: FontWeight.bold,
               fontSize: 14,
               color: Colors.black,
             ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildAchievementBox() {
    return Column(
      children: [
        _buildBoxHeader(
          iconPath: 'assets/images/icon/iconAchievement.png',
          // 🌟 อัปเดตข้อความ Header ตามตัวแปร
          title: "ความสำเร็จ $_unlockedAchievements/$_totalAchievements",
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: _buildBoxDecoration(),
          child: SingleChildScrollView( // ป้องกัน overflow กรณีมีหลายอัน
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              // 🌟 สร้าง Item ตามรูปที่ดึงมาได้
              children: _achievementImages.isEmpty 
                ? [
                    // ถ้ายังไม่มีสักอัน โชว์ข้อความ หรือเว้นว่าง
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Text("ยังไม่มีความสำเร็จที่ปลดล็อก", style: TextStyle(color: Colors.grey)),
                    )
                  ]
                : _achievementImages.map((imagePath) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _buildAchievementItem(imagePath),
                    );
                  }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // 🌟 ปรับให้รองรับ URL หรือ Asset path
  Widget _buildAchievementItem(String imagePath) {
    return Container(
      width: 55,
      height: 55,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF9DD0E7), width: 2),
      ),
      child: ClipOval(
        child: imagePath.startsWith('http')
            ? Image.network(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.star, color: Colors.grey),
              )
            : Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.star, color: Colors.grey),
              ),
      ),
    );
  }

  Widget _buildBoxHeader({required String iconPath, required String title}) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2374B5), Color(0xFF9DD0E7)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 14, right: 6),
        child: Row(
          children: [
              Image.asset(
              iconPath,
              height: 50,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Image.asset(
              'assets/images/design/design1.png',
              width: 50,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _buildBoxDecoration() {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.5),
      border: const Border(
        left: BorderSide(color: Color(0xFF9DD0E7), width: 2),
        right: BorderSide(color: Color(0xFF9DD0E7), width: 2),
        bottom: BorderSide(color: Color(0xFF9DD0E7), width: 2),
      ),
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(10),
        bottomRight: Radius.circular(10),
      ),
    );
  }
}

class GradientCircularProgressPainter extends CustomPainter {
  final double progress;
  final Gradient gradient;
  final double strokeWidth;

  GradientCircularProgressPainter({
    required this.progress,
    required this.gradient,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.grey.withValues(alpha: 0.2);
      
    canvas.drawCircle(center, radius, trackPaint);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14159 / 4, 
      2 * 3.14159 * progress, 
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}