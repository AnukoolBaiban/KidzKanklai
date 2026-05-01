import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/api_service.dart';
import 'package:flutter_application_1/screens/club_room_head.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:flutter_application_1/screens/club_quest/club_quest_detail_leader.dart';
import 'package:flutter_application_1/widgets/confirm_exit_popup.dart';
import 'package:flutter_application_1/widgets/exit_edit_club_quest_popup.dart';
import 'package:flutter_application_1/widgets/club_confirm_save_popup.dart';
import 'package:flutter_application_1/widgets/annotation_normal.dart';
import 'create_club_quest_quiz.dart';
import 'dart:io'; // 🌟 1. นำเข้า dart:io
import 'package:image_picker/image_picker.dart'; // 🌟 2. นำเข้า image_picker

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

class CreateClubQuestScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic>) onSubmit;
  final User? user;
  final bool isEditing;

  const CreateClubQuestScreen({
    Key? key,
    required this.onSubmit,
    this.initialData,
    this.user,
    this.isEditing = false,
  }) : super(key: key);

  @override
  _CreateClubQuestScreenState createState() => _CreateClubQuestScreenState();
}

class _CreateClubQuestScreenState extends State<CreateClubQuestScreen> {
  bool _isPressed = false;
  bool _showQuestInfo = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();
  DateTime? _selectedDate;
  bool _hasImage = false;

  List<QuizQuestion> _questions = [QuizQuestion()];
  int _minScore = 1;

  // 🌟 เพิ่มตัวแปรเก็บไฟล์รูปภาพ
  File? _selectedImage;

  // 🌟 แก้ไขฟังก์ชันเลือกรูปภาพ
  Future<void> _handleImagePick() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path); // เก็บไฟล์ที่เลือก
        _hasImage = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('เลือกรูปภาพแล้ว')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameController.text = widget.initialData!['name'] ?? '';
      _detailController.text = widget.initialData!['detail'] ?? '';
      _selectedDate = widget.initialData!['date'];
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

  bool _hasUnsavedChanges() {
    bool nameChanged = _nameController.text.trim().isNotEmpty;
    bool detailChanged = _detailController.text.trim().isNotEmpty;
    bool dateChanged = _selectedDate != null;
    bool imageChanged = _hasImage || _selectedImage != null;
    bool questionsChanged = _questions.length > 1 || 
        _questions[0].textController.text.trim().isNotEmpty || 
        _questions[0].optionControllers.any((c) => c.text.trim().isNotEmpty);

    if (widget.initialData != null) {
      nameChanged = _nameController.text != (widget.initialData!['name'] ?? '');
      detailChanged = _detailController.text != (widget.initialData!['detail'] ?? '');
      dateChanged = _selectedDate != widget.initialData!['date'];
    }

    return nameChanged || detailChanged || dateChanged || imageChanged || questionsChanged;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final topBarHeight = 75.0 + topPadding;
    final headerHeight = 80.0;

    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        if (!_hasUnsavedChanges()) {
          return true;
        }

        if (widget.isEditing) {
          ExitEditClubQuestPopup.show(
            context,
            onConfirm: () {
              Navigator.pop(context); // ปิด popup
              Navigator.pop(context); // ออกจากหน้า
            },
          );
        } else {
          ConfirmExitPopup.show(
            context,
            onConfirm: () {
              Navigator.pop(context); // ปิด popup
              Navigator.pop(context); // ออกจากหน้า
            },
          );
        }
        return false; // ไม่ให้กลับทันที
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            _buildBackground(),

            Column(
              children: [
                _buildTopBar(topPadding),
                _buildBlueHeader(),
                
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: 10,
                      bottom: bottomPadding + 20,
                      left: size.width * 0.05,
                      right: size.width * 0.05,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),

                          _buildTextField(
                            controller: _nameController,
                            hintText: 'ชื่อภารกิจ',
                          ),

                          SizedBox(height: 24),

                          // เนื้อหา (อยู่นอกกล่อง)
                          _buildSectionTitle('เนื้อหา'),
                          SizedBox(height: 8),

                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDatePicker(),

                                _buildDetailTextField(),
                                SizedBox(height: 16),

                                _buildCameraButton(),
                                SizedBox(height: 24),

                                _buildActionButtons(),
                                SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

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
  Widget _buildTopBar(double topPadding) {
    return Container(
        padding: EdgeInsets.only(top: topPadding),
        color: Colors.black.withOpacity(0.4),
        child: CustomTopBar(
          // user: widget.user,
          onNotificationTapped: () =>
              Navigator.pushNamed(context, '/notification'),
          onSettingsTapped: () => Navigator.pushNamed(context, '/setting'),
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

        if (!_hasUnsavedChanges()) {
          Navigator.pop(context);
          return;
        }

        if (widget.isEditing) {
          ExitEditClubQuestPopup.show(
            context,
            onConfirm: () {
              Navigator.pop(context); // ปิด popup
              Navigator.pop(context); // 🌟 แก้เป็น .pop() เพื่อย้อนกลับไปหน้าเดิม (Detail Leader)
            },
          );
        } else {
          ConfirmExitPopup.show(
            context,
            onConfirm: () {
              Navigator.pop(context); // ปิด popup
              Navigator.pop(context); // 🌟 แก้เป็น .pop() เพื่อย้อนกลับไปหน้าเดิม (Room Head)
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

  // Header with Back Button & Title
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Color(0xFF9DD0E7), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ชื่อภารกิจ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF002A50),
                  ),
                ),
              ],
            ),
          ),
          TextField(
            controller: controller,
            onChanged: (val) => setState(() {}),
            maxLength: 15,
            inputFormatters: [LengthLimitingTextInputFormatter(15)],
            decoration: InputDecoration(
              counterText: '',
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${controller.text.length}/15',
                      style: TextStyle(
                        color: controller.text.length >= 15
                            ? Colors.red
                            : Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Image.asset(
                      'assets/images/icon/iconEdit.png',
                      width: 15,
                      height: 15,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ),
            style: TextStyle(fontSize: 14, color: Color(0xFF002A50)),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'วันที่สิ้นสุด',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF002A50),
              ),
            ),
            SizedBox(width: 12),

            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Color(0xFFE6F3F9),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                _selectedDate != null
                    ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                    : '--/--/----',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ),

            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF75C6EA), Color(0xFF9DD0E7)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Image.asset(
                  'assets/images/icon/icon-calendar.png',
                  width: 22,
                  height: 22,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTextField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF9DD0E7), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'รายละเอียด',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF002A50),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_detailController.text.length}/300',
                      style: TextStyle(
                        color: _detailController.text.length >= 300
                            ? Colors.red
                            : Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Image(
                      image: AssetImage('assets/images/icon/iconEdit.png'),
                      width: 20,
                      height: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),

          TextField(
            controller: _detailController,
            onChanged: (val) => setState(() {}),
            maxLength: 300,
            inputFormatters: [LengthLimitingTextInputFormatter(300)],
            maxLines: 6,
            decoration: InputDecoration(
              counterText: '',
              hintText: 'รายละเอียด',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
            style: TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: _hasImage ? _buildImagePreview() : _buildCameraIcon(),
    );
  }

  Widget _buildCameraIcon() {
    return InkWell(
      onTap: _handleImagePick,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF68E2FA), Color(0xFF2374B5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0xFF64B5F6).withOpacity(0.4),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Image.asset(
            'assets/images/icon/icon-camera.png',
            width: 55,
            height: 55,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return GestureDetector(
      onTap: () {
        _handleImagePick();
      },
      child: Container(
        width: 800,
        height: 500,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFF9DD0E7), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image, size: 60, color: Color(0xFF64B5F6)),
                  SizedBox(height: 8),
                  Text(
                    'รูปภาพที่เลือก',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'รูปภาพ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF002A50),
                    ),
                  ),

                  Spacer(),

                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _hasImage = false;
                        _selectedImage = null; // 🌟 เคลียร์ไฟล์ทิ้งด้วย
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('ลบรูปภาพแล้ว'),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Icon(Icons.close, color: Color(0xFF447199), size: 28),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(child: _buildSubmitButtonNew()),
      ],
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateClubQuestQuizScreen(
                user: widget.user,
                isEditing: widget.isEditing,
                initialData: {
                  // 🌟 เพิ่ม ID และรูปเดิม เพื่อให้หน้าถัดไปเอาไปยิง API Update ได้ถูกข้อ
                  'id': widget.initialData?['id'], 
                  'imageUrl': widget.initialData?['imageUrl'], 
                  
                  'name': _nameController.text,
                  'detail': _detailController.text,
                  'date': _selectedDate,
                  'imageFile': _selectedImage, 
                  
                  // 🌟 ส่งคำถามเดิมและคะแนนผ่านไปยังหน้า Quiz ต่อ
                  'questions': widget.initialData?['questions'],
                  'minScore': widget.initialData?['minScore'],
                },
                onSubmit: widget.onSubmit,
              ),
            ),
          );
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
          'ถัดไป',
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
