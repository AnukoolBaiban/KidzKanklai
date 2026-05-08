import 'package:flutter/material.dart';
import 'package:flutter_application_1/api_service.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:rive/rive.dart' hide LinearGradient, Image;
import 'package:flutter_application_1/config/rive_cache.dart';
import 'package:flutter_application_1/widgets/reward_popup.dart'; // 🌟 นำเข้า RewardPopup

class ResultExamScreen extends StatefulWidget {
  final Map<String, int> statusRewards;
  final User? user;
  final bool isPassed;
  // 🌟 เพิ่มตัวแปรสำหรับรับข้อมูลรางวัลและเลเวลอัพ
  final List<dynamic> rawRewards;
  final bool leveledUp;
  final int baseLevel;
  final int newLevel;

  const ResultExamScreen({
    Key? key,
    required this.statusRewards,
    this.user,
    required this.isPassed,
    this.rawRewards = const [],
    this.leveledUp = false,
    this.baseLevel = 0,
    this.newLevel = 0,
  }) : super(key: key);

  @override
  State<ResultExamScreen> createState() => _ResultExamScreenState();
}

class _ResultExamScreenState extends State<ResultExamScreen> {
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

      if (widget.isPassed) {
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
    if (bt == 'ADULT') return 1.4;
    if (bt == 'TEEN') return 1.4;
    return 1.5;
  }

  Offset _getCharacterOffset() {
    if (widget.user == null) return const Offset(0, 10);
    final bt = widget.user!.bodyType.toUpperCase();
    if (bt == 'ADULT') return const Offset(0, -35);
    if (bt == 'TEEN') return const Offset(0, -35);
    return const Offset(0, 10);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final topBarHeight = 60.0 + topPadding;
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = (screenWidth / 375).clamp(0.8, 1.2);

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              widget.isPassed
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
                              ),
                              SizedBox(width: 8),
                              Text(
                                widget.isPassed
                                    ? 'คุณสอบผ่าน'
                                    : 'คุณสอบไม่ผ่าน',
                                style: TextStyle(
                                  fontSize: 28 * scale,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: _getTopSpacing()), // 🌟 ปรับช่องว่างตามวัยของตัวละคร

                          // ✅ รูปตัวละคร Rive พร้อมแสง Glow ข้างหลัง
                          SizedBox(
                            height: 200,
                            width: 200,
                            child: Stack(
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
                                // ตัวละคร Rive
                                widget.user == null
                                    ? Image.asset(
                                        widget.isPassed
                                            ? 'assets/images/profile/profile-character.png'
                                            : 'assets/images/profile/sad-character.png',
                                        height: 230 * scale,
                                      )
                                    : Transform.scale(
                                        scale: _getCharacterScale(),
                                        alignment: Alignment.center,
                                        child: Transform.translate(
                                          offset: _getCharacterOffset(),
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
                              ],
                            ),
                          ),

                          SizedBox(height: 20 * scale),

                          widget.isPassed
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
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        // 🌟 ใช้ .map() เพื่อดึงของรางวัลจาก API มาสร้างกล่องแบบไดนามิก
                                        children: widget.statusRewards.isEmpty
                                            ? [
                                                // 🌟 กรณีไม่มีของรางวัล (เช่น สอบตก)
                                                _buildRewardItem('assets/images/item/EXP.png', '+0', scale)
                                              ]
                                            : widget.statusRewards.entries.map((entry) {
                                                String itemName = entry.key.toUpperCase();
                                                String imgPath = 'assets/images/item/EXP.png'; // รูปเริ่มต้นเป็น EXP
                                                String prefix = '+';

                                                // 🌟 ดักจับคำในชื่อไอเทม เพื่อเลือกรูปภาพให้ถูกต้อง
                                                if (itemName.contains('COIN') || itemName.contains('เหรียญ')) {
                                                  imgPath = 'assets/images/item/coin.png'; // เปลี่ยนเป็น path รูปเหรียญของคุณ
                                                } else if (itemName.contains('GASHA') || itemName.contains('กาชา')) {
                                                  imgPath = 'assets/images/item/Gasha.png';
                                                  prefix = 'x';
                                                } else if (itemName.contains('TICKET') || itemName.contains('ตั๋ว')) {
                                                  imgPath = 'assets/images/item/Ticket_exam_img.png';
                                                  prefix = 'x';
                                                }

                                                return Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 8 * scale),
                                                  child: _buildRewardItem(imgPath, '$prefix${entry.value}', scale),
                                                );
                                              }).toList(),
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      Text(
                                        'หมายเหตุ',
                                        style: TextStyle(
                                          fontSize: 20 * scale,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 12 * scale),
                                      Text(
                                        'เพิ่มค่าสถานะให้ถึงระดับที่กำหนด\nเพื่อเพิ่มเปอร์เซ็นต์ในการสอบผ่าน',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14 * scale,
                                          fontWeight: FontWeight.normal,
                                          color: Colors.black54,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
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
                        onPressed: () async {
                          if (widget.isPassed && (widget.rawRewards.isNotEmpty || widget.leveledUp)) {
                            // 🌟 แปลง rawRewards เป็น RewardData สำหรับ Popup
                            List<RewardData> popupRewards = widget.rawRewards.map<RewardData>((rw) {
                              return RewardData(
                                type: rw['name'] == 'EXP' ? 'EXP' : 'ITEM',
                                amount: rw['added'] ?? rw['amount'] ?? 0,
                                itemName: rw['name'],
                                itemImage: rw['image'],
                              );
                            }).toList();
                            
                            // 🌟 แสดง RewardPopup (ซึ่งจะจัดการแสดง LevelUpPopup ต่อให้อัตโนมัติถ้าอัพเลเวล)
                            await RewardPopup.show(
                              context,
                              rewards: popupRewards,
                              leveledUp: widget.leveledUp,
                              baseLevel: widget.baseLevel,
                              newLevel: widget.newLevel,
                              user: widget.user,
                            );
                            
                            // ปิด ResultExamScreen หลังจากรับรางวัลเสร็จแล้ว
                            if (mounted) {
                              Navigator.pop(context);
                            }
                          } else {
                            Navigator.pop(context);
                          }
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

  Widget _buildRewardItem(String imagePath, String text, double scale) {
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
          // Item Image
          Image.asset(
            imagePath,
            width: 40 * scale,
            height: 40 * scale,
            fit: BoxFit.contain,
          ),
          SizedBox(height: 4 * scale),
          // Amount below image
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
                  "ผลลัพธ์การสอบ",
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
