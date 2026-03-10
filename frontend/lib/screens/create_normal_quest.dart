import 'package:flutter/material.dart';
import 'package:flutter_application_1/api_service.dart';
import 'package:flutter_application_1/screens/lobby.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:flutter_application_1/widgets/quest_info_card.dart';
import 'package:flutter_application_1/widgets/confirm_exit_popup.dart';
import 'package:flutter_application_1/widgets/confirm_save_popup.dart';

class CreateNormalQuestScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic>) onSubmit;
  final User? user;

  const CreateNormalQuestScreen({
    Key? key,
    required this.onSubmit,
    this.initialData,
    this.user,
  }) : super(key: key);

  @override
  _CreateNormalQuestScreenState createState() =>
      _CreateNormalQuestScreenState();
}

class _CreateNormalQuestScreenState extends State<CreateNormalQuestScreen> {
  bool _isPressed = false;
  bool _showQuestInfo = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();
  DateTime? _selectedDate;
  bool _hasImage = false;

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

    final data = {
      'name': _nameController.text,
      'detail': _detailController.text,
      'date': _selectedDate,
      'image': _hasImage,
    };

    widget.onSubmit(data);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final topBarHeight = 75.0 + topPadding;
    final headerHeight = 80.0;

    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),

          // Main Content with boundary
          Padding(
            padding: EdgeInsets.only(
              top: topBarHeight + headerHeight + 10, // เว้นที่ให้ Header ด้านบน
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
                        SizedBox(height: 32),

                        _buildSubmitButton(),
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
          user: widget.user,
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

        ConfirmExitPopup.show(
          context,
          onConfirm: () {
            Navigator.pop(context);

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => LobbyScreen(user: widget.user)),
            );
          },
        );
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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Header Bar
          Container(
            height: 80,
            padding: EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF015496), Color(0xFF2273B4)],
              ),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: _buildBackButton(),
                ),

                Expanded(
                  child: Center(
                    child: Text(
                      "ภารกิจทั่วไป",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 20), // เว้นที่ให้ Back Button

                // ปุ่ม
                Padding(
                  padding: const EdgeInsets.only(right: 15, top: 15),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showQuestInfo = !_showQuestInfo;
                      });
                    },
                    child: Icon(
                      Icons.help_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Info Card (อยู่นอก Header)
          if (_showQuestInfo)
            Positioned(
              top: 80,
              right: 20,
              child: QuestInfoCard(
                title: "ภารกิจทั่วไป",
                description:
                    "เหมาะสำหรับผู้เล่นที่จะทำกิจกรรมต่าง ๆ ในภายหลังและต้องเป็นกิจกรรมที่มีการกำหนดระยะเวลาสิ้นสุดของกิจกรรมที่ทำ",
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
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              suffixIcon: Padding(
                padding: EdgeInsets.all(15),
                child: Image.asset(
                  'assets/images/icon/iconEdit.png',
                  width: 15,
                  height: 15,
                  fit: BoxFit.contain,
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
                Image(
                  image: AssetImage('assets/images/icon/iconEdit.png'),
                  width: 20,
                  height: 20,
                ),
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
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('ลบรูปภาพแล้ว'),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Icon(
                      Icons.close,
                      color: Color(0xFF447199),
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Center(
      child: Container(
        width: 150,
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
            ConfirmSavePopup.show(
              context,
              onConfirm: () {
                Navigator.pop(context); // ปิด popup ก่อน
                _submit(); // ค่อยบันทึกจริง
              },
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
            'บันทึก',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}