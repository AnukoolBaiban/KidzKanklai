import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/api_service.dart' as api;
import 'package:flutter_application_1/screens/player_profile.dart' hide GradientCircularProgressPainter;
import 'package:flutter_application_1/widgets/character_widget.dart';
import 'package:flutter_application_1/widgets/bottom_navigation_bar.dart'; // สำหรับ GradientCircularProgressPainter
import 'package:flutter_application_1/widgets/custom_top_bar.dart';

class IncompleteMembersScreen extends StatefulWidget {
  final int questId;
  final int clubId;

  const IncompleteMembersScreen({
    Key? key,
    required this.questId,
    required this.clubId,
  }) : super(key: key);

  @override
  State<IncompleteMembersScreen> createState() => _IncompleteMembersScreenState();
}

class _IncompleteMembersScreenState extends State<IncompleteMembersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _incompleteMembers = [];
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _fetchIncompleteMembers();
  }

  // ฟังก์ชันช่วยดึงข้อมูลตัวละคร (เหมือนใน ClubDetailHeadPreloader)
  Future<api.User> _fetchUserCharacter(String uId) async {
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
        } catch (_) {}
      }
    }

    return api.User(
      id: 0, username: '', email: '', exp: exp, coins: 0, tickets: 0, vouchers: 0, bio: '', soundBGM: 0, soundSFX: 0, statIntellect: 0, statStrength: 0, statCreativity: 0,
      level: level, equippedSkin: eqSkin, equippedHair: eqHair, equippedFace: eqFace, equippedOutfit: eqOutfit, bodyType: bodyType,
    );
  }

  // 🌟 ฟังก์ชันดึงรายชื่อคนที่ยังไม่เสร็จ
  Future<void> _fetchIncompleteMembers() async {
    try {
      final supabase = Supabase.instance.client;

      // 1. ดึงสมาชิกทั้งหมดในคลับ (ไม่รวมหัวหน้า)
      final membersResponse = await supabase
          .from('user_profiles')
          .select('id, name, detail, club_role')
          .eq('club_id', widget.clubId)
          .neq('club_role', 'owner');

      // 2. ดึงคนที่ทำเควสนี้เสร็จแล้ว
      final doQuestsResponse = await supabase
          .from('do_quests')
          .select('user_id')
          .eq('quest_id', widget.questId)
          .eq('status', 'completed');

      final Set<String> completedUserIds = (doQuestsResponse as List<dynamic>)
          .map((dq) => dq['user_id'].toString())
          .toSet();

      // 3. กรองเอาเฉพาะคนที่ยังไม่มีชื่อใน completedUserIds
      final List<Map<String, dynamic>> incompleteList = [];
      for (final member in membersResponse as List<dynamic>) {
        final memberId = member['id'].toString();
        
        if (!completedUserIds.contains(memberId)) {
          // ดึงตัวละครมาแสดงผล
          final userObj = await _fetchUserCharacter(memberId);
          incompleteList.add({
            ...Map<String, dynamic>.from(member),
            'level': userObj.level,
            'user_obj': userObj,
          });
        }
      }

      if (mounted) {
        setState(() {
          _incompleteMembers = incompleteList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching incomplete members: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🌟 ฟังก์ชันคำนวณ EXP
  double _getExpPercent(int dbLevel, int totalExp) {
    int remainingExp = totalExp;
    int requiredExpForNextLevel = 0;
    for (int i = 1; i < dbLevel; i++) {
      int expUsed = (i < 6) ? 40 * i : 200 + (i * i);
      remainingExp -= expUsed;
    }
    if (dbLevel < 6) {
      requiredExpForNextLevel = 40 * dbLevel;
    } else {
      requiredExpForNextLevel = 200 + (dbLevel * dbLevel);
    }
    return (requiredExpForNextLevel > 0) ? (remainingExp / requiredExpForNextLevel).clamp(0.0, 1.0) : 0.0;
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
          // Background
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              color: const Color(0xFFE2F5FD),
              alignment: Alignment.center,
              child: Image.asset(
                "assets/images/background/bg-head.png",
                fit: BoxFit.contain,
                width: size.width * 0.8,
              ),
            ),
          ),

          // Top Bar & Header
          Column(
            children: [
              Container(
                padding: EdgeInsets.only(top: topPadding),
                color: Colors.black.withOpacity(0.4),
                child: CustomTopBar(
                  onNotificationTapped: () => Navigator.pushNamed(context, '/notification'),
                  onSettingsTapped: () => Navigator.pushNamed(context, '/setting'),
                ),
              ),
              _buildBlueHeader(),
            ],
          ),

          // Main Content
          Padding(
            padding: EdgeInsets.only(
              top: topBarHeight + headerHeight + 16,
              left: size.width * 0.05,
              right: size.width * 0.05,
              bottom: 20,
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _incompleteMembers.isEmpty
                    ? const Center(child: Text('สมาชิกทุกคนทำภารกิจนี้เสร็จแล้ว! 🎉', style: TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)))
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _incompleteMembers.length,
                        itemBuilder: (context, index) {
                          return _buildMemberCard(_incompleteMembers[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlueHeader() {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF015496), Color(0xFF2273B4)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 15,
            top: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                onTapDown: (_) => setState(() => _isPressed = true),
                onTapCancel: () => setState(() => _isPressed = false),
                onTap: () {
                  setState(() => _isPressed = false);
                  Navigator.pop(context);
                },
                child: Image.asset(
                  _isPressed ? 'assets/images/button/bt-hover-Back.png' : 'assets/images/button/bt-Back.png',
                  width: 50,
                  height: 50,
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: Center(
              child: Text(
                "สมาชิกที่ยังไม่เสร็จ",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 การ์ดสมาชิกที่ถูกตัดปุ่มไล่ออกและแถบเควสออก
  Widget _buildMemberCard(Map<String, dynamic> member) {
    final String name = member['name'] ?? 'ไม่มีชื่อ';
    final String detail = member['detail'] ?? '';
    final int level = member['level'] ?? 1;
    final String memberId = member['id'];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => PlayerProfileScreen(playerId: memberId),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8F8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF9DD0E7), width: 2),
        ),
        child: IntrinsicHeight(
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
                                  border: Border.all(color: Colors.transparent, width: 2),
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
                                border: Border.all(color: const Color(0xFF9DD0E7), width: 1.5),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$level',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black, height: 1.1),
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
                          color: const Color(0xFFCBE7F5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          "สมาชิก",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
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
                      Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                      const SizedBox(height: 6),
                      Text(
                        detail.isEmpty ? 'ไม่มีคำแนะนำตัว' : detail,
                        style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
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
      ),
    );
  }
}