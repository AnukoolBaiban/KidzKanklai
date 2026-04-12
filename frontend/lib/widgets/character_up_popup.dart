import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api_service.dart';
import 'character_widget.dart';

/// Popup สำหรับแสดงวิวัฒนาการตัวละครตอน Level Up พร้อมเอฟเฟคแบบ Pokemon
class CharacterUpPopup extends StatefulWidget {
  final int baseLevel;
  final int newLevel;
  final User? user; // รับ User มาเพื่อเรนเดอร์โมเดลที่มีชุดต่างๆ
  final VoidCallback onTapContinue;

  const CharacterUpPopup({
    super.key,
    required this.baseLevel,
    required this.newLevel,
    this.user,
    required this.onTapContinue,
  });

  /// Method สำหรับเรียกใช้งาน CharacterUpPopup
  static Future<void> show(
    BuildContext context, {
    required int baseLevel,
    required int newLevel,
    User? user,
    required VoidCallback onTapContinue,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      barrierDismissible: false,
      builder: (context) => CharacterUpPopup(
        baseLevel: baseLevel,
        newLevel: newLevel,
        user: user,
        onTapContinue: onTapContinue,
      ),
    );
  }

  @override
  State<CharacterUpPopup> createState() => _CharacterUpPopupState();
}

class _CharacterUpPopupState extends State<CharacterUpPopup>
    with TickerProviderStateMixin {
  bool _canClose = false;

  // ─── Animations ───────────────────────────────────────────────────────────
  late final AnimationController _popupController = AnimationController(
    duration: const Duration(milliseconds: 400),
    vsync: this,
  )..forward();

  late final Animation<double> _scaleAnimation = CurvedAnimation(
    parent: _popupController,
    curve: Curves.easeOutBack,
  );

  late final Animation<double> _fadeAnimation = CurvedAnimation(
    parent: _popupController,
    curve: Curves.easeIn,
  );

  // Pokemon Evolution Animation
  late final AnimationController _evoController = AnimationController(
    duration: const Duration(milliseconds: 4500),
    vsync: this,
  )..forward();

  @override
  void initState() {
    super.initState();
    // ให้อนุญาตปิดได้หลังจากการวิวัฒนาการจบ (5 วินาที)
    Future.delayed(const Duration(milliseconds: 5000), () {
      if (mounted) {
        setState(() => _canClose = true);
      }
    });
  }

  @override
  void dispose() {
    _popupController.dispose();
    _evoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 380;

    return GestureDetector(
      onTap: _canClose
          ? () {
              widget.onTapContinue();
              Navigator.pop(context);
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.zero,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: SizedBox.expand(
              child: _buildFullScreenContent(isSmall),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullScreenContent(bool isSmall) {
    return Column(
      children: [
        // ── ส่วนบน: เลขเลเวล + LEVEL UP! + กล่องเลเวล ──────────────────────
        _buildTopSection(isSmall),

        // ── ส่วนกลาง: พื้นที่ตัวละครและเอฟเฟควิวัฒนาการ ──────────────────────────
        Expanded(
          child: _buildCharacterArea(isSmall),
        ),

        // ── ส่วนล่างสุด: แตะเพื่อดำเนินการต่อ ──────────────────────────────
        _buildTapToContinue(isSmall),
        SizedBox(height: isSmall ? 30.0 : 48.0),
      ],
    );
  }

  // ─── Top Section ──────────────────────────────────────────────────────────
  Widget _buildTopSection(bool isSmall) {
    final paddingTop = isSmall ? 40.0 : 60.0;
    final gapSmall = isSmall ? 0.0 : 4.0;
    final gapAfterBox = isSmall ? 12.0 : 16.0;

    return Padding(
      padding: EdgeInsets.only(top: paddingTop, bottom: gapAfterBox),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLatestLevel(isSmall),
          SizedBox(height: gapSmall),
          _buildTitleRow(isSmall),
          SizedBox(height: isSmall ? 12.0 : 16.0),
          _buildLevelTransitionBox(isSmall),
        ],
      ),
    );
  }

  // ─── ตัวเลขเลเวลล่าสุดขนาดใหญ่ ──────────────────────────────────────────
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

  // ─── แถว "LEVEL UP!" + ดาว ────────────────────────────────────────────────
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

  // ─── ข้อความ "LEVEL UP!" แบบ Gradient ───────────────────────────────────
  Widget _buildLevelUpGradientText(bool isSmall) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Color(0xFFC6F4FF)],
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

  // ─── กล่องแสดงการเปลี่ยนเลเวล ────────────────────────────────────────────
  Widget _buildLevelTransitionBox(bool isSmall) {
    final fontSize = isSmall ? 20.0 : 24.0;
    final padding = isSmall ? 15.0 : 20.0;
    final arrowSize = isSmall ? 24.0 : 28.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: padding),
      decoration: const BoxDecoration(
        color: Color(0xFF002A50),
        border: Border.symmetric(
          horizontal: BorderSide(color: Color(0xFFC6F4FF), width: 1.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLevelText('Lv. ${widget.baseLevel}', Colors.white70, fontSize),
          const SizedBox(width: 15),
          Icon(Icons.arrow_forward_rounded, color: const Color(0xFFC6F4FF), size: arrowSize),
          const SizedBox(width: 15),
          _buildLevelText('Lv. ${widget.newLevel}', Colors.white, fontSize, isBold: true),
        ],
      ),
    );
  }

  // ─── ข้อความเลเวล ─────────────────────────────────────────────────────────
  Widget _buildLevelText(String text, Color color, double fontSize, {bool isBold = false}) {
    return Text(
      text,
      style: GoogleFonts.kanit(
        color: color,
        fontSize: fontSize,
        fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
        shadows: isBold
            ? const [Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1))]
            : null,
      ),
    );
  }

  // ─── Pokemon Evolution Logic ─────────────────────────────────────────────
  bool _isShowingNewForm(double progress) {
    if (progress < 0.2) return false;
    if (progress > 0.8) return true;
    double n = (progress - 0.2) / 0.6; // 0.0 to 1.0
    double freq = 10 + (30 * n); // ความถี่การสลับร่างเพิ่มขึ้นเรื่อยๆ
    return sin(n * freq * pi) > 0;
  }

  bool _isWhiteGlow(double progress) {
    if (progress < 0.1) return false;
    if (progress > 0.9) return false;
    return true;
  }

  // ─── พื้นที่ตัวละครและเอฟเฟค ─────────────────────────────────────────────
  Widget _buildCharacterArea(bool isSmall) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // เอฟเฟคแสงส่องจากด้านล่าง (Radial Glow)
        Positioned(
          bottom: 0,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFC6F4FF).withOpacity(0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // ── ตัวละครที่มีแอนิเมชั่นวิวัฒนาการ ─────────────────────────────────
        AnimatedBuilder(
          animation: _evoController,
          builder: (context, child) {
            final progress = _evoController.value;
            final isNew = _isShowingNewForm(progress);
            final isWhiteGlow = _isWhiteGlow(progress);

            // ใช้ IndexedStack เพื่อให้ Widget ทั้งคู่(ร่างเก่าและใหม่)โหลดทิ้งไว้ 
            // จะได้ไม่มีอาการโหลด Rive ช้าตอนสลับภาพกระพริบ
            Widget characterStack = IndexedStack(
              index: isNew ? 1 : 0,
              children: [
                CharacterWidget(
                  user: widget.user,
                  overrideLevel: widget.baseLevel, // บังคับเป็นร่างก่อนหน้า
                  height: isSmall ? 350 : 450,
                  width: isSmall ? 300 : 400,
                ),
                CharacterWidget(
                  user: widget.user,
                  overrideLevel: widget.newLevel, // บังคับเป็นร่างใหม่
                  height: isSmall ? 350 : 450,
                  width: isSmall ? 300 : 400,
                ),
              ],
            );

            // เมื่อเข้าสู่สถานะเรืองแสง
            if (isWhiteGlow) {
              double intensity = 1.0;
              if (progress > 0.1 && progress < 0.2) {
                intensity = (progress - 0.1) / 0.1; // ค่อยๆ เป็นสีขาว
              } else if (progress > 0.8 && progress < 0.9) {
                intensity = 1.0 - ((progress - 0.8) / 0.1); // จางสีขาวออกกลับเป็นปกติ
              }

              characterStack = ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    colors: [
                      Colors.white.withOpacity(max(0, min(1, intensity))),
                      Colors.white.withOpacity(max(0, min(1, intensity)))
                    ],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcATop,
                child: characterStack,
              );
            }

            // ตอนเผยร่างใหม่เสร็จ มี Bounce ให้ดีใจ
            double scale = 1.0;
            if (progress > 0.88 && progress < 0.95) {
              double pop = (progress - 0.88) / 0.07;
              scale = 1.0 + (sin(pop * pi) * 0.15); // ตัวละครเด้งขยายใหญ่ชั่วขณะ
            }

            return Transform.scale(
              scale: scale,
              child: characterStack,
            );
          },
        ),
      ],
    );
  }

  // ─── ข้อความ "แตะเพื่อดำเนินการต่อ" ─────────────────────────────────────
  Widget _buildTapToContinue(bool isSmall) {
    return AnimatedOpacity(
      opacity: _canClose ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Text(
        'แตะเพื่อดำเนินการต่อ',
        style: GoogleFonts.kanit(
          color: Colors.white70,
          fontSize: isSmall ? 14.0 : 16.0,
        ),
      ),
    );
  }
}