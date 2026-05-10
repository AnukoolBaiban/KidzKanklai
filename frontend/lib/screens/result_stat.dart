import 'package:flutter/material.dart';
import 'package:flutter_application_1/api_service.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:rive/rive.dart' hide LinearGradient, Image;
import 'package:flutter_application_1/config/rive_cache.dart';

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
  SMINumber? _screenModeInput;
  SMITrigger? _missionWinInput;
  SMITrigger? _missionLoseInput;
  SMINumber? _poseInput;
  SMINumber? _hairInput;
  SMINumber? _faceInput;
  SMINumber? _skinInput;
  SMINumber? _clothInput;
  StateMachineController? _controller;
  bool _isRiveLoaded = false;

  String? _encouragementMessage;
  bool _showEncouragement = false;

  @override
  void initState() {
    super.initState();
    _pickRandomMessage();
    // ตั้งให้แสดงผลทันทีหลังบิลด์ครั้งแรกเสร็จ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _showEncouragement = true;
        });
      }
    });
  }

  void _pickRandomMessage() {
    List<String> messages;
    if (widget.isSuccess) {
      messages = ["เก่งมากเลย!", "ยอดเยี่ยมไปเลย!", "ทำได้ดีมาก!", "พัฒนาขึ้นอีกแล้ว!"];
    } else {
      messages = ["ไม่เป็นไรนะ!", "สู้ๆ เริ่มใหม่ได้!", "พยายามอีกนิด!", "อย่าเพิ่งท้อนะ!"];
    }
    messages.shuffle();
    _encouragementMessage = messages.first;
  }

  void _onRiveInit(Artboard artboard) {
    var controller = StateMachineController.fromArtboard(
      artboard,
      'State Machine 1',
    );
    if (controller == null && artboard.stateMachines.isNotEmpty) {
      controller = StateMachineController.fromArtboard(
        artboard,
        artboard.stateMachines.first.name,
      );
    }

    if (controller != null) {
      artboard.addController(controller);
      _controller = controller;

      for (var input in controller.inputs) {
        if (input.name == 'ScreenMode') _screenModeInput = input as SMINumber;
        if (input.name == 'MissionWin') _missionWinInput = input as SMITrigger;
        if (input.name == 'MissionLose') _missionLoseInput = input as SMITrigger;
        if (input.name == 'Pose') _poseInput = input as SMINumber;
        if (input.name == 'HairID') _hairInput = input as SMINumber;
        if (input.name == 'FaceID') _faceInput = input as SMINumber;
        if (input.name == 'SkinID') _skinInput = input as SMINumber;
        if (input.name == 'OutfitID') {
          _clothInput = input as SMINumber;
        }
      }

      _screenModeInput?.value = 1.0;
      _syncRiveToEquipped();

      if (widget.isSuccess) {
        _missionWinInput?.fire();
      } else {
        _missionLoseInput?.fire();
      }
    }
    if (mounted) setState(() => _isRiveLoaded = true);
  }

  double _parseId(String s) {
    if (s.isEmpty) return 0;
    if (s.contains('_')) {
      try {
        return double.parse(s.split('_').last);
      } catch (_) {}
    }
    if (s.contains(' ')) {
      try {
        return double.parse(s.split(' ').last);
      } catch (_) {}
    }
    try {
      return double.parse(s);
    } catch (_) {
      return 0;
    }
  }

  // 🌟 ฟังก์ชันช่วยแก้ปัญหาการเรียงลำดับ HairID ใน Rive Model ที่สลับกัน
  double _getCorrectHairId(double originalId) {
    if (originalId == 2.0) return 3.0; // Hair_02 ในรูป คือ Rive ID 3
    if (originalId == 3.0) return 4.0; // Hair_03 ในรูป คือ Rive ID 4
    if (originalId == 4.0) return 2.0; // Hair_04 ในรูป คือ Rive ID 2
    return originalId;
  }

  void _syncRiveToEquipped() {
    if (_controller == null || widget.user == null) return;

    try {
      if (_hairInput != null) _hairInput!.value = _getCorrectHairId(_parseId(widget.user!.equippedHair));
      if (_faceInput != null) _faceInput!.value = _parseId(widget.user!.equippedFace);
      if (_skinInput != null) _skinInput!.value = _parseId(widget.user!.equippedSkin);
      if (_clothInput != null) {
        _clothInput!.value = _parseId(widget.user!.equippedOutfit);
      }
    } catch (e) {
      print("Error syncing Rive Profile: $e");
    }
  }

  String _getModelAsset() {
    if (widget.user != null) {
      final bt = widget.user!.bodyType.toUpperCase();
      if (bt == 'ADULT') return 'assets/animation/adult.riv';
      if (bt == 'TEEN') return 'assets/animation/teen.riv';
      return 'assets/animation/kid.riv';
    }
    return 'assets/animation/kid.riv';
  }

  double _getTopSpacing() {
    if (widget.user == null) return 40;
    final bt = widget.user!.bodyType.toUpperCase();
    if (bt == 'ADULT') return 100; // ผู้ใหญ่ตัวสูง ลดช่องว่างด้านบน
    if (bt == 'TEEN') return 80; // วัยรุ่นปานกลาง
    return 40; // เด็กตัวเล็ก เพิ่มช่องว่างด้านบน
  }

  double _getCharacterScale() {
    if (widget.user == null) return 1.5;
    final bt = widget.user!.bodyType.toUpperCase();
    if (bt == 'ADULT') return 1.4; // ผู้ใหญ่ตัวใหญ่ ลดสเกลลงนิดนึงเพื่อให้อยู่ในกรอบ
    if (bt == 'TEEN') return 1.4; // วัยรุ่นกลางๆ
    return 1.5; // เด็กตัวเล็ก ขยายสเกลให้เห็นชัด
  }

  Offset _getCharacterOffset() {
    if (widget.user == null) return const Offset(0, 10);
    final bt = widget.user!.bodyType.toUpperCase();
    if (bt == 'ADULT') return const Offset(0, -35); // ผู้ใหญ่ เลื่อนลงมาหน่อยกันหัวขาด
    if (bt == 'TEEN') return const Offset(0, -35);
    return const Offset(0, 10); // เด็ก เลื่อนขึ้นไปนิดนึง
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final topBarHeight = 60.0 + topPadding;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              widget.isSuccess
                  ? 'assets/images/background/bg11.png'
                  : 'assets/images/background/bg13.png',
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
                                  color: widget.isSuccess ? const Color(0xFF4CAF50) : Colors.red,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: _getTopSpacing()), // 🌟 ปรับช่องว่างตามวัยของตัวละคร

                          // ✅ รูปตัวละคร Rive + ลูกศรเด้งขึ้น
                          SizedBox(
                            height: 200,
                            width: 200,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                // ตัวละคร Rive
                                widget.user == null 
                                    ? Image.asset(
                                        widget.isSuccess 
                                            ? 'assets/images/profile/profile-character.png'
                                            : 'assets/images/profile/sad-character.png',
                                        height: 250,
                                      )
                                    : Transform.scale(
                                        scale: _getCharacterScale(), // ปรับขนาดตามวัย
                                        alignment: Alignment.center,
                                        child: Transform.translate(
                                          offset: _getCharacterOffset(), // ปรับตำแหน่งตามวัย
                                          child: (RiveCache().getFile(_getModelAsset()) != null 
                                              ? RiveAnimation.direct(
                                                  RiveCache().getFile(_getModelAsset())!,
                                                  fit: BoxFit.contain,
                                                  onInit: _onRiveInit,
                                                )
                                              : RiveAnimation.asset(
                                                  _getModelAsset(), 
                                                  fit: BoxFit.contain,
                                                  onInit: _onRiveInit,
                                                )),
                                        ),
                                      ),

                                // ลูกศรชี้ขึ้นทางขวา
                                if (widget.isSuccess)
                                  Positioned(
                                    right: 20,
                                    child: const AnimatedUpwardArrow(delayMs: 300),
                                  ),

                                // ลูกศรชี้ขึ้นทางซ้าย
                                if (widget.isSuccess)
                                  Positioned(
                                    left: 20,
                                    child: const AnimatedUpwardArrow(delayMs: 600), // โผล่หลังทางขวาแปปนึง
                                  ),

                                // Bubble ข้อความให้กำลังใจ (ด้านซ้ายของตัวละคร)
                                if (_showEncouragement && _encouragementMessage != null)
                                  Positioned(
                                    left: -80, // เลยขอบซ้ายออกไปเยอะๆ จะได้ไม่โดนทับ
                                    top: 60, // ระดับแก้มตัวละคร
                                    child: _buildEncouragementBubble(),
                                  ),
                              ],
                            ),
                          ),

                          SizedBox(height: 20),

                          // ✅ Title
                          Text(
                            'ค่าสถานะที่เปลี่ยนแปลง',
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

  Widget _buildEncouragementBubble() {
    return AnimatedOpacity(
      opacity: _showEncouragement ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: CustomPaint(
        painter: _SideBubblePainter(),
        child: Container(
          constraints: BoxConstraints(maxWidth: 140), // กว้างสุดแค่นี้พอ เพราะอยู่ในกล่อง
          padding: const EdgeInsets.fromLTRB(14, 10, 24, 10), // เว้นขวาให้หาง
          child: Text(
            _encouragementMessage ?? '',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF333333),
            ),
            textAlign: TextAlign.center,
          ),
        ),
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
        // ถ้าฝึกฝนไม่สำเร็จ (ล้มเหลว) ยอมให้ค่าลดลง (กรณีเสียพลังงาน)
        endValue = startValue + value;
        if (endValue < 0) endValue = 0;
      }
    } else {
      // สำหรับสเตตัสอื่นๆ ถ้าไม่สำเร็จก็ให้โชว์เลขเดิม
      if (!widget.isSuccess) {
        endValue = startValue;
      }
    }

    // 🌟 4. กำหนดสี: ถ้าเป็นบวก ให้สีเขียว, ถ้าลดลง ให้สีแดง ถ้าไม่เปลี่ยนให้สีดำ (ทั้งกรณีสำเร็จและไม่สำเร็จ)
    Color statColor = Colors.black;
    if (value > 0) {
      statColor = const Color(0xFF4CAF50);
    } else if (value < 0) {
      statColor = Colors.red;
    }

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
        padding: EdgeInsets.only(top: topPadding),
        color: Colors.black.withOpacity(0.4),
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
        
        // ถ้าค่าไม่เปลี่ยน ให้แสดงเลขเดียวเป็นสีตาม textColor
        if (widget.startValue == widget.endValue) {
          return Text(
            "$currentValue ${widget.suffix}".trim(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: widget.textColor,
            ),
          );
        }

        // 🌟 ปรับรูปแบบการแสดงผลเป็น "ค่าเก่า -> " (สีดำ) และ "ค่าใหม่" (สีตาม textColor)
        return RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            children: [
              TextSpan(
                text: "${widget.startValue} -> ",
                style: const TextStyle(color: Colors.black),
              ),
              TextSpan(
                text: "$currentValue ${widget.suffix}".trim(),
                style: TextStyle(color: widget.textColor),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AnimatedUpwardArrow extends StatefulWidget {
  final int delayMs;
  const AnimatedUpwardArrow({Key? key, this.delayMs = 300}) : super(key: key);

  @override
  State<AnimatedUpwardArrow> createState() => _AnimatedUpwardArrowState();
}

class _AnimatedUpwardArrowState extends State<AnimatedUpwardArrow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5), // เริ่มต้นต่ำกว่าเล็กน้อย
      end: const Offset(0, -1.0),  // ลอยขึ้นไปด้านบน
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20), // ค่อยๆ โผล่
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40), // ค้างไว้ให้เห็นชัดๆ
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40), // ค่อยๆ จางหายไป
    ]).animate(_controller);

    // หน่วงเวลาเล็กน้อยให้ตัวละครโผล่มาก่อน แล้วลูกศรค่อยเด้งขึ้นมา
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.arrow_upward_rounded,
              color: Color(0xFF4CAF50), // สีเขียว
              size: 50,
            ),
            Text(
              "UP!",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4CAF50), // สีเขียว
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// Custom Painter สำหรับวาดกล่องข้อความที่มีหางชี้ไปหาตัวละคร
// ==========================================
class _SideBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final bubbleWidth = size.width - 12; // เว้นพื้นที่ 12px ทางขวาให้หาง
    const radius = Radius.circular(16);
    final rect = RRect.fromLTRBR(0, 0, bubbleWidth, size.height, radius);

    final path = Path()..addRRect(rect);
    
    // เติมหางชี้ไปทางขวา (ระดับกลางค่อนไปล่างนิดนึง)
    path.moveTo(bubbleWidth - 1, size.height / 2 - 8);
    path.lineTo(size.width, size.height / 2 + 2); // จุดปลายแหลม
    path.lineTo(bubbleWidth - 1, size.height / 2 + 12);
    path.close();

    // วาดเงาทีเดียวรวมกันทั้งกล่องและหาง
    canvas.drawPath(path.shift(const Offset(0, 4)), shadowPaint);
    // วาดกล่องข้อความทับ
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
