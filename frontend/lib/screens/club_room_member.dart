import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/club_detail_member.dart';
import 'package:flutter_application_1/widgets/club/club_room_components.dart';
import 'package:flutter_application_1/screens/all_quest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/screens/club_quest/club_quest_detail_member.dart';

class ClubRoomMemberScreen extends StatefulWidget {
  const ClubRoomMemberScreen({super.key});

  @override
  State<ClubRoomMemberScreen> createState() => _ClubRoomMemberScreenState();
}

class _ClubRoomMemberScreenState extends State<ClubRoomMemberScreen> {
  int _selectedIndex = 3;
  bool _isDetailPressed = false;

  String _clubName = "กำลังโหลด...";
  bool _isLoading = true;
  List<dynamic> _quests = []; // เก็บ List ภารกิจ
  Set<int> _completedQuestIds = {}; // เก็บ ID ของเควสที่ทำสำเร็จแล้ว

  @override
  void initState() {
    super.initState();
    _fetchClubData(); // สั่งโหลดข้อมูลตอนเปิดหน้า
    // โหลดข้อมูลของหน้ารายละเอียดล่วงหน้าแบบ Background
    Future.microtask(() => ClubDetailMemberPreloader.preload());
  }

  // 🌟 1. ฟังก์ชันดึงข้อมูลชมรมและเควส
  Future<void> _fetchClubData() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      // หา club_id ของตัวเอง
      final profile = await supabase.from('user_profiles').select('club_id').eq('id', userId).single();
      
      if (profile['club_id'] != null) {
        final clubId = profile['club_id'];

        // นำ club_id ไปหาชื่อชมรม
        final club = await supabase.from('clubs').select('name').eq('id', clubId).single();
        
        // 🌟 ดึงเควสทั้งหมดที่ยังไม่หมดเวลา (อิงตาม API ใหม่)
        final questsResponse = await supabase
            .from('quests')
            .select('''
              *,
              receive (
                quantity,
                items (
                  name,
                  image
                )
              )
            ''')
            .eq('club_id', clubId)
            .gt('due_date', DateTime.now().toUtc().toIso8601String()) // กรองเฉพาะอันที่ยังไม่หมดเขต
            .order('due_date', ascending: true);

        // ดึงข้อมูลว่า user ปัจจุบันทำเควสไหนเสร็จแล้วบ้าง
        final List<int> questIds = (questsResponse as List<dynamic>).map((q) => q['id'] as int).toList();
        final Set<int> completedIds = {};

        if (questIds.isNotEmpty) {
          final doQuestsResponse = await supabase
              .from('do_quests')
              .select('quest_id')
              .eq('user_id', userId)
              .inFilter('quest_id', questIds)
              .eq('status', 'completed');

          for (var dq in doQuestsResponse) {
            completedIds.add(dq['quest_id'] as int);
          }
        }

        if (mounted) {
          setState(() {
            _clubName = club['name'];
            _quests = questsResponse;
            _completedQuestIds = completedIds; // เซ็ตค่าใส่ State
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final topBarHeight = 75.0 + topPadding;
    const headerHeight = 80.0;

    return Scaffold(
      body: Stack(
        children: [
          // ── Background ──────────────────────────────
          const ClubBackground(),

          // ── Top Bar & Header ───────────────────────
          Column(
            children: [
              ClubTopBar(topPadding: topPadding),
              ClubBlueHeader(title: _clubName),
            ],
          ),

          // ── Main Content ────────────────────────────
          Padding(
            padding: EdgeInsets.only(
              top: topBarHeight + headerHeight + 20,
              bottom: 110, // พื้นที่สำหรับ Bottom Nav Bar
              left: size.width * 0.05,
              right: size.width * 0.05,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [_buildMissionTitle(), _buildActionButtonsRow()],
                ),
                const SizedBox(height: 10),
                Expanded(child: _buildMissionBox()),
              ],
            ),
          ),

          // ── Bottom Nav Bar ──────────────────────────
          ClubBottomNavBar(
            selectedIndex: _selectedIndex,
            onItemTapped: (index) => setState(() => _selectedIndex = index),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionTitle() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Text(
        "ภารกิจของชมรม",
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildActionButtonsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [_buildDetailButton()],
    );
  }

  Widget _buildDetailButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isDetailPressed = true),
      onTapUp: (_) => setState(() => _isDetailPressed = false),
      onTapCancel: () => setState(() => _isDetailPressed = false),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ClubDetailMemberScreen(),
          ),
        );
        _fetchClubData(); // รีเฟรชข้อมูลเมื่อกลับมา
      },
      child: Container(
        width: 50,
        height: 50,
        padding: const EdgeInsets.all(2), 
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF015496),
        ),
        child: Container(
          foregroundDecoration: _isDetailPressed
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.15),
                )
              : null,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF59ABEC), Color(0xFF2374B5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Image.asset(
              "assets/images/icon/club-detail.png",
              width: 28,
              height: 28,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.image_not_supported,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🌟 2. กล่องภารกิจชมรม (เอาโควตาออก)
  Widget _buildMissionBox() {
    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFF9DD0E7), width: 2),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF9DD0E7), width: 2),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mission List แบบ scroll ได้
          Expanded(
            child: _quests.isEmpty
                ? const Center(
                    child: Text(
                      "ยังไม่มีภารกิจในขณะนี้",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _quests.length,
                    itemBuilder: (context, index) {
                      final quest = _quests[index];
                      final isLast = index == _quests.length - 1;
                      return Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                        child: _buildMissionCard(quest),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionCard(Map<String, dynamic> quest) {
    final String title = quest['name'] ?? 'ไม่มีชื่อภารกิจ';
    final int questId = quest['id'] ?? 0;

    final bool isCompleted = _completedQuestIds.contains(questId);

    String timeLeftText = "ไม่มีกำหนด";
    Color timeTextColor = Colors.red;

    if (isCompleted) {
      timeLeftText = "สำเร็จ";
      timeTextColor = Colors.green;
    } else if (quest['due_date'] != null) {
      final dueDate = DateTime.parse(quest['due_date']).toLocal();
      final difference = dueDate.difference(DateTime.now());
      if (difference.isNegative) {
        timeLeftText = "หมดเวลา";
        timeTextColor = Colors.grey;
      } else if (difference.inDays > 0) {
        timeLeftText = "เหลืออีก ${difference.inDays} วัน";
        timeTextColor = Colors.black87;
      } else {
        timeLeftText = "เหลืออีก ${difference.inHours} ชั่วโมง";
        timeTextColor = Colors.red;
      }
    }

    // 🌟 3. จัดการของรางวัล (กรณีไม่มีของรางวัล)
    final receives = quest['receive'] as List<dynamic>? ?? [];
    List<Widget> badges = [];
    
    if (receives.isEmpty) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            "ไม่มีรางวัล",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
        ),
      );
    } else {
      badges = receives.map((r) {
        final item = r['items'] ?? {};
        final itemName = item['name'] ?? "Item";
        final quantity = r['quantity'] ?? 1;
        
        final String imagePath = item['image'] ?? 'assets/images/item/Gasha.png';
        final bool isExp = itemName.toString().toUpperCase().contains("EXP");
        
        Color badgeColor = isExp ? const Color(0xFFC8E6C9) : const Color(0xFFFFE0B2);
        if (isCompleted) {
          badgeColor = Colors.grey.shade300; 
        }
        
        final String valueText = isExp ? "+$quantity" : "x$quantity";

        return RewardBadge(
          label: itemName,
          value: valueText,
          color: badgeColor,
          iconPath: imagePath,
          isClaimed: isCompleted,
        );
      }).toList();
    }

    return Container(
      decoration: BoxDecoration(
        color: isCompleted
            ? Colors.grey.shade300.withOpacity(0.85)
            : Colors.white,
        borderRadius: BorderRadius.circular(15), 
        border: Border.all(
          color: isCompleted ? Colors.grey : const Color(0xFF9DD0E7),
          width: 2,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFB775), Color(0xFFFFD4A9)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.black,
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            'ชมรม',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87, 
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: badges,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: 1,
              color: isCompleted ? Colors.grey : const Color(0xFF9DD0E7),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ClubQuestDetailScreen(
                                questData: quest,
                                isCompleted: isCompleted,
                              ),
                            ),
                          ).then((_) => _fetchClubData()); // 🌟 รีเฟรชข้อมูลเมื่อกลับมาเผื่อเพิ่งทำเควสเสร็จ
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF536DFE),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: const FittedBox(
                          child: Text(
                            'รายละเอียด',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isCompleted)
                      const Text(
                        "สำเร็จ",
                        style: TextStyle(
                          color: Color(0xFF34C759),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      FittedBox(
                        child: Text(
                          timeLeftText,
                          style: TextStyle(
                            color: timeTextColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}