import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ============================================================
// Model: ข้อมูลภารกิจแนะนำแต่ละรายการ
// ============================================================
class RecommendedQuest {
  final String title;
  final int exp;
  final String itemImagePath;
  final int itemAmount;
  final int progress;
  final int totalReq;
  final VoidCallback onTap;

  const RecommendedQuest({
    required this.title,
    required this.exp,
    required this.itemImagePath,
    required this.itemAmount,
    required this.progress,
    required this.totalReq,
    required this.onTap,
  });
}

// ============================================================
// Widget หลัก: RecommendQuestPopup
// ============================================================
class RecommendQuestPopup extends StatefulWidget {
  final List<RecommendedQuest> quests;
  final VoidCallback? onTapContinue;

  const RecommendQuestPopup({
    super.key,
    required this.quests,
    this.onTapContinue,
  });

  /// เรียกแสดง Popup
  static Future<void> show(
    BuildContext context, {
    required List<RecommendedQuest> quests,
    VoidCallback? onTapContinue,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) =>
          RecommendQuestPopup(quests: quests, onTapContinue: onTapContinue),
    );
  }

  /// ชุดภารกิจแนะนำมาตรฐานที่ใช้ในหน้า Countdown Quest
  static Future<void> showDefaultForCountdown(BuildContext context) {
    final quests = [
      RecommendedQuest(
        title: 'สำเร็จภารกิจระบบ 6 อย่าง',
        exp: 100,
        itemImagePath: 'assets/images/item/Ticket_quest_img.png',
        itemAmount: 1,
        progress: 1,
        totalReq: 6,
        onTap: () {
          Navigator.pushNamed(context, '/lobby');
        },
      ),
      RecommendedQuest(
        title: 'สร้างภารกิจส่วนตัว 3 ครั้ง',
        exp: 100,
        itemImagePath: 'assets/images/item/Ticket_quest_img.png',
        itemAmount: 1,
        progress: 1,
        totalReq: 6,
        onTap: () {
          Navigator.pushNamed(context, '/allquest');
        },
      ),
      RecommendedQuest(
        title: 'สอบวัดระดับความสามารถผ่านทั้ง 3 ระดับ',
        exp: 100,
        itemImagePath: 'assets/images/item/Ticket_quest_img.png',
        itemAmount: 1,
        progress: 1,
        totalReq: 6,
        onTap: () {
          Navigator.pushNamed(context, '/profile');
        },
      ),
    ];

    return show(context, quests: quests, onTapContinue: () {});
  }

  @override
  State<RecommendQuestPopup> createState() => _RecommendQuestPopupState();
}

class _RecommendQuestPopupState extends State<RecommendQuestPopup>
    with SingleTickerProviderStateMixin {
  // --- Animations ---
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

  int? _pressedIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapContinue() {
    widget.onTapContinue?.call();
    Navigator.pop(context);
  }

  // --- Main Build ---
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isSmall = width < 380;
              final maxHeight = constraints.maxHeight * 0.85;
              return _buildPopupContent(
                isSmall: isSmall,
                maxHeight: maxHeight,
              );
            },
          ),
        ),
      ),
    );
  }

  // ============================================================
  // โครงสร้างหลัก: หัวข้อ (ลอย) + กล่อง quest + footer
  // ============================================================
  Widget _buildPopupContent({
    required bool isSmall,
    required double maxHeight,
  }) {
    final horizontalPadding = isSmall ? 12.0 : 16.0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: maxHeight,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(isSmall),
                const SizedBox(height: 6),
                _buildSubtitle(isSmall),
                const SizedBox(height: 10),
                _buildQuestBox(isSmall),
                _buildTapToContinue(isSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Header: ลอยอยู่เหนือกล่อง (ไม่มีพื้นหลัง)
  // ============================================================
  Widget _buildHeader(bool isSmall) {
    final titleFontSize = isSmall ? 22.0 : 28.0;
    final starSize = isSmall ? 22.0 : 28.0;
    final spacing = isSmall ? 10.0 : 15.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/design/star.png',
          width: starSize,
          height: starSize,
        ),
        SizedBox(width: spacing),
        Text(
          'ภารกิจแนะนำ',
          style: GoogleFonts.kanit(
            fontSize: titleFontSize,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFFFD700),
            shadows: const [
              Shadow(
                color: Colors.black54,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        SizedBox(width: spacing),
        Image.asset(
          'assets/images/design/star.png',
          width: starSize,
          height: starSize,
        ),
      ],
    );
  }

  // ============================================================
  // กล่องภารกิจ: gradient border style เดียวกับ mission_fail_popup
  // ============================================================
  Widget _buildQuestBox(bool isSmall) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isSmall ? 4.0 : 8.0),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: const [0.0, 0.25, 0.75, 1.0],
          colors: [
            const Color(0xFFC6F4FF).withValues(alpha: 0.05),
            Colors.black.withValues(alpha: 0.30),
            Colors.black.withValues(alpha: 0.30),
            const Color(0xFFC6F4FF).withValues(alpha: 0.05),
          ],
        ),
        border: const Border.symmetric(
          horizontal: BorderSide(color: Colors.white, width: 1.0),
        ),
      ),
      // เฉพาะ quest rows — subtitle และ footer อยู่นอกกล่อง
      child: _buildQuestList(isSmall),
    );
  }

  // ============================================================
  // Subtitle
  // ============================================================
  Widget _buildSubtitle(bool isSmall) {
    return Text(
      'ทำภารกิจต่อไปนี้เพื่อรับรางวัลเพิ่มเติมได้ทันที',
      textAlign: TextAlign.center,
      style: GoogleFonts.kanit(
        fontSize: isSmall ? 13.0 : 15.0,
        color: Colors.white70,
      ),
    );
  }

  // ============================================================
  // รายการภารกิจ (Quest List)
  // ============================================================
  Widget _buildQuestList(bool isSmall) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < widget.quests.length; i++)
          _buildQuestRow(
            quest: widget.quests[i],
            isSmall: isSmall,
            index: i,
          ),
      ],
    );
  }

  Widget _buildQuestRow({
    required RecommendedQuest quest,
    required bool isSmall,
    required int index,
  }) {
    final bool isPressed = _pressedIndex == index;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressedIndex = index);
      },
      onTapCancel: () {
        setState(() => _pressedIndex = null);
      },
      onTap: () {
        setState(() => _pressedIndex = null);
        Navigator.pop(context); // ปิด popup ก่อน
        quest.onTap(); // ไปยังหน้าภารกิจ
      },
      child: Container(
        decoration: BoxDecoration(
          color:
              isPressed ? Colors.white.withValues(alpha: 0.10) : Colors.transparent,
          border: const Border(
            top: BorderSide(color: Colors.white24, width: 0.8),
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 14.0 : 18.0,
          vertical: isSmall ? 10.0 : 14.0,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ชื่อภารกิจ + Progress Bar
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quest.title,
                    style: GoogleFonts.kanit(
                      fontSize: isSmall ? 13.0 : 15.0,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  _buildProgressBar(quest, isSmall),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // รูปรางวัล EXP
            _buildRewardBadge(
              iconPath: 'assets/images/item/EXP.png',
              label: '+${quest.exp}',
              isSmall: isSmall,
            ),

            const SizedBox(width: 6),

            // รูปรางวัล Item
            _buildRewardBadge(
              iconPath: quest.itemImagePath,
              label: 'x${quest.itemAmount}',
              isSmall: isSmall,
            ),

            const SizedBox(width: 10),

            // ลูกศรชี้ขวา
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white54,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // แถบ Progress Bar
  Widget _buildProgressBar(RecommendedQuest quest, bool isSmall) {
    final ratio = quest.totalReq > 0 ? quest.progress / quest.totalReq : 0.0;
    final clampedRatio = ratio.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (_, constraints) {
        final barWidth = constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                // พื้นหลัง bar
                Container(
                  height: 10,
                  width: barWidth,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // Progress Fill
                Container(
                  height: 10,
                  width: barWidth * clampedRatio,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF59ABEC), Color(0xFF85D755)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '${quest.progress}/${quest.totalReq}',
              style: GoogleFonts.kanit(
                fontSize: isSmall ? 11.0 : 12.0,
                color: Colors.white54,
              ),
            ),
          ],
        );
      },
    );
  }

  // กล่องรางวัล (EXP / Item)
  Widget _buildRewardBadge({
    required String iconPath,
    required String label,
    required bool isSmall,
  }) {
    final boxSize = isSmall ? 46.0 : 52.0;
    final iconSize = isSmall ? 30.0 : 34.0;

    return Container(
      width: boxSize,
      height: boxSize + 16,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Image.asset(
                iconPath,
                width: iconSize,
                height: iconSize,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(3, 0, 3, 3),
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFD9D9D9),
              borderRadius: BorderRadius.circular(5),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Footer: "แตะเพื่อดำเนินการต่อ"
  // ============================================================
  Widget _buildTapToContinue(bool isSmall) {
    return GestureDetector(
      onTap: _onTapContinue,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: isSmall ? 14.0 : 18.0),
        child: Text(
          'แตะเพื่อดำเนินการต่อ',
          style: GoogleFonts.kanit(
            fontSize: isSmall ? 13.0 : 15.0,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }
}