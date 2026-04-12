import 'package:flutter/material.dart';
import 'package:flutter_application_1/api_service.dart';
import 'package:flutter_application_1/screens/club_room_head.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:flutter_application_1/screens/club_quest/club_quest_detail_leader.dart';
import 'package:flutter_application_1/widgets/confirm_exit_popup.dart';
import 'package:flutter_application_1/widgets/edit_club_quest_popup.dart';
import 'package:flutter_application_1/widgets/club_confirm_save_popup.dart';
import '../../widgets/exit_edit_club_quest_popup.dart';

class QuizQuestion {
  TextEditingController textController = TextEditingController();
  List<TextEditingController> optionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  int correctOptionIndex = 0;

  void dispose() {
    textController.dispose();
    for (var controller in optionControllers) {
      controller.dispose();
    }
  }
}

class CreateClubQuestQuizScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic>) onSubmit;
  final User? user;
  final bool isEditing;

  const CreateClubQuestQuizScreen({
    Key? key,
    required this.onSubmit,
    this.initialData,
    this.user,
    this.isEditing = false,
  }) : super(key: key);

  @override
  _CreateClubQuestQuizScreenState createState() => _CreateClubQuestQuizScreenState();
}

class _CreateClubQuestQuizScreenState extends State<CreateClubQuestQuizScreen> {
  bool _isPressed = false;
  bool _showQuestInfo = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();
  DateTime? _selectedDate;
  bool _hasImage = false;

  List<QuizQuestion> _questions = [QuizQuestion()];
  int _minScore = 1;

  void _handleImagePick() {
    setState(() {
      _hasImage = true;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('เลือกรูปภาพแล้ว')));
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameController.text = widget.initialData!['name'] ?? '';
      _detailController.text = widget.initialData!['detail'] ?? '';
      _selectedDate = widget.initialData!['date'];
      _minScore = widget.initialData!['minScore'] ?? 1;

      if (widget.initialData!['questions'] != null) {
        final List<dynamic> questionsData = widget.initialData!['questions'];
        _questions = questionsData.map((qData) {
          final q = QuizQuestion();
          q.textController.text = qData['question'] ?? '';
          if (qData['options'] != null) {
            final List<dynamic> options = qData['options'];
            for (int i = 0; i < options.length && i < 4; i++) {
              q.optionControllers[i].text = options[i] ?? '';
            }
          }
          q.correctOptionIndex = qData['correctOptionIndex'] ?? 0;
          return q;
        }).toList();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _detailController.dispose();
    for (var q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF2374B5),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submit() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('กรุณากรอกชื่อภารกิจ'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Future<void> _selectDate() async {
    // 🌟 1. คำนวณ "วันพรุ่งนี้" โดยเอาเวลาปัจจุบันมาบวกไป 1 วัน
    final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
    
    // 🌟 2. เช็คค่าเริ่มต้น ถ้ายังไม่ได้เลือกเวลา หรือเวลาที่เลือกไว้น้อยกว่าวันพรุ่งนี้ ให้ใช้พรุ่งนี้เป็นจุดเริ่มต้น
    DateTime initial = _selectedDate ?? tomorrow;
    if (initial.isBefore(tomorrow)) {
      initial = tomorrow;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial, 
      firstDate: tomorrow,  // 🌟 3. บังคับให้ปฏิทินเริ่มต้นคลิกได้ตั้งแต่วันพรุ่งนี้เป็นต้นไป (คลิกวันนี้ไม่ได้)
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2374B5),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

    final data = {
      'name': _nameController.text,
      'detail': _detailController.text,
      'date': _selectedDate,
      'image': _hasImage,
      'minScore': _minScore,
      'questions': _questions
          .map(
            (q) => {
              'question': q.textController.text,
              'options': q.optionControllers.map((c) => c.text).toList(),
              'correctOptionIndex': q.correctOptionIndex,
            },
          )
          .toList(),
    };

    widget.onSubmit(data);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;

    final topBarHeight = 75.0 + topPadding;
    final headerHeight = 80.0;

    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async => true,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: size.height,
              child: _buildBackground(),
            ),

            // Main Content with boundary
            Padding(
              padding: EdgeInsets.only(
                top:
                    topBarHeight +
                    headerHeight +
                    10, // เว้นที่ให้ Header ด้านบน
                // bottom: 110 + bottomPadding, // เว้นที่ให้ Bottom Bar ด้านล่าง
                left: size.width * 0.05,
                right: size.width * 0.05,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildQuizSection(),
                          SizedBox(height: 32),

                          _buildActionButtons(),
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Top Bar (อยู่บนสุด)
            _buildTopBar(topPadding, topBarHeight),

            // Header Title
            _buildBlueHeader(topBarHeight),

            if (_showQuestInfo)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showQuestInfo = false;
                    });
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.0), // 👈 พื้นหลังจาง ๆ
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- Widget: แถบข้อมูลผู้ใช้ (Top Bar Overlay) ---
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
          // user: widget.user,
          onNotificationTapped: () =>
              Navigator.pushNamed(context, '/notification'),
          onSettingsTapped: () => Navigator.pushNamed(context, '/setting'),
        ),
      ),
    );
  }

  // --- Widget: พื้นหลัง (Background Layer) ---
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
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () async {
        await Future.delayed(const Duration(milliseconds: 200));

        if (!mounted) return;

        setState(() => _isPressed = false);

        Navigator.pop(context);
      },
      child: Image.asset(
        _isPressed
            ? 'assets/images/button/bt-hover-Back.png'
            : 'assets/images/button/bt-Back.png',
        width: 50,
        height: 50,
      ),
    );
  }

  // Header with Back Button & Title
  Widget _buildBlueHeader(double topOffset) {
    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      child: Container(
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
            /// ปุ่ม Back (ชิดซ้าย)
            Positioned(
              left: 15,
              top: 0,
              bottom: 0,
              child: Center(child: _buildBackButton()),
            ),

            /// Title (อยู่กลางจริง)
            Positioned.fill(
              child: Center(
                child: Text(
                  widget.isEditing ? "แก้ไขภารกิจชมรม" : "สร้างภารกิจชมรม",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
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
        color: Color(0xFF002A50),
      ),
    );
  }
  Widget _buildScoreButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: enabled
              ? LinearGradient(
                  colors: [Color(0xFF556AEB), Color(0xFF59ABEC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : Color(0xFFD0D0D0),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Color(0xFF556AEB).withOpacity(0.35),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.white : Colors.white60,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildQuizSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Color(0xFF9DD0E7), width: 1),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            'คำถามตรวจสอบว่าทำภารกิจจริง',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        SizedBox(height: 8),
        ...List.generate(_questions.length, (index) {
          return _buildQuestionCard(index);
        }),
        SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF556AEB), Color(0xFF59ABEC)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF556AEB).withOpacity(0.4),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _questions.add(QuizQuestion());
                });
              },
              icon: Icon(Icons.add, color: Colors.white, size: 18),
              label: Text(
                'เพิ่มคำถาม',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 15),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Color(0xFF9DD0E7), width: 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'คะแนนขั้นต่ำเพื่อผ่านภารกิจ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF002A50),
                ),
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ปุ่ม ลด (-)
                  _buildScoreButton(
                    icon: Icons.remove,
                    enabled: _minScore > 1,
                    onTap: () {
                      if (_minScore > 1) setState(() => _minScore--);
                    },
                  ),
                  SizedBox(width: 16),
                  // แสดงคะแนน
                  Container(
                    width: 70,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Color(0xFFEAF4FB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Color(0xFF9DD0E7), width: 1.5),
                    ),
                    child: Text(
                      '$_minScore',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF002A50),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  // ปุ่ม เพิ่ม (+)
                  _buildScoreButton(
                    icon: Icons.add,
                    enabled: _minScore < _questions.length,
                    onTap: () {
                      if (_minScore < _questions.length) setState(() => _minScore++);
                    },
                  ),
                ],
              ),
              SizedBox(height: 6),
              Center(
                child: Text(
                  'สูงสุด ${_questions.length} คะแนน',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(int index) {
    QuizQuestion question = _questions[index];
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFF9DD0E7), width: 1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'คำถามที่ ${index + 1}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (_questions.length > 1)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      question.dispose();
                      _questions.removeAt(index);
                      if (_minScore > _questions.length) {
                        _minScore = _questions.length > 0
                            ? _questions.length
                            : 1;
                      }
                    });
                  },
                  child: Icon(Icons.close, color: Color(0xFF447199), size: 20),
                ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(color: Color(0xFF9DD0E7), width: 1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: TextField(
              controller: question.textController,
              decoration: InputDecoration(
                hintText: 'คำถาม',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
              ),
              style: TextStyle(fontSize: 14),
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ตัวเลือกคำตอบ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                'เฉลย',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          ...List.generate(4, (optionIndex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFF9DD0E7), width: 1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: TextField(
                        controller: question.optionControllers[optionIndex],
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'ตัวเลือกที่ ${optionIndex + 1}',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        question.correctOptionIndex = optionIndex;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: Color(0xFF1976D2),
                            width: 2,
                          ),
                        ),
                        child: question.correctOptionIndex == optionIndex
                            ? Icon(
                                Icons.circle,
                                size: 16,
                                color: Color(0xFF2374B5),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(child: _buildCancelButton()),
        SizedBox(width: 20),
        Expanded(child: _buildSubmitButtonNew()),
      ],
    );
  }
  Widget _buildCancelButton() {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFE94444),
        borderRadius: BorderRadius.circular(25),
      ),
      child: ElevatedButton(
        onPressed: () {
          if (widget.isEditing) {
            ExitEditClubQuestPopup.show(
              context,
              onConfirm: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => ClubQuestDetailLeaderScreen()),
                );
              },
            );
          } else {
            ConfirmExitPopup.show(
              context,
              onConfirm: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => ClubRoomHeadScreen()),
                );
              },
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Text(
          'ยกเลิก',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFFFFF),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButtonNew() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF556AEB), Color(0xFF59ABEC)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF4A8FE7).withOpacity(0.4),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          if (widget.isEditing) {
            EditClubQuestPopup.show(
              context,
              onConfirm: () {
                Navigator.pop(context);
                _submit();
              },
            );
          } else {
            ClubConfirmSavePopup.show(
              context,
              onConfirm: () {
                Navigator.pop(context);
                _submit();
              },
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Text(
          'บันทึก',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
