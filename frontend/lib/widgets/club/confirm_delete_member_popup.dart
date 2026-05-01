import 'package:flutter/material.dart';

class ConfirmDeleteMemberPopup extends StatefulWidget {
  final String title;
  final String subtitle;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ConfirmDeleteMemberPopup({
    Key? key,
    this.title = 'ยืนยันการไล่สมาชิกออก?',
    this.subtitle = 'สมาชิกจะถูกนำออกจากชมรมอย่างถาวร',
    required this.onConfirm,
    required this.onCancel,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    String title = 'ยืนยันการไล่สมาชิกออก?',
    String subtitle = 'สมาชิกจะถูกนำออกจากชมรมอย่างถาวร',
    required VoidCallback onConfirm,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => ConfirmDeleteMemberPopup(
        title: title,
        subtitle: subtitle,
        onConfirm: onConfirm,
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  @override
  State<ConfirmDeleteMemberPopup> createState() => _ConfirmDeleteMemberPopupState();
}

class _ConfirmDeleteMemberPopupState extends State<ConfirmDeleteMemberPopup>
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

    final containerWidth = size.width * 0.85;
    final titleFontSize = (size.width * 0.038).clamp(14.0, 18.0);
    final subtitleFontSize = (size.width * 0.033).clamp(12.0, 14.0);
    final buttonFontSize = (size.width * 0.038).clamp(14.0, 16.0);
    final buttonHeight = (size.width * 0.105).clamp(39.0, 50.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: containerWidth,
            constraints: const BoxConstraints(maxWidth: 380),
            decoration: const BoxDecoration(color: Colors.transparent),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Main Container
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color.fromARGB(5, 0, 0, 0),
                        const Color.fromARGB(80, 0, 0, 0),
                        const Color.fromARGB(5, 0, 0, 0),
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
                      // Title
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Subtitle
                      Text(
                        widget.subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: subtitleFontSize,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Buttons
                      Row(
                        children: [
                          // 🔴 ยกเลิก
                          Expanded(
                            child: GestureDetector(
                              onTap: widget.onCancel,
                              child: Container(
                                height: buttonHeight,
                                margin: const EdgeInsets.only(right: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEA4444),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFEA4444).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
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
                                margin: const EdgeInsets.only(left: 5),
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
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF59ABEC).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
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
