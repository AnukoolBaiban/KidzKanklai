import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/club_detail_member.dart';
import 'package:flutter_application_1/widgets/club/club_room_components.dart';
import 'package:flutter_application_1/screens/all_quest.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 🌟 อย่าลืม import

class ClubRoomMemberScreen extends StatefulWidget {
  const ClubRoomMemberScreen({super.key});

  @override
  State<ClubRoomMemberScreen> createState() => _ClubRoomMemberScreenState();
}

class _ClubRoomMemberScreenState extends State<ClubRoomMemberScreen> {
  int _selectedIndex = 3;
  bool _isDetailPressed = false;

  // 🌟 1. เพิ่มตัวแปรเก็บข้อมูล
  String _clubName = "กำลังโหลด...";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchClubName(); // 🌟 2. สั่งโหลดข้อมูลตอนเปิดหน้า
  }

  // 🌟 3. ฟังก์ชันดึงชื่อชมรม
  Future<void> _fetchClubName() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      // หา club_id ของตัวเอง
      final profile = await supabase.from('user_profiles').select('club_id').eq('id', userId).single();
      
      if (profile['club_id'] != null) {
        // นำ club_id ไปหาชื่อชมรม
        final club = await supabase.from('clubs').select('name').eq('id', profile['club_id']).single();
        if (mounted) {
          setState(() {
            _clubName = club['name'];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching club name: $e");
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
                Expanded(flex: 5, child: _buildMissionBox()),
                const Spacer(flex: 3), // พื้นที่ว่างสำหรับตัวละครด้านล่าง
              ],
            ),
          ),

          // ── Top Bar ─────────────────────────────────
          ClubTopBar(topPadding: topPadding, height: topBarHeight),

          // Header ───────────
          ClubBlueHeader(
             topOffset: topBarHeight, 
             title: _clubName, // 🌟 เปลี่ยนตรงนี้
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

  // ปุ่ม 1 ปุ่ม: รายละเอียดชมรมสำหรับสมาชิก
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
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ClubDetailMemberScreen(),
          ),
        );
      },
      child: Container(
        width: 50,
        height: 50,
        padding: const EdgeInsets.all(
          2,
        ), // ความหนาของเส้นขอบปกติต้องน้อยกว่านี้หน่อย ลอง 2px
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF002A50),
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

  // กล่องภารกิจชมรม (มีภารกิจ 3 อัน)
  Widget _buildMissionBox() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Expanded(
            child: _buildMissionCard("1. ลองก๋วยเตี๋ยวหลังมอ", isLast: false),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _buildMissionCard("2. ลองไก่ย่างวิเชียร", isLast: false),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildMissionCard("3. ลองส้มตำหน้ามอ", isLast: true)),
        ],
      ),
    );
  }

  Widget _buildMissionCard(String title, {required bool isLast}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9DD0E7), width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            RewardBadge(
                              label: "EXP",
                              value: "+59",
                              color: Color(0xFFC8E6C9),
                              iconPath: 'assets/images/item/EXP.png',
                            ),
                            RewardBadge(
                              label: "Item",
                              value: "x1",
                              color: Color(0xFFFFE0B2),
                              iconPath: 'assets/images/item/Gasha.png',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, color: const Color(0xFF9DD0E7)),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: ElevatedButton(
                        onPressed: () {},
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
                  ),
                  const SizedBox(height: 2),
                  const FittedBox(
                    child: Text(
                      'เหลืออีก 1 วัน',
                      style: TextStyle(
                        color: Colors.red,
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
    );
  }
}