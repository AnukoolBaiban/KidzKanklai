import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Popup สำหรับแสดงหน้าจอ "Level Up"
class LevelUpPopup extends StatefulWidget {
  final int baseLevel;
  final int newLevel;
  final VoidCallback onTapContinue;

  const LevelUpPopup({
    super.key,
    required this.baseLevel,
    required this.newLevel,
    required this.onTapContinue,
  });

  /// Method สำหรับเรียกใช้งาน LevelUpPopup
  static Future<void> show(
    BuildContext context, {
    required int baseLevel,
    required int newLevel,
    required VoidCallback onTapContinue,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => LevelUpPopup(
        baseLevel: baseLevel,
        newLevel: newLevel,
        onTapContinue: onTapContinue,
      ),
    );
  }

  @override
  State<LevelUpPopup> createState() => _LevelUpPopupState();
}

class _LevelUpPopupState extends State<LevelUpPopup>
    with SingleTickerProviderStateMixin {
  // Animations & State Initialization
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 350),
    vsync: this,
  )..forward();

  late final Animation<double> _scaleAnimation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
  );

  late final Animation<double> _fadeAnimation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeIn,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Main Layout Build
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onTapContinue();
        Navigator.pop(context); // ปิด Popup เมื่อกดหน้าจอ
      },
      behavior: HitTestBehavior.opaque,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.zero,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // คำนวณขนาดหน้าจอสำหรับการทำ Responsive
                final screenWidth = MediaQuery.of(context).size.width;
                final isSmallScreen = screenWidth < 380;

                return _buildPopupContent(isSmallScreen);
              },
            ),
          ),
        ),
      ),
    );
  }

  // UI Components Builder
  Widget _buildPopupContent(bool isSmall) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildBackgroundBlur(isSmall),
          _buildForegroundContent(isSmall),
        ],
      ),
    );
  }

  // Background Effect
  Widget _buildBackgroundBlur(bool isSmall) {
    final size = isSmall ? 100.0 : 150.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC6F4FF).withOpacity(0.35),
            blurRadius: 80,
            spreadRadius: 30,
          ),
        ],
      ),
    );
  }

  // เนื้อหาหลักของ Popup โครงสร้างบนลงล่าง
  Widget _buildForegroundContent(bool isSmall) {
    final paddingBottom = isSmall ? 15.0 : 20.0;

    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLatestLevel(isSmall),
          _buildTitleRow(isSmall),
          SizedBox(height: paddingBottom),
          _buildLevelTransitionBox(isSmall),
          SizedBox(height: paddingBottom + 10),
          _buildTapToContinue(isSmall),
        ],
      ),
    );
  }

  // ข้อความ "ตัวเลขเลเวลล่าสุด" ขนาดใหญ่
  Widget _buildLatestLevel(bool isSmall) {
    return Text(
      widget.newLevel.toString(),
      style: GoogleFonts.kanit(
        fontSize: isSmall ? 80.0 : 100.0,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        height: 1.0,
        shadows: const [
          Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
    );
  }

  // แถวข้อความ "LEVEL UP!" และรูปดาว
  Widget _buildTitleRow(bool isSmall) {
    final iconSize = isSmall ? 24.0 : 30.0;
    final spacing = isSmall ? 10.0 : 15.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/design/star.png',
          width: iconSize,
          height: iconSize,
        ),
        SizedBox(width: spacing),
        _buildLevelUpGradientText(isSmall),
        SizedBox(width: spacing),
        Image.asset(
          'assets/images/design/star.png',
          width: iconSize,
          height: iconSize,
        ),
      ],
    );
  }

  // ข้อความ "LEVEL UP"
  Widget _buildLevelUpGradientText(bool isSmall) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Color(0xFFC6F4FF)], // ไล่สีจากขาวไปสีฟ้าอ่อน
      ).createShader(bounds),
      child: Text(
        'LEVEL UP!',
        style: GoogleFonts.kanit(
          fontSize: isSmall ? 28.0 : 36.0,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [
            Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
      ),
    );
  }

  // กล่องแสดงการเลื่อนเลเวล
  Widget _buildLevelTransitionBox(bool isSmall) {
    final fontSize = isSmall ? 20.0 : 24.0;
    final padding = isSmall ? 15.0 : 20.0;
    final arrowSize = isSmall ? 24.0 : 28.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: padding),
      decoration: const BoxDecoration(
        color: Color(0xFF002A50), // พื้นหลังกล่องสีน้ำเงินเข้ม
        border: Border.symmetric(
          horizontal: BorderSide(
            color: Color(0xFFC6F4FF),
            width: 1.5,
          ), // ขอบเส้นสว่าง
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // เลเวลเดิม
          _buildLevelText('Lv. ${widget.baseLevel}', Colors.white70, fontSize),
          const SizedBox(width: 15),
          // ลูกศรเปลี่ยนเลเวล
          Icon(
            Icons.arrow_forward_rounded,
            color: const Color(0xFFC6F4FF),
            size: arrowSize,
          ),
          const SizedBox(width: 15),
          // เลเวลใหม่
          _buildLevelText(
            'Lv. ${widget.newLevel}',
            Colors.white,
            fontSize,
            isBold: true,
          ),
        ],
      ),
    );
  }

  // รูปแบบอักษรสำหรับ "Lv. X"
  Widget _buildLevelText(
    String text,
    Color color,
    double fontSize, {
    bool isBold = false,
  }) {
    return Text(
      text,
      style: GoogleFonts.kanit(
        color: color,
        fontSize: fontSize,
        fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
        shadows: isBold
            ? const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildTapToContinue(bool isSmall) {
    return Text(
      'แตะเพื่อดำเนินการต่อ',
      style: GoogleFonts.kanit(
        color: Colors.white70,
        fontSize: isSmall ? 14.0 : 16.0,
      ),
    );
  }
}