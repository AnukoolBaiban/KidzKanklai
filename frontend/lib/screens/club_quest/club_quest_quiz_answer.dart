import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 🌟 1. นำเข้า Supabase
import '../../widgets/custom_top_bar.dart';
import '../../api_service.dart';

class ClubQuestQuizAnswerScreen extends StatefulWidget {
  final int questId; // 🌟 2. รับค่า questId เข้ามา

  const ClubQuestQuizAnswerScreen({
    Key? key, 
    required this.questId, // 🌟 บังคับใส่ questId
  }) : super(key: key);

  @override
  State<ClubQuestQuizAnswerScreen> createState() =>
      _ClubQuestQuizAnswerScreenState();
}

class _ClubQuestQuizAnswerScreenState
    extends State<ClubQuestQuizAnswerScreen> {
  bool _isBackPressed = false;
  bool _isLoading = true; // 🌟 ตัวแปรเช็คสถานะ Loading

  // ข้อมูลคำถามจริงที่จะดึงมา
  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    _fetchQuizQuestions(); // 🌟 ดึงข้อมูลตอนเปิดหน้า
  }

  // 🌟 ฟังก์ชันดึงข้อมูลจาก Supabase
  Future<void> _fetchQuizQuestions() async {
    try {
      final supabase = Supabase.instance.client;

      // ดึงข้อมูลคำถามจากตาราง quest_questions
      final response = await supabase
          .from('quest_questions')
          .select('question_text, choice_a, choice_b, choice_c, choice_d, correct_answer')
          .eq('quest_id', widget.questId);

      // แปลงข้อมูลให้อยู่ในรูปแบบที่ UI ต้องการ
      List<Map<String, dynamic>> loadedQuestions = [];
      for (var item in response) {
        // หาว่าข้อไหนคือข้อที่ถูก (A=0, B=1, C=2, D=3)
        int correctIndex = 0;
        switch (item['correct_answer'].toString().toUpperCase()) {
          case 'A': correctIndex = 0; break;
          case 'B': correctIndex = 1; break;
          case 'C': correctIndex = 2; break;
          case 'D': correctIndex = 3; break;
        }

        loadedQuestions.add({
          'question': item['question_text'] ?? 'ไม่มีคำถาม',
          'choices': [
            item['choice_a'] ?? '-',
            item['choice_b'] ?? '-',
            item['choice_c'] ?? '-',
            item['choice_d'] ?? '-',
          ],
          'correctAnswer': correctIndex,
        });
      }

      if (mounted) {
        setState(() {
          _questions = loadedQuestions;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching quiz questions: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดคำถาม'), backgroundColor: Colors.red),
        );
      }
    }
  }

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
                          child: _isLoading 
                              ? const Center(child: CircularProgressIndicator()) // 🌟 โชว์ Loading
                              : _questions.isEmpty
                                  ? const Center(child: Text("ไม่มีคำถามสำหรับภารกิจนี้", style: TextStyle(color: Colors.grey)))
                                  : SingleChildScrollView(
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