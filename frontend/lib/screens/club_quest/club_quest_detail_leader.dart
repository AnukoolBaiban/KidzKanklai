import 'package:flutter/material.dart';
import '../../widgets/custom_top_bar.dart';
import '../../api_service.dart';
import 'club_quest_quiz_answer.dart';
import 'create_club_quest.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 🌟 เพิ่มบรรทัดนี้
import 'incomplete_member.dart'; // 🌟 Import ไฟล์ใหม่

class ClubQuestDetailLeaderScreen extends StatefulWidget {
  final Map<String, dynamic> questData; // 🌟 รับข้อมูลเควส

  const ClubQuestDetailLeaderScreen({
    Key? key, 
    required this.questData, // 🌟 บังคับใส่ข้อมูล
  }) : super(key: key);

  @override
  State<ClubQuestDetailLeaderScreen> createState() => _ClubQuestDetailLeaderScreenState();
}

class _ClubQuestDetailLeaderScreenState extends State<ClubQuestDetailLeaderScreen> {
  bool _isPressed = false;

  // 🌟 ตัวแปรสำหรับเก็บข้อมูลจริง
  late String _title;
  late String _description;
  late String _endDate;
  String? _imagePath;

  int _totalMembers = 0;
  int _completedMembers = 0;

  @override
  void initState() {
    super.initState();
    // 🌟 ดึงข้อมูลจาก widget.questData มาเซ็ตค่า
    final q = widget.questData;
    _title = q['name'] ?? 'ไม่มีชื่อภารกิจ';
    _description = q['detail'] ?? 'ไม่มีรายละเอียด';

    // จัดการวันที่สิ้นสุดให้อยู่ในรูปแบบ วว/ดด/ปป (พ.ศ.)
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

    // ตรวจสอบรูปภาพ
    String? img = q['image'];
    if (img != null && img.isNotEmpty) {
      _imagePath = img;
    } else {
      _imagePath = null;
    }

    _fetchQuestProgress(); // 🌟 เรียกใช้ตอนเปิดหน้า
  }

  // 🌟 ฟังก์ชันดึงข้อมูลคำถามและส่งไปหน้าแก้ไข
  Future<void> _navigateToEditQuest() async {
    // 1. โชว์วงกลมโหลดก่อน
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 2. ดึงคำถามจาก Supabase
      final supabase = Supabase.instance.client;
      final questionsRes = await supabase
          .from('quest_questions')
          .select('*')
          .eq('quest_id', widget.questData['id']);

      if (!mounted) return;
      Navigator.pop(context); // ปิดโหลด

      // 3. เตรียมข้อมูล
      Map<String, dynamic> editData = Map<String, dynamic>.from(widget.questData);
      editData['questions'] = questionsRes; // ยัดคำถามที่ดึงมาใส่เข้าไป
      editData['imageUrl'] = widget.questData['image']; // URL รูปภาพ
      
      // แปลงวันที่ให้เป็น DateTime เพื่อส่งให้ปฏิทินในหน้าฟอร์ม
      if (widget.questData['due_date'] != null) {
        editData['date'] = DateTime.parse(widget.questData['due_date']).toLocal();
      }

      // 4. เปิดหน้าฟอร์ม
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateClubQuestScreen(
            isEditing: true, // 🌟 เปิดโหมดแก้ไข
            initialData: editData, // 🌟 ส่งข้อมูลเก่าที่เตรียมไว้เข้าไปให้ครบ
            onSubmit: (data) {}, 
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // ปิดโหลดกรณี Error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถดึงข้อมูลคำถามได้'), backgroundColor: Colors.red),
      );
    }
  }

  // 🌟 ฟังก์ชันดึงสถิติคนที่ทำเควสนี้
  Future<void> _fetchQuestProgress() async {
    try {
      final supabase = Supabase.instance.client;
      
      // ดึงค่า ID มาเช็คก่อนว่าไม่เป็น null
      final clubId = widget.questData['club_id'];
      final questId = widget.questData['id'];

      if (clubId == null || questId == null) {
        debugPrint("❌ Error: clubId หรือ questId เป็น null");
        return;
      }

      // 1. นับจำนวนลูกน้องในคลับ (user_profiles มีคอลัมน์ id)
      final membersRes = await supabase
          .from('user_profiles')
          .select('id')
          .eq('club_id', clubId)
          .neq('club_role', 'owner');
      
      final total = (membersRes as List).length;

      // 2. นับคนที่ทำเควสนี้เสร็จ (🌟 เปลี่ยนจาก 'id' เป็น 'user_id' ป้องกัน Error คอลัมน์ไม่มี)
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
      // 🌟 พิมพ์ Error ออกมาดูว่าติดปัญหาอะไร
      debugPrint("❌ Error fetching progress: $e");
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
                    bottom: bottomPadding + 100, // เว้นที่ให้ปุ่ม
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
                                      // Quest Title and Dates
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _title, // 🌟 แสดงชื่อจริง
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
                                                'วันที่สิ้นสุด $_endDate', // 🌟 แสดงวันที่จริง
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

                                      // รูปภาพ Section
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
                                                          // 🌟 เปลี่ยน Image.asset เป็น Image.network สำหรับดึงภาพจริง
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

                                      // Description
                                      Text(
                                        _description, // 🌟 แสดงรายละเอียดจริง
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF313131),
                                          height: 1.5,
                                        ),
                                      ),

                                      const SizedBox(height: 24), // 🌟 เพิ่มระยะห่าง

                                      // 🌟 1. ข้อความสรุปจำนวน
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE8F4F8),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFF9DD0E7)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'ความคืบหน้าภารกิจ',
                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF002A50)),
                                            ),
                                            Text(
                                              '$_completedMembers / $_totalMembers คน',
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2374B5)),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 12),

                                      // 🌟 2. ปุ่มดูรายชื่อคนที่ยังไม่เสร็จ
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => IncompleteMembersScreen(
                                                  questId: widget.questData['id'],
                                                  clubId: widget.questData['club_id'],
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.people_alt, color: Colors.white),
                                          label: const Text(
                                            'สมาชิกที่ยังไม่เสร็จภารกิจ',
                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFEA4444),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Header "รายละเอียด"
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
          // 🌟 ให้ใช้ pop() เพื่อย้อนกลับไปหน้าเดิม
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
        children: [
          Expanded(
            child: _buildButton(
              text: 'ดูคำถาม',
              color: Color(0xFF34C759),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClubQuestQuizAnswerScreen(
                      questId: widget.questData['id'],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(width: 20),
          Expanded(
            child: _buildButton(
              text: 'แก้ไข',
              color: Color(0xFF4A8FE7),
              useGradient: true,
              onPressed: _navigateToEditQuest, // 🌟 เปลี่ยนมาเรียกฟังก์ชันที่เราสร้างไว้
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