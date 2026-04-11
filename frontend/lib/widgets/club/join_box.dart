import 'package:flutter/material.dart';

import 'package:flutter_application_1/screens/club_room_member.dart';

class JoinCodeBox extends StatelessWidget {
  final TextEditingController codeController;
  final VoidCallback onClose;

  const JoinCodeBox({
    super.key,
    required this.codeController,
    required this.onClose,
  });

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
                        onTap: onClose,
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
                    height:
                        50, // ใช้ Fixed height เพื่อป้องกัน Input field เล็กไปในจอเล็ก
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: const Color(0xFFC2E0E5),
                        width: 1.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: TextField(
                              controller: codeController,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF444444),
                              ),
                              decoration: const InputDecoration(
                                hintText: 'กรอกรหัส',
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
                          onTap: () {
                            final code = codeController.text.trim();
                            if (code.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('กรุณากรอกรหัสชมรม'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }
                            // ถ้ากรอกรหัสแล้วให้ไปข้ามไปหน้า Member ทันที
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ClubRoomMemberScreen(),
                              ),
                            );
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}