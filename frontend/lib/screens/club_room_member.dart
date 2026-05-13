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
  bool _isCollapsed = false; // 🌟 ตัวแปร toggle ย่อ/ขยายกล่องภารกิจ
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

        // 🌟 2. เรียงลำดับเควสที่ทำสำเร็จแล้วไปไว้ด้านล่างสุด
        List<dynamic> sortedQuests = List.from(questsResponse);
        sortedQuests.sort((a, b) {
          bool aCompleted = completedIds.contains(a['id']);
          bool bCompleted = completedIds.contains(b['id']);
          
          if (aCompleted && !bCompleted) return 1;
          if (!aCompleted && bCompleted) return -1;
          return 0; // รักษาลำดับเดิม (เรียงตาม due_date ไว้)
        });

        if (mounted) {
          setState(() {
            _clubName = club['name'];
            _quests = sortedQuests;
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

  // 🌟 กล่องภารกิจชมรม พร้อมปุ่ม toggle และ Animation
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
                  // Mission List แบบ scroll ได้ (แสดงเฉพาะตอนขยาย)
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

    // 🌟 3. จัดการของรางวัล
    final receives = quest['receive'] as List<dynamic>? ?? [];
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