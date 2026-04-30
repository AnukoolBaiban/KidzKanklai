import 'package:flutter/material.dart';
import 'package:flutter_application_1/api_service.dart';
import 'package:flutter_application_1/screens/club_room_head.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:flutter_application_1/screens/club_quest/club_quest_detail_leader.dart';
import 'package:flutter_application_1/widgets/confirm_exit_popup.dart';
import 'package:flutter_application_1/widgets/edit_club_quest_popup.dart';
import 'package:flutter_application_1/widgets/club_confirm_save_popup.dart';
import '../../widgets/exit_edit_club_quest_popup.dart';
import 'dart:io'; 

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

  File? _selectedImage;

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

      _selectedImage = widget.initialData!['imageFile'];

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

  void _submit() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อภารกิจ'), backgroundColor: Colors.red),
      );
      return;
    }

    for (int i = 0; i < _questions.length; i++) {
      if (_questions[i].textController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('กรุณากรอกคำถามที่ ${i + 1}'), backgroundColor: Colors.red));
        return;
      }
      for (int j = 0; j < 4; j++) {
        if (_questions[i].optionControllers[j].text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('กรุณากรอกตัวเลือกที่ ${j + 1} ในคำถามที่ ${i + 1}'), backgroundColor: Colors.red));
          return;
        }
      }
    }

    List<Map<String, dynamic>> apiQuestions = [];
    const optionLetters = ['A', 'B', 'C', 'D'];

    for (var q in _questions) {
      apiQuestions.add({
        "question_text": q.textController.text.trim(),
        "choice_a": q.optionControllers[0].text.trim(),
        "choice_b": q.optionControllers[1].text.trim(),
        "choice_c": q.optionControllers[2].text.trim(),
        "choice_d": q.optionControllers[3].text.trim(),
        "correct_answer": optionLetters[q.correctOptionIndex],
      });
    }

    Map<String, dynamic> requestData = {
      "name": _nameController.text.trim(),
      "detail": _detailController.text.trim(),
      "passing_score": _minScore,
      "questions": apiQuestions,
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final result = await ApiService.createClubQuest(
      requestData,
      imageFile: _selectedImage, 
    );

    if (mounted) Navigator.pop(context); 

    if (mounted) {
      if (result != null && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('สร้างภารกิจและอัปโหลดรูปสำเร็จ!'), backgroundColor: Color(0xFF2374B5)),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ClubRoomHeadScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result?['error'] ?? 'เกิดข้อผิดพลาด'), backgroundColor: Colors.red),
        );
      }
    }
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

            Padding(
              padding: EdgeInsets.only(
                top: topBarHeight + headerHeight + 10, 
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

            _buildTopBar(topPadding, topBarHeight),
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
                    color: Colors.black.withOpacity(0.0), 
                  ),
                ),
              ),
          ],
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

        // 🌟 แก้ไข: ใช้ Navigator.pop() 2 ครั้งเพื่อถอยกลับไปหน้าแรก แทนการเรียก Push หน้าใหม่
        if (widget.isEditing) {
          ExitEditClubQuestPopup.show(
            context,
            onConfirm: () {
              Navigator.pop(context); // ปิด popup
              Navigator.pop(context); // ย้อนกลับไปหน้า Detail Leader
              Navigator.pop(context); // ย้อนกลับไปอีกเพื่อปิดหน้าย่อย
            },
          );
        } else {
          ConfirmExitPopup.show(
            context,
            onConfirm: () {
              Navigator.pop(context); // ปิด popup
              Navigator.pop(context); // ย้อนกลับไปหน้าก่อนหน้า (CreateQuestScreen)
              Navigator.pop(context); // ย้อนกลับไปหน้า Room Head
            },
          );
        }
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
            Positioned(
              left: 15,
              top: 0,
              bottom: 0,
              child: Center(child: _buildBackButton()),
            ),
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
                  _buildScoreButton(
                    icon: Icons.remove,
                    enabled: _minScore > 1,
                    onTap: () {
                      if (_minScore > 1) setState(() => _minScore--);
                    },
                  ),
                  SizedBox(width: 16),
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
          // 🌟 แก้ไข: ใช้ Navigator.pop() แทนการ Push หน้าใหม่
          if (widget.isEditing) {
            ExitEditClubQuestPopup.show(
              context,
              onConfirm: () {
                Navigator.pop(context); // ปิด popup
                Navigator.pop(context); // ย้อนกลับ 1
                Navigator.pop(context); // ย้อนกลับ 2
              },
            );
          } else {
            ConfirmExitPopup.show(
              context,
              onConfirm: () {
                Navigator.pop(context); // ปิด popup
                Navigator.pop(context); // ย้อนกลับ 1
                Navigator.pop(context); // ย้อนกลับ 2
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