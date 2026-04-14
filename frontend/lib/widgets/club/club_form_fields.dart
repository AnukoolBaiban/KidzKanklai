import 'package:flutter/material.dart';

// ── 1. กล่องตั้งชื่อชมรม ─────────────────────────────────────
class ClubNameField extends StatelessWidget {
  final TextEditingController controller;

  const ClubNameField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFAAD7EA), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ตั้งชื่อชมรมของคุณ',
            style: TextStyle(
              fontSize: size.width * 0.06 > 24 ? 24 : size.width * 0.06,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF333333),
            ),
          ),
          TextField(
            controller: controller,
            style: TextStyle(
              fontSize: size.width * 0.038 > 16 ? 16 : size.width * 0.038,
              color: const Color(0xFF444444),
            ),
            decoration: const InputDecoration(
              hintText: 'ชื่อชมรม',
              hintStyle: TextStyle(color: Color(0xFFBBBBBB)),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: Color.fromRGBO(68, 113, 153, 1),
                  width: 1.5,
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: Color.fromRGBO(68, 113, 153, 1),
                  width: 2,
                ),
              ),
              contentPadding: EdgeInsets.only(top: 8, bottom: 4),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2. กล่องรายละเอียดของชมรม ────────────────────────────────
class ClubDescField extends StatelessWidget {
  final TextEditingController controller;

  const ClubDescField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      width: double.infinity,
      height: 120, // ใช้ Fixed height เป็น Responsive base ที่ดีกว่า
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFAAD7EA), width: 2),
      ),
      child: TextField(
        controller: controller,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: TextStyle(
          fontSize: size.width * 0.038 > 16 ? 16 : size.width * 0.038,
          color: const Color(0xFF444444),
          height: 1.5,
        ),
        decoration: const InputDecoration(
          hintText: 'รายละเอียด',
          hintStyle: TextStyle(color: Color(0xFFBBBBBB)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
      ),
    );
  }
}

// ── 3. กล่องสร้างรหัสชมรม ────────────────────────────────────
class ClubCodeSection extends StatelessWidget {
  final String? generatedCode;
  final bool isCodePressed;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;
  final VoidCallback onTapCancel;
  final VoidCallback onTap;

  const ClubCodeSection({
    super.key,
    required this.generatedCode,
    required this.isCodePressed,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFAAD7EA), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // แสดงรหัสที่สร้างแล้ว (ถ้ามี)
          if (generatedCode != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F8FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFAAD7EA), width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    generatedCode!,
                    style: TextStyle(
                      fontSize: size.width * 0.055 > 24 ? 24 : size.width * 0.055,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2374B5),
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          // ปุ่มสร้างรหัส
          GestureDetector(
            onTapDown: (_) => onTapDown(),
            onTapUp: (_) => onTapUp(),
            onTapCancel: onTapCancel,
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
              decoration: BoxDecoration(
                color: isCodePressed ? Colors.black : const Color(0xFF313131),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                generatedCode == null ? 'สร้างรหัส' : 'สร้างรหัสใหม่',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size.width * 0.042 > 16 ? 16 : size.width * 0.042,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Label เล็กๆ ─────────────────────────────────────────
class SectionLabel extends StatelessWidget {
  final String text;

  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Text(
      text,
      style: TextStyle(
        fontSize: size.width * 0.042 > 18 ? 18 : size.width * 0.042,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF333333),
      ),
    );
  }
}