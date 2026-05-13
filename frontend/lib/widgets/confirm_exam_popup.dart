import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/ticket_box.dart';

class ConfirmExamPopup extends StatefulWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final int ticketCount; // จำนวนตั๋วที่มีอยู่ตอนนี้

  const ConfirmExamPopup({
    Key? key,
    required this.onConfirm,
    required this.onCancel,
    required this.ticketCount,
  }) : super(key: key);

  /// แสดง Popup ยืนยันการเริ่มสอบ
  static Future<void> show(
    BuildContext context, {
    required VoidCallback onConfirm,
    required int ticketCount,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => ConfirmExamPopup(
        onConfirm: onConfirm,
        onCancel: () => Navigator.pop(context),
        ticketCount: ticketCount,
      ),
    );
  }

  @override
  State<ConfirmExamPopup> createState() => _ConfirmExamPopupState();
}

class _ConfirmExamPopupState extends State<ConfirmExamPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    final containerWidth = size.width * 0.85;
    final buttonHeight = isSmallScreen ? 40.0 : 45.0;
    final titleFontSize = isSmallScreen ? 14.0 : 16.0;
    final subtitleFontSize = isSmallScreen ? 11.0 : 13.0;
    final buttonFontSize = isSmallScreen ? 14.0 : 16.0;
    final topPadding = isSmallScreen ? 15.0 : 20.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: containerWidth,
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: const BoxDecoration(color: Colors.transparent),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Main Container
                Container(
                  padding: EdgeInsets.fromLTRB(20, topPadding, 20, 20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.fromARGB(5, 0, 0, 0),
                        Color.fromARGB(80, 0, 0, 0),
                        Color.fromARGB(5, 0, 0, 0),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.5),
                        width: 1,
                      ),
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ยืนยันการเริ่มสอบ?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'หากคุณสอบไม่ผ่านคุณจะเสียบัตรเข้าสอบ\nโดยที่คุณจะไม่ได้รับของรางวัลใดๆทั้งสิ้น',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: subtitleFontSize,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 20),

                      Row(
                        children: [
                          // ⚪ ยกเลิก
                          Expanded(
                            child: GestureDetector(
                              onTap: widget.onCancel,
                              child: Container(
                                height: buttonHeight,
                                margin: EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade600,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Center(
                                  child: Text(
                                    'ยกเลิก',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: buttonFontSize,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 🔵 ยืนยัน with Badge (บัตรเข้าสอบ)
                          Expanded(
                            child: GestureDetector(
                              onTap: widget.onConfirm,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    height: buttonHeight,
                                    margin: EdgeInsets.only(left: 8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFF556AEB),
                                          Color(0xFF59ABEC),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'เริ่มสอบ',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: buttonFontSize,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Badge แสดงว่าเสียบัตรเข้าสอบ 1 ใบ
                                  Positioned(
                                    top: -15,
                                    right: -6,
                                    child: TicketBox(
                                      slant: 12,
                                      borderRadius: 4,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 15,
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Image.asset(
                                              'assets/images/item/Ticket_exam_img.png',
                                              width: 20,
                                              height: 10,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              "-1",
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
