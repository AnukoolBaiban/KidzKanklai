import 'package:flutter/material.dart';

/// Widget แสดง Cost แบบมีหางชี้ (Speech Bubble)
class CostDisplayWidget extends StatelessWidget {
  final int energyCost;
  final int ticketCost;
  final bool showTicket;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;

  const CostDisplayWidget({
    Key? key,
    this.energyCost = 20,
    this.ticketCost = 1,
    this.showTicket = true,
    this.backgroundColor = Colors.white,
    this.borderColor = Colors.black,
    this.borderWidth = 3.0,
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
        padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Energy
            Image.asset(
              'assets/images/item/energy.png',
              width: 28,
              height: 28,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.flash_on, color: Colors.yellow, size: 28);
              },
            ),
            SizedBox(width: 8),
            Text(
              '-$energyCost',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),

            if (showTicket) ...[
              SizedBox(width: 16),
              Text(
                'และ',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              SizedBox(width: 16),

              // Ticket
              Image.asset(
                'assets/images/item/Ticket_energy_img.png',
                width: 28,
                height: 28,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.confirmation_number,
                      color: Colors.green, size: 28);
                },
              ),
              SizedBox(width: 8),
              Text(
                '-$ticketCost',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ],
        ),
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
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final path = Path();
    final radius = 20.0;
    final tailHeight = 16.0;
    final tailWidth = 24.0;

    // Main bubble (rounded rectangle)
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - tailHeight),
      Radius.circular(radius),
    );

    // Start from bottom-left of main bubble
    path.addRRect(rect);

    // Add tail (triangle pointing down)
    final tailStartX = size.width / 2 - tailWidth / 2;
    final tailEndX = size.width / 2 + tailWidth / 2;
    final tailTipX = size.width / 2;
    final tailBaseY = size.height - tailHeight;
    final tailTipY = size.height;

    final tailPath = Path();
    tailPath.moveTo(tailStartX, tailBaseY);
    tailPath.lineTo(tailTipX, tailTipY);
    tailPath.lineTo(tailEndX, tailBaseY);
    tailPath.close();

    // Combine main bubble and tail
    path.addPath(tailPath, Offset.zero);

    // Draw shadow
    canvas.drawShadow(
      path,
      Colors.black.withOpacity(0.15),
      4.0,
      false,
    );

    // Draw fill
    canvas.drawPath(path, paint);

    // Draw border
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}