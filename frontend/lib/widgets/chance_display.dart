import 'package:flutter/material.dart';

/// Widget แสดง Cost แบบมีหางชี้ (Speech Bubble)
class ChanceDisplay extends StatelessWidget {
  final int energyCost;
  final int ticketCost;
  final bool showTicket;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final bool showEnergy;
  final int chancePercent;

  const ChanceDisplay({
    Key? key,
    this.energyCost = 20,
    this.ticketCost = 1,
    this.showTicket = true,
    this.showEnergy = true,
    this.backgroundColor = Colors.white,
    this.borderColor = Colors.black,
    this.borderWidth = 1.0,
    this.chancePercent = 50, // 🔥 default
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SpeechBubblePainter(
        backgroundColor: _getChanceColor(),
        borderColor: borderColor,
        borderWidth: borderWidth,
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 22),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'โอกาสผ่าน $chancePercent%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getChanceColor() {
  if (chancePercent < 40) {
    return Color(0xFFE94444); // 🔴 ต่ำ
  } else if (chancePercent < 70) {
    return Color(0xFFFFC300); // 🟡 กลาง
  } else {
    return Color(0xFF48BA05); // 🟢 สูง
  }
}

  Widget _buildCostItem({
    required String icon,
    required String value,
    required IconData fallbackIcon,
    required Color fallbackColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            icon,
            width: 24,
            height: 24,
            errorBuilder: (context, error, stackTrace) {
              return Icon(fallbackIcon, color: fallbackColor, size: 24);
            },
          ),
          SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter สำหรับวาด Speech Bubble
class SpeechBubblePainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;

  SpeechBubblePainter({
    required this.backgroundColor,
    required this.borderColor,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = 16.0;
    final tailHeight = 12.0;
    final tailWidth = 20.0;

    final bubbleHeight = size.height - tailHeight;
    final tailStartX = size.width / 2 - tailWidth / 2;
    final tailEndX = size.width / 2 + tailWidth / 2;
    final tailTipX = size.width / 2;
    final tailBaseY = bubbleHeight;
    final tailTipY = size.height;

    // สร้าง Path สำหรับ main bubble + tail
    final path = Path();

    // เริ่มจากมุมบนซ้าย
    path.moveTo(radius, 0);

    // ขอบบน
    path.lineTo(size.width - radius, 0);
    path.arcToPoint(
      Offset(size.width, radius),
      radius: Radius.circular(radius),
    );

    // ขอบขวา
    path.lineTo(size.width, bubbleHeight - radius);
    path.arcToPoint(
      Offset(size.width - radius, bubbleHeight),
      radius: Radius.circular(radius),
    );

    // ขอบล่างด้านขวา (ก่อนหาง)
    path.lineTo(tailEndX, tailBaseY);

    // หาง (สามเหลี่ยม)
    path.lineTo(tailTipX, tailTipY);
    path.lineTo(tailStartX, tailBaseY);

    // ขอบล่างด้านซ้าย (หลังหาง)
    path.lineTo(radius, bubbleHeight);
    path.arcToPoint(
      Offset(0, bubbleHeight - radius),
      radius: Radius.circular(radius),
    );

    // ขอบซ้าย
    path.lineTo(0, radius);
    path.arcToPoint(Offset(radius, 0), radius: Radius.circular(radius));

    path.close();

    // วาด Shadow
    canvas.drawShadow(path, Colors.black.withOpacity(0.2), 4.0, false);

    // วาด Fill
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    // วาด Border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
