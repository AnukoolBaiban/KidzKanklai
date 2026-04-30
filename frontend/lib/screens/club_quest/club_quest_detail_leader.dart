import 'package:flutter/material.dart';
import '../../widgets/custom_top_bar.dart';
import '../../api_service.dart';
import 'club_quest_quiz_answer.dart';
import 'create_club_quest.dart';

class ClubQuestDetailLeaderScreen extends StatefulWidget {
  final User? user;
  final Map<String, dynamic> questData; // 🌟 รับข้อมูลเควส

  const ClubQuestDetailLeaderScreen({
    Key? key, 
    this.user, 
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

          // Top Bar
          _buildTopBar(topPadding, topBarHeight),

          // Main Content
          Padding(
            padding: EdgeInsets.only(
              top: topBarHeight + 10,
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

  Widget _buildTopBar(double topPadding, double height) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: height,
        padding: EdgeInsets.only(top: topPadding),
        color: Colors.black.withOpacity(0.4),
        alignment: Alignment.bottomCenter,
        child: CustomTopBar(
          onNotificationTapped: () =>
              Navigator.pushNamed(context, '/notification'),
          onSettingsTapped: () => Navigator.pushNamed(context, '/setting'),
        ),
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
      bottom: bottomPadding + 40,
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
                      questId: widget.questData['id'], // 🌟 ส่ง ID ไปยังหน้าดูคำถาม
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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => CreateClubQuestScreen(
                          user: widget.user,
                          isEditing: true,
                          initialData: {
                            'id': widget.questData['id'],
                            'name': _title,
                            'detail': _description,
                            'minScore': widget.questData['passing_score'] ?? 2,
                            // 'questions': [] // ข้อมูลคำถามจริงอาจต้องดึงเพิ่ม หรือให้หน้า Edit ไปดึงเอง
                          },
                          onSubmit: (data) {
                            debugPrint('Updated Data: $data');
                            Navigator.pop(context);
                          },
                        ),
                  ),
                );
              },
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
          padding: EdgeInsets.symmetric(vertical: 20),
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