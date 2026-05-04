import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/club_detail_head.dart';
import 'package:flutter_application_1/widgets/club/club_room_components.dart';
import 'package:flutter_application_1/api_service.dart';
import 'package:flutter_application_1/widgets/character_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User; // 🌟 อย่าลืม import
// 🌟 นำเข้าหน้า Detail (ปรับ Path ให้ตรงกับโปรเจกต์ของคุณ)
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

  // 🌟 1. เพิ่มตัวแปรเก็บข้อมูล
  String _clubName = "กำลังโหลด...";
  bool _isLoading = true;
  List<dynamic> _quests = []; // 🌟 เก็บ List ภารกิจ
  User? _user; // 🌟 เก็บข้อมูลผู้เล่นสำหรับโมเดล Rive
  List<User> _clubMembers = []; // 🌟 สมาชิกชมรมสำหรับโมเดลซ้ายขวา

  @override
  void initState() {
    super.initState();
    _fetchClubData(); // 🌟 2. สั่งโหลดข้อมูลตอนเปิดหน้า
    // โหลดข้อมูลของหน้ารายละเอียดล่วงหน้าแบบ Background
    Future.microtask(() => ClubDetailHeadPreloader.preload());
  }

  // 🌟 ฟังก์ชันคำนวณเวลาสัปดาห์นี้ (จันทร์ 00:00 - จันทร์หน้า 00:00)
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

  // 🌟 3. ฟังก์ชันดึงข้อมูลชมรมและเควส (เหมือนฝั่ง Member)
  Future<void> _fetchClubData() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      final profile = await supabase.from('user_profiles').select('club_id').eq('id', userId).single();
      
      if (profile['club_id'] != null) {
        final clubId = profile['club_id'];
        final club = await supabase.from('clubs').select('name').eq('id', clubId).single();
        final timeRange = _getThisWeekTimeRangeUTC();

        // ดึงเควส พร้อม Join ตาราง Receive และ Items
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
            .gte('start_date', timeRange['start']!)
            .lt('start_date', timeRange['end']!)
            .order('start_date', ascending: true);

        if (mounted) {
          setState(() {
            _clubName = club['name'];
            _quests = questsResponse;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }

      // 🌟 โหลดข้อมูลผู้เล่นสำหรับแสดงตัวโมเดล
      final userProfile = await ApiService.getProfile(0);
      if (mounted && userProfile != null) {
        setState(() => _user = userProfile);
      }

      // 🌟 ดึงสมาชิกชมรม (ยกเว้นตัวเอง) สุ่มมา 2 คน
      if (profile['club_id'] != null) {
        // ดึง user_ids ของสมาชิกทั้งหมดในชมรม (ยกเว้นตัวเอง)
        final membersRaw = await supabase
            .from('user_profiles')
            .select('id')
            .eq('club_id', profile['club_id'])
            .neq('id', userId);

        final memberIds = (membersRaw as List<dynamic>)
            .map((m) => m['id'] as String)
            .toList();

        if (memberIds.isNotEmpty) {
          memberIds.shuffle(Random());
          final pickedIds = memberIds.take(2).toList();
          
          // ดึง profile แต่ละคนผ่าน characters + wear (เหมือน Go backend)
          final List<User> pickedMembers = [];
          for (final memberId in pickedIds) {
            try {
              // ดึง character data
              final charData = await supabase
                  .from('characters')
                  .select('level, experience, body_type, intelligence, strength, creative')
                  .eq('user_id', memberId)
                  .single();

              // ดึง equipped items
              final wearData = await supabase
                  .from('wear')
                  .select('type, items(name)')
                  .eq('character_id', 
                    (await supabase.from('characters').select('id').eq('user_id', memberId).single())['id']
                  );

              final equipped = <String, String>{'Skin': '', 'Hair': '', 'Face': '', 'Outfit': ''};
              for (final w in (wearData as List<dynamic>)) {
                final wType = w['type'] as String? ?? '';
                final itemName = (w['items'] as Map<String, dynamic>?)?['name'] as String? ?? '';
                if (equipped.containsKey(wType)) {
                  equipped[wType] = itemName;
                }
              }

              pickedMembers.add(User(
                id: 0,
                username: '',
                email: '',
                level: charData['level'] ?? 1,
                exp: charData['experience'] ?? 0,
                coins: 0,
                tickets: 0,
                vouchers: 0,
                bio: '',
                soundBGM: 50,
                soundSFX: 50,
                equippedSkin: equipped['Skin'] ?? '',
                equippedHair: equipped['Hair'] ?? '',
                equippedFace: equipped['Face'] ?? '',
                equippedOutfit: equipped['Outfit'] ?? '',
                statIntellect: charData['intelligence'] ?? 10,
                statStrength: charData['strength'] ?? 10,
                statCreativity: charData['creative'] ?? 10,
                bodyType: charData['body_type'] ?? 'KID',
              ));
            } catch (e) {
              debugPrint('Error fetching member $memberId: $e');
            }
          }

          if (mounted && pickedMembers.isNotEmpty) {
            setState(() => _clubMembers = pickedMembers);
          }
        }
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

          // ── Character Model (ด้านหลัง content) ─────
          // 🌟 สมาชิกชมรมฝั่งซ้าย
          if (_clubMembers.isNotEmpty)
            Builder(builder: (_) {
              final m = _clubMembers[0];
              final bt = m.bodyType.toUpperCase();
              final double charH = bt == 'ADULT' ? 170 : bt == 'TEEN' ? 150 : 120;
              final double charW = bt == 'ADULT' ? 150 : bt == 'TEEN' ? 130 : 110;
              final double charBottom = bt == 'ADULT' ? 80 : bt == 'TEEN' ? 75 : 65;
              final double charLeft = bt == 'ADULT' ? 5 : bt == 'TEEN' ? 15 : 25;
              return Positioned(
                bottom: charBottom,
                left: charLeft,
                child: Opacity(
                  opacity: 0.85,
                  child: CharacterWidget(
                    user: m,
                    height: charH,
                    width: charW,
                    isInteractive: false,
                  ),
                ),
              );
            }),

          // 🌟 สมาชิกชมรมฝั่งขวา
          if (_clubMembers.length >= 2)
            Builder(builder: (_) {
              final m = _clubMembers[1];
              final bt = m.bodyType.toUpperCase();
              final double charH = bt == 'ADULT' ? 170 : bt == 'TEEN' ? 150 : 120;
              final double charW = bt == 'ADULT' ? 150 : bt == 'TEEN' ? 130 : 110;
              final double charBottom = bt == 'ADULT' ? 80 : bt == 'TEEN' ? 75 : 65;
              final double charRight = bt == 'ADULT' ? 5 : bt == 'TEEN' ? 15 : 25;
              return Positioned(
                bottom: charBottom,
                right: charRight,
                child: Opacity(
                  opacity: 0.85,
                  child: CharacterWidget(
                    user: m,
                    height: charH,
                    width: charW,
                    isInteractive: false,
                  ),
                ),
              );
            }),

          // 🌟 ตัวโมเดลผู้เล่น (ตรงกลาง)
          if (_user != null)
            Builder(builder: (_) {
              final bt = _user!.bodyType.toUpperCase();
              final double charH = bt == 'ADULT' ? 220 : bt == 'TEEN' ? 190 : 150;
              final double charW = bt == 'ADULT' ? 200 : bt == 'TEEN' ? 170 : 160;
              final double charBottom = bt == 'KID' ? 75 : 85;
              return Positioned(
                bottom: charBottom,
                left: 0,
                right: 0,
                child: Center(
                  child: CharacterWidget(
                    user: _user,
                    height: charH,
                    width: charW,
                    isInteractive: false,
                  ),
                ),
              );
            }),

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
                Expanded(flex: 5, child: _buildMissionBox()), // 🌟 กล่องภารกิจคงที่
                const Spacer(flex: 3), // พื้นที่ว่างด้านล่าง (โมเดลอยู่ด้านหลัง)
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
    bool isQuotaFull = _quests.length >= 3;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildDetailButton(),
        const SizedBox(width: 8),
        _buildCircularIconButton(
          imagePath: "assets/images/button/bt-create.png",
          isPressed: _isCreatePressed,
          isDisabled: isQuotaFull,
          onTap: () {
            // 🌟 เช็คโควตาก่อนกดสร้าง
            if (isQuotaFull) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('คุณสร้างภารกิจครบ 3 ครั้งในสัปดาห์นี้แล้ว'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
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

  // 🌟 กล่องภารกิจชมรม (คำนวณโควตา และแสดงข้อมูลจริง)
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

    // คำนวณสิทธิ์คงเหลือ
    int questsLeft = 3 - _quests.length;
    if (questsLeft < 0) questsLeft = 0;

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
          // 🌟 Header: โชว์จำนวนโควตาที่สร้างได้
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 8),
              child: Text(
                "จำนวนภารกิจที่สร้างได้ $questsLeft/3",
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
                      "ยังไม่มีภารกิจในสัปดาห์นี้",
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
    List<Widget> badges = receives.map((r) {
      final item = r['items'] ?? {};
      final itemName = item['name'] ?? "Item";
      final quantity = r['quantity'] ?? 1;

      final String imagePath = item['image'] ?? 'assets/images/item/Gasha.png';
      final bool isExp = itemName.toString().toUpperCase().contains("EXP");
      final Color color = isExp ? const Color(0xFFC8E6C9) : const Color(0xFFFFE0B2);
      final String valueText = isExp ? "+$quantity" : "x$quantity";

      return RewardBadge(
        label: itemName,
        value: valueText,
        color: color,
        iconPath: imagePath,
      );
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9DD0E7), width: 2),
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: badges.isNotEmpty ? badges : [const SizedBox.shrink()],
                    ),
                  ],
                ),
              ),
            ),
            Container(width: 1, color: const Color(0xFF9DD0E7)),
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
                          );
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