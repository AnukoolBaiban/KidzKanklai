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
      
      // 🌟 ดึงข้อมูลวันที่ (รองรับทั้ง DateTime และ String จาก DB)
      if (widget.initialData!['date'] is DateTime) {
        _selectedDate = widget.initialData!['date'];
      } else if (widget.initialData!['due_date'] != null) {
        _selectedDate = DateTime.parse(widget.initialData!['due_date']).toLocal();
      }

      // 🌟 เช็คว่ามีรูปภาพเดิมอยู่หรือไม่
      if (widget.initialData!['imageUrl'] != null || widget.initialData!['image'] != null) {
        _hasImage = true;
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
    // 🌟 คำนวณ "วันพรุ่งนี้"
    final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
    
    // 🌟 เช็คค่าเริ่มต้น ถ้าเวลาน้อยกว่าวันพรุ่งนี้ ให้เด้งไปพรุ่งนี้
    DateTime initial = _selectedDate ?? tomorrow;
    if (initial.isBefore(tomorrow)) {
      initial = tomorrow;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: tomorrow, // 🌟 บังคับให้ปฏิทินเริ่มต้นคลิกได้ตั้งแต่วันพรุ่งนี้
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

  // 🌟 ฟังก์ชันสำหรับสร้างภารกิจแบบ "ไม่มีคำถาม"
  Future<void> _submitWithoutQuestions() async {
    // 1. ดักเช็คชื่อภารกิจ
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อภารกิจ'), backgroundColor: Colors.red),
      );
      return;
    }

    // 2. ดักเช็ควันหมดเขต
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกวันที่สิ้นสุดภารกิจ'), backgroundColor: Colors.red),
      );
      return;
    }

    // 3. โชว์ Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    // 4. เตรียมข้อมูลส่งให้ API (คำถามเป็นว่าง, passing_score เป็น 0)
    Map<String, dynamic> requestData = {
      "name": _nameController.text.trim(),
      "detail": _detailController.text.trim(),
      "due_date": _selectedDate!.toUtc().toIso8601String(), // 🌟 เติม .toUtc() เข้าไป!
      "passing_score": 0, 
      "questions": [], 
    };

    Map<String, dynamic>? result;

    // 5. แยกว่าเป็นการสร้างใหม่ หรือ แก้ไขของเดิม
    if (widget.isEditing) {
      requestData['id'] = widget.initialData?['id'];
      bool shouldDeleteImage = false;
      if (_selectedImage == null && widget.initialData?['imageUrl'] != null && widget.initialData?['imageFile'] == null) {
        shouldDeleteImage = true;
      }
      result = await ApiService.updateClubQuest(
        requestData,
        imageFile: _selectedImage,
        deleteImage: shouldDeleteImage,
      );
    } else {
      result = await ApiService.createClubQuest(
        requestData,
        imageFile: _selectedImage,
      );
    }

    if (mounted) Navigator.pop(context); // ปิด Loading

    // 6. จัดการผลลัพธ์
    if (mounted) {
      if (result != null && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing ? 'อัปเดตภารกิจสำเร็จ!' : 'สร้างภารกิจสำเร็จ!'), 
            backgroundColor: const Color(0xFF2374B5),
          ),
        );
        // เด้งกลับไปหน้าหลักชมรม
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ClubRoomHeadScreen()),
          (route) => route.isFirst,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result?['error'] ?? 'เกิดข้อผิดพลาด'), backgroundColor: Colors.red),
        );
      }
    }
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
    // 🌟 เช็คว่าจะโชว์รูปจากไฟล์ที่เพิ่งเลือก หรือรูปจาก URL เดิม
    Widget imageWidget;
    if (_selectedImage != null) {
      imageWidget = Image.file(_selectedImage!, fit: BoxFit.cover);
    } else if (widget.initialData?['imageUrl'] != null) {
      imageWidget = Image.network(widget.initialData!['imageUrl'], fit: BoxFit.cover);
    } else if (widget.initialData?['image'] != null) {
      imageWidget = Image.network(widget.initialData!['image'], fit: BoxFit.cover);
    } else {
      imageWidget = const Icon(Icons.image, size: 60, color: Color(0xFF64B5F6));
    }

    return GestureDetector(
      onTap: _handleImagePick,
      child: Container(
        width: double.infinity, // 🌟 ให้ขยายเต็มพื้นที่
        height: 200, // 🌟 กำหนดความสูงให้เหมาะสม
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF9DD0E7), width: 2),
        ),
        child: Stack(
          children: [
            // 🌟 นำ Widget รูปภาพมาแสดงเต็มกรอบ
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: imageWidget,
              ),
            ),
            
            // ปุ่มกากบาทลบรูป
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _hasImage = false;
                    _selectedImage = null;
                    if (widget.initialData != null) {
                      widget.initialData!['imageUrl'] = null; // ล้าง URL เดิมทิ้งด้วย
                      widget.initialData!['image'] = null;
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.white70, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Color(0xFF447199), size: 24),
                ),
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
        Expanded(child: _buildSubmitWithoutQuizButton()),
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
          // 🌟 1. ดักเช็คชื่อภารกิจ
          if (_nameController.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('กรุณากรอกชื่อภารกิจ'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          // 🌟 2. ดักเช็ควันหมดเขต (สำคัญมาก เพราะ API ใหม่บังคับ)
          if (_selectedDate == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('กรุณาเลือกวันที่สิ้นสุดภารกิจ'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          // 🌟 3. ผ่านเงื่อนไข ให้เปลี่ยนไปหน้าตั้งคำถาม
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateClubQuestQuizScreen(
                user: widget.user,
                isEditing: widget.isEditing,
                initialData: {
                  'id': widget.initialData?['id'], 
                  'imageUrl': widget.initialData?['imageUrl'], 
                  
                  'name': _nameController.text.trim(),
                  'detail': _detailController.text.trim(),
                  'date': _selectedDate, // ส่งวันที่ไปหน้า Quiz
                  'imageFile': _selectedImage, 
                  
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
        child: const Text(
          'เพิ่มคำถาม',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // 🌟 UI ปุ่มสร้างภารกิจแบบไม่มีคำถาม
  Widget _buildSubmitWithoutQuizButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8CD853), Color(0xFF4CB050)], // โทนสีเขียวให้ดูแตกต่าง
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CB050).withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _submitWithoutQuestions, // เรียกฟังก์ชันที่เราเพิ่งสร้าง
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Text(
          widget.isEditing ? 'บันทึก' : 'สร้างภารกิจชมรม', // 🌟 ถ้าเป็นโหมดแก้ไขให้ขึ้นว่า "บันทึก"
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
