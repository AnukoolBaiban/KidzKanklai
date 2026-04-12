import 'package:flutter/material.dart';
import 'package:flutter_application_1/api_service.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';

class ResultExamScreen extends StatefulWidget {
  final Map<String, int> statusRewards;
  final User? user;
  final bool isPassed;
  final int score;
  final int total;

  const ResultExamScreen({
    Key? key,
    required this.statusRewards,
    this.user,
    required this.isPassed,
    required this.score,
    required this.total,
  }) : super(key: key);

  @override
  State<ResultExamScreen> createState() => _ResultExamScreenState();
}

class _ResultExamScreenState extends State<ResultExamScreen> {
  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final topBarHeight = 75.0 + topPadding;
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = (screenWidth / 375).clamp(0.8, 1.2);

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Container(
              color: widget.isPassed
                  ? const Color(0xFFE2F5FD)
                  : const Color(0xFFE8F5E9),
              child: Image.asset(
                widget.isPassed
                    ? 'assets/images/background/bg11.png'
                    : 'assets/images/background/bg13.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: widget.isPassed
                        ? const Color(0xFFE2F5FD)
                        : const Color(0xFFE8F5E9),
                  );
                },
              ),
            ),
          ),

          // Main Content
          Positioned.fill(
            top: topBarHeight + 80,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: 20 * scale,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🔥 กล่องหลัก
                    Container(
                      width: double.infinity,
                      constraints: BoxConstraints(maxWidth: 400),
                      padding: EdgeInsets.symmetric(
                        vertical: 30 * scale,
                        horizontal: 20 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.70),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Color(0xFF9DD0E7), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: widget.isPassed ? 15 : 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // ✅ Success Text + Icon
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                widget.isPassed
                                    ? 'assets/images/icon/check2.png'
                                    : 'assets/images/icon/X.png',
                                height: 40 * scale,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    widget.isPassed
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    size: 40 * scale,
                                    color: widget.isPassed
                                        ? Colors.green
                                        : Colors.red,
                                  );
                                },
                              ),
                              SizedBox(width: 8),
                              Text(
                                widget.isPassed
                                    ? 'คะแนนผ่านเกณฑ์'
                                    : 'คะแนนไม่ผ่านเกณฑ์',
                                style: TextStyle(
                                  fontSize: 24 * scale,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 4 * scale),

                          // Score
                          Text(
                            '${widget.score}/${widget.total} คะแนน',
                            style: TextStyle(
                              fontSize: 16 * scale,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          SizedBox(height: 20 * scale),

                          // ✅ รูปตัวละครพร้อมแสง Glow ข้างหลัง
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              if (widget.isPassed)
                                Container(
                                  width: 150 * scale,
                                  height: 150 * scale,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.yellow.withOpacity(0.5),
                                        blurRadius: 40,
                                        spreadRadius: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              Image.asset(
                                widget.isPassed
                                    ? 'assets/images/profile/profile-character.png'
                                    : 'assets/images/profile/sad-character.png',
                                height: 230 * scale,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    widget.isPassed
                                        ? Icons.sentiment_very_satisfied
                                        : Icons.sentiment_very_dissatisfied,
                                    size: 120 * scale,
                                    color: widget.isPassed
                                        ? Colors.amber
                                        : Colors.blueGrey,
                                  );
                                },
                              ),
                            ],
                          ),

                          SizedBox(height: 20 * scale),

                          SizedBox(
                            height: 130 * scale,
                            child: widget.isPassed
                                ? Column(
                                    children: [
                                      Text(
                                        'รางวัลที่ได้รับ',
                                        style: TextStyle(
                                          fontSize: 20 * scale,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 16 * scale),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          _buildRewardItem(
                                            'assets/images/item/EXP.png',
                                            Icons.stars_rounded,
                                            Colors.orange,
                                            '+59',
                                            scale,
                                          ),
                                          SizedBox(width: 16 * scale),
                                          _buildRewardItem(
                                            'assets/images/item/Gasha.png',
                                            Icons.card_giftcard,
                                            Colors.purple,
                                            '+1',
                                            scale,
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      SizedBox(height: 12 * scale),
                                      Text(
                                        'โปรดตอบคำถามใหม่อีกครั้ง',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16 * scale,
                                          fontWeight: FontWeight.normal,
                                          color: Colors.black54,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 30 * scale),

                    // ✅ ปุ่มรับรางวัล (ลอยอยู่ด้านล่างกล่องขาว เหมือนในภาพ)
                    Container(
                      width: 180 * scale,
                      height: 52 * scale,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: widget.isPassed
                              ? [Color(0xFF85D755), Color(0xFF34C759)]
                              : [Color(0xFFE94444), Color(0xFFC62828)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        border: Border.all(color: Colors.white, width: 2.5),
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                        ),
                        child: Text(
                          widget.isPassed ? 'รับรางวัล' : 'ย้อนกลับ',
                          style: TextStyle(
                            fontSize: 18 * scale,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Top Bar
          _buildTopBar(topPadding, topBarHeight),

          // Blue Header
          _buildBlueHeader(topBarHeight),
        ],
      ),
    );
  }

  Widget _buildRewardItem(
    String imagePath,
    IconData fallbackIcon,
    Color fallbackColor,
    String text,
    double scale,
  ) {
    return Container(
      width: 70 * scale,
      height: 70 * scale,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
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
            imagePath,
            width: 40 * scale,
            height: 40 * scale,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(fallbackIcon, size: 36 * scale, color: fallbackColor);
            },
          ),
          SizedBox(height: 4 * scale),
          Text(
            text,
            style: TextStyle(
              fontSize: 12 * scale,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // Header with Back Button & Title
  Widget _buildBlueHeader(double topOffset) {
    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      child: Container(
        height: 80,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF015496), Color(0xFF2273B4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            /// Title (อยู่กลางจริง)
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  "ผลลัพธ์",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(double topPadding, double height) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: height,
        padding: EdgeInsets.only(top: topPadding),
        color: Colors.black.withOpacity(0.4),
        alignment: Alignment.bottomCenter,
        child: CustomTopBar(
          user: widget.user,
          onNotificationTapped: () =>
              Navigator.pushNamed(context, '/notification'),
          onSettingsTapped: () => Navigator.pushNamed(context, '/setting'),
        ),
      ),
    );
  }
}
