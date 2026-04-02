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

enum StatType { level, intelligence, strength, creativity }

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

  SMINumber? _poseInput;
  SMINumber? _hairInput;
  SMINumber? _faceInput;
  SMINumber? _skinInput;
  SMINumber? _clothInput;
  StateMachineController? _controller;
  api.User? _user;
  bool _isRiveLoaded = false;

  // ค่า Requirements สำหรับแต่ละอาคาร
  Map<String, Map<StatType, int>> _examRequirements = {
    'ทดสอบวิทยาศาสตร์': {
      StatType.level: 6,
      StatType.intelligence: 10,
      StatType.strength: 20,
      StatType.creativity: 9,
    },
    'ทดสอบคณิตศาสตร์': {
      StatType.level: 10,
      StatType.intelligence: 15,
      StatType.strength: 10,
      StatType.creativity: 12,
    },
    'ทดสอบอังกฤษ': {
      StatType.level: 5,
      StatType.intelligence: 8,
      StatType.strength: 4,
      StatType.creativity: 6,
    },
  };
  String _getStatName(StatType type) {
    switch (type) {
      case StatType.level:
        return 'เลเวล';
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
          .select('level, experience, intelligence, strength, creative')
          .eq('user_id', user.id)
          .maybeSingle();

      if (charData != null) {
        setState(() {
          _intStat = charData['intelligence'] ?? 10;
          _strStat = charData['strength'] ?? 10;
          _creStat = charData['creative'] ?? 10;
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
        if (input.name == 'ClothID' || input.name == 'BodyID') {
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
        double val = _parseId(_user!.equippedCloth);
        if (val == 0 && _user!.equippedBody.isNotEmpty) {
          val = _parseId(_user!.equippedBody);
        }
        _clothInput!.value = val;
      }

      if (_poseInput != null) _poseInput!.value = 2.0;
    } catch (e) {
      print("Error syncing Rive Profile: $e");
    }
  }

  // ฟังก์ชันตรวจสอบว่าค่าสถานะเพียงพอหรือไม่
  bool _meetsRequirement(StatType type, int required) {
    switch (type) {
      case StatType.level:
        return _level >= required;
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

  // คำนวณเปอร์เซ็นต์ความพร้อม
  double _getReadinessPercentage(String examName) {
    final requirements = _examRequirements[examName];
    if (requirements == null) return 100.0;

    int metCount = requirements.entries
        .where((entry) => _meetsRequirement(entry.key, entry.value))
        .length;

    return (metCount / requirements.length) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final topBarHeight = 75.0 + topPadding;

    return Scaffold(
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
    );
  }

  /// 🆕 Requirements Box
  /// 🆕 Requirements Box
  Widget _buildRequirementsBox(String rawExamName) {
    // แปลงชื่อให้ตรงกับ _examRequirements เสมอ
    String examName = rawExamName;
    if (rawExamName.contains('วิทย์')) examName = 'ทดสอบวิทยาศาสตร์';
    if (rawExamName.contains('คณิต')) examName = 'ทดสอบคณิตศาสตร์';
    if (rawExamName.contains('อังกฤษ')) examName = 'ทดสอบอังกฤษ';

    final requirements = _examRequirements[examName] ?? {};
    final readiness = _getReadinessPercentage(examName);
    final canStart = _meetsAllRequirements(examName);

    final statOrder = [
      StatType.level,
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
                  return _buildRequirementRow(
                    type: type,
                    required: requirements[type] ?? -1,
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
                  children: [
                    _buildRewardItem('assets/images/item/EXP.png', '+59', 1.0),
                    SizedBox(width: 10),
                    _buildRewardItem('assets/images/item/Gasha.png', 'x1', 1.0),
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

  /// 🆕 Requirement Row
  Widget _buildRequirementRow({required StatType type, required int required}) {
    bool isMet = required < 0 ? true : _meetsRequirement(type, required);

    int currentValue;
    switch (type) {
      case StatType.level:
        currentValue = _level;
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
          children: [
            Text(
              _getStatName(type),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF000000),
              ),
            ),
            required > 0
                ? Text.rich(
                    TextSpan(
                      text: '> ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black,
                      ),
                      children: [
                        TextSpan(
                          text: '$required',
                          style: TextStyle(
                            color: isMet ? Colors.green : Colors.red,
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
      ),
    );
  }

  /// 🆕 Exam Start Button
  Widget _buildExamStartButton(bool canStart, String examName) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 180,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF556AEB), Color(0xFF59ABEC)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF556AEB).withOpacity(0.4),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () {
              // Navigate to exam
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ResultExamScreen(
                    statusRewards: {
                      'ความฉลาด': 5,
                      'ความแข็งแรง': 2,
                      'ความคิดสร้างสรรค์': 3,
                    },
                    isPassed: true,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
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
        // ตั๋วใหญ่ขึ้นและอยู่ขอบๆ
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
        Navigator.pop(context);
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
                padding: const EdgeInsets.all(8),
                child: const CircleAvatar(
                  radius: 54,
                  backgroundImage: AssetImage(
                    'assets/images/profile/profile_img.png',
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
        height: height,
        padding: EdgeInsets.only(top: topPadding),
        color: Colors.black.withOpacity(0.4),
        alignment: Alignment.bottomCenter,
        child: CustomTopBar(
          user: widget.user,
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
