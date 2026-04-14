import 'package:flutter/material.dart';
import 'package:flutter_application_1/api_service.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';

class ResultStatScreen extends StatefulWidget {
  final Map<String, int> statusRewards;
  final User? user;
  final Map<String, int> oldStats; // 🌟 1. เพิ่มตัวแปรเก็บค่าสเตตัสก่อนอัปเกรด
  final bool isSuccess; // 🌟 1. เพิ่มตัวแปรเช็ค สำเร็จ/ไม่สำเร็จ

  const ResultStatScreen({
    Key? key,
    required this.statusRewards,
    this.user,
    this.oldStats = const {}, // ค่าเริ่มต้นเผื่อไม่ได้ส่งมา
    this.isSuccess = true, // ค่าเริ่มต้นคือสำเร็จ เผื่อไม่ได้ส่งมา
  }) : super(key: key);

  @override
  State<ResultStatScreen> createState() => _ResultStatScreenState();
}

class _ResultStatScreenState extends State<ResultStatScreen> {
  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final topBarHeight = 75.0 + topPadding;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/background/bg11.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: Color(0xFFE8F5E9));
              },
            ),
          ),

          // Main Content
          Positioned.fill(
            top: topBarHeight + 80,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🔥 กล่องหลัก
                    Container(
                      constraints: BoxConstraints(maxWidth: 400),
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.70),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Color(0xFF9DD0E7), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // ✅ Success/Fail Text + Icon
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                widget.isSuccess 
                                    ? 'assets/images/icon/check2.png' 
                                    : 'assets/images/icon/X.png', // 🌟 เปลี่ยนไอคอนเป็น X ถ้าไม่สำเร็จ
                                height: 50,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    widget.isSuccess ? Icons.check_circle : Icons.cancel, 
                                    color: widget.isSuccess ? Colors.green : Colors.red,
                                    size: 40
                                  );
                                },
                              ),
                              SizedBox(width: 8),
                              Text(
                                widget.isSuccess ? 'ทำกิจกรรมสำเร็จ' : 'ทำกิจกรรมไม่สำเร็จ', // 🌟 เปลี่ยนข้อความ
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),

                          // ✅ รูปตัวละคร
                          Image.asset(
                            widget.isSuccess 
                                ? 'assets/images/profile/profile-character.png'
                                : 'assets/images/profile/sad-character.png', // 🌟 เปลี่ยนรูปถ้าไม่สำเร็จ
                            height: 250,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.person, size: 100);
                            },
                          ),

                          SizedBox(height: 20),

                          // ✅ Title
                          Text(
                            'ค่าสถานะที่ได้รับ',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),

                          SizedBox(height: 12),

                          // ✅ Status List
                          Column(
                            children: widget.statusRewards.entries.map((entry) {
                              final isIncreased = entry.value > 0;
                              return _buildStatusRow(
                                entry.key,
                                entry.value,
                                isIncreased,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // ✅ ปุ่มเสร็จสิ้น
                    Container(
                      width: 180,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF556AEB), Color(0xFF59ABEC)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(100),
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
                          'เสร็จสิ้น',
                          style: TextStyle(
                            fontSize: 20,
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

  Widget _buildStatusRow(String statusName, int value, bool isIncreased) {
    // 🌟 1. ดึงค่าเริ่มต้นมาจาก oldStats (ถ้าหาไม่เจอให้เริ่มที่ 0)
    int startValue = widget.oldStats[statusName] ?? 0;
    
    // 🌟 2. คำนวณค่าสุดท้าย
    int endValue = startValue + value;

    // 🌟 3. จัดการกรณีพลังงาน
    if (statusName == 'พลังงาน') {
      if (widget.isSuccess) {
        // ถ้าเป็นสวนสาธารณะ (สำเร็จ) และพลังงานเกิน 100 ให้ล็อกไว้ที่ 100
        if (endValue > 100) {
          endValue = 100;
        }
      } else {
        // ถ้าฝึกฝนไม่สำเร็จ (ล้มเหลว) ให้โชว์เลขเดิมของสถานะที่พยายามจะฝึก 
        // (เราไม่ต้องเอาค่าที่ติดลบไปคำนวณ ให้มันวิ่งจากค่าเดิมไปค่าเดิม จะได้นิ่งๆ)
        endValue = startValue;
      }
    } else {
      // สำหรับสเตตัสอื่นๆ ถ้าไม่สำเร็จก็ให้โชว์เลขเดิม
      if (!widget.isSuccess) {
        endValue = startValue;
      }
    }

    // 🌟 4. กำหนดสี: ถ้าสำเร็จและเป็นบวก ให้สีเขียว, ถ้าล้มเหลว (isSuccess เป็น false) ให้สีแดง
    // หมายเหตุ: แม้ค่า value จะเป็นลบ (เสียพลังงานตอนฝึกไม่ผ่าน) แต่เราโชว์เลขเดิมแล้ว เลยใช้ตัวแปร isSuccess เช็คสีแทนเลยจะชัวร์สุดครับ
    Color statColor = widget.isSuccess ? Color(0xFF4CAF50) : Colors.red;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Color(0xFFE0E0E0), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              statusName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            
            // 🌟 ใช้งาน AnimatedStatValue แทน Text ธรรมดา
            AnimatedStatValue(
              startValue: startValue,
              endValue: endValue,
              suffix: "",
              textColor: statColor, // 🌟 ส่งสีเข้าไป
            ),
          ],
        ),
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
            const Center(
              child: Text(
                "ผลลัพธ์หลังทำกิจกรรม",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
          onNotificationTapped: () =>
              Navigator.pushNamed(context, '/notification'),
          onSettingsTapped: () => Navigator.pushNamed(context, '/setting'),
        ),
      ),
    );
  }
}

class AnimatedStatValue extends StatefulWidget {
  final int startValue;
  final int endValue;
  final String suffix; // ไว้เติม (+1) ด้านหลัง
  final Color textColor; // 🌟 รับค่าสีที่ต้องการให้แสดง

  const AnimatedStatValue({
    Key? key,
    required this.startValue,
    required this.endValue,
    this.suffix = "",
    this.textColor = const Color(0xFF4CAF50), // ค่าเริ่มต้นสีเขียว
  }) : super(key: key);

  @override
  State<AnimatedStatValue> createState() => _AnimatedStatValueState();
}

class _AnimatedStatValueState extends State<AnimatedStatValue>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // 🌟 ความเร็ตอนิเมชัน (1.5 วินาที)
    );

    // สร้าง Tween ให้วิ่งจากเลขเดิม ไป เลขใหม่
    _animation = Tween<double>(
      begin: widget.startValue.toDouble(),
      end: widget.endValue.toDouble(),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic, // ให้มันค่อยๆ ช้าลงตอนใกล้จบ
    ));

    // สั่งให้เริ่มเล่น Animation ทันทีที่ Widget โหลดขึ้นมา
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // ปัดเศษทศนิยมทิ้งให้เป็นจำนวนเต็ม
        int currentValue = _animation.value.round();
        return Text(
          "$currentValue ${widget.suffix}",
          style: TextStyle( // 🌟 ลบคำว่า const ออกจากตรงนี้
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: widget.textColor, // 🌟 ตอนนี้จะหาเจอและใช้งานได้ปกติแล้ว
          ),
        );
      },
    );
  }
}