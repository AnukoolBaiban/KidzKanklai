import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TutorialQuestPopup extends StatefulWidget {
  const TutorialQuestPopup({super.key});

  @override
  State<TutorialQuestPopup> createState() => _TutorialQuestPopupState();
}

class _TutorialQuestPopupState extends State<TutorialQuestPopup> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _tutorialSteps = [
    {
      "image": "assets/images/button/bt-create.png",
      "text": "สร้างภารกิจด้วยตัวเอง",
    },
    {
      "image": "assets/images/tutorial-img1.png",
      "text": "ทำภารกิจให้สำเร็จก่อนหมดเวลา",
    },
    {"image": "assets/images/item/items.png", "text": "รับรางวัลต่างๆมากมาย"},
    {
      "image": "assets/images/icon/iconAnnotation.png",
      "text": "ตรวจสอบประเภทของภารกิจทั้งหมดภายในเกม",
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: _buildDialogContent(context),
    );
  }

  Widget _buildDialogContent(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10.0,
            offset: Offset(0.0, 10.0),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          Text(
            "ยินดีต้อนรับเข้าสู่ หน้าภารกิจ!",
            style: GoogleFonts.kanit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF015496),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemCount: _tutorialSteps.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (index == 0)
                        Container(
                          width: 120,
                          height: 120,
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF68E2FA), Color(0xFF2374B5)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: Center(
                              child: Image.asset(
                                _tutorialSteps[index]["image"]!,
                                width: 70,
                                height: 70,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        )
                      else if (index == 3)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 3), // เพิ่มระยะห่างด้านบน
                            Container(
                              width: 120,
                              height: 120,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF2374B5),
                              ),
                              child: Center(
                                child: Image.asset(
                                  _tutorialSteps[index]["image"]!,
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Image.asset(
                          _tutorialSteps[index]["image"]!,
                          height: index == 3
                              ? 90
                              : 120, // ลดขนาดรูปหน้าสุดท้ายนิดหน่อยถ้ารูปใหญ่
                          fit: BoxFit.contain,
                        ),
                      const SizedBox(
                        height: 20,
                      ), // เพิ่มระยะห่างข้อความกับรูปนิดหน่อย
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 80,
                        ), // จำกัดความสูงของพื้นที่ข้อความ
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Tooltip(
                              message:
                                  _tutorialSteps[index]["text"]!, // Tooltip เวลาข้อความแสดงไม่หมด
                              child: Text(
                                _tutorialSteps[index]["text"]!,
                                style: GoogleFonts.kanit(
                                  fontSize: index == 3 ? 16 : 18,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2, // สลับกลับมาใช้การหักบรรทัดและ
                                overflow: TextOverflow.visible,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // Page indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _tutorialSteps.length,
              (index) => _buildDot(index, context),
            ),
          ),
          const SizedBox(height: 24),
          // Next / Done button
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 10.0,
            ),
            child: ElevatedButton(
              onPressed: () {
                if (_currentPage == _tutorialSteps.length - 1) {
                  Navigator.of(context).pop();
                } else {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeIn,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2374B5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(
                _currentPage == _tutorialSteps.length - 1
                    ? "เริ่มเลย!"
                    : "ถัดไป",
                style: GoogleFonts.kanit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDot(int index, BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: _currentPage == index
            ? const Color(0xFF2374B5)
            : Colors.grey.shade300,
      ),
    );
  }
}