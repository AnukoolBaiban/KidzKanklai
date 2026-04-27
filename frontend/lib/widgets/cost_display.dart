import 'package:flutter/material.dart';

/// Widget แสดง Cost แบบมีหางชี้ (Speech Bubble)
class CostDisplayWidget extends StatelessWidget {
  final int energyCost;
  final String? energyCostText; // 🌟 1. เพิ่มตัวแปรนี้เข้ามารองรับข้อความ
  final int ticketCost;
  final bool showTicket;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final bool showEnergy;

  const CostDisplayWidget({
    Key? key,
    this.energyCost = 20,
    this.energyCostText, // 🌟 2. ใส่ใน Constructor
    this.ticketCost = 1,
    this.showTicket = true,
    this.showEnergy = true,
    this.backgroundColor = Colors.white,
    this.borderColor = Colors.black,
    this.borderWidth = 1.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SpeechBubblePainter(
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        borderWidth: borderWidth,
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🌟 เพิ่มคำว่า "ใช้ " ไว้ข้างหน้า
            Text(
              'ใช้ ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            // Energy Box
            if (showEnergy)
              _buildCostItem(
                icon: 'assets/images/item/energy.png',
                // 🌟 ลบเครื่องหมายลบออก
                value: energyCostText != null ? energyCostText! : '$energyCost',
                fallbackIcon: Icons.flash_on,
                fallbackColor: Colors.yellow,
              ),

            if (showTicket) ...[
              if (showEnergy) ...[
                SizedBox(width: 8),
                Text(
                  'และ',
                  style: TextStyle(
                    fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                  ),
                ),
                SizedBox(width: 8),
              ],

              _buildCostItem(
                icon: 'assets/images/item/Ticket_energy_img.png',
                value: ' $ticketCost',
                fallbackIcon: Icons.confirmation_number,
                fallbackColor: Colors.green,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCostItem({
    required String icon,
    required String value,
    required IconData fallbackIcon,
    required Color fallbackColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            icon,
            width: 20,
            height: 20,
            errorBuilder: (context, error, stackTrace) {
              return Icon(fallbackIcon, color: fallbackColor, size: 20);
            },
          ),
          SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
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
    final radius = 12.0;
    final tailHeight = 8.0;
    final tailWidth = 14.0;

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
