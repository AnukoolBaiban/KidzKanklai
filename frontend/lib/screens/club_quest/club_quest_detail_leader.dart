import 'package:flutter/material.dart';
import '../../widgets/custom_top_bar.dart';
import '../../api_service.dart';
import 'club_quest_quiz_answer.dart';
import 'create_club_quest.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 🌟 เพิ่มบรรทัดนี้
import '../../widgets/club/incomplete_member_popup.dart'; // 🌟 Import ไฟล์ใหม่

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
  late String _startDate;
  late String _endDate;
  String? _imagePath;

  int _totalMembers = 0;
  int _completedMembers = 0;
  bool _hasQuestions = false;

  @override
  void initState() {
    super.initState();
    // 🌟 ดึงข้อมูลจาก widget.questData มาเซ็ตค่า
    final q = widget.questData;
    _title = q['name'] ?? 'ไม่มีชื่อภารกิจ';
    _description = q['detail'] ?? 'ไม่มีรายละเอียด';

    // จัดการวันที่สร้างและวันที่สิ้นสุด
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
      
      final clubId = widget.questData['club_id'];
      final questId = widget.questData['id'];

      if (clubId == null || questId == null) {
        debugPrint("❌ Error: clubId หรือ questId เป็น null");
        return;
      }

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

      // 3. เช็คว่าภารกิจนี้มีคำถามหรือไม่
      final questionsRes = await supabase
          .from('quest_questions')
          .select('id')
          .eq('quest_id', questId);

      final hasQ = (questionsRes as List).isNotEmpty;

      if (mounted) {
        setState(() {
          _totalMembers = total;
          _completedMembers = completed;
          _hasQuestions = hasQ;
        });
      }
    } catch (e) {
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
                              Column(
                                children: [
                                  Expanded(
                                    child: Padding(
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
                                                'สร้าง $_startDate',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
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
                                                        child: GestureDetector(
                                                          onTap: () => _showFullScreenImage(context, _imagePath!),
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
                                        final bool isCompleted = _totalMembers > 0 && _completedMembers >= _totalMembers;
                                        return Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isCompleted
                                                ? const Color(0xFFE6F9EE)
                                                : (_totalMembers == 0
                                                    ? const Color(0xFFFFF5F5)
                                                    : const Color(0xFFE8F4F8)),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isCompleted
                                                  ? const Color(0xFF34C759)
                                                  : (_totalMembers == 0
                                                      ? const Color(0xFFEA4444)
                                                      : const Color(0xFF9DD0E7)),
                                            ),
                                          ),
                                          child: isCompleted
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
                                              : (_totalMembers == 0
                                                  ? const Center(
                                                      child: Text(
                                                        'ไม่มีสมาชิกในชมรม คุณจะไม่ได้รับของรางวัล',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.bold,
                                                          color: Color(0xFFEA4444),
                                                        ),
                                                      ),
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
                                                    )),
                                        );
                                      }),

                                      const SizedBox(height: 12),

                                      // 🌟 2. ปุ่มดูรายชื่อคนที่ยังไม่เสร็จ (ซ่อนเมื่อทุกคนทำเสร็จแล้ว หรือไม่มีสมาชิกเลย)
                                      if (_totalMembers > 0 && _completedMembers < _totalMembers)
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            IncompleteMemberPopup.show(
                                              context,
                                              questId: widget.questData['id'],
                                              clubId: widget.questData['club_id'],
                                            );
                                          },
                                          icon: const Icon(Icons.people_alt, color: Colors.white),
                                          label: const Text(
                                            'รายชื่อสมาชิกที่ยังทำภารกิจไม่สำเร็จ',
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
                              ],
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
    final bool isCompleted = _totalMembers > 0 && _completedMembers >= _totalMembers;

    // ภารกิจสำเร็จแล้ว
    if (isCompleted) {
      if (_hasQuestions) {
        // มีคำถาม → ปุ่มเขียว "ดูคำถาม" แทน
        return Positioned(
          bottom: bottomPadding + 20,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 150,
              decoration: BoxDecoration(
                color: const Color(0xFF34C759),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF34C759).withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'ดูคำถาม',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        // ไม่มีคำถาม → ข้อความ "ภารกิจสำเร็จ" แบบเดิม
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
    }

    // ภารกิจยังไม่เสร็จ → ปุ่มแก้ไข
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
                color: const Color(0xFF4A8FE7).withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _navigateToEditQuest,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'แก้ไข',
              style: TextStyle(
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