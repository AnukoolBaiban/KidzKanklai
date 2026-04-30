import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/club/club_room_components.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/api_service.dart';
import 'package:flutter_application_1/screens/player_profile.dart'; // 🌟 เพิ่มบรรทัดนี้ (ปรับ path ให้ตรงถ้าจำเป็น)

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

  // ข้อมูลชมรม
  String _clubName = '';
  String _clubDescription = '';

  // ข้อมูลสมาชิก
  List<Map<String, dynamic>> _members = [];

  // ภารกิจสัปดาห์นี้ (เพื่อนับ total_quests)
  List<dynamic> _weeklyQuests = [];

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  // 🌟 ฟังก์ชันคำนวณเวลาสัปดาห์นี้ (จันทร์ 00:00 - จันทร์หน้า 00:00 UTC+7)
  Map<String, String> _getThisWeekTimeRangeUTC() {
    DateTime now = DateTime.now().toUtc();
    DateTime nowUtc7 = now.add(const Duration(hours: 7));
    
    int daysSinceMonday = nowUtc7.weekday - DateTime.monday;
    
    // จันทร์นี้ 00:00:00 (อิงตามเวลาไทย)
    DateTime startOfWeekUtc7 = DateTime(nowUtc7.year, nowUtc7.month, nowUtc7.day)
        .subtract(Duration(days: daysSinceMonday));
        
    // จันทร์หน้า 00:00:00 (อิงตามเวลาไทย)
    DateTime endOfWeekUtc7 = startOfWeekUtc7.add(const Duration(days: 7));

    // 🌟 แก้ไข: แปลงเป็น String รูปแบบเวลาท้องถิ่นเป๊ะๆ (ไม่มีอักษร Z และไม่หักลบ 7 ชม.)
    // เพื่อให้ Database เปรียบเทียบตัวเลข วัน-เวลา ตรงๆ ป้องกันบั๊ก Timezone
    String formatNaiveLocal(DateTime dt) {
      String y = dt.year.toString().padLeft(4, '0');
      String m = dt.month.toString().padLeft(2, '0');
      String d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-${d}T00:00:00'; 
    }

    return {
      'start': formatNaiveLocal(startOfWeekUtc7), // ผลลัพธ์: '2024-05-27T00:00:00'
      'end': formatNaiveLocal(endOfWeekUtc7),     // ผลลัพธ์: '2024-06-03T00:00:00'
    };
  }

  // ── ดึงข้อมูลทั้งหมด ─────────────────────────────────────────────────────
  Future<void> _fetchAllData() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      // 1. ดึงข้อมูลโปรไฟล์ตัวเอง
      final myProfile = await supabase
          .from('user_profiles')
          .select('name, detail, club_id, club_role')
          .eq('id', userId)
          .single();

      final clubId = myProfile['club_id'];
      if (clubId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 2. ดึง level จาก characters
      final myCharacter = await supabase
          .from('characters')
          .select('level')
          .eq('user_id', userId)
          .maybeSingle();

      // 3. ดึงข้อมูลชมรม
      final club = await supabase
          .from('clubs')
          .select('name, description')
          .eq('id', clubId)
          .single();

      // 4. ดึงสมาชิกทั้งหมดในชมรม
      final membersResponse = await supabase
          .from('user_profiles')
          .select('id, name, detail, club_role')
          .eq('club_id', clubId);

      // 5. ดึง level ของแต่ละสมาชิก
      final List<Map<String, dynamic>> membersWithLevel = [];
      for (final member in membersResponse as List<dynamic>) {
        final charData = await supabase
            .from('characters')
            .select('level')
            .eq('user_id', member['id'])
            .maybeSingle();
        membersWithLevel.add({
          ...Map<String, dynamic>.from(member),
          'level': charData?['level'] ?? 1,
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

      // 6. ดึงภารกิจสัปดาห์นี้ (🌟 สั่ง order by start_date เพื่อให้เรียงลำดับ 1, 2, 3 เป๊ะๆ)
      final timeRange = _getThisWeekTimeRangeUTC();
      final questsResponse = await supabase
          .from('quests')
          .select('id, name')
          .eq('club_id', clubId)
          .gte('start_date', timeRange['start']!)
          .lt('start_date', timeRange['end']!)
          .order('start_date', ascending: true);

      // 7. ดึง do_quests สถานะ 'completed'
      final questIds = (questsResponse as List<dynamic>)
          .map((q) => q['id'])
          .toList();

      // 🌟 เปลี่ยนมาเก็บเป็น Set (กลุ่มของ ID) แทนการนับจำนวน
      final Map<String, Set<int>> completedQuestsMap = {};
      if (questIds.isNotEmpty) {
        final doQuestsResponse = await supabase
            .from('do_quests')
            .select('user_id, quest_id, status')
            .inFilter('quest_id', questIds)
            .eq('status', 'completed');

        for (final dq in doQuestsResponse as List<dynamic>) {
          final uid = dq['user_id'].toString();
          final qid = dq['quest_id'] as int;
          if (!completedQuestsMap.containsKey(uid)) {
            completedQuestsMap[uid] = {};
          }
          completedQuestsMap[uid]!.add(qid); // เก็บ ID ของเควสที่ทำเสร็จ
        }
      }

      // ใส่ข้อมูลการทำเควสเข้าไปในสมาชิก
      final membersWithStats = membersWithLevel.map((m) {
        final uid = m['id'].toString();
        return {
          ...m,
          'completed_quests': completedQuestsMap[uid] ?? <int>{}, // แนบ Set ลงไป
        };
      }).toList();

      if (mounted) {
        setState(() {
          _myName = myProfile['name'] ?? '';
          _myDetail = myProfile['detail'] ?? '';
          _myRole = myProfile['club_role'] ?? 'member';
          _myLevel = myCharacter?['level'] ?? 1;
          _clubName = club['name'] ?? '';
          _clubDescription = club['description'] ?? '';
          _members = membersWithStats;
          _weeklyQuests = questsResponse;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching club detail data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLeaveClubDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลาออกจากชมรม'),
        content: const Text('คุณต้องการลาออกจากชมรมนี้ใช่ไหม?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _leaveClub();
            },
            child: const Text('ลาออก', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
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
                title: _clubName.isEmpty ? 'ชมรม' : _clubName,
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
                      if (!_isShowingMembers)
                        Expanded(child: _buildDetailsBox())
                      else
                        Expanded(child: _buildMembersList()),
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
              Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [Color(0xFF88FF40), Color(0xFF66E0FF)],
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                child: const CircleAvatar(
                  radius: 50,
                  backgroundImage: AssetImage(
                    'assets/images/profile/profile_img.png',
                  ),
                  backgroundColor: Colors.transparent,
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
    final String roleLabel = isLeader ? 'เจ้าของชมรม' : 'สมาชิก';
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
              child: const Text(
                "สมาชิก",
                style: TextStyle(
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

  Widget _buildDetailsBox() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          child: Text(
            _clubDescription.isEmpty
                ? 'ไม่มีรายละเอียดชมรม'
                : _clubDescription,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
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

    // ดึงข้อมูลภารกิจที่ทำสำเร็จของสมาชิกคนนี้
    final Set<int> completedQuests = member['completed_quests'] ?? <int>{};
    final int totalQuests = _weeklyQuests.length;

    // 🌟 1. ใช้ GestureDetector ครอบเพื่อดักการกด
    return GestureDetector(
      onTap: () {
        final targetId = member['id']; // ดึง UUID ของคนที่เรากด
        if (targetId != null) {
          // 🌟 2. สั่งเปลี่ยนหน้า พร้อมส่ง playerId ไปให้
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerProfileScreen(playerId: targetId.toString()),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8F8),
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
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF9DD0E7),
                                  width: 2,
                                ),
                              ),
                              child: const CircleAvatar(
                                radius: 36,
                                backgroundImage: AssetImage(
                                  'assets/images/profile/profile_img.png',
                                ),
                                backgroundColor: Colors.transparent,
                              ),
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
                            isLeader ? "เจ้าของชมรม" : "สมาชิก",
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
          // Lower Row: แสดงวงกลมภารกิจ (ทุกคน)
          Container(height: 2, color: const Color(0xFF9DD0E7)),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 105,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isLeader
                        ? const Color(0xFFFFE0B2)
                        : const Color(0xFFCBE7F5),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    "ภารกิจที่เสร็จแล้ว",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(width: 2, color: const Color(0xFF9DD0E7)),
                Expanded(
                  child: totalQuests == 0
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'ไม่มีภารกิจสัปดาห์นี้',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      : Row(
                          children: List.generate(totalQuests, (qi) {
                            // 🌟 แก้ไข: เทียบ ID ของเควสในตำแหน่งนั้น ว่าอยู่ใน Set ที่ทำเสร็จหรือไม่
                            final int currentQuestId = _weeklyQuests[qi]['id'];
                            final bool done = completedQuests.contains(currentQuestId);
                            final bool isLastCell = qi == totalQuests - 1;
                            
                            return Expanded(
                              child: isLastCell
                                  ? _buildQuestCircle(qi + 1, done)
                                  : Row(
                                      children: [
                                        Expanded(
                                          child: _buildQuestCircle(
                                              qi + 1, done),
                                        ),
                                        Container(
                                          width: 2,
                                          color: const Color(0xFF9DD0E7),
                                        ),
                                      ],
                                    ),
                            );
                          }),
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
          child: Text(
            '$number',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}