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
  late String _endDate;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    final q = widget.questData;
    _title = q['name'] ?? 'ไม่มีชื่อภารกิจ';
    _description = q['detail'] ?? 'ไม่มีรายละเอียด';

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
  }

  // 🌟 2. ฟังก์ชันเช็คคูลดาวน์ก่อนไปหน้าตอบคำถาม
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

      // ดึงประวัติการทำเควสนี้ของผู้ใช้
      final doQuest = await supabase
          .from('do_quests')
          .select('status, last_attempt_date')
          .eq('user_id', userId)
          .eq('quest_id', questId)
          .maybeSingle();

      if (mounted) Navigator.pop(context); // ปิด Loading

      if (doQuest != null) {
        final status = doQuest['status'];
        final lastAttemptStr = doQuest['last_attempt_date'];

        // ถ้าสถานะคือ failed และมีเวลาครั้งล่าสุดบอกไว้ ให้เช็คว่าครบ 10 นาทีหรือยัง
        if (status == 'failed' && lastAttemptStr != null) {
          final lastAttempt = DateTime.parse(lastAttemptStr).toLocal();
          final now = DateTime.now();
          final difference = now.difference(lastAttempt);
          
          if (difference.inMinutes < 10) {
            // คำนวณเวลาที่เหลือ
            final remainingSeconds = 600 - difference.inSeconds;
            final minutes = remainingSeconds ~/ 60;
            final seconds = remainingSeconds % 60;
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('คุณตอบผิดไป! โปรดรออีก $minutes นาที $seconds วินาที ถึงจะตอบใหม่ได้'),
                  backgroundColor: Colors.orange.shade800,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
            return; // หยุดการทำงาน ไม่ให้ข้ามหน้า
          }
        }
      }

      // 🌟 ถ้าไม่ติดคูลดาวน์ หรือไม่เคยทำมาก่อน ให้ไปหน้าตอบคำถามได้
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
                              Padding(
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
    return Positioned(
      bottom: bottomPadding + 20,
      left: MediaQuery.of(context).size.width * 0.1,
      right: MediaQuery.of(context).size.width * 0.1,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: widget.isCompleted
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 28),
                      SizedBox(width: 8),
                      Text(
                        'ภารกิจสำเร็จ',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green, 
                        ),
                      ),
                    ],
                  )
                : _buildButton(
                    text: 'ตอบคำถาม',
                    color: Color(0xFF4A8FE7),
                    useGradient: true,
                    // 🌟 3. เปลี่ยนจากกดแล้วไปเลย เป็นเรียกฟังก์ชันเช็คคูลดาวน์ก่อน
                    onPressed: _checkCooldownAndProceed, 
                  ),
          ),
        ],
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