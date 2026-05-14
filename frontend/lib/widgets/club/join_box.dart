import 'package:flutter/material.dart';

import 'package:flutter_application_1/screens/club_room_member.dart';
import 'package:flutter_application_1/api_service.dart' as api; // 🌟 1. เพิ่ม Import ApiService

class JoinCodeBox extends StatefulWidget {
  final TextEditingController codeController;
  final VoidCallback onClose;

  const JoinCodeBox({
    super.key,
    required this.codeController,
    required this.onClose,
  });

  @override
  State<JoinCodeBox> createState() => _JoinCodeBoxState();
}

class _JoinCodeBoxState extends State<JoinCodeBox> {
  String? _errorMessage; // 🌟 เก็บข้อความ Error

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const double borderWidth = 2.5;
    const double radius = 20.0;

    final boxPadding = size.width * 0.045 > 24.0 ? 24.0 : size.width * 0.045;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 450,
        ), // ไม่ให้กล่องยาวทะลุบน iPad
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF59ABEC), Color(0xFFC6F4FF)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF59ABEC).withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            padding: const EdgeInsets.all(borderWidth),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xF2F7F7F7),
                borderRadius: BorderRadius.circular(radius - borderWidth),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: boxPadding,
                vertical: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── หัวข้อ + ปุ่มปิด ──────────────────────────
                  Row(
                    children: [
                      const SizedBox(width: 22),
                      const Expanded(
                        child: Text(
                          'กรอกรหัสชมรม',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onClose,
                        child: const Icon(
                          Icons.close,
                          color: Color(0xFF59ABEC),
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // ── ช่องกรอกรหัส + ปุ่มส่ง ─────────────────
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: _errorMessage != null
                            ? Colors.red.withOpacity(0.5)
                            : const Color(0xFFC2E0E5),
                        width: 1.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: TextField(
                              controller: widget.codeController,
                              maxLength: 6,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF444444),
                              ),
                              onChanged: (_) {
                                if (_errorMessage != null) {
                                  setState(() => _errorMessage = null);
                                }
                              },
                              decoration: const InputDecoration(
                                hintText: 'กรอกรหัส',
                                counterText: '',
                                hintStyle: TextStyle(
                                  color: Color(0xFFBBBBBB),
                                  fontSize: 15,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            final code = widget.codeController.text.trim();
                            
                            setState(() => _errorMessage = null); // 🌟 เคลียร์ Error ก่อน

                            if (code.isEmpty) {
                              setState(() => _errorMessage = 'กรุณากรอกรหัสชมรม');
                              return;
                            }

                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (ctx) => const Center(child: CircularProgressIndicator()),
                            );

                            final result = await api.ApiService.joinClub(code);

                            if (context.mounted) Navigator.pop(context);

                            if (context.mounted) {
                              if (result != null && result['success'] == true) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(result['message'] ?? 'เข้าร่วมชมรมสำเร็จ!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                widget.onClose();
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ClubRoomMemberScreen(),
                                  ),
                                );
                              } else {
                                // ❌ ล้มเหลว -> โชว์ Error ใต้ช่องกรอก
                                setState(() {
                                  _errorMessage = result?['error'] ?? 'ไม่พบชมรมนี้หรือเกิดข้อผิดพลาด';
                                });
                              }
                            }
                          },
                          child: Container(
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 26),
                            decoration: const BoxDecoration(
                              color: Color(0xFF313131),
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(50),
                                bottomRight: Radius.circular(50),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'ยืนยัน',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 🌟 ส่วนที่เพิ่มใหม่: ข้อความ Error ใต้ TextField
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}