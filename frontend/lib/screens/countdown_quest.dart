import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/api_service.dart';

import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:flutter_application_1/widgets/annotation.dart';
import 'package:flutter_application_1/widgets/ticket_box.dart';
import 'package:flutter_application_1/widgets/confirm_giveup_popup.dart';
import 'package:flutter_application_1/widgets/mission_fail_popup.dart';
import 'package:google_fonts/google_fonts.dart';

class CountdownQuestScreen extends StatefulWidget {
  final User? user;
  const CountdownQuestScreen({super.key, this.user});

  @override
  State<CountdownQuestScreen> createState() => _CountdownQuestScreenState();
}

class _CountdownQuestScreenState extends State<CountdownQuestScreen>
    with SingleTickerProviderStateMixin {
  // ==========================================
  // State Variables & Controllers
  // ==========================================
  bool _isPressed = false;
  final TextEditingController _detailController = TextEditingController();
  static const int _maxChars = 30;
  int _charCount = 0;

  bool _isRunning = false;
  Timer? _timer;
  int _selectedMinutes = 0;
  int _selectedSeconds = 0;
  int _selectedActualSeconds = 0;
  int _elapsedTotalSeconds = 0;

  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _initBlinkAnimation();
  }

  void _initBlinkAnimation() {
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: false);

    _blinkAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 80),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.2), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 0.2, end: 1.0), weight: 50),
    ]).animate(_blinkController);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _blinkController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  // ==========================================
  // Timer Logic & Formatting
  // จัดการระบบนับเวลาถอยหลัง การคำนวณชั่วโมง/นาที/วินาที และการขึ้น UI แจ้งเตือนเมื่อกดยกเลิก
  // ==========================================
  void _startTimer() {
    if (_selectedMinutes == 0 &&
        _selectedSeconds == 0 &&
        _selectedActualSeconds == 0)
      return;
    setState(() {
      _isRunning = true;
      _elapsedTotalSeconds = 0;
    });
    _resumeTimer();
  }

  void _resumeTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _elapsedTotalSeconds++;
        if (_selectedActualSeconds > 0) {
          _selectedActualSeconds--;
        } else if (_selectedSeconds > 0) {
          _selectedSeconds--;
          _selectedActualSeconds = 59;
        } else if (_selectedMinutes > 0) {
          _selectedMinutes--;
          _selectedSeconds = 59;
          _selectedActualSeconds = 59;
        } else {
          _stopTimer();
        }
      });
    });
  }

  void _stopTimer({bool reset = false}) {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      if (reset) {
        _selectedMinutes = 0;
        _selectedSeconds = 0;
        _selectedActualSeconds = 0;
        _elapsedTotalSeconds = 0;
      }
    });
  }

  String get _formattedElapsedTime {
    int hours = _elapsedTotalSeconds ~/ 3600;
    int minutes = (_elapsedTotalSeconds % 3600) ~/ 60;
    int seconds = _elapsedTotalSeconds % 60;
    return hours > 0
        ? '${hours.toString().padLeft(2, '0')}.${minutes.toString().padLeft(2, '0')}.${seconds.toString().padLeft(2, '0')}'
        : '00.${minutes.toString().padLeft(2, '0')}.${seconds.toString().padLeft(2, '0')}';
  }

  void _handleBackInterrupt() {
    if (_isRunning) {
      _timer?.cancel();
      ConfirmGiveUpPopup.show(
        context,
        onConfirm: () {
          Navigator.pop(context);
          String finalTime = _formattedElapsedTime;
          _stopTimer(reset: true);
          MissionFailPopup.show(
            context,
            elapsedTime: finalTime,
            onTapContinue: () {},
          );
        },
      ).then((_) {
        if (_isRunning && mounted) _resumeTimer();
      });
    }
  }

  // ==========================================
  // Main Build Method
  // วาดโครงสร้างหลักของหน้าจอ , จัดการ PopScope สำหรับกดปุ่มย้อนกลับของโทรศัพท์มือถือ
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isSmallScreen = size.width < 380;

    final topBarHeight = 75.0 + topPadding;
    final headerHeight = isSmallScreen ? 70.0 : 80.0;
    final titleFontSize = isSmallScreen ? 28.0 : 36.0;

    return PopScope(
      canPop: !_isRunning,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _handleBackInterrupt();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            _buildBackground(),
            _buildMainContentScrollable(
              size,
              topBarHeight,
              headerHeight,
              bottomPadding,
              isSmallScreen,
            ),
            Positioned(
              bottom: bottomPadding + 50,
              left: 0,
              right: 0,
              child: Center(child: _buildStartButton(size, isSmallScreen)),
            ),
            _buildTopBar(topPadding, topBarHeight),
            _buildBlueHeader(topBarHeight, headerHeight, titleFontSize),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // UI Component Builders
  // แยกฟังก์ชันสำหรับสร้าง Widget แต่ละส่วน (พื้นหลัง, แถบด้านบน, แถบชื่อภารกิจ, กล่องเวลา, และปุ่มเริ่ม)
  // ==========================================

  // สร้างพื้นหลังของจอ (ท้องฟ้า)
  Widget _buildBackground() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFE2F5FD),
      child: Image.asset("assets/images/background/bg6.png", fit: BoxFit.cover),
    );
  }

  // แถบสีดำบางๆด้านบนสุด แสดงโปรไฟล์ผู้ใช้ เลเวล และเหรียญ
  Widget _buildTopBar(double topPadding, double height) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: height,
        padding: EdgeInsets.only(top: topPadding),
        color: Colors.black.withValues(alpha: 0.4),
        alignment: Alignment.bottomCenter,
        child: CustomTopBar(
          onNotificationTapped: () =>
              Navigator.pushNamed(context, '/notification'),
          onSettingsTapped: () => Navigator.pushNamed(context, '/setting'),
        ),
      ),
    );
  }

  // กล่องหัวข้อ "ภารกิจทันที" , ปุ่มย้อนกลับ และไอคอนคำถาม (Annotation)
  Widget _buildBlueHeader(
    double topOffset,
    double height,
    double titleFontSize,
  ) {
    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF015496), Color(0xFF2273B4)],
          ),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 20),
                child: _buildBackButton(),
              ),
            ),
            Center(
              child: Text(
                "ภารกิจทันที",
                textAlign: TextAlign.center,
                style: GoogleFonts.kanit(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            const Positioned(bottom: 8, right: 15, child: AnnotationButton()),
          ],
        ),
      ),
    );
  }

  // ปุ่มย้อนกลับ (ลูกศรสีเหลือง) จัดการ Animation การกดและเรียก Popup หากเวลากำลังเดิน
  Widget _buildBackButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () async {
        setState(() => _isPressed = false);
        if (_isRunning) {
          _handleBackInterrupt();
        } else {
          await Future.delayed(const Duration(milliseconds: 200));
          if (mounted) Navigator.pop(context);
        }
      },
      child: Image.asset(
        _isPressed
            ? 'assets/images/button/bt-hover-Back.png'
            : 'assets/images/button/bt-Back.png',
        width: 50,
        height: 50,
      ),
    );
  }

  // กล่องตั้งค่าเวลา และช่องกรอกข้อความ
  Widget _buildMainContentScrollable(
    Size size,
    double topBarHeight,
    double headerHeight,
    double bottomPadding,
    bool isSmallScreen,
  ) {
    final timerFontSize = isSmallScreen ? 48.0 : 64.0;
    final inputFontSize = isSmallScreen ? 16.0 : 18.0;

    return Padding(
      padding: EdgeInsets.only(
        top: topBarHeight + headerHeight + 20,
        bottom: bottomPadding + 20,
        left: size.width * 0.05,
        right: size.width * 0.05,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight:
                size.height -
                (topBarHeight + headerHeight + bottomPadding + 40),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _buildClickToSetTimeText(),
              const SizedBox(height: 10),
              _buildDigitalTimerCard(timerFontSize),
              const SizedBox(height: 20),
              _buildActivityNameInput(size.width * 0.6, inputFontSize),
            ],
          ),
        ),
      ),
    );
  }

  // ข้อความ "คลิกเพื่อตั้งเวลา" (Effect กระพริบ)
  Widget _buildClickToSetTimeText() {
    return Visibility(
      visible: !_isRunning,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: FadeTransition(
        opacity: _blinkAnimation,
        child: Text(
          "คลิกเพื่อตั้งเวลา",
          style: GoogleFonts.kanit(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            shadows: const [
              Shadow(
                offset: Offset(0, 2),
                blurRadius: 4.0,
                color: Colors.black87,
              ),
              Shadow(
                offset: Offset(0, 0),
                blurRadius: 10.0,
                color: Colors.black,
              ),
              Shadow(
                offset: Offset(0, 0),
                blurRadius: 16.0,
                color: Colors.black87,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // กล่องขาวแสดงตัวเลขเวลา (หน้าหลัก)
  Widget _buildDigitalTimerCard(double timerFontSize) {
    return GestureDetector(
      onTap: () {
        if (!_isRunning) _showTimePickerPopup(context);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD9D9D9), width: 4.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            "${_selectedMinutes.toString().padLeft(2, '0')}:${_selectedSeconds.toString().padLeft(2, '0')}:${_selectedActualSeconds.toString().padLeft(2, '0')}",
            textAlign: TextAlign.center,
            style: GoogleFonts.kanit(
              fontSize: timerFontSize,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  // ช่องกรอกชื่อกิจกรรม
  Widget _buildActivityNameInput(double width, double fontSize) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFD9D9D9), width: 4.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        enabled: !_isRunning,
        controller: _detailController,
        textAlign: TextAlign.center,
        maxLength: _maxChars,
        onChanged: (val) => setState(() => _charCount = val.length),
        style: GoogleFonts.kanit(fontSize: fontSize, color: Colors.black87),
        decoration: InputDecoration(
          hintText: "ตั้งชื่อกิจกรรม",
          hintStyle: GoogleFonts.kanit(
            fontSize: fontSize,
            color: Colors.grey.shade500,
          ),
          border: InputBorder.none,
          isDense: true,
          counterText: '',
          suffix: _charCount > 0
              ? Text(
                  "$_charCount/$_maxChars",
                  style: GoogleFonts.kanit(
                    fontSize: 12,
                    color: _charCount >= _maxChars
                        ? Colors.red.shade400
                        : Colors.grey.shade400,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  // ปุ่มเริ่มจับเวลาถอยหลัง และกล่องไอคอนตั๋วขวาที่ปุ่ม
  Widget _buildStartButton(Size size, bool isSmallScreen) {
    bool isTimeSet = _selectedMinutes > 0 || _selectedSeconds > 0;
    final buttonWidth = isSmallScreen ? size.width * 0.70 : size.width * 0.60;
    final buttonHeight = isSmallScreen ? 60.0 : 72.0;
    final buttonFontSize = isSmallScreen ? 28.0 : 36.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () {
            if (!isTimeSet) return;
            if (_isRunning) {
              _handleBackInterrupt();
            } else {
              _startTimer();
            }
          },
          child: Container(
            width: buttonWidth,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    height: buttonHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: _isRunning
                            ? const [
                                Color(0xFFEA4444),
                                Color(0xFF992B2B),
                              ] // Red: Give Up
                            : isTimeSet
                            ? const [
                                Color(0xFF59ABEC),
                                Color(0xFF2374B5),
                              ] // Blue: Ready
                            : const [
                                Color(0xFFD9D9D9),
                                Color(0xFF8A8A8A),
                              ], // Grey: Disabled
                      ),
                    ),
                  ),
                  Text(
                    _isRunning ? "ยอมแพ้" : "เริ่ม",
                    style: GoogleFonts.kanit(
                      fontSize: buttonFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          offset: Offset(0, 2),
                          blurRadius: 6,
                          color: Colors.black38,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!_isRunning)
          Positioned(
            top: -15,
            right: -6,
            child: TicketBox(
              slant: 12,
              borderRadius: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/item/Ticket_quest_img.png',
                      width: 30,
                      height: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "-1",
                      style: GoogleFonts.kanit(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ฟังก์ชันสั่งเปิด Popup เลือกเวลา (เปิดส่วนของ Time Picker Dialog Sub-Widget)
  void _showTimePickerPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: _TimePickerPopupWidget(
            initialHours: _selectedMinutes,
            initialMinutes: _selectedSeconds,
            onConfirm: (int h, int m) {
              setState(() {
                _selectedMinutes = h;
                _selectedSeconds = m;
                _selectedActualSeconds = 0;
              });
            },
          ),
        );
      },
    );
  }
}

// ==========================================
// Time Picker Dialog Sub-Widget
// Widget แสดง Popup เพื่อให้ผู้ใช้ปัดเลือกชั่วโมงและนาทีได้
// ==========================================
class _TimePickerPopupWidget extends StatefulWidget {
  final int initialHours;
  final int initialMinutes;
  final Function(int hours, int minutes) onConfirm;

  const _TimePickerPopupWidget({
    required this.initialHours,
    required this.initialMinutes,
    required this.onConfirm,
  });

  @override
  State<_TimePickerPopupWidget> createState() => _TimePickerPopupWidgetState();
}

class _TimePickerPopupWidgetState extends State<_TimePickerPopupWidget> {
  late int hours;
  late int minutes;

  @override
  void initState() {
    super.initState();
    hours = widget.initialHours;
    minutes = widget.initialMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 380;

    final timeFontSize = isSmallScreen ? 56.0 : 70.0;
    final headerHeight = isSmallScreen ? 100.0 : 120.0;
    final buttonPadding = isSmallScreen ? 30.0 : 40.0;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEDDCC), width: 4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Time Readout
          Container(
            height: headerHeight,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF5F5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:00",
                  style: GoogleFonts.kanit(
                    fontSize: timeFontSize,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF333333),
                  ),
                ),
              ),
            ),
          ),

          // Controls Section
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFC6F4FF), Colors.white],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTimeSetter(
                      "ชั่วโมง",
                      hours,
                      8,
                      (val) => setState(() => hours = val),
                    ),
                    const SizedBox(width: 20),
                    _buildTimeSetter(
                      "นาที",
                      minutes,
                      59,
                      (val) => setState(() => minutes = val),
                    ),
                  ],
                ),
                SizedBox(
                  height: 44,
                  child: Center(
                    child: Opacity(
                      opacity: _showWarning() ? 1.0 : 0.0,
                      child: Text(
                        _getWarningMessage(),
                        style: GoogleFonts.kanit(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFD9534F),
                        ),
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  ignoring: _showWarning(),
                  child: GestureDetector(
                    onTap: () {
                      widget.onConfirm(hours, minutes);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: buttonPadding,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        gradient: _showWarning()
                            ? const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFD9D9D9), Color(0xFF8A8A8A)],
                              )
                            : const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF2B78BA), Color(0xFF75B2E1)],
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        "ยืนยัน",
                        style: GoogleFonts.kanit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
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

  bool _showWarning() =>
      (hours == 8 && minutes > 0) || (hours == 0 && minutes < 10);
  String _getWarningMessage() {
    if (hours == 8 && minutes > 0)
      return '* หมายเหตุ: ตั้งเวลาได้สูงสุด 8 ชั่วโมง';
    if (hours == 0 && minutes < 10)
      return '* หมายเหตุ: ตั้งเวลาขั้นต่ำ 10 นาที';
    return '';
  }

  Widget _buildTimeSetter(
    String label,
    int value,
    int maxValue,
    ValueChanged<int> onChanged, {
    int minValue = 0,
  }) {
    final List<int> items = maxValue == 0
        ? [0]
        : List.generate(maxValue - minValue + 1, (i) => minValue + i);
    final initialItem = items.indexOf(value.clamp(minValue, maxValue));

    return Expanded(
      child: Container(
        height: 150,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF9DD0E7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.kanit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 5),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: AbsorbPointer(
                  absorbing: maxValue == 0,
                  child: ListWheelScrollView.useDelegate(
                    key: ValueKey('$minValue-$maxValue'),
                    controller: FixedExtentScrollController(
                      initialItem: initialItem < 0 ? 0 : initialItem,
                    ),
                    itemExtent: 40,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (idx) =>
                        onChanged(items[idx.clamp(0, items.length - 1)]),
                    overAndUnderCenterOpacity: 0.3,
                    childDelegate: maxValue == 0
                        ? ListWheelChildListDelegate(
                            children: [
                              Center(
                                child: Text(
                                  "00",
                                  style: GoogleFonts.kanit(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black38,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListWheelChildListDelegate(
                            children: items
                                .map(
                                  (v) => Center(
                                    child: Text(
                                      v.toString().padLeft(2, '0'),
                                      style: GoogleFonts.kanit(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
