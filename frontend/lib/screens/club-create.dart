import 'dart:math';
import 'package:flutter/material.dart';
import '../widgets/custom_top_bar.dart';
import '../widgets/club/club_form_fields.dart';
import 'club_room_head.dart';
import '../api_service.dart' as api; // 🌟 1. เพิ่ม Import ApiService

// ============================================================
// หน้าสร้างชมรม
// ============================================================
class ClubCreateScreen extends StatefulWidget {
  const ClubCreateScreen({super.key});

  @override
  State<ClubCreateScreen> createState() => _ClubCreateScreenState();
}

class _ClubCreateScreenState extends State<ClubCreateScreen> {
  // ── State ───────────────────────────────────────────────────
  bool _isBackPressed = false;
  bool _isSubmitting = false;
  bool _isCodePressed = false;
  bool _isSubmitPressed = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String? _generatedCode; // รหัสชมรมที่สร้างแล้ว

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // ── สร้างรหัสชมรมแบบสุ่ม 6 ตัวอักษร ────────────────────────
  void _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final code = List.generate(
      6,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    setState(() => _generatedCode = code);
  }

  // ── ยืนยันการสร้างชมรม ─────────────────────────────────────
  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อชมรม'), backgroundColor: Colors.red),
      );
      return;
    }
    // 🌟 2. หมายเหตุ: ลบการเช็ค _generatedCode ออก เพราะ Backend จะสุ่มโค้ดให้เราเอง 
    // ตัว _generatedCode ที่เราสุ่มในแอปตอนนี้มีไว้แค่ประดับตกแต่ง UI ไม่ได้ส่งไปให้ Backend ครับ

    setState(() => _isSubmitting = true);

    // 🌟 3. ยิง API ของจริง
    final result = await api.ApiService.createClub(name, desc);

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (result != null && result['success'] == true) {
        // 🎉 สร้างสำเร็จ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('สร้างชมรมสำเร็จ! รหัสเชิญของคุณคือ: ${result['invite_code']}'),
            backgroundColor: const Color(0xFF2374B5),
          ),
        );

        // TODO: (ถ้ามีหน้า ClubRoomHead) ส่ง club_id หรือข้อมูลไปให้หน้านั้นด้วย
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ClubRoomHeadScreen()),
        );
      } else {
        // ❌ สร้างไม่สำเร็จ (เช่น มีชมรมอยู่แล้ว)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result?['error'] ?? 'ไม่สามารถสร้างชมรมได้'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topBarHeight = 75.0 + topPadding;
    const headerHeight = 80.0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          _buildBackground(),

          // ── Main Content ────────────────────────────────────
          Padding(
            padding: EdgeInsets.only(
              top: topBarHeight + headerHeight + 12,
              left: size.width < 380 ? 24 : 40, // Responsive padding ยืดหยุ่น
              right: size.width < 380 ? 24 : 40,
              bottom: bottomPadding + 20,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 500,
                ), // จำกัดความกว้างสูงสุดเวลาใช้จอใหญ่
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. กล่องตั้งชื่อชมรม
                          ClubNameField(controller: _nameController),
                          SizedBox(
                            height: size.height * 0.035 > 24
                                ? 24
                                : size.height * 0.035,
                          ),

                          // 2. รายละเอียดของชมรม
                          Expanded(
                            child: ClubDescField(controller: _descController),
                          ),
                          SizedBox(
                            height: size.height * 0.05 > 40
                                ? 40
                                : size.height * 0.05,
                          ),

                          _buildBottomButton(size),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Top Bar & Header ───────────────────────────
          Column(
            children: [
              _buildTopBar(topPadding),
              _buildBlueHeader(),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WIDGETS
  // ============================================================

  // ── Background ──────────────────────────
  Widget _buildBackground() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        color: const Color(0xFFE2F5FD),
        alignment: Alignment.center,
        child: Image.asset(
          'assets/images/background/bg-head.png',
          fit: BoxFit.contain,
          width: MediaQuery.of(context).size.width * 0.8,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  // ── Top Bar ───────────────────────────────────
  Widget _buildTopBar(double topPadding) {
    return Container(
      padding: EdgeInsets.only(top: topPadding),
      color: Colors.black.withValues(alpha: 0.4),
      child: CustomTopBar(
        onNotificationTapped: () =>
            Navigator.pushNamed(context, '/notification'),
        onSettingsTapped: () => Navigator.pushNamed(context, '/setting'),
      ),
    );
  }

  // Header
  Widget _buildBlueHeader() {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF015496), Color(0xFF2273B4)],
        ),
      ),
      child: Stack(
          alignment: Alignment.center,
          children: [
            // ── หัวข้อ "สร้างชมรม" ────────
            Positioned.fill(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 30,
                  ), // ดันข้อความในปุ่มให้กึ่งกลางกับปุ่ม
                  child: Text(
                    'สร้างชมรม',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            // ── ปุ่มย้อนกลับ (ชิดซ้าย) ─────────────────────────
            Positioned(
              left: 20,
              child: GestureDetector(
                onTapDown: (_) => setState(() => _isBackPressed = true),
                onTapCancel: () => setState(() => _isBackPressed = false),
                onTap: () async {
                  setState(() => _isBackPressed = false);
                  await Future.delayed(const Duration(milliseconds: 100));
                  if (mounted) Navigator.pop(context);
                },
                child: Image.asset(
                  _isBackPressed
                      ? 'assets/images/button/bt-hover-Back.png'
                      : 'assets/images/button/bt-Back.png',
                  width: 50,
                  height: 50,
                  errorBuilder: (_, __, ___) => Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEEEEEE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF333333),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }

  // ── Bottom Button: ยืนยันการสร้าง ────────────────────────────
  Widget _buildBottomButton(Size size) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 10),
        child: GestureDetector(
          onTapDown: _isSubmitting
              ? null
              : (_) => setState(() => _isSubmitPressed = true),
          onTapUp: _isSubmitting
              ? null
              : (_) => setState(() => _isSubmitPressed = false),
          onTapCancel: _isSubmitting
              ? null
              : () => setState(() => _isSubmitPressed = false),
          onTap: _isSubmitting
              ? null
              : () {
                  setState(() => _isSubmitPressed = false);
                  _submit();
                },
          child: Container(
            width: size.width * 0.7,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isSubmitPressed
                    ? const [Color(0xFF3A4DD1), Color(0xFF3B8FCB)] // เข้มขึ้น
                    : const [Color(0xFF556AEB), Color(0xFF59ABEC)], // ปกติ
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF556AEB).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    'ยืนยันการสร้าง',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}