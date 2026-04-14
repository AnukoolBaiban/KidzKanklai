import 'package:flutter/material.dart';
import '../../widgets/custom_top_bar.dart';
import '../../api_service.dart';

class ClubQuestQuizAnswerScreen extends StatefulWidget {
  final User? user;

  const ClubQuestQuizAnswerScreen({Key? key, this.user}) : super(key: key);

  @override
  State<ClubQuestQuizAnswerScreen> createState() =>
      _ClubQuestQuizAnswerScreenState();
}

class _ClubQuestQuizAnswerScreenState
    extends State<ClubQuestQuizAnswerScreen> {
  bool _isBackPressed = false;

  // Mock Questions Data พร้อมเฉลย (correctAnswer = index ของตัวเลือกที่ถูก)
  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'ก๋วยเตี๋ยวเนื้อพิเศษราคาเท่าไหร่',
      'choices': ['50 บาท', '40 บาท', '60 บาท', '45 บาท'],
      'correctAnswer': 0, // 50 บาท
    },
    {
      'question': 'เจ้าของร้านชื่ออะไร',
      'choices': ['กุ้ง', 'แก้ว', 'เก่ง', 'กบ'],
      'correctAnswer': 0, // กุ้ง
    },
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topBarHeight = 75.0 + topPadding;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          _buildBackground(),

          // Top Bar
          _buildTopBar(topPadding, topBarHeight),

          // Main Content
          Padding(
            padding: EdgeInsets.only(
              top: topBarHeight + 10,
              left: size.width * 0.05,
              right: size.width * 0.05,
              bottom: bottomPadding + 20,
            ),
            child: Column(
              children: [
                // Back Button
                Row(children: [_buildBackButton()]),

                SizedBox(height: 10),

                // Content Card
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Color(0xFFAAD7EA), width: 3),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Scrollable Content
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Notice Banner
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFE3F2FD),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Color(0xFF90CAF9),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: Color(0xFF1976D2),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'ข้อที่เป็นเครื่องหมายถูกสีน้ำเงินคือเฉลยที่ถูกต้อง',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF1976D2),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Questions List
                                ...List.generate(_questions.length, (qIndex) {
                                  final q = _questions[qIndex];
                                  return _buildQuestionBlock(qIndex, q);
                                }),
                              ],
                            ),
                          ),
                        ),

                        // Header "คำถาม"
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: _buildHeaderTitle(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Components ====================

  Widget _buildBackground() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        color: const Color(0xFFE2F5FD),
        alignment: Alignment.center,
        child: Image.asset(
          "assets/images/background/bg-head.png",
          fit: BoxFit.contain,
          width: MediaQuery.of(context).size.width * 0.8,
          errorBuilder: (context, error, stackTrace) => Container(),
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
          // user: widget.user,
          onNotificationTapped: () =>
              Navigator.pushNamed(context, '/notification'),
          onSettingsTapped: () => Navigator.pushNamed(context, '/setting'),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isBackPressed = true),
      onTapCancel: () => setState(() => _isBackPressed = false),
      onTap: () async {
        await Future.delayed(const Duration(milliseconds: 150));
        if (mounted) {
          Navigator.pop(context);
          setState(() => _isBackPressed = false);
        }
      },
      child: Image.asset(
        _isBackPressed
            ? 'assets/images/button/bt-hover-Back.png'
            : 'assets/images/button/bt-Back.png',
        width: 50,
        height: 50,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back, color: Color(0xFF2374B5)),
          );
        },
      ),
    );
  }

  Widget _buildHeaderTitle() {
    return Align(
      alignment: Alignment.topCenter,
      child: FractionalTranslation(
        translation: const Offset(0, -0.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2374B5),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Text(
            "คำถาม",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionBlock(int qIndex, Map<String, dynamic> q) {
    final int correctIdx = q['correctAnswer'] as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question text
        Text(
          '${qIndex + 1}. ${q['question']}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        SizedBox(height: 8),

        // Choices (read-only, เฉลยถูกต้องถูกแสดงให้ชัด)
        ...List.generate((q['choices'] as List).length, (cIndex) {
          final choice = q['choices'][cIndex] as String;
          final isCorrect = cIndex == correctIdx;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                // Radio circle (ติ้กเฉลยแบบ read-only)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: isCorrect
                            ? Color(0xFF1976D2)
                            : Color(0xFFBBBBBB),
                        width: 2,
                      ),
                    ),
                    child: isCorrect
                        ? Icon(
                            Icons.circle,
                            size: 16,
                            color: Color(0xFF2374B5),
                          )
                        : null,
                  ),
                ),

                // Choice text
                Expanded(
                  child: Text(
                    choice,
                    style: TextStyle(
                      fontSize: 14,
                      color: isCorrect
                          ? Color(0xFF2374B5)
                          : Color(0xFF777777),
                      fontWeight: isCorrect
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                ),

                // เครื่องหมายถูกด้านขวาสำหรับเฉลย
                if (isCorrect)
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: Color(0xFF2374B5),
                  ),
              ],
            ),
          );
        }),

        SizedBox(height: 20),
      ],
    );
  }
}
