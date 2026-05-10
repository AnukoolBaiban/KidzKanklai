import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/api_service.dart' as api;
import 'package:flutter_application_1/screens/player_profile.dart' hide GradientCircularProgressPainter;
import 'package:flutter_application_1/widgets/character_widget.dart';
import 'package:flutter_application_1/widgets/bottom_navigation_bar.dart'; // สำหรับ GradientCircularProgressPainter

class IncompleteMemberPopup extends StatefulWidget {
  final int questId;
  final int clubId;

  const IncompleteMemberPopup({
    Key? key,
    required this.questId,
    required this.clubId,
  }) : super(key: key);

  static Future<void> show(BuildContext context, {required int questId, required int clubId}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => IncompleteMemberPopup(questId: questId, clubId: clubId),
    );
  }

  @override
  State<IncompleteMemberPopup> createState() => _IncompleteMemberPopupState();
}

class _IncompleteMemberPopupState extends State<IncompleteMemberPopup> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _incompleteMembers = [];
  int _totalMembers = 0;

  @override
  void initState() {
    super.initState();
    _fetchIncompleteMembers();
  }

  // --- Functions from incomplete_member.dart ---
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

  Future<void> _fetchIncompleteMembers() async {
    try {
      final supabase = Supabase.instance.client;

      final membersResponse = await supabase
          .from('user_profiles')
          .select('id, name, detail, club_role')
          .eq('club_id', widget.clubId)
          .neq('club_role', 'owner');

      final doQuestsResponse = await supabase
          .from('do_quests')
          .select('user_id')
          .eq('quest_id', widget.questId)
          .eq('status', 'completed');

      final Set<String> completedUserIds = (doQuestsResponse as List<dynamic>)
          .map((dq) => dq['user_id'].toString())
          .toSet();

      final List<Map<String, dynamic>> incompleteList = [];
      for (final member in membersResponse as List<dynamic>) {
        final memberId = member['id'].toString();
        
        if (!completedUserIds.contains(memberId)) {
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
          _totalMembers = (membersResponse as List).length;
          _incompleteMembers = incompleteList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching incomplete members: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
  // --- End of functions from incomplete_member.dart ---

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      elevation: 0,
      child: Center(
        child: Container(
          width: size.width * 0.9,
          height: 550, // บังคับความสูง
          constraints: const BoxConstraints(maxWidth: 350, maxHeight: 550),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // 1) พื้นหลัง Background Split
              Positioned.fill(
                child: Column(
                  children: [
                    Container(
                      height: 120, // ความสูงพื้นที่สีฟ้าเข้ม
                      color: const Color(0xFF9DD0E7),
                    ),
                    Expanded(
                      child: Container(
                        color: const Color(0xFFC6F4FF), // สีฟ้าอ่อน
                      ),
                    ),
                  ],
                ),
              ),

              // 2) Content
              Column(
                mainAxisSize: MainAxisSize.max, // ให้ Content ขยายเต็ม Stack
                children: [
                  // Header
                  SizedBox(
                    height: 65,
                    child: Stack(
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 56.0),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: const Text(
                                'รายชื่อสมาชิกที่ยังทำภารกิจไม่สำเร็จ',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF002A50),
                                  shadows: [
                                    Shadow(color: Colors.white, offset: Offset(1.5, 1.5), blurRadius: 1),
                                    Shadow(color: Colors.white, offset: Offset(-1.5, -1.5), blurRadius: 1),
                                    Shadow(color: Colors.white, offset: Offset(1.5, -1.5), blurRadius: 1),
                                    Shadow(color: Colors.white, offset: Offset(-1.5, 1.5), blurRadius: 1),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // ปุ่มปิด X
                        Positioned(
                          right: 16,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(
                                Icons.close,
                                color: Color.fromARGB(255, 255, 255, 255),
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // กล่องสีขาวด้านใน
                  Expanded( // ขยายเต็มที่เหลือของ Column
                    child: Container(
                      margin: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _isLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _incompleteMembers.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: Text(
                                      'สมาชิกทุกคนทำภารกิจนี้เสร็จแล้ว! 🎉',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                )
                              : Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                                      child: Text(
                                        'จำนวน ${_incompleteMembers.length}/$_totalMembers คน',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF447199),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: ScrollConfiguration(
                                        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                                        child: ListView.builder(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          shrinkWrap: true,
                                          physics: const BouncingScrollPhysics(),
                                          itemCount: _incompleteMembers.length,
                                          itemBuilder: (context, index) {
                                            return _buildMemberCard(_incompleteMembers[index]);
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final String name = member['name'] ?? 'ไม่มีชื่อ';
    final String detail = member['detail'] ?? '';
    final int level = member['level'] ?? 1;
    final String memberId = member['id'].toString();

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
                width: 90, // ปรับลดขนาดเล็กน้อยเพื่อให้พอดี popup
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
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
                                size: const Size(60, 60), // ย่อขนาด
                                painter: GradientCircularProgressPainter(
                                  progress: member['user_obj'] != null ? _getExpPercent(member['user_obj'].level, member['user_obj'].exp) : 0.0,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF88FF40), Color(0xFF66E0FF)],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                  strokeWidth: 3,
                                ),
                              ),
                              Container(
                                width: 54, // ย่อขนาด
                                height: 54, // ย่อขนาด
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(color: Colors.transparent, width: 2),
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: IgnorePointer(
                                  child: Transform.translate(
                                    offset: const Offset(2, 10), // ย่อขนาด
                                    child: Transform.scale(
                                      scale: 1.4, // ย่อขนาด
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
                              width: 24, // ย่อขนาด
                              height: 24, // ย่อขนาด
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
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black, height: 1.1), // ย่อขนาด
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        padding: const EdgeInsets.symmetric(vertical: 2), // ย่อขนาด
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBE7F5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          "สมาชิก",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black), // ย่อขนาด
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
                      Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)), // ย่อขนาด
                      const SizedBox(height: 4),
                      Text(
                        detail.isEmpty ? 'ไม่มีคำแนะนำตัว' : detail,
                        style: const TextStyle(fontSize: 11, color: Colors.black87, height: 1.3), // ย่อขนาด
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
