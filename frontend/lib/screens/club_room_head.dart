import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/club_detail_head.dart';
import 'package:flutter_application_1/widgets/club/club_room_components.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/screens/all_quest.dart';
import 'package:flutter_application_1/screens/club_quest/club_quest_detail_leader.dart';

class ClubRoomHeadScreen extends StatefulWidget {
  const ClubRoomHeadScreen({super.key});

  @override
  State<ClubRoomHeadScreen> createState() => _ClubRoomHeadScreenState();
}

class _ClubRoomHeadScreenState extends State<ClubRoomHeadScreen> {
  int _selectedIndex = 3;
  bool _isDetailPressed = false;
  bool _isCreatePressed = false;

  String _clubName = "กำลังโหลด...";
  bool _isLoading = true;
  List<dynamic> _quests = []; // เก็บ List ภารกิจ
  int _ticketCount = 0; // 🌟 1. เพิ่มตัวแปรเก็บจำนวนตั๋ว
  Set<int> _completedQuestIds = {}; // 🌟 เก็บ ID ของเควสที่สมาชิกทุกคนทำสำเร็จแล้ว

  @override
  void initState() {
    super.initState();
    _fetchClubData(); // สั่งโหลดข้อมูลตอนเปิดหน้า
    // โหลดข้อมูลของหน้ารายละเอียดล่วงหน้าแบบ Background
    Future.microtask(() => ClubDetailHeadPreloader.preload());
  }

  // 🌟 ฟังก์ชันดึงข้อมูลชมรมและเควส
  Future<void> _fetchClubData() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      // 🌟 2. ดึงข้อมูลจำนวนตั๋ว (Item ID = 19) ในกระเป๋าของผู้ใช้
      final ticketData = await supabase
          .from('collect')
          .select('quantity')
          .eq('user_id', userId)
          .eq('item_id', 19)
          .maybeSingle(); // ใช้ maybeSingle เผื่อว่าไม่มีตั๋วเลย

      int tickets = 0;
      if (ticketData != null) {
        tickets = ticketData['quantity'] ?? 0;
      }

      final profile = await supabase.from('user_profiles').select('club_id').eq('id', userId).single();
      
      if (profile['club_id'] != null) {
        final clubId = profile['club_id'];
        final club = await supabase.from('clubs').select('name').eq('id', clubId).single();

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
            .gt('due_date', DateTime.now().toUtc().toIso8601String())
            .order('due_date', ascending: true);

        // 🌟 1. นับจำนวนสมาชิกทั้งหมดในชมรม (ยกเว้นหัวหน้าชมรม)
        final membersResponse = await supabase
            .from('user_profiles')
            .select('id')
            .eq('club_id', clubId)
            .neq('club_role', 'owner');
        final int totalMembers = (membersResponse as List).length;

        // 🌟 2. ดึงข้อมูลการทำภารกิจของสมาชิก
        final List<int> questIds = (questsResponse as List<dynamic>).map((q) => q['id'] as int).toList();
        final Set<int> completedQuestIds = {};

        if (questIds.isNotEmpty && totalMembers > 0) {
          final doQuestsResponse = await supabase
              .from('do_quests')
              .select('quest_id, user_id')
              .inFilter('quest_id', questIds)
              .eq('status', 'completed');

          // นับจำนวนคนที่ทำเควสสำเร็จ (แบบไม่ซ้ำคน)
          Map<int, Set<String>> questCompletionMap = {};
          for (var dq in doQuestsResponse) {
            final qId = dq['quest_id'] as int;
            final uId = dq['user_id'] as String;
            if (!questCompletionMap.containsKey(qId)) {
              questCompletionMap[qId] = {};
            }
            questCompletionMap[qId]!.add(uId);
          }

          questCompletionMap.forEach((qId, userSet) {
            if (userSet.length >= totalMembers) {
              completedQuestIds.add(qId);
            }
          });
        }

        // 🌟 3. เรียงลำดับเควสที่ทำสำเร็จแล้วไปไว้ด้านล่างสุด
        List<dynamic> sortedQuests = List.from(questsResponse);
        sortedQuests.sort((a, b) {
          bool aCompleted = completedQuestIds.contains(a['id']);
          bool bCompleted = completedQuestIds.contains(b['id']);
          
          if (aCompleted && !bCompleted) return 1;
          if (!aCompleted && bCompleted) return -1;
          return 0; // รักษาลำดับเดิม (เรียงตาม due_date ไว้)
        });

        if (mounted) {
          setState(() {
            _ticketCount = tickets; // 🌟 เก็บจำนวนตั๋วลง State
            _clubName = club['name'];
            _quests = sortedQuests;
            _completedQuestIds = completedQuestIds;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching club data: $e");
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
              bottom: 110,
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
                Expanded(child: _buildMissionBox()), // กล่องภารกิจ
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

  // ปุ่ม 2 ปุ่ม: รายละเอียดชมรม และสร้างภารกิจ
  Widget _buildActionButtonsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildDetailButton(),
        const SizedBox(width: 8),
        _buildCircularIconButton(
          imagePath: "assets/images/button/bt-create.png",
          isPressed: _isCreatePressed,
          isDisabled: false, // 🌟 ไม่มีการจำกัดสิทธิ์การกดสร้างแล้ว
          onTap: () {
            Navigator.pushNamed(context, '/createclubquest');
          },
          onPressedChanged: (val) => setState(() => _isCreatePressed = val),
        ),
      ],
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
          MaterialPageRoute(builder: (context) => const ClubDetailHeadScreen()),
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

  Widget _buildCircularIconButton({
    required String imagePath,
    required VoidCallback onTap,
    required bool isPressed,
    required ValueChanged<bool> onPressedChanged,
    bool isDisabled = false,
  }) {
    return GestureDetector(
      onTapDown: (_) => onPressedChanged(true),
      onTapUp: (_) => onPressedChanged(false),
      onTapCancel: () => onPressedChanged(false),
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        padding: const EdgeInsets.all(3),
        foregroundDecoration: isPressed
            ? BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.15),
              )
            : null,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isDisabled 
                ? [Colors.grey.shade400, Colors.grey.shade600] 
                : const [Color(0xFF68E2FA), Color(0xFF2374B5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDisabled ? Colors.grey.shade300 : Colors.white,
          ),
          child: Center(
            child: Opacity(
              opacity: isDisabled ? 0.5 : 1.0,
              child: Image.asset(
                imagePath,
                width: 28,
                height: 28,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.image_not_supported, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🌟 กล่องภารกิจชมรม
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
          // 🌟 เพิ่มข้อความบอกจำนวนตั๋วที่มุมขวาบน
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 8),
              child: Text(
                "จำนวนตั๋วสร้างภารกิจชมรมที่มี $_ticketCount",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),

          // 🌟 Mission List แบบ scroll ได้
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

  // 🌟 การ์ดแสดงภารกิจแต่ละอัน
  Widget _buildMissionCard(Map<String, dynamic> quest) {
    final String title = quest['name'] ?? 'ไม่มีชื่อภารกิจ';
    final int questId = quest['id'] ?? 0;

    final bool isCompleted = _completedQuestIds.contains(questId);

    String timeLeftText = "ไม่มีกำหนด";
    Color timeTextColor = Colors.red;

    if (quest['due_date'] != null) {
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

    final receives = quest['receive'] as List<dynamic>? ?? [];
    
    // 🌟 3. จัดการของรางวัล
    List<Widget> badges = receives.map((r) {
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

    return Container(
      decoration: BoxDecoration(
        color: isCompleted
            ? Colors.grey.shade300.withValues(alpha: 0.85)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                            border: Border.all(color: Colors.black, width: 1),
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
                    if (receives.isEmpty)
                      Container(
                        height: 60,
                        alignment: Alignment.center,
                        child: const Text(
                          "ไม่มีของรางวัลสำหรับภารกิจนี้",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
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
                              builder: (context) => ClubQuestDetailLeaderScreen(
                                questData: quest,
                              ),
                            ),
                          ).then((_) => _fetchClubData()); // 🌟 รีเฟรชหน้าหลังกลับมาจากแก้ไข/ดูรายละเอียด
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