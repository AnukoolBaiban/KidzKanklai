import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/widgets/club/club_delete_popup.dart';
import 'package:flutter_application_1/widgets/club/club_room_components.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/api_service.dart';
import 'package:flutter_application_1/screens/player_profile.dart' hide GradientCircularProgressPainter; // 🌟 ดูโปรไฟล์เพื่อน
import 'package:flutter_application_1/widgets/character_widget.dart'; // เพิ่มบรรทัดนี้
import 'package:flutter_application_1/widgets/bottom_navigation_bar.dart'; // สำหรับ GradientCircularProgressPainter
import 'package:flutter_application_1/api_service.dart' as api; // เพิ่มบรรทัดนี้

class ClubDetailHeadScreen extends StatefulWidget {
  const ClubDetailHeadScreen({super.key});

  @override
  State<ClubDetailHeadScreen> createState() => _ClubDetailHeadScreenState();
}

class _ClubDetailHeadScreenState extends State<ClubDetailHeadScreen> {
  bool _isDeletePressed = false;
  int _selectedIndex = 3;
  bool _isShowingMembers = false;

  bool _isEditingName = false;
  bool _isEditingDetail = false;

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _detailFocusNode = FocusNode();

  final TextEditingController _clubNameController = TextEditingController();
  final TextEditingController _clubDetailController = TextEditingController();

  // ── State Variables ──────────────────────────────────────────────────────
  bool _isLoading = true;

  // ข้อมูลตัวเอง (หัวหน้า)
  String _myName = '';
  String _myDetail = '';
  int _myLevel = 1;
  api.User? _myUser; // เก็บข้อมูลผู้ใช้ปัจจุบันสำหรับแสดงตัวละคร

  // ข้อมูลชมรม
  int _clubId = 0;
  String _inviteCode = '';
  String _clubName = ''; // เก็บค่าเดิมไว้เทียบบันทึก

  // ข้อมูลสมาชิก
  List<Map<String, dynamic>> _members = [];
  List<dynamic> _weeklyQuests = [];

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _detailFocusNode.dispose();
    _clubNameController.dispose();
    _clubDetailController.dispose();
    super.dispose();
  }

  // 🌟 ฟังก์ชันคำนวณเวลาสัปดาห์นี้
  Map<String, String> _getThisWeekTimeRangeUTC() {
    DateTime now = DateTime.now().toUtc();
    DateTime nowUtc7 = now.add(const Duration(hours: 7));
    int daysSinceMonday = nowUtc7.weekday - DateTime.monday;
    DateTime startOfWeekUtc7 = DateTime(nowUtc7.year, nowUtc7.month, nowUtc7.day)
        .subtract(Duration(days: daysSinceMonday));
    DateTime endOfWeekUtc7 = startOfWeekUtc7.add(const Duration(days: 7));

    String formatNaiveLocal(DateTime dt) {
      String y = dt.year.toString().padLeft(4, '0');
      String m = dt.month.toString().padLeft(2, '0');
      String d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-${d}T00:00:00'; 
    }

    return {
      'start': formatNaiveLocal(startOfWeekUtc7),
      'end': formatNaiveLocal(endOfWeekUtc7),
    };
  }

  // 🌟 ฟังก์ชันคำนวณ EXP เปอร์เซ็นต์
  double _getExpPercent(int dbLevel, int totalExp) {
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

    return (requiredExpForNextLevel > 0)
        ? (remainingExp / requiredExpForNextLevel).clamp(0.0, 1.0)
        : 0.0;
  }

  // 🌟 ฟังก์ชันช่วยดึงข้อมูลตัวละครและของที่สวมใส่
  Future<api.User> _fetchUserCharacter(String uId) async {
    final supabase = Supabase.instance.client;
    final charData = await supabase
        .from('characters')
        .select('id, level, experience, body_type, skin_color, emotion')
        .eq('user_id', uId)
        .maybeSingle();

    String eqSkin = '';
    String eqFace = '';
    String eqHair = '';
    String eqOutfit = '';
    int level = 1;
    int exp = 0;
    String bodyType = 'KID';

    if (charData != null) {
      eqSkin = charData['skin_color']?.toString() ?? '';
      eqFace = charData['emotion']?.toString() ?? '';
      level = charData['level'] ?? 1;
      exp = charData['experience'] ?? 0;
      bodyType = charData['body_type']?.toString() ?? 'KID';

      final charId = charData['id'];
      if (charId != null) {
        try {
          final wearResponse = await supabase
              .from('wear')
              .select('type, items(name, image)')
              .eq('character_id', charId);

          for (var w in wearResponse as List<dynamic>) {
            final type = w['type']?.toString().toLowerCase() ?? '';
            final itemData = w['items'];
            if (itemData != null) {
              final itemVal = itemData['name']?.toString() ?? itemData['image']?.toString() ?? '';
              if (type == 'hair') eqHair = itemVal;
              if (type == 'face' || type == 'emotion') eqFace = itemVal;
              if (type == 'skin') eqSkin = itemVal;
              if (type == 'cloth' || type == 'outfit' || type == 'clothes') eqOutfit = itemVal;
            }
          }
        } catch (e) {
          debugPrint('Error fetching wear for $charId: $e');
        }
      }
    }

    return api.User(
      id: 0, username: '', email: '', exp: exp, coins: 0, tickets: 0, vouchers: 0, bio: '', soundBGM: 0, soundSFX: 0, statIntellect: 0, statStrength: 0, statCreativity: 0,
      level: level,
      equippedSkin: eqSkin,
      equippedHair: eqHair,
      equippedFace: eqFace,
      equippedOutfit: eqOutfit,
      bodyType: bodyType,
    );
  }

  // ── ดึงข้อมูลทั้งหมด ─────────────────────────────────────────────────────
  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 1. ตรวจสอบว่าตัวเองอยู่ชมรมไหนและได้ข้อมูลโปรไฟล์ตัวเองด้วย
      final myProfile = await supabase
          .from('user_profiles')
          .select('name, detail, club_id')
          .eq('id', userId)
          .single();

      final clubId = myProfile['club_id'];
      if (clubId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 2. ข้อมูลตัวละครตัวเอง
      api.User myUserObj = await _fetchUserCharacter(userId);

      // 3. ข้อมูลชมรม
      final club = await supabase
          .from('clubs')
          .select('name, description, invite_code')
          .eq('id', clubId)
          .single();

      // 4. สมาชิกทั้งหมด
      final membersResponse = await supabase
          .from('user_profiles')
          .select('id, name, detail, club_role')
          .eq('club_id', clubId);

      final List<Map<String, dynamic>> membersWithLevel = [];
      for (final member in membersResponse as List<dynamic>) {
        final userObj = await _fetchUserCharacter(member['id']);

        membersWithLevel.add({
          ...Map<String, dynamic>.from(member),
          'level': userObj.level,
          'user_obj': userObj,
        });
      }

      // เรียงหัวหน้าขึ้นก่อน
      membersWithLevel.sort((a, b) {
        final aRole = a['club_role'] ?? '';
        final bRole = b['club_role'] ?? '';
        if (aRole == 'owner' && bRole != 'owner') return -1;
        if (aRole != 'owner' && bRole == 'owner') return 1;
        return 0;
      });

      // 5. ภารกิจและประวัติ
      final timeRange = _getThisWeekTimeRangeUTC();
      final questsResponse = await supabase
          .from('quests')
          .select('id, name')
          .eq('club_id', clubId)
          .gte('start_date', timeRange['start']!)
          .lt('start_date', timeRange['end']!)
          .order('start_date', ascending: true);

      final questIds = (questsResponse as List<dynamic>).map((q) => q['id']).toList();
      final Map<String, Set<int>> completedQuestsMap = {};
      
      debugPrint('🔍 [HEAD] questIds this week: $questIds');
      
      if (questIds.isNotEmpty) {
        final doQuestsResponse = await supabase
            .from('do_quests')
            .select('user_id, quest_id, status')
            .inFilter('quest_id', questIds);

        debugPrint('🔍 [HEAD] all do_quests rows: $doQuestsResponse');

        for (final dq in doQuestsResponse as List<dynamic>) {
          final uid = dq['user_id'].toString();
          final qid = dq['quest_id'] as int;
          final status = dq['status'].toString();
          if (status != 'not_started' && status != 'in_progress' && status != 'assigned') {
            if (!completedQuestsMap.containsKey(uid)) {
              completedQuestsMap[uid] = {};
            }
            completedQuestsMap[uid]!.add(qid);
          }
        }
        debugPrint('🔍 [HEAD] completedQuestsMap: $completedQuestsMap');
      }

      final membersWithStats = membersWithLevel.map((m) {
        final uid = m['id'].toString();
        return {
          ...m,
          'completed_quests': completedQuestsMap[uid] ?? <int>{},
        };
      }).toList();

      if (mounted) {
        setState(() {
          _clubId = clubId;
          _myName = myProfile['name'] ?? '';
          _myDetail = myProfile['detail'] ?? '';
          _myLevel = myUserObj.level;
          _myUser = myUserObj;
          
          _clubName = club['name'] ?? '';
          _inviteCode = club['invite_code'] ?? '------';
          _clubNameController.text = _clubName;
          _clubDetailController.text = club['description'] ?? '';

          _members = membersWithStats;
          _weeklyQuests = questsResponse;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching head data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🌟 บันทึกการแก้ไขชื่อ/รายละเอียด ลง Supabase ตรงๆ (ง่ายกว่ารอ API)
  Future<bool> _updateClubInfo(String column, String value) async {
    try {
      await Supabase.instance.client
          .from('clubs')
          .update({column: value})
          .eq('id', _clubId);
      
      return true;
    } catch (e) {
      debugPrint("Update Club error: $e");
      return false;
    }
  }

  void _showEditDialog(String title, String currentValue, String columnToUpdate) {
    final TextEditingController controller = TextEditingController(text: currentValue);
    final int maxLength = columnToUpdate == 'name' ? 20 : 300;

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
                  inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
                  maxLines: columnToUpdate == 'description' ? 3 : 1,
                  style: const TextStyle(fontSize: 16),
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                    final bool isMax = currentLength == maxLength;
                    return Text(
                      '$currentLength/$maxLength',
                      style: TextStyle(
                        color: isMax ? Colors.red : Colors.black54,
                        fontSize: 12,
                      ),
                    );
                  },
                  decoration: InputDecoration(
                    hintText: "กรอก$titleใหม่",
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
                            // ชื่อห้ามว่าง
                            if (columnToUpdate == 'name' && newValue.isEmpty) return;

                            // Show Loading Dialog
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (ctx) => const Center(child: CircularProgressIndicator()),
                            );

                            final success = await _updateClubInfo(columnToUpdate, newValue);

                            if (mounted) {
                              Navigator.pop(context); // Close loading dialog
                              if (success) {
                                setState(() {
                                  if (columnToUpdate == 'name') {
                                    _clubName = newValue;
                                    _clubNameController.text = newValue;
                                  } else if (columnToUpdate == 'description') {
                                    _clubDetailController.text = newValue;
                                  }
                                });
                                Navigator.pop(context); // Close edit dialog
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('บันทึกข้อมูลเรียบร้อย')),
                                );
                              } else {
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

  // 🌟 ฟังก์ชันเตะสมาชิก
  Future<void> _kickMember(String targetId, String name) async {
    // 1. Popup ยืนยัน
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ไล่สมาชิกออก'),
        content: Text('คุณต้องการไล่ "$name" ออกจากชมรมใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ไล่ออก', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    // 2. เรียก API
    final result = await ApiService.kickClubMember(targetId);

    if (mounted) Navigator.pop(context); // ปิด Loading

    if (mounted) {
      if (result != null && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ไล่สมาชิกออกแล้ว'), backgroundColor: Colors.green));
        _fetchAllData(); // โหลดข้อมูลใหม่
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result?['error'] ?? 'ไล่ออกล้มเหลว'), backgroundColor: Colors.red));
      }
    }
  }

  void _showDeleteClubDialog() {
    ClubDeletePopup.show(
      context,
      onConfirm: () async {
        Navigator.pop(context);
        showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
        
        final result = await ApiService.deleteClub(); // เรียก API ลบชมรม
        
        if (mounted) Navigator.pop(context);

        if (result != null && result['success'] == true) {
          if(mounted) Navigator.pushNamedAndRemoveUntil(context, '/club', (route) => route.isFirst);
        } else {
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result?['error'] ?? 'ลบชมรมล้มเหลว'), backgroundColor: Colors.red));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final topBarHeight = 75.0 + topPadding;
    const headerHeight = 80.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          const ClubBackground(),

          // ── Top Bar & Header ───────────────────────
          Column(
            children: [
              ClubTopBar(topPadding: topPadding),
              ClubBlueHeader(
                title: _clubName, // 🌟 ใช้ชื่อชมรมจริง
                onBackPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          Padding(
            padding: EdgeInsets.only(
              top: topBarHeight + headerHeight + 16,
              left: size.width * 0.05,
              right: size.width * 0.05,
              bottom: 110,
            ),
            child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLeaderCard(),
                const SizedBox(height: 16),
                _buildTabs(),
                const SizedBox(height: 12),
                if (!_isShowingMembers) ...[
                  _buildInviteCodeSection(),
                  const SizedBox(height: 12),
                  Expanded(child: _buildDetailsBox()),
                ] else ...[
                  Expanded(child: _buildMembersList()),
                ],
              ],
            ),
          ),

          ClubBottomNavBar(
            selectedIndex: _selectedIndex,
            onItemTapped: (index) => setState(() => _selectedIndex = index),
          ),
        ],
      ),
    );
  }

  // --- Components ที่เหลือเหมือนเดิม แต่เปลี่ยนไปใช้ตัวแปรจริง ---

  Widget _buildLeaderCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF9DD0E7), width: 1.5),
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            right: 0,
            child: Image.asset(
              'assets/images/design/design2.png',
              height: 130,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          ),
          Positioned(
            top: 3,
            right: 3,
            child: Image.asset(
              'assets/images/design/design1.png',
              width: 40,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAvatarSection(),
                const SizedBox(width: 16),
                _buildLeaderInfoSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(110, 110),
                painter: GradientCircularProgressPainter(
                  progress: _myUser != null ? _getExpPercent(_myUser!.level, _myUser!.exp) : 0.0,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF88FF40), Color(0xFF66E0FF)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  strokeWidth: 6,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: IgnorePointer(
                    child: Transform.translate(
                      offset: const Offset(2, 20),
                      child: Transform.scale(
                        scale: 1.6,
                        child: RepaintBoundary(
                          child: CharacterWidget(
                            user: _myUser,
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
            bottom: -5,
            right: -5,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Colors.white, Color(0xFFE0E0E0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "$_myLevel",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black, height: 1),
                  ),
                  const Text("Lv.", style: TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold, height: 1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderInfoSection() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  _myName.isEmpty ? '...' : _myName,
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB775),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: const Text("หัวหน้า", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 35,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF9DD0E7), width: 1.5),
            ),
            child: Text(
              _myDetail.isEmpty ? 'ยังไม่มีคำแนะนำตัว' : _myDetail,
              style: TextStyle(fontSize: 14, color: _myDetail.isEmpty ? Colors.grey : Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isDeletePressed = true),
              onTapCancel: () => setState(() => _isDeletePressed = false),
              onTap: () {
                setState(() => _isDeletePressed = false);
                _showDeleteClubDialog();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                decoration: BoxDecoration(
                  color: _isDeletePressed ? const Color(0xFFC72E2E) : const Color(0xFFEA4444),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('ลบชมรม', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _isShowingMembers = false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _isShowingMembers ? const Color(0xFF6EB9DB) : const Color(0xFF114575),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Text("เกี่ยวกับชมรม", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _isShowingMembers = true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _isShowingMembers ? const Color(0xFF114575) : const Color(0xFF6EB9DB),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Text("สมาชิก", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInviteCodeSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF9DD0E7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: Row(
              children: [
                const Expanded(flex: 2, child: Text("ชื่อชมรม", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF00385D)))),
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 35,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 40),
                        Expanded(
                          child: Center(
                            child: Text(
                              _clubName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showEditDialog("ชื่อชมรม", _clubName, "name"),
                          child: Container(
                            width: 40,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 6),
                            child: Image.asset('assets/images/icon/iconEdit.png', width: 18, height: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
            child: Row(
              children: [
                const Expanded(flex: 2, child: Text("รหัสเชิญเข้าชมรม", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF00385D)))),
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 35,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))],
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(_inviteCode, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87))),
                        GestureDetector(
                          onTap: () {
                            debugPrint("Copy code tapped"); // 🌟 นำไปผูกกับ Clipboard.setData ได้
                          },
                          child: Container(
                            width: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4A7699),
                              borderRadius: BorderRadius.only(topRight: Radius.circular(18), bottomRight: Radius.circular(18)),
                            ),
                            child: Center(child: Image.asset('assets/images/icon/iconCopy.png', width: 20, height: 20)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9DD0E7), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'รายละเอียด',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF002A50),
                  ),
                ),
                GestureDetector(
                  onTap: () => _showEditDialog("รายละเอียดชมรม", _clubDetailController.text, "description"),
                  child: Image.asset('assets/images/icon/iconEdit.png', width: 20, height: 20),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      _clubDetailController.text.isEmpty ? 'เพิ่มรายละเอียดชมรมที่นี่...' : _clubDetailController.text,
                      style: TextStyle(
                        fontSize: 14,
                        color: _clubDetailController.text.isEmpty ? Colors.black54 : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList() {
    if (_members.isEmpty) {
      return const Center(child: Text('ไม่พบข้อมูลสมาชิก', style: TextStyle(color: Colors.grey)));
    }
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 0),
        itemCount: _members.length,
        itemBuilder: (context, index) {
          return _buildMemberCard(_members[index]);
        },
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final bool isLeader = (member['club_role'] ?? '') == 'owner';
    final String name = member['name'] ?? 'ไม่มีชื่อ';
    final String detail = member['detail'] ?? '';
    final int level = member['level'] ?? 1;
    final String memberId = member['id'];

    final Set<int> completedQuests = member['completed_quests'] ?? <int>{};
    final int totalQuests = _weeklyQuests.length;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                PlayerProfileScreen(playerId: memberId),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8F8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF9DD0E7), width: 2),
        ),
        child: Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 105,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  CustomPaint(
                                    size: const Size(80, 80),
                                    painter: GradientCircularProgressPainter(
                                      progress: member['user_obj'] != null ? _getExpPercent(member['user_obj'].level, member['user_obj'].exp) : 0.0,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF88FF40), Color(0xFF66E0FF)],
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                      ),
                                      strokeWidth: 4,
                                    ),
                                  ),
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      border: Border.all(color: Colors.transparent, width: 2),
                                    ),
                                    clipBehavior: Clip.hardEdge,
                                    child: IgnorePointer(
                                      child: Transform.translate(
                                        offset: const Offset(2, 15),
                                        child: Transform.scale(
                                          scale: 1.6,
                                          child: RepaintBoundary(
                                            child: CharacterWidget(
                                              user: member['user_obj'],
                                              isInteractive: false,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Positioned(
                                bottom: -4,
                                right: -4,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(
                                      color: const Color(0xFF9DD0E7),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '$level',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.black,
                                          height: 1.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: isLeader
                                  ? const Color(0xFFFFB775)
                                  : const Color(0xFFCBE7F5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black, width: 1.5),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              isLeader ? "หัวหน้า" : "สมาชิก",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(width: 2, color: const Color(0xFF9DD0E7)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                              ),
                              if (!isLeader) const SizedBox(width: 8),
                              if (!isLeader) // 🌟 ซ่อนปุ่มเตะถ้าเป็นหัวหน้า
                                ElevatedButton(
                                  onPressed: () => _kickMember(memberId, name),
                                  style: ButtonStyle(
                                    backgroundColor: MaterialStateProperty.resolveWith<Color>(
                                      (states) => states.contains(MaterialState.pressed) ? const Color(0xFFC72E2E) : const Color(0xFFEA4444),
                                    ),
                                    foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                                    padding: MaterialStateProperty.all<EdgeInsetsGeometry>(const EdgeInsets.all(12)),
                                    minimumSize: MaterialStateProperty.all<Size>(Size.zero),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: MaterialStateProperty.all<OutlinedBorder>(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                  ),
                                  child: const Text("ไล่ออก", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(detail.isEmpty ? 'ไม่มีคำแนะนำตัว' : detail, style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!isLeader) ...[          
              Container(height: 2, color: const Color(0xFF9DD0E7)),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 105,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFCBE7F5),
                        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8)),
                      ),
                      alignment: Alignment.center,
                      child: const Text("ภารกิจที่เสร็จแล้ว", style: TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold)),
                    ),
                    Container(width: 2, color: const Color(0xFF9DD0E7)),
                    Expanded(
                      child: totalQuests == 0
                          ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('ไม่มีภารกิจสัปดาห์นี้', style: TextStyle(fontSize: 12, color: Colors.grey))))
                          : Row(
                              children: List.generate(totalQuests, (qi) {
                                final int currentQuestId = _weeklyQuests[qi]['id'];
                                final bool done = completedQuests.contains(currentQuestId);
                                final bool isLastCell = qi == totalQuests - 1;
                                return Expanded(
                                  child: isLastCell
                                      ? _buildQuestCircle(qi + 1, done)
                                      : Row(children: [Expanded(child: _buildQuestCircle(qi + 1, done)), Container(width: 2, color: const Color(0xFF9DD0E7))]),
                                );
                              }),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuestCircle(int number, bool done) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: done ? const Color(0xFF8CD853) : const Color(0xFFE0E0E0),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 1.5),
        ),
        child: Center(
          child: Text('$number', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black, height: 1.1), textAlign: TextAlign.center),
        ),
      ),
    );
  }
}