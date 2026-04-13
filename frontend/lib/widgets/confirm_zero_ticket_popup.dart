import 'package:flutter/material.dart';

class ConfirmZeroTicketPopup extends StatefulWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ConfirmZeroTicketPopup({
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
      builder: (context) => ConfirmZeroTicketPopup(
        onConfirm: onConfirm,
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  @override
  State<ConfirmZeroTicketPopup> createState() => _ConfirmZeroTicketPopupState();
}

class _ConfirmZeroTicketPopupState extends State<ConfirmZeroTicketPopup>
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
    final containerHeight = isSmallScreen ? 170.0 : 190.0;
    final buttonHeight = isSmallScreen ? 40.0 : 45.0;
    final titleFontSize = isSmallScreen ? 14.0 : 16.0;
    final subtitleFontSize = isSmallScreen ? 11.0 : 13.0;
    final buttonFontSize = isSmallScreen ? 14.0 : 16.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: containerWidth,
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: containerHeight,
            ),
            decoration: BoxDecoration(color: Colors.transparent),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Main Container
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  height: containerHeight,
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'คุณมีตั๋วไม่เพียงพอ!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'คุณสามารถสร้างภารกิจได้\nแต่จะไม่ได้รับของรางวัลเมื่อทำสำเร็จ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: subtitleFontSize,
                        ),
                      ),
                      SizedBox(height: 20),

                      Row(
                        children: [
                          // 🔴 ยกเลิก
                          Expanded(
                            child: GestureDetector(
                              onTap: widget.onCancel,
                              child: Container(
                                height: buttonHeight,
                                margin: EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Color(0xFFEA4444),
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

                          // 🔵 ยืนยัน
                          Expanded(
                            child: GestureDetector(
                              onTap: widget.onConfirm,
                              child: Container(
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
                                    'ยืนยัน',
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
