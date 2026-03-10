import 'package:flutter/material.dart';
import '../widgets/custom_top_bar.dart';
import '../api_service.dart';

class QuestDetailScreen extends StatefulWidget {
  final QuestItem quest;
  final User? user;

  const QuestDetailScreen({
    Key? key,
    required this.quest,
    this.user,
  }) : super(key: key);

  @override
  State<QuestDetailScreen> createState() => _QuestDetailScreenState();
}

class _QuestDetailScreenState extends State<QuestDetailScreen> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/BG1.png'),
            fit: BoxFit.cover,
            onError: (exception, stackTrace) {},
          ),
          color: Color(0xFFE3F2FD),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              CustomTopBar(
                onNotificationTapped: () {
                  Navigator.pushNamed(context, '/notification');
                },
                onSettingsTapped: () {
                  Navigator.pushNamed(context, '/settings');
                },
              ),

              // Back Button
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTapDown: (_) => setState(() => _isPressed = true),
                      onTapUp: (_) => setState(() => _isPressed = false),
                      onTapCancel: () => setState(() => _isPressed = false),
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Image.asset(
                        _isPressed
                            ? 'assets/bt-hover-Back.png'
                            : 'assets/bt-Back.png',
                        width: 50,
                        height: 50,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.arrow_back,
                              color: Color(0xFF2374B5),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // White Container
                      Container(
                        margin: EdgeInsets.only(top: 30),
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Color(0xFF2374B5),
                            width: 3,
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 40),

                              // Quest Name Section
                              _buildSectionTitle('สรุปคณิตบทที่ 1'),

                              SizedBox(height: 16),

                              // Dates
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'เริ่ม 25/06/06',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    'สิ้นสุด 27/06/06',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 24),

                              // รูปภาพ Section
                              Text(
                                'รูปภาพ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),

                              SizedBox(height: 12),

                              // Image Preview
                              Center(
                                child: Container(
                                  width: 180,
                                  height: 220,
                                  decoration: BoxDecoration(
                                    color: Color(0xFFE8F4F8),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Color(0xFFB3E5FC),
                                      width: 2,
                                    ),
                                  ),
                                  child: widget.quest.imagePath != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Image.asset(
                                            widget.quest.imagePath!,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return _buildPlaceholderImage();
                                            },
                                          ),
                                        )
                                      : _buildPlaceholderImage(),
                                ),
                              ),

                              SizedBox(height: 24),

                              // รายละเอียด Section
                              Text(
                                'อ่านวิธีได้: 2 ขน และทำการบันทึปบทที่ 1 หน้า 75',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),

                              SizedBox(height: 32),

                              // Buttons
                              Row(
                                children: [
                                  // ปุ่มยืนยัน (แดง)
                                  Expanded(
                                    child: _buildButton(
                                      text: 'ยอมเเพ้',
                                      color: Color(0xFFE74A4A),
                                      onPressed: () {
                                        _showGiveUpDialog();
                                      },
                                    ),
                                  ),

                                  SizedBox(width: 12),

                                  // ปุ่มทำสำเร็จ (น้ำเงิน)
                                  Expanded(
                                    child: _buildButton(
                                      text: 'ทำสำเร็จ',
                                      color: Color(0xFF4A8FE7),
                                      onPressed: () {
                                        _showCompleteDialog();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Header Title
                      _buildHeaderTitle(),
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

  Widget _buildHeaderTitle() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF005395), Color(0xFF2374B5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            "รายละเอียด",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2374B5),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 80,
            color: Color(0xFFB3E5FC),
          ),
          SizedBox(height: 8),
          Text(
            'เทสต็อป\nภารกิจเเบบปกติ',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64B5F6),
              fontWeight: FontWeight.w500,
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
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
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

  void _showGiveUpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ยืนยันยอมแพ้'),
        content: Text('คุณแน่ใจหรือไม่ว่าต้องการยอมแพ้ภารกิจนี้?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // ปิด dialog
              Navigator.pop(context); // กลับหน้าเดิม
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('ยอมแพ้ภารกิจแล้ว'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: Text('ยืนยัน', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showCompleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ยืนยันทำสำเร็จ'),
        content: Text('คุณแน่ใจหรือไม่ว่าทำภารกิจนี้สำเร็จแล้ว?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // ปิด dialog
              Navigator.pop(context); // กลับหน้าเดิม
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('ทำภารกิจสำเร็จ! +100 EXP'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text('ยืนยัน', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }
}

// Quest Model
class QuestItem {
  final String id;
  final String name;
  final String description;
  final String? imagePath;
  final DateTime startDate;
  final DateTime dueDate;
  final bool isCompleted;

  QuestItem({
    required this.id,
    required this.name,
    required this.description,
    this.imagePath,
    required this.startDate,
    required this.dueDate,
    this.isCompleted = false,
  });
}