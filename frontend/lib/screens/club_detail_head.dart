import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/club/club_delete_popup.dart';
import 'package:flutter_application_1/widgets/club/club_room_components.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/api_service.dart';
import 'package:flutter_application_1/screens/player_profile.dart'; // 🌟 ดูโปรไฟล์เพื่อน

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

  // ── ดึงข้อมูลทั้งหมด ─────────────────────────────────────────────────────
  Future<void> _fetchAllData() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      // 1. ข้อมูลตัวเอง
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

      // 2. Level ตัวเอง
      final myCharacter = await supabase
          .from('characters')
          .select('level')
          .eq('user_id', userId)
          .maybeSingle();

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

      if (mounted) {
        setState(() {
          _clubId = clubId;
          _myName = myProfile['name'] ?? '';
          _myDetail = myProfile['detail'] ?? '';
          _myLevel = myCharacter?['level'] ?? 1;
          
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
  Future<void> _updateClubInfo(String column, String value) async {
    try {
      await Supabase.instance.client
          .from('clubs')
          .update({column: value})
          .eq('id', _clubId);
      
      if (column == 'name') {
        setState(() => _clubName = value); // อัปเดต Topbar
      }
    } catch (e) {
      debugPrint("Update Club error: $e");
    }
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
      body: Stack(
        children: [
          const ClubBackground(),

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

          ClubTopBar(topPadding: topPadding, height: topBarHeight),

          ClubBlueHeader(
            topOffset: topBarHeight,
            title: _clubName, // 🌟 ใช้ชื่อชมรมจริง
            onBackPressed: () => Navigator.pop(context),
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
                  backgroundImage: AssetImage('assets/images/profile/profile_img.png'),
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
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _clubNameController,
                      focusNode: _nameFocusNode,
                      readOnly: !_isEditingName,
                      onTapOutside: (event) {
                        setState(() {
                          _isEditingName = false;
                        });
                        _nameFocusNode.unfocus();
                        _updateClubInfo('name', _clubNameController.text); // 🌟 บันทึก
                      },
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                      decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isEditingName = true;
                      });
                      _nameFocusNode.requestFocus();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6, right: 6, top: 4, bottom: 4),
                      child: Image.asset('assets/images/icon/iconEdit.png', width: 22, height: 22),
                    ),
                  ),
                ],
              ),
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
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(right: 30),
                child: TextField(
                  controller: _clubDetailController,
                  focusNode: _detailFocusNode,
                  readOnly: !_isEditingDetail,
                  maxLines: null,
                  onTapOutside: (event) {
                    setState(() {
                      _isEditingDetail = false;
                    });
                    _detailFocusNode.unfocus();
                    _updateClubInfo('description', _clubDetailController.text); // 🌟 บันทึก
                  },
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero, hintText: 'เพิ่มรายละเอียดชมรมที่นี่...'),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isEditingDetail = true;
                });
                _detailFocusNode.requestFocus();
              },
              child: Image.asset('assets/images/icon/iconEdit.png', width: 22, height: 22),
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
          MaterialPageRoute(builder: (context) => PlayerProfileScreen(playerId: memberId)),
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
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF9DD0E7), width: 2),
                            ),
                            child: const CircleAvatar(
                              radius: 36,
                              backgroundImage: AssetImage('assets/images/profile/profile_img.png'),
                              backgroundColor: Colors.transparent,
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
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: isLeader ? const Color(0xFFFFB775) : const Color(0xFFCBE7F5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black, width: 1.5),
                            ),
                            child: Text(isLeader ? "เจ้าของชมรม" : "สมาชิก", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
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
            Container(height: 2, color: const Color(0xFF9DD0E7)),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 105,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isLeader ? const Color(0xFFFFE0B2) : const Color(0xFFCBE7F5),
                      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8)),
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