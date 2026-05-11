import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/widgets/club/club_room_components.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/api_service.dart';
import 'package:flutter_application_1/screens/player_profile.dart' hide GradientCircularProgressPainter; // 🌟 เพิ่มบรรทัดนี้ (ปรับ path ให้ตรงถ้าจำเป็น)
import 'package:flutter_application_1/widgets/character_widget.dart'; // เพิ่มบรรทัดนี้
import 'package:flutter_application_1/widgets/bottom_navigation_bar.dart'; // สำหรับ GradientCircularProgressPainter
import 'package:flutter_application_1/api_service.dart' as api; // เพิ่มบรรทัดนี้
import 'package:flutter_application_1/widgets/club/confirm_quit_popup.dart';

// 🌟 คลาสจัดการการโหลดข้อมูลล่วงหน้า
class ClubDetailMemberPreloader {
  static Map<String, dynamic>? cachedData;
  static bool isPreloading = false;

  static void clearCache() {
    cachedData = null;
    isPreloading = false;
  }

  static Map<String, String> getThisWeekTimeRangeUTC() {
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

  static Future<api.User> fetchUserCharacter(String uId) async {
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

  static Future<void> preload({bool forceRefresh = false}) async {
    if (!forceRefresh && (isPreloading || cachedData != null)) return;
    isPreloading = true;

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        isPreloading = false;
        return;
      }

      final myProfile = await supabase
          .from('user_profiles')
          .select('name, detail, club_id, club_role')
          .eq('id', userId)
          .single();

      final clubId = myProfile['club_id'];
      if (clubId == null) {
        isPreloading = false;
        return;
      }

      api.User myUserObj = await fetchUserCharacter(userId);

      final club = await supabase
          .from('clubs')
          .select('name, description, invite_code')
          .eq('id', clubId)
          .single();

      final membersResponse = await supabase
          .from('user_profiles')
          .select('id, name, detail, club_role')
          .eq('club_id', clubId);

      final List<Map<String, dynamic>> membersWithLevel = [];
      for (final member in membersResponse as List<dynamic>) {
        final userObj = await fetchUserCharacter(member['id']);

        membersWithLevel.add({
          ...Map<String, dynamic>.from(member),
          'level': userObj.level,
          'user_obj': userObj,
        });
      }

      membersWithLevel.sort((a, b) {
        final aRole = a['club_role'] ?? '';
        final bRole = b['club_role'] ?? '';
        final aId = a['id'].toString();
        final bId = b['id'].toString();

        if (aRole == 'owner' && bRole != 'owner') return -1;
        if (aRole != 'owner' && bRole == 'owner') return 1;

        if (aId == userId) return -1;
        if (bId == userId) return 1;

        return 0;
      });

      final timeRange = getThisWeekTimeRangeUTC();
      final questsResponse = await supabase
          .from('quests')
          .select('id, name')
          .eq('club_id', clubId)
          .gte('start_date', timeRange['start']!)
          .lt('start_date', timeRange['end']!)
          .order('start_date', ascending: true);

      final questIds = (questsResponse as List<dynamic>).map((q) => q['id']).toList();
      final Map<String, Set<int>> completedQuestsMap = {};
      
      if (questIds.isNotEmpty) {
        final doQuestsResponse = await supabase
            .from('do_quests')
            .select('user_id, quest_id, status')
            .inFilter('quest_id', questIds)
            .inFilter('status', ['completed', 'claimed']);

        for (final dq in doQuestsResponse as List<dynamic>) {
          final uid = dq['user_id'].toString();
          final qid = dq['quest_id'] as int;
          if (!completedQuestsMap.containsKey(uid)) {
            completedQuestsMap[uid] = {};
          }
          completedQuestsMap[uid]!.add(qid);
        }
      }

      final membersWithStats = membersWithLevel.map((m) {
        final uid = m['id'].toString();
        return {
          ...m,
          'completed_quests': completedQuestsMap[uid] ?? <int>{},
        };
      }).toList();

      cachedData = {
        'clubId': clubId,
        'myProfile': myProfile,
        'myUserObj': myUserObj,
        'club': club,
        'membersWithStats': membersWithStats,
        'questsResponse': questsResponse,
      };

    } catch (e) {
      debugPrint("Preload Member Data Error: $e");
    } finally {
      isPreloading = false;
    }
  }
}

class ClubDetailMemberScreen extends StatefulWidget {
  const ClubDetailMemberScreen({super.key});

  @override
  State<ClubDetailMemberScreen> createState() => _ClubDetailMemberScreenState();
}

class _ClubDetailMemberScreenState extends State<ClubDetailMemberScreen> {
  bool _isLeavePressed = false;
  int _selectedIndex = 3;
  bool _isShowingMembers = false;

  // ── State Variables ──────────────────────────────────────────────────────
  bool _isLoading = true;

  // ข้อมูลตัวเอง
  String _myName = '';
  String _myDetail = '';
  String _myRole = '';
  int _myLevel = 1;
  api.User? _myUser; // เก็บข้อมูลผู้ใช้ปัจจุบันสำหรับแสดงตัวละคร

  // ข้อมูลชมรม
  String _clubName = '';
  String _clubDescription = '';
  String _inviteCode = '';

  // ข้อมูลสมาชิก
  List<Map<String, dynamic>> _members = [];

  // ภารกิจสัปดาห์นี้ (เพื่อนับ total_quests)
  List<dynamic> _weeklyQuests = [];

  @override
  void initState() {
    super.initState();
    _fetchAllData();
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

  // ── ดึงข้อมูลทั้งหมด ─────────────────────────────────────────────────────
  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);

    // รอให้ Preload เสร็จ (ถ้ากำลังโหลดอยู่)
    while (ClubDetailMemberPreloader.isPreloading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // ถ้าไม่มีข้อมูล Cache ค่อยโหลดใหม่
    if (ClubDetailMemberPreloader.cachedData == null) {
      await ClubDetailMemberPreloader.preload();
    }

    final data = ClubDetailMemberPreloader.cachedData;

    if (data != null && mounted) {
      setState(() {
        _myName = data['myProfile']['name'] ?? '';
        _myDetail = data['myProfile']['detail'] ?? '';
        _myRole = data['myProfile']['club_role'] ?? 'member';
        _myUser = data['myUserObj'];
        _myLevel = _myUser!.level;
        
        _clubName = data['club']['name'] ?? '';
        _clubDescription = data['club']['description'] ?? '';
        _inviteCode = data['club']['invite_code'] ?? '------';

        _members = data['membersWithStats'];
        _weeklyQuests = data['questsResponse'];
        _isLoading = false;
      });

      // 🌟 โหลดข้อมูลสมาชิกทั้งหมดและตัวละครใหม่แบบเบื้องหลังเพื่อให้เรียลไทม์
      await ClubDetailMemberPreloader.preload(forceRefresh: true);
      
      final newData = ClubDetailMemberPreloader.cachedData;
      if (newData != null && mounted) {
        setState(() {
          _members = newData['membersWithStats'];
          _myUser = newData['myUserObj'];
          _myLevel = _myUser!.level;
          _clubName = newData['club']['name'] ?? '';
          _clubDescription = newData['club']['description'] ?? '';
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLeaveClubDialog() {
    ConfirmQuitPopup.show(
      context,
      onConfirm: () async {
        Navigator.pop(context); // ปิด Popup ยืนยัน
        await _leaveClub();
      },
    );
  }

  Future<void> _leaveClub() async {
    // โชว์ Loading ขณะกำลังรอ API
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    // ยิง API ไปที่ Backend
    final result = await ApiService.leaveClub();

    // ปิด Loading
    if (mounted) Navigator.pop(context);

    if (mounted) {
      if (result != null && result['success'] == true) {
        // สำเร็จ! แจ้งเตือนและเตะกลับไปหน้าเข้าชมรม (ล้าง stack หน้าต่างเก่าๆ ทิ้งด้วย)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('คุณได้ลาออกจากชมรมแล้ว'),
            backgroundColor: Color(0xFF2374B5),
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/club', (route) => route.isFirst);
      } else {
        // ล้มเหลว
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result?['error'] ?? 'เกิดข้อผิดพลาด ไม่สามารถลาออกได้'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final topBarHeight = 75.0 + topPadding;
    const headerHeight = 80.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const ClubBackground(),

          // ── Top Bar & Header ───────────────────────
          Column(
            children: [
              ClubTopBar(topPadding: topPadding),
              ClubBlueHeader(
                title: 'ข้อมูลชมรม',
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
                    '$_myLevel',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
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

  Widget _buildLeaderInfoSection() {
    final bool isLeader = _myRole == 'owner';
    final String roleLabel = isLeader ? 'หัวหน้า' : 'สมาชิก';
    final Color roleBgColor =
        isLeader ? const Color(0xFFFFE0B2) : const Color(0xFFCBE7F5);

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
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: roleBgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: Text(
                  roleLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
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
              style: TextStyle(
                fontSize: 14,
                color: _myDetail.isEmpty ? Colors.grey : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isLeavePressed = true),
              onTapCancel: () => setState(() => _isLeavePressed = false),
              onTap: () {
                setState(() => _isLeavePressed = false);
                _showLeaveClubDialog();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _isLeavePressed
                      ? const Color(0xFFC72E2E)
                      : const Color(0xFFEA4444),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'ลาออก',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
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
                color: _isShowingMembers
                    ? const Color(0xFF6EB9DB)
                    : const Color(0xFF114575),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Text(
                "เกี่ยวกับชมรม",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
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
                color: _isShowingMembers
                    ? const Color(0xFF114575)
                    : const Color(0xFF6EB9DB),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                "สมาชิก (${_members.length}/50)",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
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
                    alignment: Alignment.center,
                    child: Text(
                      _clubName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
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
                          onTap: () async {
                            await Clipboard.setData(ClipboardData(text: _inviteCode));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('คัดลอกรหัสเชิญแล้ว!'),
                                  backgroundColor: Color(0xFF2374B5),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
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
              children: const [
                Text(
                  'รายละเอียด',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF002A50),
                  ),
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
                      _clubDescription.isEmpty
                          ? 'ไม่มีรายละเอียดชมรม'
                          : _clubDescription,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
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
      return const Center(
        child: Text(
          'ไม่พบข้อมูลสมาชิก',
          style: TextStyle(color: Colors.grey),
        ),
      );
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
    final String memberId = member['id']?.toString() ?? '';
    final String currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final bool isMe = memberId.isNotEmpty && memberId == currentUserId;

    // 🌟 1. ใช้ GestureDetector ครอบเพื่อดักการกด
    return GestureDetector(
      onTap: () {
        final targetId = member['id']; // ดึง UUID ของคนที่เรากด
        if (targetId != null) {
          // 🌟 2. สั่งเปลี่ยนหน้า พร้อมส่ง playerId ไปให้
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  PlayerProfileScreen(playerId: targetId.toString()),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFE5F3FF) : const Color(0xFFFFF8F8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF9DD0E7), width: 2),
          // 🌟 เพิ่มเงาเล็กน้อยเวลากด หรือให้ดูเป็นปุ่มได้ (ถ้าต้องการ)
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Upper Row
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
                                    border: Border.all(
                                      color: Colors.transparent,
                                      width: 2,
                                    ),
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
                                        height: 1,
                                      ),
                                    ),
                                    const Text(
                                      "Lv.",
                                      style: TextStyle(
                                        fontSize: 7,
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
                            border:
                                Border.all(color: Colors.black, width: 1.5),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          detail.isEmpty ? 'ไม่มีคำแนะนำตัว' : detail,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                detail.isEmpty ? Colors.grey : Colors.black87,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}