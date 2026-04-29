import 'package:flutter/material.dart';
import '../../widgets/custom_top_bar.dart';
import '../../api_service.dart';
import 'result_club_quiz_member.dart';
import '../../widgets/exit_edit_club_quest_popup.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 🌟 อย่าลืม import

class ClubQuestQuizMemberScreen extends StatefulWidget {
  final int questId; // 🌟 1. เพิ่มตัวแปรรับ ID ภารกิจ

  const ClubQuestQuizMemberScreen({
    Key? key, 
    required this.questId, // 🌟 บังคับรับค่า ID
  }) : super(key: key);

  @override
  State<ClubQuestQuizMemberScreen> createState() =>
      _ClubQuestQuizMemberScreenState();
}

class _ClubQuestQuizMemberScreenState extends State<ClubQuestQuizMemberScreen> {
  bool _isBackPressed = false;

  // 🌟 2. ลบ Mock Data ออก และใช้ตัวแปรเก็บข้อมูลจริง
  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true; // โชว์โหลดตอนดึงคำถาม

  @override
  void initState() {
    super.initState();
    _fetchQuestions(); // 🌟 ดึงคำถามจาก Database ทันทีที่เปิดหน้า
  }

  // 🌟 ฟังก์ชันดึงคำถามจาก Supabase
  Future<void> _fetchQuestions() async {
    try {
      final supabase = Supabase.instance.client;
      // ดึงเฉพาะคำถามและตัวเลือก (ไม่ดึง correct_answer มาเพื่อป้องกันแฮกเกอร์ดูเฉลย)
      final response = await supabase
          .from('quest_questions')
          .select('id, question_text, choice_a, choice_b, choice_c, choice_d')
          .eq('quest_id', widget.questId);

      final List<Map<String, dynamic>> loadedQuestions = [];
      for (var q in response) {
        loadedQuestions.add({
          'id': q['id'],
          'question': q['question_text'],
          'choices': [q['choice_a'], q['choice_b'], q['choice_c'], q['choice_d']],
          'selected': null, // ยังไม่ได้เลือก
        });
      }

      if (mounted) {
        setState(() {
          _questions = loadedQuestions;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching questions: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ดึงคำถามล้มเหลว'), backgroundColor: Colors.red));
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
              bottom: bottomPadding + 100,
            ),
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator()) // 🌟 โชว์ Loading ระหว่างดึงคำถาม
                : Column(
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

          // Bottom Button (ซ่อนปุ่มถ้ายังโหลดคำถามไม่เสร็จ)
          if (!_isLoading) _buildBottomButton(bottomPadding),
        ],
      ),
    );
  }

  // ==================== Components (UI คงเดิม) ====================

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
          errorBuilder: (context, error, stackTrace) {
            return Container();
          },
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

        // Choices
        ...List.generate((q['choices'] as List).length, (cIndex) {
          final choice = q['choices'][cIndex] as String;
          final isSelected = q['selected'] == cIndex;

          return GestureDetector(
            onTap: () {
              setState(() {
                _questions[qIndex]['selected'] = cIndex;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _questions[qIndex]['selected'] = cIndex;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: Color(0xFF1976D2),
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.circle,
                                size: 16,
                                color: Color(0xFF2374B5),
                              )
                            : null,
                      ),
                    ),
                  ),
                  Text(
                    choice,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected
                          ? Color(0xFF2374B5)
                          : Color(0xFF333333),
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBottomButton(double bottomPadding) {
    return Positioned(
      bottom: bottomPadding + 40,
      left: MediaQuery.of(context).size.width * 0.2,
      right: MediaQuery.of(context).size.width * 0.2,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF556AEB), Color(0xFF59ABEC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF4A8FE7).withOpacity(0.35),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          // 🌟 3. แก้ไขปุ่มเพื่อเชื่อมต่อ API ส่งคำตอบ
          onPressed: () async {
            // ก. เช็คว่าตอบครบทุกข้อหรือไม่
            bool allAnswered = _questions.every((q) => q['selected'] != null);
            if (!allAnswered) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('กรุณาตอบคำถามให้ครบทุกข้อ'), backgroundColor: Colors.orange),
              );
              return;
            }

            // โชว์ Loading หมุนๆ
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => const Center(child: CircularProgressIndicator()),
            );

            // ข. จัดเตรียมคำตอบเพื่อส่งให้ API
            const optionsMap = ['A', 'B', 'C', 'D']; // แปลง Index เป็น A,B,C,D
            List<Map<String, dynamic>> answers = [];
            for (var q in _questions) {
              answers.add({
                "question_id": q['id'],
                "answer": optionsMap[q['selected']],
              });
            }

            final requestData = {
              "quest_id": widget.questId,
              "answers": answers,
            };

            // ค. ส่ง API
            final result = await ApiService.submitClubQuest(requestData);

            if (mounted) Navigator.pop(context); // ปิด Loading

            if (mounted) {
            if (result != null && result['success'] == true) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ResultExamScreen(
                    isPassed: result['is_passed'],
                    score: result['score'],
                    total: _questions.length,
                    rewardsList: result['rewards'], // 🌟 ส่งของรางวัลที่ได้จาก API มาตรงนี้เลย!
                  ),
                ),
              );
            } else {
                // ❌ เกิดข้อผิดพลาด หรือ ติด Cooldown อยู่
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result?['error'] ?? 'เกิดข้อผิดพลาด'), 
                    backgroundColor: Colors.red,
                  ),
                );
                
                // ถ้าติด Cooldown ให้เด้งกลับไปหน้า Detail หลัก
                if (result?['cooldown_seconds'] != null) {
                  Navigator.pop(context); 
                }
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
          child: Text(
            'ส่งคำตอบ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}