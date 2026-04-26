import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/club_detail_head.dart';
import 'package:flutter_application_1/widgets/club/club_room_components.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 🌟 อย่าลืม import

class ClubRoomHeadScreen extends StatefulWidget {
  const ClubRoomHeadScreen({super.key});

  @override
  State<ClubRoomHeadScreen> createState() => _ClubRoomHeadScreenState();
}

class _ClubRoomHeadScreenState extends State<ClubRoomHeadScreen> {
  int _selectedIndex = 3;
  bool _isDetailPressed = false;
  bool _isCreatePressed = false;

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
                Expanded(flex: 5, child: _buildEmptyMissionBox()),
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
          onTap: () {
            Navigator.pushNamed(context, '/createclubquest');
            debugPrint("Create mission tapped");
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
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ClubDetailHeadScreen()),
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

  // รูปแบบปุ่มกลมเหมือนใน all_quest.dart
  Widget _buildCircularIconButton({
    required String imagePath,
    required VoidCallback onTap,
    required bool isPressed,
    required ValueChanged<bool> onPressedChanged,
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
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF68E2FA), Color(0xFF2374B5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: Center(
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
    );
  }

  // กล่องภารกิจชมรม (สถานะ: ยังไม่มีภารกิจ)
  Widget _buildEmptyMissionBox() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF9DD0E7), width: 2),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 12,
            right: 16,
            child: Text(
              "จำนวนภารกิจที่สร้างได้ 3/3",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const Align(
            alignment: Alignment.center,
            child: Text(
              "ยังไม่มีภารกิจในตอนนี้",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}