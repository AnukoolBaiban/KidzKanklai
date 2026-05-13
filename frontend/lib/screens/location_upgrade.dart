import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:flutter_application_1/api_service.dart' as api;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_application_1/config/app_config.dart';
import 'package:rive/rive.dart' hide LinearGradient, Image;
import 'package:flutter_application_1/config/rive_cache.dart';
import 'package:flutter_application_1/widgets/energy_bar.dart';
import 'package:flutter_application_1/widgets/cost_display.dart';
import 'package:flutter_application_1/widgets/chance_display.dart';
import 'package:flutter_application_1/widgets/ticket_box.dart';
import 'package:flutter_application_1/screens/result_stat.dart';
import 'package:flutter_application_1/screens/exam.dart';
import 'package:flutter_application_1/screens/video_transition_screen.dart';
import 'package:flutter_application_1/widgets/annotation.dart';

class LocationUpgradeScreen extends StatefulWidget {
  final api.User? user;
  final String locationName;
  final String locationImage;
  final Map<String, int> statusRewards;

  const LocationUpgradeScreen({
    Key? key,
    required this.user,
    required this.locationName,
    required this.locationImage,
    required this.statusRewards,
  }) : super(key: key);

  @override
  State<LocationUpgradeScreen> createState() => _LocationUpgradeScreenState();
}

class _LocationUpgradeScreenState extends State<LocationUpgradeScreen> {
  bool _isPressed = false;
  final SupabaseClient _supabase = Supabase.instance.client;

  String _displayName = "Loading...";
  String _displayBio = "กำลังโหลดข้อมูล...";
  String _uid = "Loading...";

  int _level = 1;
  int _currentExp = 0;
  int _nextLevelExp = 40;
  double _expPercent = 0.0;
  int _energyBarKey = 0; // 🌟 1. เพิ่มตัวแปร key สำหรับ EnergyBar

  String _intStat = "10";
  String _strStat = "10";
  String _creStat = "10";
  String _stamina = "0"; // 🌟 1. เพิ่มตัวแปรเก็บค่าพลังงานตรงนี้
  int _energyTicketCount = -1; // 🌟 เก็บจำนวนตั๋วพลังงาน (-1 = ยังไม่โหลด)

  SMINumber? _poseInput;
  SMINumber? _hairInput;
  SMINumber? _faceInput;
  SMINumber? _skinInput;
  SMINumber? _clothInput;
  StateMachineController? _controller;
  api.User? _user;
  bool _isRiveLoaded = false;
  Map<String, String> _examStatuses = {}; // เก็บสถานะว่าสอบผ่านหรือยัง

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
    _fetchEnergyTicketCount(); // 🌟 ดึงจำนวนตั๋วพลังงาน
    if (widget.locationName == 'สนามสอบ') {
      _fetchExamStatuses();
    }
  }

  Future<void> _fetchExamStatuses() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final conductData = await _supabase
          .from('conduct')
          .select('exam_id, status, exams(name)')
          .eq('user_id', user.id)
          .order('exam_id', ascending: false)
          .limit(3);

      debugPrint('📋 conductData: $conductData');

      if (conductData != null && (conductData as List).isNotEmpty) {
        Map<String, String> fetched = {};
        for (var conduct in conductData) {
          final exam = conduct['exams'];
          if (exam == null) continue;
          String dbName = exam['name'] ?? '';
          String status = conduct['status'] ?? 'pending';
          debugPrint('📋 exam name: "$dbName" | status: "$status"');
          
          // แมปชื่อตรงๆ จาก DB (ชื่อในฐานข้อมูลคือ ตึกสอบวิทยาศาสตร์, ตึกสอบคณิตศาสตร์, ตึกสอบอังกฤษ)
          String key = '';
          if (dbName.contains('วิทยาศาสตร์')) {
            key = 'ตึกสอบวิทยาศาสตร์';
          } else if (dbName.contains('คณิตศาสตร์')) {
            key = 'ตึกสอบคณิตศาสตร์';
          } else if (dbName.contains('อังกฤษ')) {
            key = 'ตึกสอบอังกฤษ';
          }
          if (key.isNotEmpty) {
            // ถ้าเคยมีสถานะเป็น completed แล้ว อย่าให้ pending ทับ
            if (fetched[key] != 'completed') {
              fetched[key] = status;
            }
          }
        }
        debugPrint('📋 fetched exam statuses: $fetched');
        if (mounted) setState(() => _examStatuses = fetched);
      }
    } catch (e) {
      debugPrint('Error fetching exam statuses: $e');
    }
  }

  // 🌟 ดึงจำนวนตั๋วพลังงาน (item_id = 21) จากตาราง collect
  Future<void> _fetchEnergyTicketCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('collect')
          .select('quantity')
          .eq('user_id', userId)
          .eq('item_id', 21)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _energyTicketCount = response != null ? (response['quantity'] ?? 0) : 0;
        });
      }
    } catch (e) {
      debugPrint('Error fetching energy ticket count: $e');
      if (mounted) setState(() => _energyTicketCount = 0);
    }
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
          _intStat = charData['intelligence'].toString();
          _strStat = charData['strength'].toString();
          _creStat = charData['creative'].toString();
          _stamina = charData['stamina'].toString(); // 🌟 2.2 เก็บค่าพลังงานที่ดึงมาได้
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

  // 🌟 ฟังก์ชันช่วยแก้ปัญหาการเรียงลำดับ HairID ใน Rive Model ที่สลับกัน
  double _getCorrectHairId(double originalId) {
    if (originalId == 2.0) return 3.0; // Hair_02 ในรูป คือ Rive ID 3
    if (originalId == 3.0) return 4.0; // Hair_03 ในรูป คือ Rive ID 4
    if (originalId == 4.0) return 2.0; // Hair_04 ในรูป คือ Rive ID 2
    return originalId;
  }

  void _syncRiveToEquipped() {
    if (_controller == null || _user == null) return;

    try {
      if (_hairInput != null) _hairInput!.value = _getCorrectHairId(_parseId(_user!.equippedHair));
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

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    final topBarHeight = 60.0 + topPadding;

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
                  /// Status Rewards Box
                  _buildStatusRewardsBox(),

                  if (widget.locationName != 'สนามสอบ') ...[
                    SizedBox(height: 20),
                    /// Stat Box
                    _buildStatBox(),
                    SizedBox(height: 20),
                  ],
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
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  widget.locationName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              right: 15,
              child: AnnotationButton(
                title: widget.locationName == 'สนามสอบ' 
                    ? "รายละเอียดการสอบ" 
                    : "รายละเอียดการฝึกฝน",
                isUpgrade: widget.locationName != 'สนามสอบ',
                isExam: widget.locationName == 'สนามสอบ',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRewardsBox() {
    Map<String, dynamic> displayRewards = {}; // 🌟 เปลี่ยนเป็น dynamic เพื่อรองรับทั้ง int (stat) และ string (ข้อความสวนสาธารณะ)

    switch (widget.locationName) {
      case 'สวนสนุก':
        displayRewards = {
          'ความคิดสร้างสรรค์': 1,
        };
        break;
      case 'โรงยิม':
        displayRewards = {
          'ความแข็งแรง': 1,
        };
        break;
      case 'หอสมุด':
        displayRewards = {
          'ความฉลาด': 1,
        };
        break;
      case 'สวนสาธารณะ':
        // 🌟 ใส่ข้อความแทนตัวเลขไปเลยสำหรับสวนสาธารณะ
        displayRewards = {'พลังงาน': '70 - 90'}; 
        break;
      case 'สนามสอบ':
        return _buildExamMap();
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
        children: [
          ///EADER (Gradient)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: 16 * scale,
              vertical: 12 * scale,
            ),
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
            child: Text(
              'ค่าสถานะที่ให้เมื่อทำกิจกรรมสำเร็จ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16 * scale,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          /// 🔷 CONTENT
          Padding(
            padding: EdgeInsets.all(16 * scale),
            child: Column(
              children: [
                ...displayRewards.entries.map((entry) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 2 * scale),
                    child: _buildStatusRow(entry.key, entry.value), // 🌟 ไม่ต้องส่ง isIncreased แล้ว
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

  Widget _buildStatusRow(String statusName, dynamic value) {
    String displayValue = "";
    Color valueColor = const Color(0xFF4CAF50); // สีเขียวพื้นฐาน

    // 🌟 1. ดึงค่า Stat ปัจจุบันของตัวละคร
    String currentStat = "0";
    if (statusName == 'ความฉลาด') currentStat = _intStat;
    if (statusName == 'ความแข็งแรง') currentStat = _strStat;
    if (statusName == 'ความคิดสร้างสรรค์') currentStat = _creStat;

    // 🌟 2. จัดการวิธีแสดงผล
    if (widget.locationName == 'สวนสาธารณะ') {
      // ถ้าเป็นสวนสาธารณะ ให้โชว์ string ที่เราส่งมาเลย
      displayValue = "$value"; 
    } else {
      // ถ้าเป็นค่า Stat ทั่วไป ให้เอา "ปัจจุบัน + ที่จะได้" (เช่น 10 +1)
      displayValue = "$currentStat (+$value)";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              statusName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF000000),
              ),
            ),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: valueColor,
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
      padding: EdgeInsets.fromLTRB(20,20,20,20),
      child: Column(
        children: [
          // 🌟 ใช้ CostDisplayWidget แบบเดิม แต่ซ่อนตั๋วเพื่อให้มันโชว์แค่ พลังงาน และพื้นหลังสีขาว
          if (!isPark) ...[
            Center(
              child: CostDisplayWidget(
                energyCostText: '10-20', 
                showTicket: false, // 🌟 ไม่โชว์ตั๋ว เพราะเราย้ายตั๋วไปติดกับปุ่มแล้ว
                showEnergy: true,
              ),
            ),
            SizedBox(height: 8),
          ],

          // ✅ ปุ่ม Start (แก้ตรงนี้)
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 180,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _energyTicketCount == 0
                        ? [Color(0xFF9E9E9E), Color(0xFFBDBDBD)] // 🌟 สีเทาเมื่อตั๋วหมด
                        : [Color(0xFF556AEB), Color(0xFF59ABEC)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: _energyTicketCount == 0
                          ? Colors.grey.withOpacity(0.3)
                          : Color(0xFF4A8FE7).withOpacity(0.4),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _energyTicketCount == 0 ? null : () async {
                  // 🌟 1. แปลงชื่อสถานที่เป็นภาษาอังกฤษเพื่อส่งให้ API
                  String apiLocation = '';
                  switch (widget.locationName) {
                    case 'หอสมุด':
                      apiLocation = 'library';
                      break;
                    case 'โรงยิม':
                      apiLocation = 'gym';
                      break;
                    case 'สวนสนุก':
                      apiLocation = 'amusement_park';
                      break;
                    case 'สวนสาธารณะ':
                      apiLocation = 'park';
                      break;
                    default:
                      apiLocation = 'park';
                  }

                  // 🌟 2. โชว์ Loading สวยๆ ระหว่างรอ API
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => const Center(child: CircularProgressIndicator()),
                  );

                  // 🌟 3. ยิง API
                  final result = await api.ApiService.performLocationAction(apiLocation);

                  // 🌟 4. ปิด Loading
                  if (mounted) Navigator.pop(context);

                  if (result != null) {
                    // 🌟 เล่นวิดีโอคั่นกลาง
                    String videoPath = '';
                    if (widget.locationName == 'หอสมุด') videoPath = 'assets/video/add-int.mp4';
                    else if (widget.locationName == 'โรงยิม') videoPath = 'assets/video/add-str.mp4';
                    else if (widget.locationName == 'สวนสนุก') videoPath = 'assets/video/add-cre.mp4';
                    else if (widget.locationName == 'สวนสาธารณะ') videoPath = 'assets/video/add-energy.mp4';

                    if (videoPath.isNotEmpty && mounted) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VideoTransitionScreen(videoPath: videoPath),
                        ),
                      );
                    }

                    // เก็บค่าเก่าก่อนอัปเดต เพื่อส่งให้ ResultStatScreen ทำอนิเมชัน
                    Map<String, int> oldStatsData = {
                      'ความฉลาด': int.tryParse(_intStat) ?? 0,
                      'ความแข็งแรง': int.tryParse(_strStat) ?? 0,
                      'ความคิดสร้างสรรค์': int.tryParse(_creStat) ?? 0,
                      'พลังงาน': int.tryParse(_stamina) ?? 0, // เพิ่มการเก็บพลังงานเก่า
                    };

                    if (result['success'] == true) {
                      // _fetchUserProfile(); // รีเฟรชข้อมูลตัวละคร (ย้ายไปทำตอนกลับมาจาก popup)

                      if (mounted) {
                        // 🌟 เตรียมของรางวัลที่จะส่งไปโชว์
                        Map<String, int> correctRewards = {};
                        if (widget.locationName == 'หอสมุด') correctRewards = {'ความฉลาด': 1, 'พลังงาน': result['stamina_change'] ?? 0};
                        if (widget.locationName == 'โรงยิม') correctRewards = {'ความแข็งแรง': 1, 'พลังงาน': result['stamina_change'] ?? 0};
                        if (widget.locationName == 'สวนสนุก') correctRewards = {'ความคิดสร้างสรรค์': 1, 'พลังงาน': result['stamina_change'] ?? 0};
                        if (widget.locationName == 'สวนสาธารณะ') {
                           // ถ้าเป็นสวนสาธารณะ ให้ดึงค่าที่ได้ฟื้นฟูจริงจาก API มาโชว์
                           correctRewards = {'พลังงาน': result['stamina_change'] ?? 0};
                        }

                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ResultStatScreen(
                              isSuccess: true, // บอกว่าสำเร็จ
                              statusRewards: correctRewards,
                              oldStats: oldStatsData,
                              user: _user, // 🌟 ส่ง user ไปให้โชว์แอนิเมชัน
                            ),
                          ),
                        );
                        
                        // 🌟 ดึงข้อมูลใหม่หลังจากปิดหน้า ResultStatScreen (เพื่อให้เรียลไทม์)
                        if (mounted) {
                          setState(() {
                            _energyBarKey++; // บังคับให้ EnergyBar รีโหลดใหม่
                          });
                          _fetchUserProfile(); // อัปเดต state ตัวละคร
                          _fetchEnergyTicketCount(); // 🌟 รีเฟรชตั๋วด้วย
                        }
                      }
                    } else {
                      // _fetchUserProfile(); // รีเฟรชให้เห็นหลอดพลังงานลด (ย้ายไปทำด้านล่าง)

                      // 🌟 โชว์หน้าจอฝึกไม่สำเร็จสำหรับทุกสถานที่ (รวมถึงสวนสาธารณะเวลาตั๋วไม่พอ)
                      if (mounted) {
                        
                        // 🌟 1. สร้าง Map เพื่อบอกว่าเราพยายามฝึกอะไรอยู่ (ใส่ค่า +0 เพราะไม่ได้เพิ่ม) หรือ เสียพลังงานไปเท่าไหร่
                        Map<String, int> failedStat = {};
                        if (widget.locationName == 'หอสมุด') failedStat = {'ความฉลาด': 0, 'พลังงาน': result['stamina_change'] ?? 0};
                        if (widget.locationName == 'โรงยิม') failedStat = {'ความแข็งแรง': 0, 'พลังงาน': result['stamina_change'] ?? 0};
                        if (widget.locationName == 'สวนสนุก') failedStat = {'ความคิดสร้างสรรค์': 0, 'พลังงาน': result['stamina_change'] ?? 0};
                        if (widget.locationName == 'สวนสาธารณะ') failedStat = {'พลังงาน': result['stamina_change'] ?? 0};

                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ResultStatScreen(
                              isSuccess: false, // บอกว่าล้มเหลว (จะโชว์รูปตัวละครเศร้าและเลขสีแดง/ดำ)
                              
                              // 🌟 2. ส่ง stat ที่พยายามฝึก ไปโชว์
                              statusRewards: failedStat, 
                              oldStats: oldStatsData,
                              user: _user, // 🌟 ส่ง user ไปให้โชว์แอนิเมชัน
                            ),
                          ),
                        );
                      }
                      
                      // 🌟 ดึงข้อมูลใหม่หลังจากแสดงผลล้มเหลว หรือกลับมาจากหน้า popup
                      if (mounted) {
                        setState(() {
                          _energyBarKey++;
                        });
                        _fetchUserProfile();
                        _fetchEnergyTicketCount(); // 🌟 รีเฟรชตั๋วด้วย
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent, // 🌟 ป้องกันพื้นหลังเทาซ้อน
                  disabledForegroundColor: Colors.white, // 🌟 ตัวหนังสือยังคงเป็นสีขาว
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  'เริ่มทำกิจกรรม',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              ),

              // 🌟 2. เพิ่มป้ายตั๋วติดที่มุมปุ่ม
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
                          'assets/images/item/Ticket_energy_img.png',
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EnergyBar(key: ValueKey(_energyBarKey)),
                    const SizedBox(height: 15),
                    Row(
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
                                _intStat,
                              ),
                              const SizedBox(height: 8),
                              _buildStatRowWithIcon(
                                'assets/images/profile/stat-str-img.png',
                                "ความแข็งแรง",
                                _strStat,
                              ),
                              const SizedBox(height: 8),
                              _buildStatRowWithIcon(
                                'assets/images/profile/stat-cre-img.png',
                                "ความคิดสร้างสรรค์",
                                _creStat,
                              ),
                            ],
                          ),
                        ),
                      ],
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
    return SizedBox(
      key: ValueKey('exam-map-${_examStatuses.values.join('-')}'),
      height: 580,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // อาคารบนซ้าย (วิทย์)
          Positioned(
            top: 150,
            left: 0,
            child: _buildExamBuilding(
              label: 'ตึกสอบวิทยาศาสตร์',
              image: 'assets/images/map/sci_building.png',
              stat: {'ความฉลาด': 1, 'ความแข็งแรง': 0, 'ความคิดสร้างสรรค์': 0},
              width: 140,
              isPassed: _examStatuses['ตึกสอบวิทยาศาสตร์'] == 'completed',
            ),
          ),
          // อาคารบนขวา (คณิต)
          Positioned(
            top: 40,
            right: 0,
            child: _buildExamBuilding(
              label: 'ตึกสอบคณิตศาสตร์',
              image: 'assets/images/map/math_building.png',
              stat: {'ความฉลาด': 2, 'ความแข็งแรง': 0, 'ความคิดสร้างสรรค์': 0},
              width: 130,
              isPassed: _examStatuses['ตึกสอบคณิตศาสตร์'] == 'completed',
            ),
          ),

          // อาคารล่าง (อังกฤษ)
          Positioned(
            top: 360,
            right: 30,
            child: _buildExamBuilding(
              label: 'ตึกสอบอังกฤษ',
              image: 'assets/images/map/eng_building.png',
              stat: {'ความฉลาด': 1, 'ความแข็งแรง': 0, 'ความคิดสร้างสรรค์': 1},
              width: 160,
              isPassed: _examStatuses['ตึกสอบอังกฤษ'] == 'completed',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamBuilding({
    required String label,
    required String image,
    required Map<String, int> stat,
    double width = 120,
    bool isPassed = false,
  }) {
    return _ExamBuildingItem(
      key: ValueKey('$label-$isPassed'), // บังคับ rebuild เมื่อสถานะเปลี่ยน
      imagePath: image,
      label: label,
      width: width,
      isPassed: isPassed,
      onTap: () async {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => ExamScreen(
              user: _user,
              locationName: label,
              locationImage: image,
              statusRewards: stat,
            ),
          ),
        );
        debugPrint('📋 [location_upgrade] returned from ExamScreen with result: $result for $label');
        // ถ้า ExamScreen ส่งค่า true กลับมา แปลว่าสอบผ่านแล้ว → อัปเดตสถานะทันที
        if (mounted) {
          if (result == true) {
            setState(() {
              _examStatuses[label] = 'completed';
            });
            debugPrint('📋 [location_upgrade] forcefully set $label to completed');
          }
          // ดึงข้อมูลล่าสุดจาก DB อีกครั้งเพื่อความถูกต้อง
          await _fetchExamStatuses();
        }
      },
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
              gradient: const LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xFF1A3D62), Color(0xFF195290)],
              ),
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

class _ExamBuildingItem extends StatefulWidget {
  final String imagePath;
  final String label;
  final double width;
  final VoidCallback onTap;
  final bool isPassed;

  const _ExamBuildingItem({
    super.key,
    required this.imagePath,
    required this.label,
    required this.width,
    required this.onTap,
    this.isPassed = false,
  });

  @override
  State<_ExamBuildingItem> createState() => _ExamBuildingItemState();
}

class _ExamBuildingItemState extends State<_ExamBuildingItem> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _isPressed ? 0.90 : (_isHovered ? 1.05 : 1.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Image.asset(
                    widget.imagePath,
                    width: widget.width,
                    fit: BoxFit.contain,
                  ),
                  // ✅ ติ๊กถูกบอกว่าสอบผ่านแล้ว
                  if (widget.isPassed)
                    Positioned(
                      top: -5,
                      right: -5,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: widget.isPassed ? Colors.green.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: widget.isPassed ? Border.all(color: Colors.green, width: 1.5) : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: _isHovered ? 8 : 4,
                      offset: Offset(0, _isHovered ? 4 : 2),
                    )
                  ],
                ),
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: widget.isPassed ? Colors.green.shade800 : Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
