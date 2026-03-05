import 'package:flutter/material.dart';

class ConfirmGiveUpPopup extends StatefulWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ConfirmGiveUpPopup({
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
      builder: (context) => ConfirmGiveUpPopup(
        onConfirm: onConfirm,
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  @override
  State<ConfirmGiveUpPopup> createState() => _ConfirmGiveUpPopupState();
}

class _ConfirmGiveUpPopupState extends State<ConfirmGiveUpPopup>
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
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: BoxConstraints(maxHeight: 500),
            decoration: BoxDecoration(color: Colors.transparent),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Main Container
                Container(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                  height: 180,
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
                      SizedBox(height: 30),
                      Text(
                        'ยืนยันที่จะยอมแพ้หรือไม่?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'หากยอมแพ้ คุณจะไม่ได้รับของรางวัลทั้งหมด',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // 🔴 ยกเลิก
                          Expanded(
                            child: GestureDetector(
                              onTap: widget.onCancel,
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12),
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
                                padding: EdgeInsets.symmetric(vertical: 12),
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
