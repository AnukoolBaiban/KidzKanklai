import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/club_detail_head.dart';
import 'package:flutter_application_1/widgets/club/club_room_components.dart';
import 'package:flutter_application_1/widgets/reward_popup.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/screens/all_quest.dart';
import 'package:flutter_application_1/screens/club_quest/club_quest_detail_leader.dart';
import 'package:flutter_application_1/api_service.dart';

class ClubRoomHeadScreen extends StatefulWidget {
  final bool isNewClub; // 🌟 true = เพิ่งสร้างชมรมใหม่ → แสดง popup ตั๋ว

  const ClubRoomHeadScreen({super.key, this.isNewClub = false});

  @override
  State<ClubRoomHeadScreen> createState() => _ClubRoomHeadScreenState();
}

class _ClubRoomHeadScreenState extends State<ClubRoomHeadScreen> {
  int _selectedIndex = 3;
  bool _isDetailPressed = false;
  bool _isCreatePressed = false;

  String _clubName = "กำลังโหลด...";
  bool _isLoading = true;
  bool _isCollapsed = false; // 🌟 ตัวแปร toggle ย่อ/ขยายกล่องภารกิจ
  List<dynamic> _quests = []; // เก็บ List ภารกิจ
  int _ticketCount = 0; // 🌟 1. เพิ่มตัวแปรเก็บจำนวนตั๋ว
  Set<int> _completedQuestIds = {}; // 🌟 เก็บ ID ของเควสที่สมาชิกทุกคนทำสำเร็จแล้ว
  Map<int, int> _questProgressMap = {}; // 🌟 เก็บความคืบหน้าของแต่ละเควส
  int _totalMembersCount = 1; // 🌟 เก็บจำนวนสมาชิกทั้งหมดเพื่อเอาไปใช้กับหลอด

  @override
  void initState() {
    super.initState();
    _fetchClubData();
    _checkDailyLoginRewards();
    // โหลดข้อมูลของหน้ารายละเอียดล่วงหน้าแบบ Background
    Future.microtask(() => ClubDetailHeadPreloader.preload());
  }

  // ฟังก์ชันเช็คและโชว์ป๊อปอัป
  Future<void> _checkDailyLoginRewards() async {
    final apiRewards = await ApiService.claimLoginBonus();

    if (apiRewards.isNotEmpty && mounted) {
      List<RewardData> collectedRewards = [];

      for (var reward in apiRewards) {
        collectedRewards.add(
          RewardData.item(
            name: reward['name'],
            amount: reward['added'],
            image: reward['image'], // 🌟 จับค่าใส่ตรงๆ ได้เลย โค้ดสั้นลงมาก!
          ),
        );
      }

      await RewardPopup.show(context, rewards: collectedRewards);
    }
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
        Map<int, int> progressMap = {}; // 🌟 เก็บความคืบหน้าแบบ local ก่อน

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
            progressMap[qId] = userSet.length;
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
            _questProgressMap = progressMap;
            _totalMembersCount = totalMembers;
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
              ClubBlueHeader(
                title: _clubName,
                annotationTitle: "รายละเอียดชมรม",
                isClubAnnotation: true,
              ),
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
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: _buildMissionBox(constraints.maxHeight - 20),
                        ),
                      );
                    },
                  ),
                ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "ภารกิจของชมรม",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/item/Ticket_clubquest_img.png',
                width: 22,
                height: 22,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.confirmation_num, size: 18, color: Colors.blueAccent),
              ),
              const SizedBox(width: 5),
              Text(
                '$_ticketCount/3',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
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
          isDisabled: _totalMembersCount == 0 || _isLoading, // 🌟 ปิดปุ่มถ้าไม่มีสมาชิก
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
              "assets/images/icon/club-detail2.png",
              width: 28,
              height: 28,
              fit: BoxFit.contain,
              color: Colors.white,
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
      onTapDown: isDisabled ? null : (_) => onPressedChanged(true),
      onTapUp: isDisabled ? null : (_) => onPressedChanged(false),
      onTapCancel: isDisabled ? null : () => onPressedChanged(false),
      onTap: isDisabled ? null : onTap,
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

  // 🌟 กล่องภารกิจชมรม พร้อมปุ่ม toggle ย่อ/ขยาย และ Animation
  Widget _buildMissionBox(double maxHeight) {
    final BoxDecoration boxDecoration = BoxDecoration(
      color: Colors.white.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFF9DD0E7), width: 2),
    );

    if (_isLoading) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          // 🌟 ปุ่ม Toggle อยู่ด้านหลัง
          _buildToggleButton(),
          Container(
            margin: const EdgeInsets.only(bottom: 22), // 🌟 สร้างขอบเขตให้ Stack ครอบคลุมปุ่ม
            width: double.infinity,
            decoration: boxDecoration,
            padding: const EdgeInsets.all(10),
            child: _isCollapsed
                ? const SizedBox(
                    height: 36,
                    child: Center(
                      child: Text(
                        "กำลังโหลดข้อมูล...",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  )
                : const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text(
                          "กำลังโหลดข้อมูล...",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  ),
          ),
        ],
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 🌟 ปุ่ม Toggle มุมขวาล่าง (อยู่ด้านหลัง)
        _buildToggleButton(),

        // 🌟 ตัวกล่องภารกิจ
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(bottom: 22), // 🌟 สร้างขอบเขตให้ Stack ครอบคลุมปุ่ม
          width: double.infinity,
          height: _isCollapsed ? 72 : maxHeight, // ความสูงตอนย่อ=72 (มองเห็น 50px), ตอนขยาย=เต็มที่
          decoration: boxDecoration,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          clipBehavior: Clip.hardEdge, // ซ่อนเนื้อหาที่ล้นตอนกำลังพับ
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(
              // คำนวณความสูงเนื้อหาให้พอดีกับ AnimatedContainer (ลบ margin 22, padding 16, border 4 = 42)
              height: _isCollapsed ? 30 : maxHeight - 42,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 🌟 เพิ่มข้อความบอกจำนวนภารกิจที่อยู่ตรงกลาง
                  SizedBox(
                    height: 30,
                    child: Center(
                      child: Text(
                        "ภารกิจที่ยังไม่สำเร็จ ${_quests.length - _completedQuestIds.length}/${_quests.length}",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ),
                  // 🌟 Mission List แบบ scroll ได้ (แสดงเฉพาะตอนขยาย)
                  if (!_isCollapsed)
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
            ),
          ),
        ),
      ],
    );
  }

  // 🌟 ปุ่มสี่เหลี่ยมเล็ก toggle ย่อ/ขยาย
  Widget _buildToggleButton() {
    return Positioned(
      bottom: -10, // 🌟 ให้อยู่ในขอบเขต Stack
      right: 20,
      child: GestureDetector(
        onTap: () => setState(() => _isCollapsed = !_isCollapsed),
        child: Container(
          width: 36,
          height: 36, // เพิ่มความสูงให้ซ่อนอยู่ข้างหลังกล่องได้พอดี
          decoration: BoxDecoration(
            color: const Color(0xFF2374B5),
            // โค้งเฉพาะมุมล่างซ้ายและขวา ให้เหมือนที่คั่นหนังสือ
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
            border: Border.all(color: const Color(0xFF9DD0E7), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.only(bottom: 2), // ดันไอคอนลงมานิดนึง
          child: Icon(
            _isCollapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
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

                    // 🌟 Progress Bar ใต้ของรางวัล
                    const SizedBox(height: 10),
                    _buildProgressBar(
                      isCompleted,
                      _questProgressMap[questId] ?? 0,
                      _totalMembersCount,
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
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'รายละเอียด',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                      Text(
                        timeLeftText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: timeTextColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
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

  Widget _buildProgressBar(bool isDone, int progress, int totalReq) {
    double percent = totalReq > 0 ? (progress / totalReq).clamp(0.0, 1.0) : 0.0;
    if (isDone) percent = 1.0;
    final String countText = isDone ? "$totalReq/$totalReq" : "$progress/$totalReq";

    return Container(
      height: 20,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percent,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF59ABEC), Color(0xFF85D755)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Center(
            child: Text(
              'จำนวนสมาชิกที่สำเร็จภารกิจนี้ $countText',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: percent > 0.5 ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}