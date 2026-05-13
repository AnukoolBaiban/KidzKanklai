import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnnotationButton extends StatelessWidget {
  final String? title;
  final String? description;
  final bool isClub;
  final bool isExam;
  final bool isUpgrade;

  const AnnotationButton({
    super.key,
    this.title,
    this.description,
    this.isClub = false,
    this.isExam = false,
    this.isUpgrade = false,
  });

  void _showAnnotationPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(dialogContext).size.width * 0.05,
            vertical: 24.0,
          ),
          child: Container(
            width: MediaQuery.of(dialogContext).size.width * 0.9,
            padding: EdgeInsets.all(
              MediaQuery.of(dialogContext).size.width * 0.05,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(dialogContext),
                const SizedBox(height: 15),
                _buildContent(context),
                const SizedBox(height: 20),
                _buildCloseButton(dialogContext),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext dialogContext) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox(width: 24), // Spacer for balance
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title ?? "รายละเอียดภารกิจ",
              style: GoogleFonts.kanit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF015496),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        InkWell(
          onTap: () => Navigator.pop(dialogContext),
          child: const Icon(Icons.close, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: SingleChildScrollView(
        child: description != null
            ? _buildCustomDescription()
            : (isClub 
                ? _buildClubDescription() 
                : (isExam 
                    ? _buildExamDescription() 
                    : (isUpgrade ? _buildUpgradeDescription() : _buildDefaultDescription()))),
      ),
    );
  }

  Widget _buildExamDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "การสอบเป็นการวัดระดับความรู้ในแต่ละด้าน โดยมีเงื่อนไขดังนี้:",
          style: GoogleFonts.kanit(
            fontSize: 16,
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildSection(
          "1. บัตรเข้าสอบ\n",
          "ต้องมีบัตรเข้าสอบสำหรับการเข้าสอบแต่ละครั้ง",
        ),
        const SizedBox(height: 12),
        _buildSection(
          "2. พลังงาน\n",
          "ต้องมีค่าพลังงานเพียงพอตามที่ข้อสอบกำหนด",
        ),
        const SizedBox(height: 12),
        _buildSection(
          "3. โอกาสผ่าน\n",
          "ขึ้นอยู่กับค่าสถานะที่กำหนด ยิ่งมีค่าสถานะถึงเกณฑ์ที่กำหนด โอกาสสอบผ่านก็จะยิ่งมากขึ้น",
        ),
        const SizedBox(height: 12),
        _buildSection(
          "4. ของรางวัล\n",
          "หากสอบผ่านจะได้รับของรางวัลและค่าประสบการณ์ที่เพิ่มขึ้น",
        ),
      ],
    );
  }

  Widget _buildUpgradeDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "การฝึกฝนในแต่ละสถานที่ช่วยเพิ่มค่าสถานะในด้านต่างๆ ดังนี้:",
          style: GoogleFonts.kanit(
            fontSize: 16,
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildSection(
          "1. การเพิ่มค่าสถานะ\n",
          "• หอสมุด: เพิ่มความฉลาด (Intelligence)\n• โรงยิม: เพิ่มความแข็งแรง (Strength)\n• สวนสนุก: เพิ่มความคิดสร้างสรรค์ (Creativity)",
        ),
        const SizedBox(height: 16),
        _buildSection(
          "2. การฟื้นฟูพลังงาน\n",
          "• สวนสาธารณะ: ใช้สำหรับฟื้นฟูพลังงาน (Stamina)",
        ),
        const SizedBox(height: 16),
        _buildSection(
          "3. เงื่อนไข\n",
          "ทุกการฝึกฝนต้องใช้ตั๋วฝึกฝนและจะเสียค่าพลังงานบางส่วน (ยกเว้นการฟื้นฟูในสวนสาธารณะ)",
        ),
      ],
    );
  }

  Widget _buildClubDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "ชมรมคือพื้นที่สำหรับทำกิจกรรมร่วมกับเพื่อนๆ โดยแบ่งบทบาทหน้าที่ ดังนี้:",
          style: GoogleFonts.kanit(
            fontSize: 16,
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildSection(
          "1. หัวหน้าชมรม\n",
          "มีหน้าที่สร้างและมอบหมายภารกิจชมรมให้กับสมาชิก โดยจะได้รับของรางวัลเมื่อสมาชิกทำภารกิจสำเร็จมากกว่าครึ่งหนึ่งของสมาชิกทั้งหมด",
        ),
        const SizedBox(height: 16),
        _buildSection(
          "2. สมาชิกชมรม\n",
          "มีหน้าที่ทำภารกิจที่ได้รับมอบหมายจากหัวหน้าชมรมให้สำเร็จ โดยจะได้รับของรางวัลทันทีที่ทำภารกิจสำเร็จ",
        ),
      ],
    );
  }

  Widget _buildCustomDescription() {
    return Text(
      description!,
      style: GoogleFonts.kanit(fontSize: 16, color: Colors.black87),
      textAlign: TextAlign.left,
    );
  }

  Widget _buildDefaultDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "ภารกิจในเกมแบ่งออกเป็น 2 ประเภทหลัก ได้แก่",
          style: GoogleFonts.kanit(
            fontSize: 16,
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildSection(
          "1. ภารกิจระบบ\n",
          "คือ ภารกิจที่ระบบเกมสร้างไว้แล้ว ซึ่งจะได้รับรางวัลถ้าผู้เล่นทำภารกิจสำเร็จ (รีเซ็ตทุกสัปดาห์)",
        ),
        const SizedBox(height: 16),
        _buildSection(
          "2. ภารกิจส่วนตัว\n",
          "คือ ภารกิจที่ผู้เล่นสร้างขึ้นเอง เพื่อกำหนดเป้าหมายสิ่งที่อยากทำหรืออยากเรียนรู้ด้วยตัวเอง โดยต้องใช้ตั๋วภารกิจในการสร้าง\n\n",
          subTitle: "ภารกิจส่วนตัวแบ่งออกเป็น 2 แบบ ได้แก่:",
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSubSection(
                "2.1 ภารกิจทั่วไป\n",
                "ภารกิจที่ผู้เล่นสามารถสร้างขึ้นเพื่อกำหนดรายละเอียดภารกิจตามความต้องการของตนเอง และสามารถกำหนดระยะเวลาสิ้นสุดภารกิจเองได้\n",
                "* เหมาะสำหรับการตั้งเป้าหมายที่ต้องใช้เวลานานในการทำให้สำเร็จ หรือการวางแผนการทำกิจกรรมในระยะยาว",
              ),
              const SizedBox(height: 12),
              _buildSubSection(
                "2.2 ภารกิจทันที\n",
                "ภารกิจที่ผู้เล่นต้องเริ่มทำทันทีเมื่อกดเริ่ม โดยระบบจะเริ่มนับเวลาถอยหลังเองอัตโนมัติหลังจากที่ผู้เล่นกดเริ่มทำภารกิจ\n",
                "* เหมาะสำหรับผู้เล่นที่ต้องการทำกิจกรรมที่ต้องโฟกัส ณ ขณะนั้น หรือการทำภารกิจอย่างต่อเนื่อง (ตั้งเวลานับถอยหลังได้สูงสุด 8 ชั่วโมง)",
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, String content, {String? subTitle}) {
    final baseStyle = GoogleFonts.kanit(fontSize: 16, color: Colors.black87);
    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(
            text: title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF015496),
            ),
          ),
          TextSpan(text: content),
          if (subTitle != null)
            TextSpan(
              text: subTitle,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }

  Widget _buildSubSection(String title, String content, String note) {
    final baseStyle = GoogleFonts.kanit(fontSize: 16, color: Colors.black87);
    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(
            text: title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2374B5),
            ),
          ),
          TextSpan(text: content),
          TextSpan(
            text: note,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseButton(BuildContext dialogContext) {
    return ElevatedButton(
      onPressed: () => Navigator.pop(dialogContext),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2374B5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      ),
      child: Text(
        "เข้าใจแล้ว",
        style: GoogleFonts.kanit(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAnnotationPopup(context),
      child: Image.asset(
        'assets/images/icon/iconAnnotation.png',
        width: 24,
        height: 24,
        fit: BoxFit.contain,
      ),
    );
  }
}