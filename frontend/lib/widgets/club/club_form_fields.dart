import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:characters/characters.dart';

// ── 1. กล่องตั้งชื่อชมรม ─────────────────────────────────────
class ClubNameField extends StatefulWidget {
  final TextEditingController controller;

  const ClubNameField({super.key, required this.controller});

  @override
  State<ClubNameField> createState() => _ClubNameFieldState();
}

class _ClubNameFieldState extends State<ClubNameField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateState);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateState);
    super.dispose();
  }

  void _updateState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9DD0E7), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'ชื่อชมรม',
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
            controller: widget.controller,
            maxLength: 20,
            inputFormatters: [LengthLimitingTextInputFormatter(20)],
            decoration: InputDecoration(
              counterText: '',
              hintText: 'ตั้งชื่อชมรมของคุณ',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.controller.text.characters.length}/20',
                      style: TextStyle(
                        color: widget.controller.text.characters.length >= 20
                            ? Colors.red
                            : Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Image.asset(
                      'assets/images/icon/iconEdit.png',
                      width: 18,
                      height: 18,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ),
            style: const TextStyle(fontSize: 16, color: Color(0xFF002A50)),
          ),
        ],
      ),
    );
  }
}

// ── 2. กล่องรายละเอียดของชมรม ────────────────────────────────
class ClubDescField extends StatefulWidget {
  final TextEditingController controller;

  const ClubDescField({super.key, required this.controller});

  @override
  State<ClubDescField> createState() => _ClubDescFieldState();
}

class _ClubDescFieldState extends State<ClubDescField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateState);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateState);
    super.dispose();
  }

  void _updateState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9DD0E7), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'รายละเอียด',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF002A50),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.controller.text.characters.length}/300',
                      style: TextStyle(
                        color: widget.controller.text.characters.length >= 300
                            ? Colors.red
                            : Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Image(
                      image: AssetImage('assets/images/icon/iconEdit.png'),
                      width: 18,
                      height: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              maxLength: 300,
              inputFormatters: [LengthLimitingTextInputFormatter(300)],
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'รายละเอียดของชมรม',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}