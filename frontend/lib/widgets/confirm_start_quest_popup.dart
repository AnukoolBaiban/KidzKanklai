import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/ticket_box.dart';

class ConfirmStartQuestPopup extends StatefulWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ConfirmStartQuestPopup({
    Key? key,
    required this.onConfirm,
    required this.onCancel,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onConfirm,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => ConfirmStartQuestPopup(
        onConfirm: onConfirm,
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  @override
  State<ConfirmStartQuestPopup> createState() => _ConfirmStartQuestPopupState();
}

class _ConfirmStartQuestPopupState extends State<ConfirmStartQuestPopup>
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
    // ✅ Responsive values
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
                    gradient: const LinearGradient(
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
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ยืนยันที่จะเริ่มทำภารกิจทันที?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ภารกิจของคุณจะเริ่มนับเวลาถอยหลังทันที',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: subtitleFontSize,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          // ⚪ ยกเลิก
                          Expanded(
                            child: GestureDetector(
                              onTap: widget.onCancel,
                              child: Container(
                                height: buttonHeight,
                                margin: const EdgeInsets.only(right: 8),
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

                          // 🔵 ยืนยัน with Badge
                          Expanded(
                            child: GestureDetector(
                              onTap: widget.onConfirm,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    height: buttonHeight,
                                    margin: const EdgeInsets.only(left: 8),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
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
                                        'ยืนยัน',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: buttonFontSize,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Badge
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
                                              'assets/images/item/Ticket_quest_img.png',
                                              width: 20,
                                              height: 10,
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
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
