import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:flutter_application_1/api_service.dart' as api;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_application_1/config/app_config.dart';
import 'package:rive/rive.dart' hide LinearGradient, Image;
import 'package:flutter_application_1/config/rive_cache.dart';
import 'package:flutter_application_1/widgets/chance_display.dart';
import 'package:flutter_application_1/screens/result_stat.dart';
import 'package:flutter_application_1/screens/result_exam.dart';
import 'package:flutter_application_1/widgets/ticket_box.dart';
import 'package:flutter_application_1/widgets/energy_bar.dart'; // 🌟 นำเข้า EnergyBar Widget

// 🌟 เปลี่ยนจาก level เป็น energy
enum StatType { energy, intelligence, strength, creativity }

class ExamScreen extends StatefulWidget {
  final api.User? user;
  final String locationName;
  final String locationImage;
  final Map<String, int> statusRewards;

  const ExamScreen({
    Key? key,
    required this.user,
    required this.locationName,
    required this.locationImage,
    required this.statusRewards,
  }) : super(key: key);

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  bool _isPressed = false;
  final SupabaseClient _supabase = Supabase.instance.client;

  String _displayName = "Loading...";
  String _displayBio = "กำลังโหลดข้อมูล...";
  String _uid = "Loading...";

  int _level = 1;
  int _currentExp = 0;
  int _nextLevelExp = 40;
  double _expPercent = 0.0;

  int _intStat = 10;
  int _strStat = 10;
  int _creStat = 10;
  int _stamina = 0; // 🌟 1. เพิ่มตัวแปรเก็บพลังงาน

  SMINumber? _poseInput;
  SMINumber? _hairInput;
  SMINumber? _faceInput;
  SMINumber? _skinInput;
  SMINumber? _clothInput;
  StateMachineController? _controller;
  api.User? _user;
  bool _isRiveLoaded = false;
  bool _didPassExam = false; // ตัวแปรบอกว่าสอบผ่านหรือยัง เพื่อส่งค่ากลับไปหน้า location_upgrade

  // ค่า Requirements สำหรับแต่ละอาคาร
  // 🌟 2. ลบ Mockup เดิมออก ให้เหลือแค่วงเล็บปีกกาว่างๆ
  Map<String, Map<StatType, int>> _examRequirements = {};
  Map<String, String> _examTypes = {}; // <- เพิ่มบรรทัดนี้
  Map<String, List<Map<String, dynamic>>> _examRewards = {}; // 🌟 1. เพิ่มตัวแปรเก็บของรางวัล
  Map<String, int> _examIds = {}; // 🌟 เพิ่มตัวแปรเก็บ ID ข้อสอบ
  Map<String, String> _examStatuses = {}; // 🌟 1. เพิ่มตัวแปรเก็บสถานะว่าผ่านหรือยัง

  String _getStatName(StatType type) {
    switch (type) {
      case StatType.energy: // 🌟
        return 'พลังงาน';
      case StatType.intelligence:
        return 'ความฉลาด';
      case StatType.strength:
        return 'ความแข็งแรง';
      case StatType.creativity:
        return 'ความคิดสร้างสรรค์';
    }
  }

  String? _selectedExam; // เก็บข้อสอบที่เลือก

  // Background paths สำหรับแต่ละสถานที่
  String get _backgroundPath {
    switch (widget.locationName) {
      case 'โรงยิม':
        return 'assets/images/background/bg8.png';
      case 'หอสมุด':
        return 'assets/images/background/bg7.png';
      case 'สวนสนุก':
        return 'assets/images/background/bg9.png';
      case 'สวนสาธารณะ':
        return 'assets/images/background/bg10.png';
      case 'สนามสอบ':
        return 'assets/images/background/bg12.png';
      default:
        return 'assets/images/background/bg14.png';
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _fetchFullProfileForRive();
    _fetchExams(); // 🌟 สั่งให้ดึงข้อสอบตอนเปิดหน้าต่าง
  }

  void _updateLevelUI(int dbLevel, int totalExp) {
    int remainingExp = totalExp;
    int requiredExpForNextLevel = 0;

    for (int i = 1; i < dbLevel; i++) {
      int expUsed = 0;
      if (i < 6) {
        expUsed = 40 * i;
      } else {
        expUsed = 200 + (i * i);
      }
      remainingExp -= expUsed;
    }

    if (dbLevel < 6) {
      requiredExpForNextLevel = 40 * dbLevel;
    } else {
      requiredExpForNextLevel = 200 + (dbLevel * dbLevel);
    }

    if (mounted) {
      setState(() {
        _level = dbLevel;
        _currentExp = remainingExp;
        _nextLevelExp = requiredExpForNextLevel;
        _expPercent = (_nextLevelExp > 0)
            ? (_currentExp / _nextLevelExp).clamp(0.0, 1.0)
            : 0.0;
      });
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      setState(() {
        _uid = user.id.substring(0, 8);
      });

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

      final charData = await _supabase
          .from('characters')
          .select('level, experience, intelligence, strength, creative, stamina')
          .eq('user_id', user.id)
          .maybeSingle();

      if (charData != null) {
        setState(() {
          _intStat = charData['intelligence'] ?? 10;
          _strStat = charData['strength'] ?? 10;
          _creStat = charData['creative'] ?? 10;
          _stamina = charData['stamina'] ?? 10; // 🌟 เก็บค่าพลังงานเอาไปเช็ค
        });

        final dbLevel = charData['level'] as int? ?? 1;
        final totalExp = charData['experience'] as int? ?? 0;
        _updateLevelUI(dbLevel, totalExp);
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }

  Future<void> _fetchFullProfileForRive() async {
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

  // 🌟 แก้ไขฟังก์ชันดัก Error เรื่องตัวแปรที่ไม่ได้ประกาศ
  Future<void> _fetchExams() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final conductData = await _supabase
          .from('conduct')
          .select('exam_id, status, exams(*, take(quantity, items(name, image)))') 
          .eq('user_id', user.id)
          .order('exam_id', ascending: false)
          .limit(3);

      if (conductData != null && (conductData as List).isNotEmpty) {
        Map<String, Map<StatType, int>> fetchedRequirements = {};
        Map<String, String> fetchedTypes = {};
        Map<String, List<Map<String, dynamic>>> fetchedRewards = {};
        Map<String, int> fetchedIds = {};      // ✅ เพิ่มการประกาศตัวแปรนี้
        Map<String, String> fetchedStatuses = {}; // ✅ เพิ่มการประกาศตัวแปรนี้

        for (var conduct in conductData) {
          final exam = conduct['exams'];
          if (exam == null) continue;

          String dbName = exam['name'] ?? '';
          String examKey = '';
          
          if (dbName.contains('วิทยาศาสตร์')) {
            examKey = 'ทดสอบวิทยาศาสตร์';
          } else if (dbName.contains('คณิตศาสตร์')) {
            examKey = 'ทดสอบคณิตศาสตร์';
          } else if (dbName.contains('อังกฤษ')) {
            examKey = 'ทดสอบอังกฤษ';
          } else {
            examKey = dbName;
          }

          fetchedRequirements[examKey] = {
            StatType.energy: exam['stamina'] ?? 15,
            StatType.intelligence: exam['intelligence'] ?? 0,
            StatType.strength: exam['strength'] ?? 0,
            StatType.creativity: exam['creative'] ?? 0,
          };

          fetchedTypes[examKey] = exam['type'] ?? '';
          fetchedIds[examKey] = exam['id'] ?? 0; // ✅ ใช้ fetchedIds ที่ประกาศใหม่
          fetchedStatuses[examKey] = conduct['status'] ?? 'pending';
          
          List<Map<String, dynamic>> rewardsList = [];
          if (exam['take'] != null) {
            for (var t in exam['take']) {
              final item = t['items'];
              if (item != null) {
                String itemName = item['name']?.toString().toUpperCase() ?? '';
                String prefix = (itemName.contains('EXP') || itemName.contains('COIN') || itemName.contains('เหรียญ')) ? '+' : 'x';
                
                String imgPath = item['image'] ?? 'EXP.png';
                if (!imgPath.startsWith('assets/')) {
                  imgPath = 'assets/images/item/$imgPath';
                }

                rewardsList.add({
                  'image': imgPath,
                  'text': '$prefix${t['quantity'] ?? 1}',
                });
              }
            }
          }
          fetchedRewards[examKey] = rewardsList;
        }

        if (mounted) {
          setState(() {
            _examRequirements = fetchedRequirements; 
            _examTypes = fetchedTypes;
            _examRewards = fetchedRewards; 
            _examIds = fetchedIds;      // ✅ อัปเดตค่าเข้าตัวแปรของ Class
            _examStatuses = fetchedStatuses; // ✅ อัปเดตค่าเข้าตัวแปรของ Class
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching exams: $e');
    }
  }

  void _onRiveInit(Artboard artboard) {
    var controller = StateMachineController.fromArtboard(
      artboard,
      'State Machine 1',
    );
    if (controller == null && artboard.stateMachines.isNotEmpty) {
      controller = StateMachineController.fromArtboard(
        artboard,
        artboard.stateMachines.first.name,
      );
    }

    if (controller != null) {
      artboard.addController(controller);
      _controller = controller;

      for (var input in controller.inputs) {
        if (input.name == 'Pose') _poseInput = input as SMINumber;
        if (input.name == 'HairID') _hairInput = input as SMINumber;
        if (input.name == 'FaceID') _faceInput = input as SMINumber;
        if (input.name == 'SkinID') _skinInput = input as SMINumber;
        if (input.name == 'OutfitID') {
          _clothInput = input as SMINumber;
        }
      }

      _syncRiveToEquipped();

      if (_poseInput != null) {
        _poseInput!.value = 2.0;
      }
    }
    if (mounted) setState(() => _isRiveLoaded = true);
  }

  double _parseId(String s) {
    if (s.isEmpty) return 0;
    if (s.contains('_')) {
      try {
        return double.parse(s.split('_').last);
      } catch (_) {}
    }
    if (s.contains(' ')) {
      try {
        return double.parse(s.split(' ').last);
      } catch (_) {}
    }
    try {
      return double.parse(s);
    } catch (_) {
      return 0;
    }
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

      if (_poseInput != null) _poseInput!.value = 2.0;
    } catch (e) {
      print("Error syncing Rive Profile: $e");
    }
  }

  String _getModelAsset() {
    if (_user != null) {
      final bt = _user!.bodyType.toUpperCase();
      if (bt == 'ADULT') return 'assets/animation/adult.riv';
      if (bt == 'TEEN') return 'assets/animation/teen.riv';
      return 'assets/animation/kid.riv';
    }
    int lvl = _level;
    if (lvl >= 30) return 'assets/animation/adult.riv';
    if (lvl >= 15) return 'assets/animation/teen.riv';
    return 'assets/animation/kid.riv';
  }

  // ฟังก์ชันตรวจสอบว่าค่าสถานะเพียงพอหรือไม่
  bool _meetsRequirement(StatType type, int required) {
    switch (type) {
      case StatType.energy: // 🌟
        return _stamina >= required;
      case StatType.intelligence:
        return _intStat >= required;
      case StatType.strength:
        return _strStat >= required;
      case StatType.creativity:
        return _creStat >= required;
    }
  }

  // ฟังก์ชันตรวจสอบว่าผ่านทุก requirement หรือไม่
  bool _meetsAllRequirements(String examName) {
    final requirements = _examRequirements[examName];
    if (requirements == null) return true;

    return requirements.entries.every(
      (entry) => _meetsRequirement(entry.key, entry.value),
    );
  }

  // คำนวณเปอร์เซ็นต์ความพร้อม (เริ่มต้น 95% หักลบตามที่ขาด)
  double _getReadinessPercentage(String examName) {
    final requirements = _examRequirements[examName];
    if (requirements == null) return 100.0;

    final currentType = _examTypes[examName] ?? '';
    int passChance = 95; // 🌟 1. เริ่มต้นที่ 95%

    // --- 2. คำนวณ Energy (Stamina) ---
    int reqStamina = requirements[StatType.energy] ?? 15;
    if (_stamina < reqStamina) {
      passChance -= (reqStamina - _stamina) * 3; // หัก 3% ต่อ 1 แต้มที่ขาด
    }

    // --- 3. ฟังก์ชันช่วยหักคะแนน Stat หลัก/รอง ---
    int calculateDeduction(int playerStat, int requiredStat, bool isMainStat) {
      if (playerStat >= requiredStat) {
        return 0; // ผ่านเกณฑ์ ไม่โดนหัก
      }
      int missingPoints = requiredStat - playerStat;
      return isMainStat ? (missingPoints * 10) : (missingPoints * 5); // หลักหัก 10, รองหัก 5
    }

    // --- 4. หักลบทีละ Stat ---
    passChance -= calculateDeduction(_intStat, requirements[StatType.intelligence] ?? 0, currentType == "intelligence");
    passChance -= calculateDeduction(_strStat, requirements[StatType.strength] ?? 0, currentType == "strength");
    passChance -= calculateDeduction(_creStat, requirements[StatType.creativity] ?? 0, currentType == "creative");

    // --- 5. บังคับไม่ให้ติดลบ ---
    if (passChance < 0) passChance = 0;

    return passChance.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final topBarHeight = 60.0 + topPadding;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _didPassExam);
      },
      child: Scaffold(
      body: Stack(
        children: [
          /// Background (แยกตามสถานที่)
          Positioned.fill(
            child: Image.asset(
              _backgroundPath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Image.asset(
                  'assets/images/background/bg6.png',
                  fit: BoxFit.cover,
                );
              },
            ),
          ),

          /// Main content
          Positioned.fill(
            top: topBarHeight,
            bottom: 0,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 100, 24, 24),
              child: Column(
                children: [
                  /// Exam Buildings or Requirements Box
                  if (widget.locationName == 'สนามสอบ')
                    _buildExamMap()
                  else
                    _buildRequirementsBox(widget.locationName),

                  SizedBox(height: 20),

                  /// Requirements Box (แสดงเมื่อเลือกข้อสอบในแผนที่)
                  if (widget.locationName == 'สนามสอบ' && _selectedExam != null)
                    _buildRequirementsBox(_selectedExam!),

                  if (widget.locationName == 'สนามสอบ' && _selectedExam != null)
                    SizedBox(height: 20),

                  if (true) ...[
                    EnergyBar(),
                    SizedBox(height: 20),
                  ],

                  /// Stat Box
                  _buildStatBox(),

                  SizedBox(height: 20),
                ],
              ),
            ),
          ),

          /// Top Bar
          _buildTopBar(topPadding, topBarHeight),

          /// Blue Header
          _buildBlueHeader(topBarHeight),
        ],
      ),
    ),
    );
  }

  /// 🆕 Requirements Box
  /// 🆕 Requirements Box
  Widget _buildRequirementsBox(String rawExamName) {
    // แปลงชื่อให้ตรงกับ _examRequirements เสมอ
    String examName = rawExamName;
    if (rawExamName.contains('วิทยาศาสตร์')) examName = 'ทดสอบวิทยาศาสตร์';
    if (rawExamName.contains('คณิตศาสตร์')) examName = 'ทดสอบคณิตศาสตร์';
    if (rawExamName.contains('อังกฤษ')) examName = 'ทดสอบอังกฤษ';

    final requirements = _examRequirements[examName] ?? {};
    final currentType = _examTypes[examName] ?? ''; // 🌟 3.1 ดึง type จากที่เก็บไว้
    final readiness = _getReadinessPercentage(examName);
    final canStart = _meetsAllRequirements(examName);
    final rewards = _examRewards[examName] ?? []; // 🌟 3.1 ดึงของรางวัลจาก state
    

    final statOrder = [
      StatType.energy, // 🌟 เปลี่ยนจาก level
      StatType.intelligence,
      StatType.strength,
      StatType.creativity,
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF9DD0E7), width: 2),
      ),
      child: Column(
        children: [
          /// Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2374B5), Color.fromARGB(255, 127, 179, 202)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Center(
              child: Text(
                'ค่าสถานะที่ต้องการ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                /// 🔥 4 ช่องเสมอ
                ...statOrder.map((type) {
                  
                  // 🌟 3.2 เช็คว่า Stat ช่องนี้ตรงกับ type ของข้อสอบหรือไม่
                  bool isMainStat = false;
                  if (currentType == 'intelligence' && type == StatType.intelligence) isMainStat = true;
                  if (currentType == 'strength' && type == StatType.strength) isMainStat = true;
                  if (currentType == 'creative' && type == StatType.creativity) isMainStat = true;

                  return _buildRequirementRow(
                    type: type,
                    required: requirements[type] ?? -1,
                    isMainStat: isMainStat, // 🌟 3.3 ส่งค่าไปบอกฟังก์ชันวาด
                  );
                }).toList(),

                SizedBox(height: 16),

                /// ของรางวัล
                Text(
                  'ของรางวัล',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  // 🌟 3.2 สร้างกล่องรางวัลแบบวนลูปตามจำนวนของที่มีใน DB
                  children: rewards.isNotEmpty
                      ? rewards.map((rw) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5), // เว้นระยะห่าง 10 ระหว่างกล่อง (ซ้ายขวาอย่างละ 5)
                            child: _buildRewardItem(rw['image'], rw['text'], 1.0),
                          );
                        }).toList()
                      : [
                          // กรณีที่ข้อมูลยังไม่มา หรือ DB ไม่มีของรางวัลผูกไว้ ให้โชว์กล่องเปล่า
                          _buildRewardItem('assets/images/item/EXP.png', '+0', 1.0),
                        ],
                ),

                SizedBox(height: 16),

                Column(
                  children: [
                    ChanceDisplay(chancePercent: readiness.toInt()),
                    SizedBox(height: 8),
                    _buildExamStartButton(canStart, examName),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardItem(String imagePath, String text, double scale) {
    return Container(
      width: 60,
      padding: EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Item Image
          Image.asset(
            imagePath,
            width: 40 * scale,
            height: 40 * scale,
            fit: BoxFit.contain,
          ),
          SizedBox(height: 4 * scale),
          // Amount below image
          Text(
            text,
            style: TextStyle(
              fontSize: 12 * scale,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow({required StatType type, required int required, bool isMainStat = false}) { // 🌟 รับค่า isMainStat
    bool isMet = required < 0 ? true : _meetsRequirement(type, required);

    int currentValue;
    switch (type) {
      case StatType.energy: 
        currentValue = _stamina;
        break;
      case StatType.intelligence:
        currentValue = _intStat;
        break;
      case StatType.strength:
        currentValue = _strStat;
        break;
      case StatType.creativity:
        currentValue = _creStat;
        break;
      default:
        currentValue = 0; // เผื่อกรณี stat ชนิดอื่น
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 5),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Color(0xFFE0E0E0), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center, // จัดให้อยู่กึ่งกลาง
          children: [
            Text(
              _getStatName(type),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF000000),
              ),
            ),
            // 🌟 ซ้อน Column ฝั่งขวา เพื่อดันข้อความแจ้งเตือนไว้ด้านบนของเลข
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isMainStat)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '(มีผลต่อโอกาสผ่านสูง)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54, // ใช้สีเทามาตรฐานเพื่อไม่กวนสีเดิมของแอป
                      ),
                    ),
                  ),
                required > 0
                    ? Text.rich(
                        TextSpan(
                          text: 'ค่าที่แนะนำ: ', // 🌟 แก้จาก '> ' เป็นคำใหม่
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black,
                          ),
                          children: [
                            TextSpan(
                              text: '$required',
                              style: TextStyle(
                                color: isMet ? Colors.green : Colors.red, // คงเงื่อนไขสีเดิมไว้
                              ),
                            ),
                          ],
                        ),
                      )
                    : Text(
                        '-',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 🆕 Exam Start Button
  Widget _buildExamStartButton(bool canStart, String examName) {
    // 🌟 3.1 เช็คสถานะว่าสอบผ่านไปแล้วหรือยัง
    bool isPassed = _examStatuses[examName] == 'completed';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 180,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isPassed 
                ? [Color(0xFF9E9E9E), Color(0xFFBDBDBD)] // สีเทาเมื่อสอบผ่านแล้ว
                : [Color(0xFF556AEB), Color(0xFF59ABEC)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: isPassed 
                  ? Colors.grey.withOpacity(0.3) 
                  : Color(0xFF556AEB).withOpacity(0.4),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            // 🌟 3.2 ถ้าสอบผ่านแล้วให้ใส่ null จะทำให้ปุ่มล็อกและกดไม่ได้
            onPressed: isPassed ? null : () async {
              if (examName.isEmpty) return;
              
              int currentExamId = _examIds[examName] ?? 0;
              if (currentExamId == 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ไม่พบข้อมูลข้อสอบ!')));
                return;
              }

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => const Center(child: CircularProgressIndicator()),
              );

              final result = await api.ApiService.startExam(currentExamId);

              if (mounted) Navigator.pop(context);

              if (result != null) {
                if (result['success'] == true) {
                  bool resultPassed = result['is_passed'] ?? false;
                  
                  // บันทึกว่าสอบผ่านเพื่อส่งกลับไปหน้า location_upgrade
                  if (resultPassed) {
                    _didPassExam = true;
                  }
                  
                  Map<String, int> finalRewards = {};
                  if (resultPassed && result['rewards'] != null) {
                    for (var r in result['rewards']) {
                      finalRewards[r['name']] = r['amount']; 
                    }
                  }

                  _fetchUserProfile();
                  
                  if (mounted) {
                    // 🌟 3.3 ใส่ await เพื่อให้แอปหยุดรอจนกว่าผู้เล่นจะกดปิดหน้าผลสอบ
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ResultExamScreen(
                          statusRewards: finalRewards,
                          isPassed: resultPassed,
                        ),
                      ),
                    );
                    
                    // 🌟 3.4 พอกลับมาหน้านี้ ให้รีเฟรชข้อสอบทันที เพื่อให้ปุ่มเปลี่ยนเป็น "สอบผ่านแล้ว"
                    _fetchExams();
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result['error'] ?? 'เกิดข้อผิดพลาด'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent, // 🌟 ล็อกไม่ให้พื้นหลังเทาเวลากดไม่ได้
              disabledForegroundColor: Colors.white, // 🌟 ล็อกไม่ให้ตัวหนังสือเทาเวลากดไม่ได้ (รักษา UI เดิม)
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPassed) ...[
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                ],
                Text(
                  isPassed ? 'สอบผ่านแล้ว' : 'เริ่มสอบ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // 🌟 3.6 ถ้าสอบผ่านแล้วให้ซ่อนป้ายตั๋วทิ้งไปเลย จะได้ดูสมจริง
        if (!isPassed)
        Positioned(
          top: -12,
          right: -10,
          child: TicketBox(
            slant: 12,
            borderRadius: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/item/Ticket_exam_img.png',
                    width: 20,
                    height: 10,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "-1",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () async {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        setState(() => _isPressed = false);
        Navigator.pop(context, _didPassExam);
      },
      child: Image.asset(
        _isPressed
            ? 'assets/images/button/bt-hover-Back.png'
            : 'assets/images/button/bt-Back.png',
        width: 50,
        height: 50,
      ),
    );
  }

  Widget _buildBlueHeader(double topOffset) {
    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      child: Container(
        height: 80,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF015496), Color(0xFF2273B4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 15,
              top: 0,
              bottom: 0,
              child: Center(child: _buildBackButton()),
            ),
            Center(
              child: Text(
                widget.locationName,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRewardsBox() {
    Map<String, int> displayRewards = {};

    switch (widget.locationName) {
      case 'สวนสนุก':
        displayRewards = {
          'ความฉลาด': 0,
          'ความแข็งแรง': 0,
          'ความคิดสร้างสรรค์': 1,
        };
        break;
      case 'โรงยิม':
        displayRewards = {
          'ความฉลาด': 0,
          'ความแข็งแรง': 1,
          'ความคิดสร้างสรรค์': 0,
        };
        break;
      case 'หอสมุด':
        displayRewards = {
          'ความฉลาด': 1,
          'ความแข็งแรง': 0,
          'ความคิดสร้างสรรค์': 0,
        };
        break;
      case 'สวนสาธารณะ':
        displayRewards = {'พลังงาน': 20};
        break;
      default:
        displayRewards = widget.statusRewards;
    }

    final scale = MediaQuery.of(context).size.width / 375;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF9DD0E7), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ///HEADER (Gradient)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: 16 * scale,
              vertical: 12 * scale,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2374B5), Color(0xFF9DD0E7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Text(
              'ค่าสถานะที่ต้องการ',
              style: TextStyle(
                fontSize: 16 * scale,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          /// CONTENT
          Padding(
            padding: EdgeInsets.all(16 * scale),
            child: Column(
              children: [
                ...displayRewards.entries.map((entry) {
                  final isIncreased = entry.value > 0;
                  return Padding(
                    padding: EdgeInsets.only(bottom: 2 * scale),
                    child: _buildStatusRow(entry.key, entry.value, isIncreased),
                  );
                }).toList(),

                SizedBox(height: 2 * scale),

                _buildActionSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String statusName, int value, bool isIncreased) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Color(0xFFE0E0E0), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              statusName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF002A50),
              ),
            ),
            Text(
              isIncreased ? '+$value' : '$value',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isIncreased ? Color(0xFF4CAF50) : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Action Section (Cost + Button in one box)
  Widget _buildActionSection() {
    final isPark = widget.locationName == 'สวนสาธารณะ';

    return Container(
      padding: EdgeInsets.all(20),
      child: Stack(
        // 🔥 ต้องมี Stack
        children: [
          Column(
            children: [
              /// Cost Display
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(
                    child: ChanceDisplay(
                      energyCost: 20,
                      ticketCost: 1,
                      showTicket: true,
                      showEnergy: !isPark,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              /// ปุ่ม Start
              Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF556AEB), Color(0xFF59ABEC)],
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ResultStatScreen(
                          statusRewards: widget.statusRewards,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  child: Text(
                    'เริ่มสอบ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),

          /// 🔥 Badge (ถูกต้องแล้ว)
          Positioned(
            top: 0,
            right: 0,
            child: TicketBox(
              slant: 12,
              borderRadius: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/item/Ticket_exam_img.png',
                      width: 20,
                      height: 10,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "-1",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox() {
    return Column(
      children: [
        _buildBoxHeader(
          iconPath: 'assets/images/icon/icon-white-loading.png',
          title: _displayName,
        ),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
            border: const Border(
              left: BorderSide(color: Color(0xFF9DD0E7), width: 2),
              right: BorderSide(color: Color(0xFF9DD0E7), width: 2),
              bottom: BorderSide(color: Color(0xFF9DD0E7), width: 2),
            ),
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
                padding: const EdgeInsets.all(15),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildAvatarSection(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStatRowWithIcon(
                            'assets/images/profile/stat-int-img.png',
                            "ความฉลาด",
                            _intStat.toString(),
                          ),
                          const SizedBox(height: 8),
                          _buildStatRowWithIcon(
                            'assets/images/profile/stat-str-img.png',
                            "ความแข็งแรง",
                            _strStat.toString(),
                          ),
                          const SizedBox(height: 8),
                          _buildStatRowWithIcon(
                            'assets/images/profile/stat-cre-img.png',
                            "ความคิดสร้างสรรค์",
                            _creStat.toString(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExamMap() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF9DD0E7), width: 2),
      ),
      child: Column(
        children: [
          // อาคารบน (วิทย์ / คณิต)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildExamBuilding(
                label: 'ทดสอบวิทยาศาสตร์',
                image: 'assets/images/map/sci_building.png',
                stat: {'ความฉลาด': 1, 'ความแข็งแรง': 0, 'ความคิดสร้างสรรค์': 0},
              ),
              _buildExamBuilding(
                label: 'ทดสอบคณิตศาสตร์',
                image: 'assets/images/map/math_building.png',
                stat: {'ความฉลาด': 2, 'ความแข็งแรง': 0, 'ความคิดสร้างสรรค์': 0},
              ),
            ],
          ),

          SizedBox(height: 20),

          // อาคารล่าง (อังกฤษ)
          _buildExamBuilding(
            label: 'ทดสอบอังกฤษ',
            image: 'assets/images/map/eng_building.png',
            stat: {'ความฉลาด': 1, 'ความแข็งแรง': 0, 'ความคิดสร้างสรรค์': 1},
          ),
        ],
      ),
    );
  }

  Widget _buildExamBuilding({
    required String label,
    required String image,
    required Map<String, int> stat,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedExam = label;
        });
      },
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: _selectedExam == label
                  ? Border.all(color: Color(0xFF2374B5), width: 3)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.home, size: 50);
                },
              ),
            ),
          ),

          const SizedBox(height: 6),

          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _selectedExam == label ? Color(0xFF2374B5) : Colors.black,
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
                  progress: _expPercent,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF88FF40), Color(0xFF66E0FF)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  strokeWidth: 8,
                ),
              ),
              Container(
                width: 114,
                height: 114,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: _user == null 
                  ? const Center(child: CircularProgressIndicator()) 
                  : Transform.scale(
                      scale: 1.6,
                      alignment: Alignment.center,
                      child: Transform.translate(
                        offset: Offset(1, _user!.bodyType.toUpperCase() == 'KID' ? 15 : 15),
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
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "$_level",
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

  Widget _buildStatRowWithIcon(String iconPath, String label, String value) {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
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
            Image.asset(iconPath, height: 50, fit: BoxFit.contain),
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

  Widget _buildTopBar(double topPadding, double height) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(top: topPadding),
        color: Colors.black.withOpacity(0.4),
        child: CustomTopBar(
          onNotificationTapped: () =>
              Navigator.pushNamed(context, '/notification'),
          onSettingsTapped: () => Navigator.pushNamed(context, '/setting'),
        ),
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
      ..color = Colors.grey.withOpacity(0.2);

    canvas.drawCircle(center, radius, trackPaint);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );

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
