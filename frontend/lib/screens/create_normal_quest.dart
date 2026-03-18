import 'dart:io'; // 🌟 1. เพิ่มสำหรับจัดการไฟล์
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // 🌟 2. เพิ่ม ImagePicker
import 'package:flutter_application_1/api_service.dart';
import 'package:flutter_application_1/screens/lobby.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:flutter_application_1/widgets/quest_info_card.dart';
import 'package:flutter_application_1/widgets/confirm_exit_popup.dart';
import 'package:flutter_application_1/widgets/confirm_save_popup.dart';
import 'package:flutter_application_1/widgets/annotation_normal.dart';

class CreateNormalQuestScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic>)? onSubmit;
  final User? user;

  const CreateNormalQuestScreen({
    Key? key,
    this.onSubmit,
    this.initialData,
    this.user,
  }) : super(key: key);

  @override
  _CreateNormalQuestScreenState createState() => _CreateNormalQuestScreenState();
}

class _CreateNormalQuestScreenState extends State<CreateNormalQuestScreen> {
  bool _isPressed = false;
  bool _showQuestInfo = false;
  bool _isSubmitting = false; // 🌟 เพิ่มตัวแปรสำหรับแสดงสถานะ Loading ตอนกดบันทึก

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();
  DateTime? _selectedDate;
  
  // 🌟 เปลี่ยนจากการเก็บแค่ bool มาเป็นการเก็บ File รูปภาพจริงๆ
  File? _selectedImage; 
  final ImagePicker _picker = ImagePicker();

  // 🌟 ฟังก์ชันเลือกรูปจากแกลเลอรีของเครื่อง
  Future<void> _handleImagePick() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800, // บีบอัดขนาดเบื้องต้น
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('เลือกรูปภาพแล้ว')),
          );
        }
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
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

  // 🌟 ฟังก์ชัน Submit ที่ปรับให้ยิง API จริง
  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อภารกิจ'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกวันที่สิ้นสุด'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isSubmitting = true; // เริ่มหมุน Loading
    });

    // ยิง API สร้างภารกิจ
    final success = await ApiService.createNormalQuest(
      name: _nameController.text.trim(),
      detail: _detailController.text.trim(),
      dueDate: _selectedDate!,
      imageFile: _selectedImage, // ส่งไฟล์รูปไปด้วย
    );

    setState(() {
      _isSubmitting = false; // ปิด Loading
    });

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('สร้างภารกิจสำเร็จ!'), backgroundColor: Colors.green),
      );
      
      // ถ้ามีการส่ง onSubmit มาให้ (ใช้เรียกอัปเดตหน้าก่อนหน้าถ้ามี)
      if (widget.onSubmit != null) {
        widget.onSubmit!({
          'name': _nameController.text,
          'detail': _detailController.text,
          'date': _selectedDate,
          'has_image': _selectedImage != null,
        });
      }

      // กลับไปหน้าก่อนหน้า (หรือกลับไปหน้าเลือกเควส)
      Navigator.pop(context); 
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เกิดข้อผิดพลาดในการสร้างภารกิจ'), backgroundColor: Colors.red),
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
      onWillPop: () async {
        // เมื่อกดปุ่ม back → แสดง ConfirmExitPopup
        await ConfirmExitPopup.show(
          context,
          onConfirm: () {
            Navigator.pop(context); // ปิด popup
            Navigator.pop(context); // ออกจากหน้า (ไม่บันทึก)
          },
        );
        return false; // ไม่ให้กลับทันที
      },
      child: Scaffold(
        body: Stack(
        children: [
          _buildBackground(),

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
                  _buildTextField(controller: _nameController, hintText: 'ชื่อภารกิจ'),
                  const SizedBox(height: 24),
                  _buildSectionTitle('เนื้อหา'),
                  const SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDatePicker(),
                        _buildDetailTextField(),
                        const SizedBox(height: 16),
                        _buildCameraButton(),
                        const SizedBox(height: 32),
                        
                        // 🌟 โชว์ Loading ถ้ากำลังยิง API อยู่
                        _isSubmitting 
                            ? const Center(child: CircularProgressIndicator()) 
                            : _buildSubmitButton(),
                            
                        const SizedBox(height: 20),
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
      top: 0, left: 0, right: 0,
      child: Container(
        height: height,
        padding: EdgeInsets.only(top: topPadding),
        color: Colors.black.withOpacity(0.4),
        alignment: Alignment.bottomCenter,
        child: CustomTopBar(
          onNotificationTapped: () => Navigator.pushNamed(context, '/notification'),
          onSettingsTapped: () => Navigator.pushNamed(context, '/settings'),
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

        ConfirmExitPopup.show(
          context,
          onConfirm: () {
            Navigator.pop(context); // ปิด Popup
            Navigator.pop(context); // ปิดหน้าจอสร้างเควส กลับไปหน้าเดิม
          },
        );
      },
      child: Image.asset(
        _isPressed ? 'assets/images/button/bt-hover-Back.png' : 'assets/images/button/bt-Back.png',
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
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildBackButton(),
                  const SizedBox(width: 60),
                  const Text(
                    "ภารกิจทั่วไป",
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                const SizedBox(width: 80),
                ],
              ),
            ),
            // Annotation button stays at bottom right
            const Positioned(bottom: 8, right: 15, child: AnnotationButton()),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF002A50)));
  }

  Widget _buildTextField({required TextEditingController controller, required String hintText}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFF9DD0E7), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('ชื่อภารกิจ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF002A50))),
              ],
            ),
          ),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffixIcon: Padding(
                padding: const EdgeInsets.all(15),
                child: Image.asset('assets/images/icon/iconEdit.png', width: 15, height: 15, fit: BoxFit.contain),
              ),
            ),
            style: const TextStyle(fontSize: 14, color: Color(0xFF002A50)),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('วันที่สิ้นสุด', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF002A50))),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F3F9),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                _selectedDate != null ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}' : '--/--/----',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ),
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF75C6EA), Color(0xFF9DD0E7)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Image.asset('assets/images/icon/icon-calendar.png', width: 22, height: 22, fit: BoxFit.contain),
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
        border: Border.all(color: const Color(0xFF9DD0E7), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('รายละเอียด', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF002A50))),
                Image(image: AssetImage('assets/images/icon/iconEdit.png'), width: 20, height: 20),
              ],
            ),
          ),
          TextField(
            controller: _detailController,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'รายละเอียด',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraButton() {
    return Align(
      alignment: Alignment.centerRight,
      // 🌟 สลับการโชว์ ถ้ารูปมาแล้วให้โชว์ _buildImagePreview()
      child: _selectedImage != null ? _buildImagePreview() : _buildCameraIcon(),
    );
  }

  Widget _buildCameraIcon() {
    return InkWell(
      onTap: _handleImagePick,
      child: Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF68E2FA), Color(0xFF2374B5)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: const Color(0xFF64B5F6).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Center(
          child: Image.asset('assets/images/icon/icon-camera.png', width: 55, height: 55, fit: BoxFit.contain),
        ),
      ),
    );
  }

  // 🌟 ฟังก์ชันพรีวิวรูปภาพจากไฟล์ที่เลือกมา
  Widget _buildImagePreview() {
    return Container(
      width: double.infinity,
      height: 200, // กำหนดความสูงตายตัวไม่ให้เกินกรอบ
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9DD0E7), width: 2),
      ),
      child: Stack(
        children: [
          // โชว์รูปภาพจริงจาก File
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              _selectedImage!,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          
          // ปุ่มกากบาทเพื่อลบรูป
          Positioned(
            top: 8, right: 8,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedImage = null; // ล้างค่ารูปทิ้ง
                });
              },
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white70,
                ),
                child: const Icon(Icons.close, color: Colors.red, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Center(
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF556AEB), Color(0xFF59ABEC)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(color: const Color(0xFF4A8FE7).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: ElevatedButton(
          onPressed: () {
            ConfirmSavePopup.show(
              context,
              onConfirm: () {
                Navigator.pop(context); // ปิด popup ก่อน
                _submit(); // ค่อยบันทึกจริง (ยิง API)
              },
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          ),
          child: const Text('บันทึก', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }
}