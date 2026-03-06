import 'package:flutter/material.dart';
import 'dart:math' as math;

class RewardPopup extends StatefulWidget {
  final String rewardType; // 'EXP', 'COIN', 'TICKET', 'ITEM'
  final int amount;
  final String? itemName;
  final String? itemImage;
  final VoidCallback? onClose;

  const RewardPopup({
    Key? key,
    required this.rewardType,
    required this.amount,
    this.itemName,
    this.itemImage,
    this.onClose,
  }) : super(key: key);

  @override
  State<RewardPopup> createState() => _RewardPopupState();

  // Static method สำหรับเรียกใช้งาน
  static Future<void> show(
    BuildContext context, {
    required String rewardType,
    required int amount,
    String? itemName,
    String? itemImage,
    VoidCallback? onClose,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => RewardPopup(
        rewardType: rewardType,
        amount: amount,
        itemName: itemName,
        itemImage: itemImage,
        onClose: onClose,
      ),
    );
  }
}

class _RewardPopupState extends State<RewardPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

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
                Container(  
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.4),
                        blurRadius: 100, // ยิ่งมากยิ่งฟุ้ง
                        spreadRadius: 60,
                      ),
                    ],
                  ),
                ),

                // Main Container
                Container(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.fromARGB(5, 0, 0, 0),
                        Color.fromARGB(50, 0, 0, 0),
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
                      SizedBox(height: 9),
                      Text(
                        'ได้รับรางวัล',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFFFFF),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 10),

                      // Reward Icon
                      _buildRewardIcon(),

                      SizedBox(height: 10),

                      // Reward Text
                      Text(
                        _getRewardText(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.normal,
                          color: Color(0xFFFFFFFF),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      // Close Button (ไม่มีตาม Figma - ให้ tap ที่ไหนก็ได้)
                    ],
                  ),
                ),

                // Header Title
                Positioned(top: -60, left: 0, right: 0, child: _buildHeader()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: -60,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Positioned(
                left: 0,
                bottom: 0,
                child: Image.asset(
                  'assets/images/icon/Star11.png',
                  width: 26,
                  height: 26,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(width: 4),
              Positioned(
                top: 0,
                child: Center(
                  child: Text(
                    'รับรางวัลสำเร็จ',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      foreground: Paint()
                        ..shader = const LinearGradient(
                          colors: [
                            Color(0xFFFFD700), // Gold
                            Color(0xFFFFA500), // Orange
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ).createShader(const Rect.fromLTWH(0, 0, 200, 40)),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 4),
              Positioned(
                right: 0,
                bottom: 0,
                child: Image.asset(
                  'assets/images/icon/Star11.png',
                  width: 26,
                  height: 26,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRewardIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            "assets/images/item/EXP.png",
            width: 40,
            height: 40,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(Icons.stars, size: 40, color: Color(0xFFFFA726));
            },
          ),
          SizedBox(height: 4),
          // Amount below image
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '+${widget.amount}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(width: 4),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRewardColor() {
    switch (widget.rewardType.toUpperCase()) {
      case 'EXP':
        return Color(0xFF4A8FE7);
      case 'COIN':
        return Color(0xFFFFB800);
      case 'TICKET':
        return Color(0xFFE74A4A);
      case 'ITEM':
        return Color(0xFF66BB6A);
      default:
        return Color(0xFF2374B5);
    }
  }

  String _getRewardText() {
    String itemText = widget.itemName ?? widget.rewardType;
    return 'แตะเพื่อดำเนินการต่อ';
  }
}

// Helper class สำหรับ Reward data
class RewardData {
  final String type;
  final int amount;
  final String? itemName;
  final String? itemImage;

  RewardData({
    required this.type,
    required this.amount,
    this.itemName,
    this.itemImage,
  });

  // Factory constructors สำหรับสร้างแบบง่าย
  factory RewardData.exp(int amount) {
    return RewardData(type: 'EXP', amount: amount);
  }

  factory RewardData.coin(int amount) {
    return RewardData(type: 'COIN', amount: amount);
  }

  factory RewardData.ticket(int amount) {
    return RewardData(type: 'TICKET', amount: amount);
  }

  factory RewardData.item({
    required String name,
    required int amount,
    String? image,
  }) {
    return RewardData(
      type: 'ITEM',
      amount: amount,
      itemName: name,
      itemImage: image,
    );
  }
}