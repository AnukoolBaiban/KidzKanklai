import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 🌟 1. อย่าลืม Import Supabase
import '../../widgets/custom_top_bar.dart';
import '../../api_service.dart';
import '../../screens/lobby.dart';
import '../../widgets/confirm_giveup_popup.dart';
import '../../widgets/reward_popup.dart';
import 'club_quest_quiz_member.dart';


class ClubQuestDetailScreen extends StatefulWidget {
  final Map<String, dynamic> questData; 
  final bool isCompleted; 

  const ClubQuestDetailScreen({
    Key? key, 
    required this.questData,
    this.isCompleted = false, 
  }) : super(key: key);

  @override
  State<ClubQuestDetailScreen> createState() => _ClubQuestDetailScreenState();
}

class _ClubQuestDetailScreenState extends State<ClubQuestDetailScreen> {
  bool _isPressed = false;

  late String _title;
  late String _description;
  late String _startDate;
  late String _endDate;
  String? _imagePath;

  int _totalMembers = 0;
  int _completedMembers = 0;

  @override
  void initState() {
    super.initState();
    final q = widget.questData;
    _title = q['name'] ?? 'ไม่มีชื่อภารกิจ';
    _description = q['detail'] ?? 'ไม่มีรายละเอียด';

    if (q['start_date'] != null) {
      try {
        DateTime parsed = DateTime.parse(q['start_date']).toLocal();
        String dd = parsed.day.toString().padLeft(2, '0');
        String mm = parsed.month.toString().padLeft(2, '0');
        String yy = (parsed.year + 543).toString().substring(2);
        _startDate = "$dd/$mm/$yy";
      } catch (e) {
        _startDate = "--/--/--";
      }
    } else {
      _startDate = "--/--/--";
    }

    if (q['due_date'] != null) {
      try {
        DateTime parsed = DateTime.parse(q['due_date']).toLocal();
        String dd = parsed.day.toString().padLeft(2, '0');
        String mm = parsed.month.toString().padLeft(2, '0');
        String yy = (parsed.year + 543).toString().substring(2);
        _endDate = "$dd/$mm/$yy";
      } catch (e) {
        _endDate = "--/--/--";
      }
    } else {
      _endDate = "--/--/--";
    }

    String? img = q['image'];
    if (img != null && img.isNotEmpty) {
      _imagePath = img;
    } else {
      _imagePath = null;
    }

    _fetchQuestProgress();
  }

  // 🌟 ฟังก์ชันสำหรับแสดง Dialog รูปภาพแบบเต็ม
  void _showFullScreenImage(BuildContext context, String path) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9), // พื้นหลังดำเข้มโปร่งแสง
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero, // ให้ขยายเต็มหน้าจอ
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 🌟 สามารถบีบซูมรูปได้
              InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: path.startsWith('http')
                    ? Image.network(path, fit: BoxFit.contain)
                    : Image.asset(path, fit: BoxFit.contain),
              ),
              // ปุ่มปิดสีขาวมุมขวาบน
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🌟 ฟังก์ชันดึงสถิติคนที่ทำเควสนี้
  Future<void> _fetchQuestProgress() async {
    try {
      final supabase = Supabase.instance.client;
      
      final clubId = widget.questData['club_id'];
      final questId = widget.questData['id'];

      if (clubId == null || questId == null) return;

      // 1. นับจำนวนลูกน้องในคลับ
      final membersRes = await supabase
          .from('user_profiles')
          .select('id')
          .eq('club_id', clubId)
          .neq('club_role', 'owner');
      
      final total = (membersRes as List).length;

      // 2. นับคนที่ทำเควสนี้เสร็จ
      final doQuestsRes = await supabase
          .from('do_quests')
          .select('user_id') 
          .eq('quest_id', questId)
          .eq('status', 'completed');
          
      final completed = (doQuestsRes as List).length;

      if (mounted) {
        setState(() {
          _totalMembers = total;
          _completedMembers = completed;
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching progress: $e");
    }
  }

  // 🌟 2. ฟังก์ชันเช็คคูลดาวน์ และตรวจสอบว่ามีคำถามหรือไม่
  Future<void> _checkCooldownAndProceed() async {
    // แสดง Loading ระหว่างเช็คข้อมูล
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;
      final questId = widget.questData['id'];
      
      // ดึง passing_score มาเพื่อเช็คว่ามีคำถามไหม
      final int passingScore = widget.questData['passing_score'] ?? 1;

      // ดึงประวัติการทำเควสนี้ของผู้ใช้
      final doQuest = await supabase
          .from('do_quests')
          .select('status, last_attempt_date')
          .eq('user_id', userId)
          .eq('quest_id', questId)
          .maybeSingle();

      if (mounted && passingScore > 0) {
        Navigator.pop(context); // ปิด Loading (เฉพาะกรณีที่มีคำถาม เพราะต้องไปหน้าถัดไป)
      }

      if (doQuest != null) {
        final status = doQuest['status'];
        final lastAttemptStr = doQuest['last_attempt_date'];

        // เช็คคูลดาวน์ 10 นาที
        if (status == 'failed' && lastAttemptStr != null) {
          final lastAttempt = DateTime.parse(lastAttemptStr).toLocal();
          final now = DateTime.now();
          final difference = now.difference(lastAttempt);
          
          if (difference.inMinutes < 10) {
            if (mounted && passingScore == 0) Navigator.pop(context); // ปิด Loading

            final remainingSeconds = 600 - difference.inSeconds;
            final minutes = remainingSeconds ~/ 60;
            final seconds = remainingSeconds % 60;
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('โปรดรออีก $minutes นาที $seconds วินาที ถึงจะทำภารกิจใหม่ได้'),
                  backgroundColor: Colors.orange.shade800,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
            return; // หยุดการทำงาน
          }
        }
      }

      // 🌟 แยกลอจิก: ถ้า "ไม่มีคำถาม" ให้ยิง API และโชว์ RewardPopup
      if (passingScore == 0) {
        // 1. ดึง Profile ก่อนเรียก API เพื่อบันทึก Level เดิม
        final profileBefore = await ApiService.getProfile(0);
        final oldLevel = profileBefore?.level ?? 0;

        // 2. ยิง API ส่งเควส (ส่ง array ว่างเพราะไม่มีคำถาม)
        Map<String, dynamic> requestData = {
          "quest_id": questId,
          "answers": [], 
        };
        final result = await ApiService.submitClubQuest(requestData);
        
        if (mounted) Navigator.pop(context); // ปิด Loading หลังยิง API เสร็จ

        // 3. จัดการผลลัพธ์
        if (mounted) {
          if (result != null && result['success'] == true) {
            
            // ดึง Profile ใหม่หลัง API ทำงานเสร็จเพื่อเปรียบเทียบ Level
            final freshProfile = await ApiService.getProfile(0);
            final actualNewLevel = freshProfile?.level ?? oldLevel;
            final didLevelUp = actualNewLevel > oldLevel;

            final apiRewards = (result['rewards'] as List?) ?? [];

            // 🌟 เช็คว่ามีของรางวัลให้โชว์หรือไม่
            if (apiRewards.isNotEmpty) {
              // แปลงข้อมูลจาก API เป็น RewardData
              List<RewardData> popupRewards = apiRewards.map<RewardData>((rw) {
                final String rwName = (rw['name'] ?? '').toUpperCase();
                final int rwItemId = rw['item_id'] ?? 0;
                // 🌟 ตรวจสอบ item_id ก่อน (20=Coin, 22=EXP) แล้ว fallback ไปเช็ค item_type/name
                final String rwItemType = (rw['item_type'] ?? '').toUpperCase();
                String rwType = 'ITEM';
                if (rwItemId == 22 || rwItemType == 'EXP' || rwName.contains('EXP')) {
                  rwType = 'EXP';
                } else if (rwItemId == 20 || rwItemType == 'COIN' || rwItemType == 'CURRENCY' ||
                    rwName.contains('COIN') || rwName.contains('เหรียญ')) {
                  rwType = 'COIN';
                }

                return RewardData(
                  type: rwType,
                  amount: rw['amount'] ?? 0,
                  itemName: rw['name'],
                  itemImage: rw['image'],
                );
              }).toList();

              // เรียกหน้าต่างของรางวัล (แบบที่คุณทำใน QuestDetailScreen)
              await RewardPopup.show(
                context, 
                rewards: popupRewards,
                leveledUp: didLevelUp,
                baseLevel: oldLevel,
                newLevel: actualNewLevel,
                user: freshProfile,
              );
            } else {
              // ถ้าสำเร็จแต่ไม่มีของรางวัล
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ทำภารกิจสำเร็จ!'),
                  backgroundColor: Colors.green,
                ),
              );
              await Future.delayed(const Duration(seconds: 1));
              
              // 🌟 กรณีไม่มีของรางวัล แต่มีการเลเวลอัพ
              if (mounted && didLevelUp) {
                await RewardPopup.show(
                  context, 
                  rewards: [],
                  leveledUp: true,
                  baseLevel: oldLevel,
                  newLevel: actualNewLevel,
                  user: freshProfile,
                );
              }
            }

            // 🌟 เด้งกลับหน้าเดิม พร้อมส่งค่า true ไปบอกให้รีเฟรชข้อมูลเควส
            if (mounted) {
              Navigator.pop(context, true); 
            }

          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result?['error'] ?? 'เกิดข้อผิดพลาด'), backgroundColor: Colors.red),
            );
          }
        }

      } else {
        // 🌟 ลอจิกเดิม: ถ้า "มีคำถาม" ก็เด้งไปหน้าทำ Quiz ตามปกติ
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClubQuestQuizMemberScreen(
                questId: questId,
              ),
            ),
          );
        }
      }

    } catch (e) {
      if (mounted) Navigator.pop(context); // ปิด Loading กรณี Error
      debugPrint("Check cooldown error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เกิดข้อผิดพลาดในการตรวจสอบข้อมูล'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topBarHeight = 75.0 + topPadding;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          _buildBackground(),

          Column(
            children: [
              // Top Bar
              _buildTopBar(topPadding),

              // Main Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: 10,
                    left: size.width * 0.05,
                    right: size.width * 0.05,
                    bottom: bottomPadding + 100,
                  ),
                  child: Column(
                    children: [
                      // Back Button
                      Row(children: [_buildBackButton()]),

                      SizedBox(height: 10),

                      // Content Card
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Color(0xFFAAD7EA), width: 3),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Scrollable Content
                              Column(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _title,
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF447199),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'สร้าง $_startDate',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              Text(
                                                'วันที่สิ้นสุด $_endDate',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 5),

                                      Container(height: 2, color: Color(0xFFB3E5FC)),

                                      SizedBox(height: 20),

                                      if (_imagePath != null) ...[
                                        Container(
                                          width: double.infinity,
                                          padding: EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(
                                              color: Color(0xFF9DD0E7),
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.1),
                                                blurRadius: 8,
                                                offset: Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'รูปภาพ',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF002A50),
                                                ),
                                              ),
                                              SizedBox(height: 12),
                                              LayoutBuilder(
                                                builder: (context, constraints) {
                                                  return Center(
                                                    child: Container(
                                                      width: constraints.maxWidth * 0.6,
                                                      constraints: BoxConstraints(
                                                        maxWidth: 300,
                                                        maxHeight: 300,
                                                      ),
                                                      child: AspectRatio(
                                                        aspectRatio: 1,
                                                        child: GestureDetector(
                                                          onTap: () => _showFullScreenImage(context, _imagePath!),
                                                          child: ClipRRect(
                                                            borderRadius: BorderRadius.circular(12),
                                                            child: Image.network(
                                                              _imagePath!,
                                                              fit: BoxFit.cover,
                                                              errorBuilder: (context, error, stackTrace) {
                                                                return Container(
                                                                  color: Color(0xFFE8F4F8),
                                                                  child: Center(
                                                                    child: Icon(
                                                                      Icons.broken_image,
                                                                      size: 60,
                                                                      color: Colors.grey,
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: 20),
                                      ],

                                      Text(
                                        _description,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF313131),
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              child: Column(
                                children: [
                                  // 🌟 1. ข้อความสรุปจำนวน
                                  Builder(builder: (context) {
                                    final bool allDone = _totalMembers > 0 && _completedMembers >= _totalMembers;
                                    return Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: allDone ? const Color(0xFFE6F9EE) : const Color(0xFFE8F4F8),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: allDone ? const Color(0xFF34C759) : const Color(0xFF9DD0E7),
                                        ),
                                      ),
                                      child: allDone
                                          ? const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.check_circle, color: Color(0xFF34C759), size: 18),
                                                SizedBox(width: 8),
                                                Text(
                                                  'สมาชิกทุกคนทำภารกิจนี้สำเร็จแล้ว',
                                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF34C759)),
                                                ),
                                              ],
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text(
                                                  'ความคืบหน้าภารกิจของสมาชิก',
                                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF002A50)),
                                                ),
                                                Text(
                                                  '$_completedMembers / $_totalMembers คน',
                                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2374B5)),
                                                ),
                                              ],
                                            ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),

                        Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: _buildHeaderTitle(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Bottom Buttons
          _buildBottomButtons(bottomPadding),
        ],
      ),
    );
  }

  // ==================== Components ====================

  Widget _buildBackground() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        color: const Color(0xFFE2F5FD),
        alignment: Alignment.center,
        child: Image.asset(
          "assets/images/background/bg-head.png",
          fit: BoxFit.contain,
          width: MediaQuery.of(context).size.width * 0.8,
          errorBuilder: (context, error, stackTrace) {
            return Container();
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(double topPadding) {
    return Container(
        padding: EdgeInsets.only(top: topPadding),
        color: Colors.black.withOpacity(0.4),
        child: CustomTopBar(
          onNotificationTapped: () =>
              Navigator.pushNamed(context, '/notification'),
          onSettingsTapped: () => Navigator.pushNamed(context, '/setting'),
        ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () async {
        await Future.delayed(const Duration(milliseconds: 150));
        if (mounted) {
          Navigator.pop(context);
        }
      },
      child: Image.asset(
        _isPressed
            ? 'assets/images/button/bt-hover-Back.png'
            : 'assets/images/button/bt-Back.png',
        width: 50,
        height: 50,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back, color: Color(0xFF2374B5)),
          );
        },
      ),
    );
  }

  Widget _buildHeaderTitle() {
    return Align(
      alignment: Alignment.topCenter,
      child: FractionalTranslation(
        translation: const Offset(0, -0.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2374B5),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Text(
            "รายละเอียด",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButtons(double bottomPadding) {
    // 🌟 1. ดึงค่า passing_score เพื่อเช็คว่ามีคำถามหรือไม่ (ถ้าเป็น 0 คือไม่มีคำถาม)
    final int passingScore = widget.questData['passing_score'] ?? 1;
    
    // 🌟 2. กำหนดข้อความปุ่มตามเงื่อนไข
    final String buttonText = passingScore > 0 ? 'ตอบคำถาม' : 'สำเร็จภารกิจ';

    if (widget.isCompleted) {
      return Positioned(
        bottom: bottomPadding + 30,
        left: 0,
        right: 0,
        child: const Center(
          child: Text(
            'ภารกิจสำเร็จ',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6CC732),
            ),
          ),
        ),
      );
    }

    return Positioned(
      bottom: bottomPadding + 20,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 150,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF556AEB), Color(0xFF59ABEC)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4A8FE7).withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _checkCooldownAndProceed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: Text(
              buttonText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
    bool useGradient = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: useGradient ? null : color,
        gradient: useGradient
            ? LinearGradient(
                colors: [Color(0xFF556AEB), Color(0xFF59ABEC)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}